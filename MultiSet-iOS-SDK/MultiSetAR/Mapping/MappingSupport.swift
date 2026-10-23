/*
Copyright (c) 2026 MultiSet AI. All rights reserved.
Licensed under the MultiSet License. You may not use this file except in compliance with the License. and you can't re-distribute this file without a prior notice
For license details, visit www.multiset.ai.
Redistribution in source or binary forms must retain this notice.
*/

import ARKit
import MultiSetSDK

enum MappingSupport {

    /// The devices on which a scan produces depth and mesh: iPhone 12 Pro and later Pro
    /// models, iPad Pro 2020 and later.
    ///
    /// Refuse a scan where it is chosen rather than where it starts. The preview needs
    /// neither depth nor meshing, so an ungated device would show a working camera and then
    /// fail the moment Start was tapped.
    static var supportsLiDARScan: Bool {
        ARWorldTrackingConfiguration.isSupported
            && ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth)
            && ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh)
    }

    /// A posed-RGB scan needs nothing beyond world tracking.
    static var supportsPosedRGBScan: Bool {
        ARWorldTrackingConfiguration.isSupported
    }

    /// The scans this device can record, the better one first. Empty when it cannot track the world.
    static var captureKinds: [MappingCaptureKind] {
        [MappingCaptureKind.lidar, .posedRGB].filter(supports)
    }

    static func supports(_ kind: MappingCaptureKind) -> Bool {
        switch kind {
        case .lidar: return supportsLiDARScan
        case .posedRGB: return supportsPosedRGBScan
        @unknown default: return false
        }
    }

    static let unsupportedTitle = "This device can't scan maps"

    static let unsupportedMessage = "Building a VPS map needs world tracking, which this "
        + "device does not support."

    static let lidarUnavailableMessage = "A LiDAR scan needs the LiDAR scanner, which "
        + "this device does not have — it takes an iPhone 12 Pro or a later Pro model, "
        + "or an iPad Pro from 2020 onwards. Choose Non-LiDAR instead."
}
