/*
Copyright (c) 2026 MultiSet AI. All rights reserved.
Licensed under the MultiSet License. You may not use this file except in compliance with the License. and you can't re-distribute this file without a prior notice
For license details, visit www.multiset.ai.
Redistribution in source or binary forms must retain this notice.
*/

import Foundation
import ARKit
import UIKit
import MultiSetSDK

/// Reads the current ARKit frame into a `CameraFrame`. Passes the raw camera pose and
/// intrinsics; the SDK applies the portrait correction.
final class ARSessionFrameSource: MultiSetFrameSource {

    let session: ARSession

    /// Restarting tracking needs the configuration and the watchdog the controller owns,
    /// so the reset is delegated rather than re-running the session from here.
    weak var sessionController: ARSessionController?

    init(session: ARSession) {
        self.session = session
    }

    @MainActor
    func acquireFrame() async -> CameraFrame? {
        guard let frame = session.currentFrame else {
            print("MultiSetSDK >> ARSession has no current frame - is session.run(_:) called and the view on screen?")
            return nil
        }

        guard frame.camera.trackingState == .normal else {
            print("MultiSetSDK >> Frame not ready for capture - tracking state: \(frame.camera.trackingState.diagnosticLabel)")
            return nil
        }

        let interfaceOrientation = UIApplication
            .shared
            .connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?
            .interfaceOrientation ?? .portrait

        return CameraFrame(
            pixelBuffer: frame.capturedImage,
            cameraTransform: frame.camera.transform,
            intrinsics: frame.camera.intrinsics,
            orientation: interfaceOrientation.isLandscape ? .landscape : .portrait,
            timestamp: frame.timestamp
        )
    }

    var isHostActive: Bool {
        return UIApplication.shared.applicationState == .active
    }

    @MainActor
    func resetWorldOrigin() {
        sessionController?.resetWorldOrigin()
    }
}

private extension ARCamera.TrackingState {
    var diagnosticLabel: String {
        switch self {
        case .notAvailable:
            return "not available"
        case .limited(.initializing):
            return "limited (initializing - move the device to start tracking)"
        case .limited(.excessiveMotion):
            return "limited (excessive motion - move more slowly)"
        case .limited(.insufficientFeatures):
            return "limited (insufficient features - point at a more textured surface)"
        case .limited(.relocalizing):
            return "limited (relocalizing)"
        case .limited:
            return "limited"
        case .normal:
            return "normal"
        }
    }
}
