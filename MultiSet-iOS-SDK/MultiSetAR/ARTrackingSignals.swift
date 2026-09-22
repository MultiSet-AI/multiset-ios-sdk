/*
Copyright (c) 2026 MultiSet AI. All rights reserved.
Licensed under the MultiSet License. You may not use this file except in compliance with the License. and you can't re-distribute this file without a prior notice
For license details, visit www.multiset.ai.
Redistribution in source or binary forms must retain this notice.
*/

import Foundation
import ARKit
import MultiSetSDK

extension MultiSet {

    /// Maps ARKit's tracking state onto the SDK's session signals. `.initializing` means a
    /// new world frame, so the pose reference is dropped; relocalizing and unavailable are
    /// recoverable, so it is only marked stale. The gate signal goes first.
    func forwardARTrackingState(_ trackingState: ARCamera.TrackingState) {
        switch trackingState {
        case .normal:
            break
        case .limited(.relocalizing), .notAvailable:
            notifyTrackingInterrupted()
        case .limited(.initializing):
            notifyWorldOriginReset()
        case .limited:
            break
        @unknown default:
            notifyTrackingInterrupted()
        }

        reportTrackingState(trackingState == .normal ? .tracking : .paused)
    }
}
