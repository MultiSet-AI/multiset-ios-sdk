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

    /// Show or hide the gizmo (RGB axes + origin sphere)
    public func setGizmoVisible(_ visible: Bool) {
        MultiSetARScene.shared.renderer.gizmoVisual?.isEnabled = visible
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
}
