/*
Copyright (c) 2026 MultiSet AI. All rights reserved.
Licensed under the MultiSet License. You may not use this file except in compliance with the License. and you can't re-distribute this file without a prior notice
For license details, visit www.multiset.ai.
Redistribution in source or binary forms must retain this notice.
*/

import Foundation
import RealityKit
import ARKit
import Metal
import simd
import UIKit
import Combine
import MultiSetSDK

/// Internal GLB mesh renderer for RealityKit
internal class MeshRenderer {

    // MARK: - Properties

    // Multiple meshes can be displayed simultaneously — e.g. each map in a
    // localized mapset overlays its own portion of the space. Keyed by mapId so
    // meshes accumulate instead of replacing one another (mirrors Unity, where
    // each localized map is a separate persistent child of the shared anchor).
    private var meshEntities: [String: Entity] = [:]
    private var revealAnimators: [String: MeshRevealAnimator] = [:]
    // A load whose token no longer matches was cancelled by a remove while it was building.
    private var inFlightLoads: [String: UUID] = [:]
    // Shared by every primitive: each CustomMaterial init re-registers the whole shader library.
    private var revealMaterial: CustomMaterial?

    /// Applied to every mesh as it attaches, so one that lands while meshes are hidden stays hidden.
    private(set) var meshesVisible = true

    /// The SDK hides the mesh while a tracking break has left it where the room no longer is.
    /// Kept apart from `meshesVisible`, the user's setting, so neither can undo the other.
    private var isOutOfPlace = false

    var meshColor: SIMD4<Float> = SIMD4<Float>(0.482, 0.173, 0.749, 0.7)

    // MARK: - Initialization

    init() {
        loadMetalShader()
    }

    private func loadMetalShader() {
        guard let device = MTLCreateSystemDefaultDevice() else {
            print("MultiSetSDK >> MeshRenderer: No Metal device available")
            return
        }

        do {
            let library = try device.makeDefaultLibrary(bundle: Bundle(for: MeshRenderer.self))
            let shader = CustomMaterial.SurfaceShader(named: "radialRevealSurface", in: library)
            var material = try CustomMaterial(surfaceShader: shader, lightingModel: .unlit)
            // Set tint to white so the shader has full control over color output.
            // RealityKit multiplies baseColor.tint with the shader's set_base_color().
            material.baseColor.tint = .white
            material.blending = .transparent(opacity: 1.0)
            // Start hidden (radius = 0), animator will drive this
            material.custom.value = SIMD4<Float>(0, 0, 0, 0)

            if #available(iOS 18.0, *) {
                material.faceCulling = .back
            }
            revealMaterial = material
        } catch {
            print("MultiSetSDK >> MeshRenderer: Failed to load Metal shader, using fallback material - \(error)")
        }
    }

    // MARK: - Public Methods

    func renderMesh(meshResult: MapMeshAsset, parentEntity: Entity, cameraWorldPosition: SIMD3<Float>? = nil, arSession: ARSession? = nil) {
        let mapId = meshResult.mapId

        // Already rendered for this map and still attached → nothing to do.
        // (Dedup so re-localization against the same map doesn't reload it.)
        if let existing = meshEntities[mapId], existing.parent != nil {
            return
        }

        // A render for this map is already in flight.
        if inFlightLoads[mapId] != nil {
            return
        }

        // Stale entry (was removed from the scene) → drop it before re-rendering.
        if let stale = meshEntities[mapId] {
            revealAnimators[mapId]?.stopAnimation()
            revealAnimators[mapId] = nil
            stale.removeFromParent()
            meshEntities[mapId] = nil
        }

        let token = UUID()
        inFlightLoads[mapId] = token

        Task { @MainActor in
            await loadAndRenderMesh(meshResult: meshResult, token: token, parent: parentEntity, cameraWorldPosition: cameraWorldPosition, arSession: arSession)
            if inFlightLoads[mapId] == token {
                inFlightLoads[mapId] = nil
            }
        }
    }

    /// Removes all rendered meshes (used when clearing/resetting the scene).
    func removeMesh() {
        inFlightLoads.removeAll()

        for animator in revealAnimators.values {
            animator.stopAnimation()
        }
        revealAnimators.removeAll()

        for entity in meshEntities.values {
            entity.removeFromParent()
        }
        meshEntities.removeAll()
    }

    /// Removes a single map's mesh, leaving any others in place.
    func removeMesh(mapId: String) {
        inFlightLoads[mapId] = nil
        revealAnimators[mapId]?.stopAnimation()
        revealAnimators[mapId] = nil
        meshEntities[mapId]?.removeFromParent()
        meshEntities[mapId] = nil
    }

    func setMeshVisible(_ visible: Bool) {
        meshesVisible = visible
        applyVisibility()
    }

    func setOutOfPlace(_ outOfPlace: Bool) {
        isOutOfPlace = outOfPlace
        applyVisibility()
    }

    private func applyVisibility() {
        for entity in meshEntities.values {
            entity.isEnabled = meshesVisible && !isOutOfPlace
        }
    }

    /// Whether a mesh is attached to the live AR scene. The renderer outlives the view, so
    /// entries from a torn-down ARView stay in `meshEntities` with no scene.
    func hasMesh() -> Bool {
        return meshEntities.values.contains { $0.scene != nil }
    }

    /// A mesh is being parsed and built into the scene.
    var isBuildingMesh: Bool {
        return !inFlightLoads.isEmpty
    }

    func isMeshRenderedForMap(mapId: String) -> Bool {
        return meshEntities[mapId] != nil
    }

    func forceRerender() {
        removeMesh()
    }

    func setMeshColor(r: Float, g: Float, b: Float, alpha: Float) {
        meshColor = SIMD4<Float>(r, g, b, alpha)
    }

    // MARK: - Private Methods

    @MainActor
    private func loadAndRenderMesh(meshResult: MapMeshAsset, token: UUID, parent: Entity, cameraWorldPosition: SIMD3<Float>?, arSession: ARSession?) async {
        do {
            let glbData = meshResult.glbData
            // Parsing a large map takes hundreds of ms in Debug builds; on main that froze AR.
            let rootNodes = try await Task.detached(priority: .userInitiated) {
                try GLBParser.parse(glbData, preparing: MeshRenderer.prepareForReveal)
            }.value
            guard inFlightLoads[meshResult.mapId] == token else { return }

            let material: any Material = revealMaterial ?? makeFallbackMaterial()
            let containerEntity = Entity()
            for node in rootNodes {
                containerEntity.addChild(await buildEntity(node, material: material))
            }
            guard inFlightLoads[meshResult.mapId] == token else { return }

            containerEntity.position = meshResult.localPose.position
            containerEntity.orientation = meshResult.localPose.rotation
            containerEntity.scale = SIMD3<Float>(1, 1, 1)
            containerEntity.isEnabled = meshesVisible && !isOutOfPlace

            parent.addChild(containerEntity)

            meshEntities[meshResult.mapId] = containerEntity

            // Start radial reveal animation if custom material is active and camera position is available
            if revealMaterial != nil, let cameraPos = cameraWorldPosition {
                let animator = MeshRevealAnimator()
                animator.loop = true
                animator.delayBetweenLoops = 20.0
                revealAnimators[meshResult.mapId] = animator
                animator.startRevealAnimation(containerEntity: containerEntity, cameraWorldPosition: cameraPos, arSession: arSession)
            }
        } catch {
            // Mesh loading failed silently
        }
    }

    @MainActor
    private func buildEntity(_ node: GLBNode<GLBPrimitive>, material: any Material) async -> Entity {
        let entity = Entity()
        entity.transform = node.transform

        for primitive in node.primitives {
            if let modelEntity = makeModelEntity(primitive, material: material) {
                entity.addChild(modelEntity)
            }
            // MeshResource.generate must run on main; yielding per primitive lets ARView draw between them.
            await Task.yield()
        }

        for child in node.children {
            entity.addChild(await buildEntity(child, material: material))
        }
        return entity
    }

    @MainActor
    private func makeModelEntity(_ primitive: GLBPrimitive, material: any Material) -> ModelEntity? {
        var meshDescriptor = MeshDescriptor(name: "glb_mesh")
        meshDescriptor.positions = MeshBuffer(primitive.positions)
        meshDescriptor.primitives = .triangles(primitive.indices)

        if primitive.normals.count == primitive.positions.count {
            meshDescriptor.normals = MeshBuffer(primitive.normals)
        }

        guard let meshResource = try? MeshResource.generate(from: [meshDescriptor]) else { return nil }
        return ModelEntity(mesh: meshResource, materials: [material])
    }

    /// Standard UnlitMaterial (no animation), used when the reveal shader failed to load.
    private func makeFallbackMaterial() -> UnlitMaterial {
        let tintColor = UIColor(
            red: CGFloat(meshColor.x),
            green: CGFloat(meshColor.y),
            blue: CGFloat(meshColor.z),
            alpha: CGFloat(meshColor.w)
        )
        var material = UnlitMaterial()
        material.color = .init(tint: tintColor)
        material.blending = .transparent(opacity: .init(floatLiteral: Float(meshColor.w)))

        if #available(iOS 18.0, *) {
            material.faceCulling = .back
        }
        return material
    }

    private static func prepareForReveal(_ raw: GLBRawPrimitive) -> GLBPrimitive? {
        guard !raw.positions.isEmpty else { return nil }
        let indices = raw.indices ?? []
        return GLBPrimitive(
            positions: raw.positions,
            normals: raw.normals,
            indices: indices.isEmpty ? raw.sequentialIndices : indices
        )
    }
}
