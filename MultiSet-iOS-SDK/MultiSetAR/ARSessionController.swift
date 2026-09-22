/*
Copyright (c) 2026 MultiSet AI. All rights reserved.
Licensed under the MultiSet License. You may not use this file except in compliance with the License. and you can't re-distribute this file without a prior notice
For license details, visit www.multiset.ai.
Redistribution in source or binary forms must retain this notice.
*/

import Foundation
import ARKit
import RealityKit
import MultiSetSDK

/// Owns the ARSession delegate and forwards what ARKit reports to the SDK
final class ARSessionController: NSObject, ARSessionDelegate {

    var session: ARSession?
    var arView: ARView?
    var gizmoAnchor: AnchorEntity?

    /// How long a resumed session may spend relocalizing before the adapter gives up and
    /// starts a new world frame. ARKit does not time this out itself: if the device was
    /// carried elsewhere while the app was backgrounded there is nothing left to
    /// relocalize against, and the session stays in `.limited(.relocalizing)`
    /// indefinitely — a state in which `ARSessionFrameSource` can never return a frame
    /// and every localization fails on "no frames captured".
    private static let relocalizationTimeout: TimeInterval = 6.0

    private var relocalizationWatchdog: Task<Void, Never>?

    @MainActor
    func resetWorldOrigin() {
        session?.pause()
        restartTracking()
    }

    /// Starts a new world frame and tells the SDK, so the pose gate discards an anchor
    /// measured in the frame being thrown away rather than comparing across the two.
    @MainActor
    private func restartTracking() {
        cancelRelocalizationWatchdog()
        session?.run(createARConfiguration(), options: [.resetTracking])

        MultiSet.shared.notifyWorldOriginReset()

        MultiSetARScene.shared.renderer.resetMapAnchor()
    }

    // MARK: - Relocalization Watchdog

    @MainActor
    private func startRelocalizationWatchdog() {
        cancelRelocalizationWatchdog()

        relocalizationWatchdog = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(Self.relocalizationTimeout * 1_000_000_000))
            guard !Task.isCancelled, let self = self else { return }

            // A nil frame counts as not recovered: it is the same dead session seen from
            // one step further back.
            let state = self.session?.currentFrame?.camera.trackingState
            guard state != .normal else { return }

            print("MultiSetSDK >> Relocalization did not recover in \(Self.relocalizationTimeout)s - starting a new world frame")
            self.restartTracking()
        }
    }

    @MainActor
    private func cancelRelocalizationWatchdog() {
        relocalizationWatchdog?.cancel()
        relocalizationWatchdog = nil
    }

    /// Called when the view that owns this controller goes away. Without it a pending
    /// watchdog would fire against a session the SDK has already been detached from and
    /// restart tracking underneath whatever replaced it.
    @MainActor
    func teardown() {
        cancelRelocalizationWatchdog()
    }

    // MARK: - AR Configuration

    func createARConfiguration() -> ARWorldTrackingConfiguration {
        let configuration = ARWorldTrackingConfiguration()
        configuration.worldAlignment = .gravity
        configuration.isAutoFocusEnabled = true

        if type(of: configuration).supportsFrameSemantics(.sceneDepth) {
            configuration.frameSemantics = .sceneDepth
        }
        return configuration
    }

    // MARK: - ARSessionDelegate

    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        DispatchQueue.main.async {
            if camera.trackingState == .normal {
                self.cancelRelocalizationWatchdog()
            }
            MultiSet.shared.forwardARTrackingState(camera.trackingState)
        }
    }

    func sessionWasInterrupted(_ session: ARSession) {
        print("MultiSetSDK >> AR session interrupted")
        DispatchQueue.main.async {
            self.cancelRelocalizationWatchdog()
            MultiSet.shared.notifyTrackingInterrupted()
        }
    }

    func sessionInterruptionEnded(_ session: ARSession) {
        print("MultiSetSDK >> AR session interruption ended")
        DispatchQueue.main.async {
            MultiSet.shared.notifyTrackingInterrupted()
            self.startRelocalizationWatchdog()
        }
    }

    /// ARKit is allowed to try: a short interruption that relocalizes keeps the world
    /// frame, and with it every anchor already placed in it. `startRelocalizationWatchdog`
    /// covers the case it cannot recover from.
    func sessionShouldAttemptRelocalization(_ session: ARSession) -> Bool {
        return true
    }
}
