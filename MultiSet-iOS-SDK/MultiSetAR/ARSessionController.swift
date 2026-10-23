/*
Copyright (c) 2026 MultiSet AI. All rights reserved.
Licensed under the MultiSet License. You may not use this file except in compliance with the License. and you can't re-distribute this file without a prior notice
For license details, visit www.multiset.ai.
Redistribution in source or binary forms must retain this notice.
*/

import Foundation
import ARKit
import RealityKit
import UIKit
import MultiSetSDK

/// Owns the ARSession delegate and forwards what ARKit reports to the SDK
final class ARSessionController: NSObject, ARSessionDelegate {

    var session: ARSession?
    var arView: ARView?
    var gizmoAnchor: AnchorEntity?

    /// The session is paused because the app is in the background.
    private var isPausedForBackground = false
    /// Frames up to here were taken before the app's last trip to the background. Until ARKit
    /// delivers a new one, `currentFrame` still shows the place the device was carried away from.
    private(set) var framesStaleUpTo: TimeInterval = 0
    private var freshTrackingReport: Task<Void, Never>?
    private var lifecycleObservers: [NSObjectProtocol] = []

    @MainActor
    func resetWorldOrigin() {
        session?.pause()
        restartTracking()
    }

    /// Starts a new world frame and tells the SDK, so the pose gate discards an anchor
    /// measured in the frame being thrown away rather than comparing across the two.
    /// Same options as the MultiSet apps: no ARKit anchor from the old frame survives into it.
    @MainActor
    private func restartTracking() {
        session?.run(createARConfiguration(), options: [.resetTracking, .removeExistingAnchors])

        MultiSet.shared.notifyWorldOriginReset()

        MultiSetARScene.shared.renderer.resetMapAnchor()
    }

    /// Called when the view that owns this controller goes away, so nothing it scheduled reports
    /// tracking for a session the SDK has already been detached from.
    @MainActor
    func teardown() {
        freshTrackingReport?.cancel()
        lifecycleObservers.forEach(NotificationCenter.default.removeObserver)
        lifecycleObservers.removeAll()
    }

    // MARK: - App Lifecycle

    /// The trip to the background is handled here rather than left to RealityKit and ARKit.
    @MainActor
    func observeAppLifecycle() {
        guard lifecycleObservers.isEmpty else { return }
        let center = NotificationCenter.default
        lifecycleObservers = [
            center.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.appDidEnterBackground() }
            },
            center.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.appDidBecomeActive() }
            }
        ]
    }

    @MainActor
    private func appDidEnterBackground() {
        guard let session, MultiSetARScene.shared.isAttached(session) else { return }
        freshTrackingReport?.cancel()
        framesStaleUpTo = max(framesStaleUpTo, session.currentFrame?.timestamp ?? 0)
        isPausedForBackground = true
        session.pause()
        // An interruption plus tracking reported as not normal, so a host's localize button stays
        // off until tracking is back.
        MultiSet.shared.forwardARTrackingState(.notAvailable)
    }

    /// A fresh world frame, as the MultiSet Field app does. Resumed instead, the session carried
    /// on from the pose the app left at, or relocalized into the old frame, and neither matches a
    /// room the device was walked away from: a fix made after the trip was moved off it again.
    @MainActor
    private func appDidBecomeActive() {
        guard isPausedForBackground else { return }
        isPausedForBackground = false
        print("MultiSetSDK >> Back from the background - starting a new world frame")
        restartTracking()
        reportTrackingOnceFresh()
    }

    /// Forwards the tracking state of the first frame taken from now on. A recovery the SDK arms
    /// waits for tracking to be reported normal, and ARKit may already be there, with no change
    /// left to report.
    @MainActor
    private func reportTrackingOnceFresh() {
        let since = max(framesStaleUpTo, session?.currentFrame?.timestamp ?? 0)
        freshTrackingReport?.cancel()
        freshTrackingReport = Task { @MainActor [weak self] in
            for _ in 0..<50 {
                try? await Task.sleep(nanoseconds: 100_000_000)
                guard let self, !Task.isCancelled else { return }
                if let frame = self.session?.currentFrame, frame.timestamp > since {
                    MultiSet.shared.forwardARTrackingState(frame.camera.trackingState)
                    return
                }
            }
        }
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
            MultiSet.shared.forwardARTrackingState(camera.trackingState)
        }
    }

    func sessionWasInterrupted(_ session: ARSession) {
        print("MultiSetSDK >> AR session interrupted")
        DispatchQueue.main.async {
            MultiSet.shared.notifyTrackingInterrupted()
        }
    }

    func sessionInterruptionEnded(_ session: ARSession) {
        print("MultiSetSDK >> AR session interruption ended")
        DispatchQueue.main.async {
            MultiSet.shared.notifyTrackingInterrupted()
            self.reportTrackingOnceFresh()
        }
    }

    /// No relocalization: after an interruption ARKit resets tracking and starts at
    /// `.limited(.initializing)`, which the SDK treats as a new world frame. Allowed to
    /// relocalize, ARKit could fit the old frame back on late, or onto the wrong place once the
    /// device had been carried elsewhere, moving a fix made after the interruption off with it.
    func sessionShouldAttemptRelocalization(_ session: ARSession) -> Bool {
        return false
    }
}
