/*
Copyright (c) 2026 MultiSet AI. All rights reserved.
Licensed under the MultiSet License. You may not use this file except in compliance with the License. and you can't re-distribute this file without a prior notice
For license details, visit www.multiset.ai.
Redistribution in source or binary forms must retain this notice.
*/

import Metal
import OSLog
import RealityKit
import UIKit

/// Draws the posed-RGB scan's coverage: every confirmed feature point as a glowing yellow
/// sprite, in world coordinates under one `AnchorEntity(world: .zero)`, so the cloud stays
/// on the surfaces it was seen on as the person walks. Display only.
///
/// Built to cost nothing a ten-minute scan would notice. Points are merged into chunk
/// meshes of `chunkSize` — tens of draw calls at the cap, never one entity per point — and
/// a sprite is four vertices that the shader turns to face the camera, so the GPU does the
/// billboarding and the CPU never touches a point again once it is drawn. Only the newest
/// chunk is rebuilt, at most every `rebuildInterval`; a re-bucket rebuilds the rest one
/// chunk per frame. Geometry is prepared off the main actor, and on iOS 18 the mesh too.
@MainActor
final class FeaturePointCloudRenderer {
    nonisolated static let chunkSize = 1_024
    nonisolated static let spriteRadius: Float = 0.012
    /// Linear RGB of the glow; the shader whitens the core.
    nonisolated static let glow = SIMD3<Float>(1.0, 0.72, 0.05)
    static let rebuildInterval: Duration = .milliseconds(250)

    private let arView: ARView
    private let root = AnchorEntity(world: .zero)
    private let material: any RealityKit.Material
    private let usesSprites: Bool
    private var chunks: [[SIMD3<Float>]] = [[]]
    private var entities: [ModelEntity] = []
    private var dirty: Set<Int> = []
    private var worker: Task<Void, Never>?
    /// Bumped by every clear, so a chunk prepared for a cloud since replaced is dropped.
    private var generation = 0
    private var isShowing = false

    private nonisolated static let log = Logger(subsystem: "ai.multiset.sdk", category: "scan-points")

    init(arView: ARView) {
        self.arView = arView
        root.name = "FeaturePointCloudRenderer"
        if let sprite = Self.makeSpriteMaterial() {
            material = sprite
            usesSprites = true
        } else {
            material = UnlitMaterial(color: UIColor(red: 1, green: 0.85, blue: 0.2, alpha: 1))
            usesSprites = false
        }
    }

    /// Call after the recording's session run, which removes every anchor, possibly the
    /// one RealityKit placed for `root`.
    func begin() {
        clear()
        arView.scene.removeAnchor(root)
        arView.scene.addAnchor(root)
        isShowing = true
    }

    /// Keeps what is drawn — the coverage as it stood when recording stopped.
    func suspend() {
        isShowing = false
    }

    func end() {
        clear()
        arView.scene.removeAnchor(root)
    }

    func apply(_ update: FeaturePointCollector.Update) {
        guard isShowing else { return }
        switch update {
        case .append(let points):
            let firstTouched = chunks.count - 1
            for point in points {
                if chunks[chunks.count - 1].count == Self.chunkSize { chunks.append([]) }
                chunks[chunks.count - 1].append(point)
            }
            dirty.formUnion(firstTouched..<chunks.count)
        case .replace(let points):
            clear()
            isShowing = true
            chunks = stride(from: 0, to: max(points.count, 1), by: Self.chunkSize).map {
                Array(points[$0..<min($0 + Self.chunkSize, points.count)])
            }
            dirty = Set(chunks.indices)
        }
        startWorker()
    }

    private func startWorker() {
        guard worker == nil else { return }
        let generation = generation
        let usesSprites = usesSprites
        worker = Task { [weak self] in
            while !Task.isCancelled, let self, let index = self.dirty.min() {
                self.dirty.remove(index)
                let points = self.chunks[index]
                let prepared = await Task.detached(priority: .utility) {
                    await Self.prepare(points, sprites: usesSprites)
                }.value
                guard !Task.isCancelled, generation == self.generation else { return }
                self.show(prepared, at: index)
                let isNewest = index == self.chunks.count - 1
                try? await Task.sleep(for: isNewest ? Self.rebuildInterval : .milliseconds(16))
            }
            // A cancelled worker has already been replaced; clearing would orphan the new one.
            guard !Task.isCancelled else { return }
            self?.worker = nil
        }
    }

    private func show(_ prepared: PreparedMesh, at index: Int) {
        let mesh: MeshResource
        switch prepared {
        case .mesh(let resource):
            mesh = resource
        case .descriptor(let descriptor):
            do {
                mesh = try MeshResource.generate(from: [descriptor])
            } catch {
                Self.log.error("point chunk failed: \(error.localizedDescription, privacy: .public)")
                return
            }
        case .empty, .failed:
            return
        }
        while entities.count <= index {
            let entity = ModelEntity()
            entities.append(entity)
            root.addChild(entity)
        }
        entities[index].model = ModelComponent(mesh: mesh, materials: [material])
    }

    private func clear() {
        isShowing = false
        generation += 1
        worker?.cancel()
        worker = nil
        for entity in entities { entity.removeFromParent() }
        entities.removeAll()
        chunks = [[]]
        dirty.removeAll()
    }

    // MARK: - Geometry

    private enum PreparedMesh: @unchecked Sendable {
        case mesh(MeshResource)
        /// Before iOS 18 `MeshResource.generate` is main-actor only, so that step runs on main.
        case descriptor(MeshDescriptor)
        case empty
        case failed
    }

    private nonisolated static func prepare(_ points: [SIMD3<Float>], sprites: Bool) async -> PreparedMesh {
        guard !points.isEmpty else { return .empty }
        let descriptor = sprites ? spriteDescriptor(for: points) : tetrahedronDescriptor(for: points)
        guard #available(iOS 18.0, *) else { return .descriptor(descriptor) }
        do {
            return .mesh(try await MeshResource(from: [descriptor]))
        } catch {
            log.error("point chunk failed: \(error.localizedDescription, privacy: .public)")
            return .failed
        }
    }

    private nonisolated static let corners: [SIMD2<Float>] = [[0, 0], [1, 0], [1, 1], [0, 1]]
    // Both windings: which one faces the camera depends on how RealityKit orients uv0, and
    // per-material culling is iOS 18 only. The back pair is culled, so it costs no fill.
    private nonisolated static let spriteIndices: [UInt32] = [0, 1, 2, 0, 2, 3, 0, 2, 1, 0, 3, 2]

    nonisolated static func spriteDescriptor(for points: [SIMD3<Float>]) -> MeshDescriptor {
        var positions: [SIMD3<Float>] = []
        positions.reserveCapacity(points.count * 4)
        var uvs: [SIMD2<Float>] = []
        uvs.reserveCapacity(points.count * 4)
        var indices: [UInt32] = []
        indices.reserveCapacity(points.count * spriteIndices.count)
        for (i, point) in points.enumerated() {
            let base = UInt32(i * 4)
            for corner in corners {
                positions.append(point)
                uvs.append(corner)
            }
            for index in spriteIndices { indices.append(base + index) }
        }
        var descriptor = MeshDescriptor(name: "scan-points")
        descriptor.positions = MeshBuffers.Positions(positions)
        descriptor.textureCoordinates = MeshBuffers.TextureCoordinates(uvs)
        descriptor.primitives = .triangles(indices)
        return descriptor
    }

    // The flat-colour fallback when the shader library is missing: a sprite left unopened
    // would be invisible, so each point is a small closed tetrahedron instead.
    private nonisolated static let tetrahedron: [SIMD3<Float>] = [[1, 1, 1], [1, -1, -1], [-1, 1, -1], [-1, -1, 1]]
    private nonisolated static let tetrahedronFaces: [UInt32] = [0, 1, 2, 0, 3, 1, 0, 2, 3, 1, 3, 2]

    nonisolated static func tetrahedronDescriptor(for points: [SIMD3<Float>]) -> MeshDescriptor {
        let scale = spriteRadius * 0.5 / Float(3).squareRoot()
        var positions: [SIMD3<Float>] = []
        positions.reserveCapacity(points.count * 4)
        var indices: [UInt32] = []
        indices.reserveCapacity(points.count * tetrahedronFaces.count)
        for (i, point) in points.enumerated() {
            let base = UInt32(i * 4)
            for corner in tetrahedron { positions.append(point + corner * scale) }
            for index in tetrahedronFaces { indices.append(base + index) }
        }
        var descriptor = MeshDescriptor(name: "scan-points")
        descriptor.positions = MeshBuffers.Positions(positions)
        descriptor.primitives = .triangles(indices)
        return descriptor
    }

    // MARK: - Material

    /// Set once; nothing writes a uniform per frame, so the material is never reassigned.
    /// Loaded from the bundle this adapter is compiled into, as `ScanMeshRenderer` is.
    private static func makeSpriteMaterial() -> CustomMaterial? {
        guard let device = MTLCreateSystemDefaultDevice() else { return nil }
        do {
            let library = try device.makeDefaultLibrary(bundle: Bundle(for: FeaturePointCloudRenderer.self))
            guard library.functionNames.contains("scanFeaturePointSurface"),
                  library.functionNames.contains("scanFeaturePointGeometry") else {
                log.error("feature point shaders missing from the default library; using flat points")
                return nil
            }
            var material = try CustomMaterial(
                surfaceShader: CustomMaterial.SurfaceShader(named: "scanFeaturePointSurface", in: library),
                geometryModifier: CustomMaterial.GeometryModifier(named: "scanFeaturePointGeometry", in: library),
                lightingModel: .unlit)
            material.custom.value = SIMD4(glow, spriteRadius)
            material.blending = .transparent(opacity: 1.0)
            return material
        } catch {
            log.error("feature point material unavailable; using flat points: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }
}
