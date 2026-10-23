/*
Copyright (c) 2026 MultiSet AI. All rights reserved.
Licensed under the MultiSet License. You may not use this file except in compliance with the License. and you can't re-distribute this file without a prior notice
For license details, visit www.multiset.ai.
Redistribution in source or binary forms must retain this notice.
*/

import ARKit
import RealityKit
import UIKit
import MultiSetSDK

/// The ARKit session a map scan runs on, configured to match the Unity mapper.
///
/// Every setting is load-bearing: `.smoothedSceneDepth` would apply temporal smoothing the
/// shipped depth files do not have. Classification is requested only to colour the surfaces
/// `ScanMeshRenderer` draws; the map's mesh is written from the anchors' geometry and carries
/// no labels.
///
/// A `.posedRGB` source runs with neither depth nor reconstruction, draws ARKit's feature
/// points instead of the mesh, and reports every camera update to the SDK, which decides
/// from them which frames may be kept.
///
/// `automaticallyConfigureSession: false` means RealityKit never runs a session of its own,
/// so the camera stays black until the SDK calls `startPreview()` or `startRecording()`.
@MainActor
final class ARMappingSource: NSObject, MultiSetMappingSource, ARSessionDelegate {

    let arView: ARView
    let captureKind: MappingCaptureKind
    /// LiDAR only: the reconstruction drawn while recording.
    let meshRenderer: ScanMeshRenderer?
    /// Posed RGB only: the coverage cloud drawn while recording.
    let pointCloud: FeaturePointCloudRenderer?
    /// Posed RGB only: the coverage cloud's source, fed from the delegate's own thread.
    nonisolated let featurePoints: FeaturePointCollector?

    // `ARSession.currentFrame` is safe to read from any thread; the SDK samples it off main.
    nonisolated(unsafe) private let captureSession: ARSession
    private let location = CoreLocationGeoHintProvider()

    private var session: ARSession { arView.session }

    init(kind: MappingCaptureKind = .lidar) {
        captureKind = kind
        arView = ARView(frame: .zero, cameraMode: .ar, automaticallyConfigureSession: false)
        let isPosedRGB = kind == .posedRGB
        meshRenderer = isPosedRGB ? nil : ScanMeshRenderer(arView: arView)
        pointCloud = isPosedRGB ? FeaturePointCloudRenderer(arView: arView) : nil
        featurePoints = isPosedRGB ? FeaturePointCollector() : nil
        captureSession = arView.session
        super.init()
        arView.renderOptions = [
            .disableMotionBlur, .disableDepthOfField, .disableHDR, .disablePersonOcclusion,
            .disableGroundingShadows, .disableAREnvironmentLighting, .disableCameraGrain
        ]
        session.delegate = self
        if isPosedRGB {
            // Removed with the source: a selector observer does not outlive its target.
            NotificationCenter.default.addObserver(
                self, selector: #selector(didReceiveMemoryWarning),
                name: UIApplication.didReceiveMemoryWarningNotification, object: nil)
        }
    }

    // MARK: - MultiSetMappingSource

    var locationProvider: MultiSetGeoHintProvider? { location }

    func authorizeCamera() async -> Bool {
        await MappingCameraAccess.authorize()
    }

    func startPreview() {
        UIApplication.shared.isIdleTimerDisabled = true
        session.run(makeConfiguration(recording: false), options: [])
        meshRenderer?.end()
        featurePoints?.stop()
        pointCloud?.end()
    }

    /// The reset puts the world origin at the device pose the scan begins from — the frame
    /// every saved pose is expressed in. A preview must never reset, or it would move that
    /// origin out from under the scan.
    func startRecording() {
        // ARKit raises an exception for a frame semantic the device cannot produce.
        guard MappingSupport.supports(captureKind) else {
            MultiSet.shared.mapping.reportSourceFailure(
                captureKind == .lidar ? MappingSupport.lidarUnavailableMessage : MappingSupport.unsupportedMessage)
            return
        }
        UIApplication.shared.isIdleTimerDisabled = true
        session.run(makeConfiguration(recording: true), options: [.resetTracking, .removeExistingAnchors])
        meshRenderer?.begin()
        if let pointCloud {
            pointCloud.begin()
            featurePoints?.start { [weak pointCloud] update in pointCloud?.apply(update) }
        }
    }

    func pause() {
        session.pause()
        meshRenderer?.suspend()
        featurePoints?.stop()
        pointCloud?.suspend()
        UIApplication.shared.isIdleTimerDisabled = false
    }

    func trackingSample() -> MappingTrackingSample? {
        session.currentFrame.map(Self.sample(from:))
    }

    /// Image and pose from one `ARFrame`; nothing of the frame outlives the call but its buffer.
    nonisolated func acquireRGBFrame() -> MappingRGBFrame? {
        guard let frame = captureSession.currentFrame,
              case .normal = frame.camera.trackingState else { return nil }
        return MappingRGBFrame(
            pixelBuffer: frame.capturedImage,
            cameraTransform: frame.camera.transform,
            intrinsics: frame.camera.intrinsics,
            timestamp: frame.timestamp)
    }

    /// Image, depth and pose come from one `ARFrame`, and nothing of the frame outlives the
    /// call except its two buffers: holding `ARFrame`s starves ARKit's buffer pool.
    nonisolated func acquireMappingFrame() -> MappingFrame? {
        guard let frame = captureSession.currentFrame,
              case .normal = frame.camera.trackingState,
              let depth = frame.sceneDepth?.depthMap else { return nil }
        return MappingFrame(
            pixelBuffer: frame.capturedImage,
            depthMap: depth,
            cameraTransform: frame.camera.transform,
            intrinsics: frame.camera.intrinsics)
    }

    /// ARKit refines its mesh anchors continuously, so what the session holds at stop is
    /// the finished reconstruction.
    func meshChunks() -> [MappingMeshChunk] {
        let anchors = session.currentFrame?.anchors.compactMap { $0 as? ARMeshAnchor } ?? []
        return anchors.compactMap(ARMeshGeometry.chunk(from:))
    }

    // MARK: - Configuration

    private func makeConfiguration(recording: Bool) -> ARWorldTrackingConfiguration {
        let configuration = ARWorldTrackingConfiguration()
        configuration.worldAlignment = .gravity
        configuration.planeDetection = []
        // Only a posed-RGB scan reads the light estimate, to say "too dark" before its feature
        // points thin out; LiDAR ranges in the dark and Unity runs without it.
        configuration.isLightEstimationEnabled = captureKind == .posedRGB
        configuration.isAutoFocusEnabled = true
        // The capture format is a plain halving of 1920×1440; do not rely on it being the default.
        // A posed-RGB device without it scans at its default, halved; the SDK sizes from the frame.
        if let format = ARWorldTrackingConfiguration.supportedVideoFormats.first(where: {
            $0.imageResolution == CGSize(width: 1920, height: 1440)
        }) {
            configuration.videoFormat = format
        }
        // A preview carries neither: it keeps ten minutes of LiDAR reconstruction off the
        // thermal budget of a scan that has not begun.
        if recording, captureKind == .lidar {
            configuration.frameSemantics = [.sceneDepth]
            let classifies = ARWorldTrackingConfiguration.supportsSceneReconstruction(.meshWithClassification)
            configuration.sceneReconstruction = classifies ? .meshWithClassification : .mesh
        }
        return configuration
    }

    /// Only plain values leave the frame, so the sample can hop actors without holding it.
    private nonisolated static func sample(from frame: ARFrame) -> MappingTrackingSample {
        MappingTrackingSample(
            cameraTransform: frame.camera.transform,
            intrinsics: frame.camera.intrinsics,
            imageWidth: Int(frame.camera.imageResolution.width),
            imageHeight: Int(frame.camera.imageResolution.height),
            timestamp: frame.timestamp,
            trackingState: MappingTrackingState(frame.camera.trackingState),
            featurePointCount: frame.rawFeaturePoints?.points.count ?? 0,
            ambientIntensity: frame.lightEstimate.map { Float($0.ambientIntensity) })
    }

    @objc private func didReceiveMemoryWarning() {
        featurePoints?.coarsen()
    }

    // MARK: - ARSessionDelegate

    /// Posed RGB only. The `ARFrame` itself must not be captured by the hop, or ARKit's frame
    /// pool starves within seconds.
    nonisolated func session(_ session: ARSession, didUpdate frame: ARFrame) {
        guard let featurePoints else { return }
        let sample = Self.sample(from: frame)
        featurePoints.offer(frame)
        Task { @MainActor in MultiSet.shared.mapping.reportTrackingSample(sample) }
    }

    nonisolated func session(_ session: ARSession, didFailWithError error: any Error) {
        let message = error.localizedDescription
        Task { @MainActor in MultiSet.shared.mapping.reportSourceFailure(message) }
    }

    /// Tracking after an interruption is in a different world frame; the SDK ends the scan.
    nonisolated func sessionWasInterrupted(_ session: ARSession) {
        Task { @MainActor in await MultiSet.shared.mapping.reportSourceInterrupted() }
    }

    nonisolated func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        forwardMeshAnchors(anchors) { $0.update($1) }
    }

    nonisolated func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        forwardMeshAnchors(anchors) { $0.update($1) }
    }

    nonisolated func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
        forwardMeshAnchors(anchors) { $0.remove($1) }
    }

    private nonisolated func forwardMeshAnchors(
        _ anchors: [ARAnchor],
        _ apply: @escaping @MainActor (ScanMeshRenderer, [ARMeshAnchor]) -> Void
    ) {
        let meshAnchors = anchors.compactMap { $0 as? ARMeshAnchor }
        guard !meshAnchors.isEmpty else { return }
        Task { @MainActor in
            guard let meshRenderer = self.meshRenderer else { return }
            apply(meshRenderer, meshAnchors)
        }
    }
}

private extension MappingTrackingState {
    init(_ state: ARCamera.TrackingState) {
        switch state {
        case .normal: self = .normal
        case .notAvailable: self = .unavailable
        case .limited(.initializing): self = .initializing
        case .limited(.relocalizing): self = .relocalizing
        case .limited(.excessiveMotion): self = .excessiveMotion
        case .limited: self = .insufficientFeatures
        }
    }
}
