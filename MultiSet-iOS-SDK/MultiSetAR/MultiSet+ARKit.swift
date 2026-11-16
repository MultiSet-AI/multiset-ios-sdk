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

/// How the map anchor `MultiSetARView` owns moves to each new fix.
public enum AlignmentSmoothing: Equatable {

    /// Jump straight to each fix, as in 2.3.0.
    case off

    /// Glide to each fix over this many seconds: linear in position, spherical in rotation.
    /// The first placement, and the first fix after the scene was out of place, still jump.
    case interpolate(seconds: Double)
}

/// The 1.x ARKit-typed API, kept source-compatible on top of the platform boundary
extension MultiSet {

    /// Set the AR session for localization
    /// - Parameter session: The ARSession to use for capturing frames
    public func setARSession(_ session: ARSession?) {
        setFrameSource(MultiSetARScene.shared.frameSource(for: session))
    }

    /// Set the parent entity for mesh rendering
    /// - Parameter entity: The RealityKit entity to parent meshes to
    public func setParentEntity(_ entity: Entity?) {
        MultiSetARScene.shared.renderer.mapParent = entity
        setMeshRenderer(MultiSetARScene.shared.renderer)
    }

    /// Set the root entity for object tracking meshes (world-fixed, independent of gizmo)
    /// - Parameter entity: The RealityKit entity to parent object tracking meshes to
    public func setObjectTrackingRootEntity(_ entity: Entity?) {
        MultiSetARScene.shared.renderer.objectRoot = entity
        setMeshRenderer(MultiSetARScene.shared.renderer)
        setPoseSink(MultiSetARScene.shared.renderer)
    }

    /// Allow or hide the gizmo (RGB axes + origin sphere). Even when allowed it shows only once a
    /// fix has placed it, and not while a tracking break has left the scene out of place.
    public func setGizmoVisible(_ visible: Bool) {
        MultiSetARScene.shared.renderer.setGizmoAllowed(visible)
    }

    /// Show or hide the map and object meshes in the scene, and any that arrive later.
    ///
    /// Hidden meshes are still downloaded and kept, so showing them again is instant. To stop
    /// downloading them at all, turn off `MultiSetConfig.meshVisualization` instead.
    public func setMeshVisible(_ visible: Bool) {
        MultiSetARScene.shared.renderer.setMeshesVisible(visible)
    }

    /// Whether meshes are shown. See `setMeshVisible(_:)`.
    public var isMeshVisible: Bool {
        MultiSetARScene.shared.renderer.meshesVisible
    }

    /// Whether a map mesh is in the AR scene, shown or hidden. Becomes true once the mesh has
    /// finished loading, which can be well after `onMeshLoaded`.
    public var hasMapMesh: Bool {
        MultiSetARScene.shared.renderer.hasMapMesh
    }

    /// Whether an object outline mesh is in the AR scene, shown or hidden
    public var hasObjectMesh: Bool {
        MultiSetARScene.shared.renderer.hasObjectMesh
    }

    /// True from the moment a localized map's mesh is fetched until it is in the AR scene: the
    /// core's `isLoadingMapMesh`, then the parse and build here. Drive a loading indicator from this.
    public var isMapMeshLoading: Bool {
        isLoadingMapMesh || MultiSetARScene.shared.renderer.isBuildingMapMesh
    }

    /// The object counterpart of `isMapMeshLoading`.
    public var isObjectMeshLoading: Bool {
        isLoadingObjectMesh || MultiSetARScene.shared.renderer.isBuildingObjectMesh
    }

    /// Smooth how the map anchor `MultiSetARView` owns moves between fixes. Off by default.
    ///
    /// `mapAlignment` and `geoAlignment` report the accepted fix; `deviceGeolocation` and
    /// `deviceMapPose` use the anchor as shown. A parent entity the host moves itself through
    /// `setGizmoUpdateHandler` is not smoothed.
    public func setAlignmentSmoothing(_ smoothing: AlignmentSmoothing) {
        MultiSetARScene.shared.renderer.setSmoothing(smoothing)
    }

    /// Where the device is on Earth right now, and which way it faces; nil without a camera
    /// frame or a `geoAlignment`.
    ///
    /// Reads the current ARKit frame and interface orientation, and uses the map anchor as the
    /// scene shows it, so the answer matches the screen while smoothing is on.
    /// - Parameter headingMode: `.cameraForward` for the direction the camera looks, or
    ///   `.deviceTop` for the device's top edge, as for a phone held flat over a 2D map.
    public func deviceGeolocation(headingMode: HeadingMode = .cameraForward) -> Geolocation? {
        guard var alignment = geoAlignment,
              let camera = MultiSetARScene.shared.renderer.session?.currentFrame?.camera else { return nil }
        if let rendered = MultiSetARScene.shared.renderer.renderedMapAnchor {
            alignment = alignment.replacingAnchor(rendered)
        }
        return alignment.geolocation(ofCamera: camera.transform, orientation: ARSessionFrameSource.interfaceOrientation,
                                     headingMode: headingMode)
    }

    /// The device's pose in the map right now, the "you are here" of a floor plan; nil without a
    /// camera frame or a `mapAlignment`.
    ///
    /// The rotation follows `LocalizationResult.estimatedRotation`: in portrait it carries the
    /// same 90° correction about the camera's Z axis as a query.
    public func deviceMapPose() -> AnchorPose? {
        guard var alignment = mapAlignment,
              let camera = MultiSetARScene.shared.renderer.session?.currentFrame?.camera else { return nil }
        if let rendered = MultiSetARScene.shared.renderer.renderedMapAnchor {
            alignment = alignment.replacingAnchor(rendered)
        }
        return alignment.mapPose(ofCamera: camera.transform, orientation: ARSessionFrameSource.interfaceOrientation)
    }
}
