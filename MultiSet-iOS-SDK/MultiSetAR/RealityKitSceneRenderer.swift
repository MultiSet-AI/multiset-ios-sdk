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

/// Places what the SDK reports into a RealityKit scene: moves the gizmo anchor, parents map
/// meshes under the map anchor, and keeps one entity per tracked object.
final class RealityKitSceneRenderer: MultiSetPoseSink, MultiSetMeshRenderer {

    /// Read for the camera position that centres the radial reveal
    weak var session: ARSession?

    /// Set only by `MultiSetARView`. A host that passes its own parent entity moves it
    /// through `setGizmoUpdateHandler`, so this renderer must not move that one too.
    var gizmoAnchor: AnchorEntity?
    var gizmoVisual: Entity?

    var mapParent: Entity?
    var objectRoot: Entity?

    private let mapMeshRenderer = MeshRenderer()
    private let objectMeshRenderer = OutlineMeshRenderer()
    private var objectEntities: [String: Entity] = [:]

    func mapAnchorDidUpdate(_ pose: AnchorPose) {
        guard let gizmoAnchor = gizmoAnchor else { return }

        let position = pose.position
        let rotation = pose.rotation
        guard position.x.isFinite, position.y.isFinite, position.z.isFinite else {
            print("MultiSetSDK >> Invalid position: \(position)")
            return
        }
        guard rotation.vector.x.isFinite, rotation.vector.y.isFinite, rotation.vector.z.isFinite, rotation.vector.w.isFinite else {
            print("MultiSetSDK >> Invalid rotation: \(rotation)")
            return
        }

        gizmoAnchor.transform.translation = position
        gizmoAnchor.transform.rotation = rotation
        gizmoVisual?.isEnabled = true

        print("MultiSetSDK >> Gizmo updated to Position: \(position), Rotation: \(rotation)")
    }

    func objectPoseDidUpdate(objectCode: String, pose: AnchorPose) {
        let entity = objectEntity(for: objectCode)
        entity.transform.translation = pose.position
        entity.transform.rotation = pose.rotation
        entity.isEnabled = true
    }

    func renderMapMesh(_ mesh: MapMeshAsset) {
        guard let parent = mapParent else { return }

        let cameraWorldPosition: SIMD3<Float>? = session?.currentFrame.map { frame in
            let col3 = frame.camera.transform.columns.3
            return SIMD3<Float>(col3.x, col3.y, col3.z)
        }

        mapMeshRenderer.renderMesh(meshResult: mesh, parentEntity: parent, cameraWorldPosition: cameraWorldPosition, arSession: session)
    }

    func removeAllMapMeshes() {
        mapMeshRenderer.removeMesh()
    }

    /// Put the gizmo back where it sits before the first fix. A world frame that has been
    /// restarted no longer contains the pose the anchor was placed at, so leaving it lit
    /// at that transform points the user at a location that no longer means anything.
    func resetMapAnchor() {
        gizmoAnchor?.transform.translation = SIMD3<Float>(0, 0, 0)
        gizmoAnchor?.transform.rotation = simd_quatf(angle: 0, axis: SIMD3<Float>(0, 1, 0))
        gizmoVisual?.isEnabled = false
    }

    func renderObjectMesh(_ mesh: ObjectMeshAsset) {
        guard let parent = objectEntities[mesh.objectCode] else { return }
        objectMeshRenderer.renderOutlineMesh(meshResult: mesh, parentEntity: parent)
    }

    func setObjectMeshVisible(_ visible: Bool, objectCode: String) {
        objectMeshRenderer.setMeshVisible(for: objectCode, visible: visible)
    }

    /// Map and object meshes share one setting; `MultiSet.setMeshVisible(_:)` sets it.
    var meshesVisible: Bool {
        mapMeshRenderer.meshesVisible
    }

    var hasMapMesh: Bool {
        mapMeshRenderer.hasMesh()
    }

    var hasObjectMesh: Bool {
        objectMeshRenderer.hasMesh()
    }

    func setMeshesVisible(_ visible: Bool) {
        mapMeshRenderer.setMeshVisible(visible)
        objectMeshRenderer.setAllMeshesVisible(visible)
    }

    func removeAllObjectMeshes() {
        objectMeshRenderer.removeAllMeshes()
        objectEntities.values.forEach { $0.removeFromParent() }
        objectEntities.removeAll()
    }

    /// Drop every reference to the AR view that is going away.
    ///
    /// This renderer is a singleton shared by both AR screens, so whatever is left here after a
    /// view is dismantled points into a scene that no longer exists: meshes parented to a dead
    /// anchor, and a gizmo the next view will never see. Called by
    /// `MultiSetARView.dismantleUIView`, and only once a newer view has been shown not to own
    /// the SDK already — detaching after a handover would wipe the live view's scene.
    func detach() {
        removeAllMapMeshes()
        removeAllObjectMeshes()
        gizmoAnchor = nil
        gizmoVisual = nil
        mapParent = nil
        objectRoot = nil
        session = nil
    }

    private func objectEntity(for objectCode: String) -> Entity {
        if let existing = objectEntities[objectCode] {
            return existing
        }

        let entity = Entity()
        entity.name = objectCode
        entity.isEnabled = false

        objectRoot?.addChild(entity)
        objectEntities[objectCode] = entity

        return entity
    }
}
