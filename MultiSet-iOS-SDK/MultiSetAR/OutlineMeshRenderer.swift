/*
Copyright (c) 2026 MultiSet AI. All rights reserved.
Licensed under the MultiSet License. You may not use this file except in compliance with the License. and you can't re-distribute this file without a prior notice
For license details, visit www.multiset.ai.
Redistribution in source or binary forms must retain this notice.
*/

import Foundation
import RealityKit
import Metal
import simd
import UIKit
import MultiSetSDK

/// Renders object tracking meshes as the MultiSet app's animated outline (Unity's `OutlineOnly`).
///
/// Two entities per primitive stand in for the shader's two passes: an `OcclusionMaterial`
/// mesh for the depth-only pass that hides the interior, and a shell expanded along the
/// normals by the geometry modifier. The shell's triangles are wound the other way so
/// RealityKit's default back-face culling behaves as Unity's `Cull Front` — `faceCulling`
/// exists only from iOS 18, and without either the shell covers the object as a blob.
/// Animation is driven by the shader's own clock; nothing is rebuilt per frame.
internal class OutlineMeshRenderer {

    // MARK: - Properties

    private var meshEntities: [String: Entity] = [:]  // objectCode -> container entity
    // A load whose token no longer matches was cancelled by a remove while it was building.
    private var inFlightLoads: [String: UUID] = [:]

    // Shared by every primitive: each CustomMaterial init re-registers the whole shader library.
    private var outlineMaterial: CustomMaterial?
    private let occlusionMaterial = OcclusionMaterial()

    /// OutlineMat's `_OutlineWidth`, in metres of model space
    private let outlineWidth: Float = 0.006

    /// Applied to every mesh as it attaches, so an object recognised while meshes are hidden
    /// does not appear on its own.
    private(set) var meshesVisible = true

    /// Objects the core hid because their placement is stale. The global setting must not bring
    /// them back, or an outline would show where its object no longer is.
    private var hiddenObjectCodes: Set<String> = []

    // MARK: - Initialization

    init() {
        loadMetalShaders()
    }

    private func loadMetalShaders() {
        guard let device = MTLCreateSystemDefaultDevice() else {
            // No Metal device available
            return
        }

        do {
            let library = try device.makeDefaultLibrary(bundle: Bundle(for: OutlineMeshRenderer.self))
            let surfaceShader = CustomMaterial.SurfaceShader(named: "outlineSurface", in: library)
            let geometryModifier = CustomMaterial.GeometryModifier(named: "outlineGeometry", in: library)

            var material = try CustomMaterial(
                surfaceShader: surfaceShader,
                geometryModifier: geometryModifier,
                lightingModel: .unlit
            )
            material.baseColor.tint = .white
            material.blending = .transparent(opacity: 1.0)
            // x = outline width, read by the geometry modifier
            material.custom.value = SIMD4<Float>(outlineWidth, 0, 0, 0)
            outlineMaterial = material
        } catch {
            // Metal shader load failed, will use fallback material
        }
    }

    // MARK: - Public Methods

    func renderOutlineMesh(meshResult: ObjectMeshAsset, parentEntity: Entity) {
        let objectCode = meshResult.objectCode

        // Don't re-render if already loaded or loading for this object
        // `parent != nil` is load-bearing, and `MeshRenderer.renderMesh` has always had it.
        // Keying on presence alone means an entity orphaned when the host's AR view went away
        // blocks its own replacement for the rest of the process.
        if let existing = meshEntities[objectCode], existing.parent != nil { return }
        if inFlightLoads[objectCode] != nil { return }

        let token = UUID()
        inFlightLoads[objectCode] = token

        Task { @MainActor in
            await loadAndRenderMesh(meshResult: meshResult, token: token, parent: parentEntity)
            if inFlightLoads[objectCode] == token {
                inFlightLoads[objectCode] = nil
            }
        }
    }

    func removeAllMeshes() {
        inFlightLoads.removeAll()
        hiddenObjectCodes.removeAll()
        for (_, entity) in meshEntities {
            entity.removeFromParent()
        }
        meshEntities.removeAll()
    }

    /// The core calls this with `true` whenever it re-tracks an object, so the global
    /// setting must win or background re-tracking would bring hidden meshes back.
    func setMeshVisible(for objectCode: String, visible: Bool) {
        if visible {
            hiddenObjectCodes.remove(objectCode)
        } else {
            hiddenObjectCodes.insert(objectCode)
        }
        meshEntities[objectCode]?.isEnabled = visible && meshesVisible
    }

    func setAllMeshesVisible(_ visible: Bool) {
        meshesVisible = visible
        for (objectCode, entity) in meshEntities {
            entity.isEnabled = visible && !hiddenObjectCodes.contains(objectCode)
        }
    }

    /// Whether an outline is attached to the live AR scene; entries from a torn-down ARView have none.
    /// A mesh is being parsed and built into the scene.
    var isBuildingMesh: Bool {
        return !inFlightLoads.isEmpty
    }

    func hasMesh() -> Bool {
        return meshEntities.values.contains { $0.scene != nil }
    }

    // MARK: - Private Methods

    @MainActor
    private func loadAndRenderMesh(meshResult: ObjectMeshAsset, token: UUID, parent: Entity) async {
        do {
            // Deriving the shell's normals from the indexed faces is the expensive half of an
            // object mesh, so it runs off main with the rest of the decode.
            let glbData = meshResult.glbData
            let rootNodes = try await Task.detached(priority: .userInitiated) {
                try GLBParser.parse(glbData, preparing: OutlineMeshRenderer.prepareForOutline)
            }.value
            guard inFlightLoads[meshResult.objectCode] == token else { return }

            let outline: any Material = outlineMaterial ?? Self.makeFallbackMaterial()
            let containerEntity = Entity()
            for node in rootNodes {
                containerEntity.addChild(await buildEntity(node, outline: outline))
            }
            guard inFlightLoads[meshResult.objectCode] == token else { return }

            containerEntity.position = .zero
            containerEntity.orientation = simd_quatf(ix: 0, iy: 0, iz: 0, r: 1)
            containerEntity.isEnabled = meshesVisible && !hiddenObjectCodes.contains(meshResult.objectCode)

            parent.addChild(containerEntity)
            meshEntities[meshResult.objectCode] = containerEntity
        } catch {
            // Mesh rendering failed silently
        }
    }

    // MARK: - Entity Creation

    @MainActor
    private func buildEntity(_ node: GLBNode<OutlinePrimitive>, outline: any Material) async -> Entity {
        let entity = Entity()
        entity.transform = node.transform

        for primitive in node.primitives {
            var occlusionDescriptor = MeshDescriptor(name: "occlusion_mesh")
            occlusionDescriptor.positions = MeshBuffer(primitive.positions)
            occlusionDescriptor.primitives = .triangles(primitive.indices)
            occlusionDescriptor.normals = MeshBuffer(primitive.normals)

            var outlineDescriptor = MeshDescriptor(name: "outline_mesh")
            outlineDescriptor.positions = MeshBuffer(primitive.positions)
            outlineDescriptor.primitives = .triangles(primitive.shellIndices)
            outlineDescriptor.normals = MeshBuffer(primitive.normals)

            if let occlusion = try? MeshResource.generate(from: [occlusionDescriptor]),
               let shell = try? MeshResource.generate(from: [outlineDescriptor]) {
                entity.addChild(ModelEntity(mesh: occlusion, materials: [occlusionMaterial]))
                entity.addChild(ModelEntity(mesh: shell, materials: [outline]))
            }
            // MeshResource.generate must run on main; yielding per primitive lets ARView draw between them.
            await Task.yield()
        }

        for child in node.children {
            entity.addChild(await buildEntity(child, outline: outline))
        }
        return entity
    }

    /// No shader library: a still shell in OutlineMat's colour, which the reversed winding
    /// and the occluder still reduce to an outline.
    private static func makeFallbackMaterial() -> UnlitMaterial {
        var material = UnlitMaterial()
        material.color = .init(tint: UIColor(red: 0.3195, green: 0.1014, blue: 0.5, alpha: 0.5882))
        material.blending = .transparent(opacity: 0.5882)
        return material
    }

    // MARK: - Geometry Helpers

    private static func prepareForOutline(_ raw: GLBRawPrimitive) -> OutlinePrimitive? {
        guard !raw.positions.isEmpty else { return nil }

        let indices = raw.indices ?? raw.sequentialIndices
        // The service's scanned object meshes carry positions and UVs but no normals,
        // and the shell is expanded along them — so they are derived here, from the
        // indexed faces, the way Unity's importer derives them.
        let normals = raw.normals.count == raw.positions.count
            ? raw.normals
            : smoothNormals(positions: raw.positions, indices: indices)

        return OutlinePrimitive(
            positions: raw.positions,
            normals: normals,
            indices: indices,
            shellIndices: reversedWinding(indices)
        )
    }

    /// Angle-weighted vertex normals over the indexed faces, welded across duplicated
    /// vertices. Scans split vertices along texture seams; normals that stop at a seam
    /// would open a gap in the shell exactly where the outline should be continuous.
    /// Angle weighting keeps a normal independent of how a face was triangulated, where
    /// area weighting counts a quad's diagonal corners twice.
    private static func smoothNormals(positions: [SIMD3<Float>], indices: [UInt32]) -> [SIMD3<Float>] {
        var weldIndex = [Int](repeating: 0, count: positions.count)
        var buckets: [SIMD3<Int32>: Int] = [:]
        var accumulated: [SIMD3<Float>] = []
        for (i, p) in positions.enumerated() {
            // Positions within 0.1 mm are one vertex
            let key = SIMD3<Int32>(Int32((p.x * 10_000).rounded()), Int32((p.y * 10_000).rounded()), Int32((p.z * 10_000).rounded()))
            if let existing = buckets[key] {
                weldIndex[i] = existing
            } else {
                buckets[key] = accumulated.count
                weldIndex[i] = accumulated.count
                accumulated.append(.zero)
            }
        }

        var i = 0
        while i + 2 < indices.count {
            let a = Int(indices[i]), b = Int(indices[i + 1]), c = Int(indices[i + 2])
            i += 3
            guard a < positions.count, b < positions.count, c < positions.count else { continue }
            let pa = positions[a], pb = positions[b], pc = positions[c]
            let faceNormal = cross(pb - pa, pc - pa)
            guard length_squared(faceNormal) > 1e-18 else { continue }
            let unit = normalize(faceNormal)
            accumulated[weldIndex[a]] += unit * angle(pb - pa, pc - pa)
            accumulated[weldIndex[b]] += unit * angle(pc - pb, pa - pb)
            accumulated[weldIndex[c]] += unit * angle(pa - pc, pb - pc)
        }

        return weldIndex.map { welded in
            let n = accumulated[welded]
            return length_squared(n) > 1e-12 ? normalize(n) : SIMD3<Float>(0, 1, 0)
        }
    }

    private static func angle(_ u: SIMD3<Float>, _ v: SIMD3<Float>) -> Float {
        let denominator = length(u) * length(v)
        guard denominator > 1e-12 else { return 0 }
        return acos(min(max(dot(u, v) / denominator, -1), 1))
    }

    /// Every triangle wound the other way, so front and back faces swap.
    private static func reversedWinding(_ indices: [UInt32]) -> [UInt32] {
        var result = indices
        var i = 0
        while i + 2 < result.count {
            result.swapAt(i + 1, i + 2)
            i += 3
        }
        return result
    }
}

/// One primitive's occluder and shell, prepared off the main thread
private struct OutlinePrimitive: Sendable {
    let positions: [SIMD3<Float>]
    let normals: [SIMD3<Float>]
    let indices: [UInt32]
    /// `indices` with every triangle's winding reversed, so default back-face culling
    /// leaves the inside of the shell — the outline — where it pokes out past the occluder
    let shellIndices: [UInt32]
}
