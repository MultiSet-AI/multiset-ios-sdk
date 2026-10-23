/*
Copyright (c) 2026 MultiSet AI. All rights reserved.
Licensed under the MultiSet License. You may not use this file except in compliance with the License. and you can't re-distribute this file without a prior notice
For license details, visit www.multiset.ai.
Redistribution in source or binary forms must retain this notice.
*/

import ARKit
import OSLog
import RealityKit
import UIKit

/// How the reconstruction is drawn over the room while a map is recorded.
enum ScanMeshDisplay: String, CaseIterable, Identifiable {
    case surface, wireframe

    var id: Self { self }

    var title: String {
        switch self {
        case .surface: "Surface"
        case .wireframe: "Wireframe"
        }
    }

    var hint: String {
        switch self {
        case .surface: "Coloured by the surface type detected"
        case .wireframe: "Every reconstructed triangle"
        }
    }
}

/// Draws the reconstruction while a map is recorded, so the person scanning can see which
/// parts of the room are already covered.
///
/// Surface mirrors each `ARMeshAnchor` into an entity with one material per
/// `ScanSurfaceClass`, shaded by `ScanMeshSurface.metal`; Wireframe is ARKit's own
/// `showSceneUnderstanding`. Display only — the SDK reads the session's anchors through
/// `ARMappingSource.meshChunks()`, so nothing here reaches the map.
@MainActor
final class ScanMeshRenderer {
    static let opacity: Float = 0.48

    var display: ScanMeshDisplay = .surface {
        didSet { if display != oldValue { applyDisplay() } }
    }

    private let arView: ARView
    private let root = AnchorEntity(world: .zero)
    private let materials: [any RealityKit.Material]
    private var entities: [UUID: ModelEntity] = [:]
    private var live: Set<UUID> = []
    private var pending: [UUID: ARMeshAnchor] = [:]
    private var queue: [UUID] = []
    private var worker: Task<Void, Never>?
    /// Between `begin` and `end`: the session is reconstructing, or was when it paused.
    private var isShowing = false
    /// Between `begin` and `suspend`: anchor updates are being drawn.
    private var isFollowing = false

    private nonisolated static let log = Logger(subsystem: "ai.multiset.sdk", category: "scan-mesh")

    init(arView: ARView) {
        self.arView = arView
        materials = Self.makeMaterials()
        // Scene-understanding occlusion would hide a surface drawn exactly on the geometry.
        arView.environment.sceneUnderstanding.options = []
        root.name = "ScanMeshRenderer"
        arView.scene.addAnchor(root)
    }

    /// Call after the recording's session run. That run removes every anchor, possibly the
    /// one RealityKit placed for `root`, so `root` is added again.
    func begin() {
        clear()
        arView.scene.removeAnchor(root)
        arView.scene.addAnchor(root)
        isShowing = true
        isFollowing = true
        applyVisibility()
    }

    /// Stops following the session and keeps what is drawn, which is the room as it stood
    /// when the recording stopped.
    func suspend() {
        isFollowing = false
        cancelBuilds()
    }

    /// A preview has no reconstruction, so there is nothing left to show.
    func end() {
        clear()
        applyVisibility()
    }

    func update(_ anchors: [ARMeshAnchor]) {
        guard isFollowing else { return }
        for anchor in anchors {
            live.insert(anchor.identifier)
            // World space, not parent-relative: ARKit moves the world anchor when it refines.
            entities[anchor.identifier]?.setTransformMatrix(anchor.transform, relativeTo: nil)
        }
        guard display == .surface else { return }
        for anchor in anchors where pending.updateValue(anchor, forKey: anchor.identifier) == nil {
            queue.append(anchor.identifier)
        }
        startBuilding()
    }

    func remove(_ anchors: [ARMeshAnchor]) {
        for anchor in anchors {
            live.remove(anchor.identifier)
            pending.removeValue(forKey: anchor.identifier)
            entities.removeValue(forKey: anchor.identifier)?.removeFromParent()
        }
    }

    // MARK: - Display

    private func applyVisibility() {
        root.isEnabled = display == .surface
        arView.debugOptions = isShowing && display == .wireframe ? [.showSceneUnderstanding] : []
    }

    private func applyDisplay() {
        applyVisibility()
        guard display == .surface, isFollowing else {
            cancelBuilds()
            return
        }
        // Surface drew nothing while hidden, so every current chunk is stale.
        let anchors = arView.session.currentFrame?.anchors.compactMap { $0 as? ARMeshAnchor } ?? []
        update(anchors)
    }

    private func clear() {
        isShowing = false
        isFollowing = false
        cancelBuilds()
        for entity in entities.values {
            entity.removeFromParent()
        }
        entities.removeAll()
        live.removeAll()
    }

    // MARK: - Building

    /// One chunk at a time, oldest request first, with a pause between them: ARKit revises
    /// anchors faster than they are worth redrawing, and this runs while frames are written.
    /// The worker itself is utility too, or awaiting the detached task would raise it.
    private func startBuilding() {
        guard worker == nil, !queue.isEmpty else { return }
        worker = Task(priority: .utility) { [weak self] in
            while !Task.isCancelled, let anchor = self?.nextAnchor() {
                let prepared = await Task.detached(priority: .utility) {
                    await Self.prepare(anchor)
                }.value
                guard !Task.isCancelled else { return }
                self?.show(prepared, for: anchor)
                try? await Task.sleep(for: .milliseconds(35))
            }
            guard !Task.isCancelled else { return }
            self?.worker = nil
        }
    }

    private func cancelBuilds() {
        worker?.cancel()
        worker = nil
        pending.removeAll()
        queue.removeAll()
    }

    private func nextAnchor() -> ARMeshAnchor? {
        while !queue.isEmpty {
            if let anchor = pending.removeValue(forKey: queue.removeFirst()) { return anchor }
        }
        return nil
    }

    private func show(_ prepared: PreparedMesh, for anchor: ARMeshAnchor) {
        let identifier = anchor.identifier
        guard live.contains(identifier) else { return }
        let mesh: MeshResource
        switch prepared {
        case .mesh(let resource):
            mesh = resource
        case .descriptor(let descriptor):
            do {
                mesh = try MeshResource.generate(from: [descriptor])
            } catch {
                Self.log.error("Scan chunk mesh failed: \(error.localizedDescription)")
                return
            }
        case .failed:
            return
        case .empty:
            entities.removeValue(forKey: identifier)?.removeFromParent()
            return
        }
        let entity: ModelEntity
        if let existing = entities[identifier] {
            entity = existing
        } else {
            entity = ModelEntity()
            entities[identifier] = entity
            root.addChild(entity)
        }
        entity.model = ModelComponent(mesh: mesh, materials: materials)
        entity.setTransformMatrix(anchor.transform, relativeTo: nil)
    }

    /// `failed` keeps the chunk already drawn: ARKit may never revise that anchor again, and
    /// a hole would read as a part of the room that was never scanned.
    private enum PreparedMesh: @unchecked Sendable {
        case mesh(MeshResource)
        /// Before iOS 18 `MeshResource.generate` is main-actor only, so that step runs on main.
        case descriptor(MeshDescriptor)
        case empty
        case failed
    }

    private nonisolated static func prepare(_ anchor: ARMeshAnchor) async -> PreparedMesh {
        let geometry = anchor.geometry
        guard geometry.faces.primitiveType == .triangle, geometry.faces.count > 0,
              geometry.vertices.count > 0 else { return .empty }
        let positions = ARMeshGeometry.float3s(from: geometry.vertices)
        let surface = ScanSurfaceMesh(
            positions: positions,
            indices: ARMeshGeometry.indices(from: geometry.faces),
            classes: classes(from: geometry.classification))
        guard !surface.isEmpty else { return .empty }

        var descriptor = MeshDescriptor(name: "scan_surface")
        descriptor.positions = MeshBuffer(positions)
        let normals = ARMeshGeometry.float3s(from: geometry.normals)
        if normals.count == positions.count {
            descriptor.normals = MeshBuffer(normals)
        }
        descriptor.primitives = .triangles(surface.indices)
        descriptor.materials = .perFace(surface.materialIndices)

        guard #available(iOS 18.0, *) else { return .descriptor(descriptor) }
        do {
            return .mesh(try await MeshResource(from: [descriptor]))
        } catch {
            log.error("Scan chunk mesh failed: \(error.localizedDescription)")
            return .failed
        }
    }

    private nonisolated static func classes(from source: ARGeometrySource?) -> [UInt8]? {
        guard let source, source.format == .uchar, source.componentsPerVector == 1,
              source.stride > 0 else { return nil }
        let available = source.buffer.length - source.offset
        guard available > 0 else { return nil }
        let count = min(source.count, (available - 1) / source.stride + 1)
        let base = source.buffer.contents().advanced(by: source.offset)
        return (0..<count).map { base.load(fromByteOffset: $0 * source.stride, as: UInt8.self) }
    }

    // MARK: - Materials

    /// One per `ScanSurfaceClass`, in `allCases` order, which is what the per-face indices name.
    private static func makeMaterials() -> [any RealityKit.Material] {
        let shader = loadShader()
        return ScanSurfaceClass.allCases.map { surface -> any RealityKit.Material in
            if let shader, var material = try? CustomMaterial(surfaceShader: shader, lightingModel: .lit) {
                material.custom.value = SIMD4(surface.linearRGB, 0)
                material.blending = .transparent(opacity: .init(scale: opacity))
                return material
            }
            var material = UnlitMaterial(color: surface.uiColor)
            material.blending = .transparent(opacity: .init(scale: opacity))
            return material
        }
    }

    /// The bundle this adapter is compiled into, whose `default.metallib` holds the shader.
    private static func loadShader() -> CustomMaterial.SurfaceShader? {
        guard let device = MTLCreateSystemDefaultDevice() else { return nil }
        do {
            let library = try device.makeDefaultLibrary(bundle: Bundle(for: ScanMeshRenderer.self))
            guard library.functionNames.contains("scanMeshSurface") else {
                log.error("scanMeshSurface is missing from the default library; using flat colours")
                return nil
            }
            return CustomMaterial.SurfaceShader(named: "scanMeshSurface", in: library)
        } catch {
            log.error("Default Metal library unavailable; using flat colours: \(error.localizedDescription)")
            return nil
        }
    }
}

private extension ScanSurfaceClass {
    var uiColor: UIColor {
        UIColor(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1)
    }
}
