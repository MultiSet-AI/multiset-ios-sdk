/*
Copyright (c) 2026 MultiSet AI. All rights reserved.
Licensed under the MultiSet License. You may not use this file except in compliance with the License. and you can't re-distribute this file without a prior notice
For license details, visit www.multiset.ai.
Redistribution in source or binary forms must retain this notice.
*/

import SwiftUI
import RealityKit
import ARKit
import MultiSetSDK

/// Public AR view component for MultiSet SDK localization
/// Embed this view in your SwiftUI hierarchy to display AR content with localization
public struct MultiSetARView: UIViewRepresentable {

    // MARK: - Properties

    private let gizmoManager = GizmoManager()

    /// The parent entity for mesh rendering (accessible for advanced use cases)
    public var parentEntity: Entity? {
        return gizmoManager.gizmoAnchor
    }

    // MARK: - Initialization

    /// Initialize the AR view
    /// - Note: Call MultiSet.shared.initialize() before using this view
    public init() {}

    // MARK: - UIViewRepresentable

    /// Owns the session delegate for the lifetime of the ARView: `ARSession.delegate` is weak, and
    /// SwiftUI discards this struct on every re-render, so the struct cannot own it.
    public final class Coordinator {
        let sessionController = ARSessionController()
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    public func makeUIView(context: Context) -> ARView {
        let sessionController = context.coordinator.sessionController
        let arView = ARView(frame: .zero)
        let configuration = sessionController.createARConfiguration()
        configuration.worldAlignment = .gravity
        configuration.isAutoFocusEnabled = true

        #if !targetEnvironment(simulator)
        arView.session.run(configuration)
        #endif

        arView.session.delegate = sessionController
        sessionController.session = arView.session
        sessionController.arView = arView

        MultiSetARScene.shared.sessionController = sessionController

        let (anchor, gizmoVisual) = addGizmo(to: arView)
        gizmoManager.gizmoAnchor = anchor
        sessionController.gizmoAnchor = anchor

        addLighting(to: arView)

        connectToSDK(arView: arView, gizmoAnchor: anchor, gizmoVisual: gizmoVisual)

        return arView
    }

    public func updateUIView(_ uiView: ARView, context: Context) {
        // Updates handled through SDK callbacks
    }

    // Also takes the watermark down; skipped when a newer view already owns the SDK.
    public static func dismantleUIView(_ uiView: ARView, coordinator: Coordinator) {
        // Ahead of the ownership guard: this controller's watchdog has to stop whether or
        // not a newer view has taken the SDK over.
        coordinator.sessionController.teardown()

        guard MultiSetARScene.shared.isAttached(uiView.session) else { return }

        // Order matters: the SDK's own teardown runs through a renderer that is still wired up,
        // then the renderer lets go of this view's entities.
        MultiSet.shared.setARSession(nil)
        MultiSetARScene.shared.renderer.detach()
    }

    // MARK: - SDK Integration

    private func connectToSDK(arView: ARView, gizmoAnchor: AnchorEntity, gizmoVisual: Entity) {
        // Create a separate world-fixed anchor for object tracking meshes
        let objectTrackingAnchor = AnchorEntity(world: [0, 0, 0])
        objectTrackingAnchor.name = "ObjectTrackingAnchor"
        arView.scene.anchors.append(objectTrackingAnchor)

        let scene = MultiSetARScene.shared
        scene.renderer.gizmoAnchor = gizmoAnchor
        scene.renderer.gizmoVisual = gizmoVisual
        scene.renderer.mapParent = gizmoAnchor
        scene.renderer.objectRoot = objectTrackingAnchor

        MultiSet.shared.setARSession(arView.session)
        MultiSet.shared.setPoseSink(scene.renderer)
        MultiSet.shared.setMeshRenderer(scene.renderer)
        MultiSet.shared.setGeoHintProvider(scene.geoHintProvider)
    }

    // MARK: - Gizmo Setup

    private func addGizmo(to arView: ARView) -> (AnchorEntity, Entity) {
        // Create a red axis for X
        let xAxis = ModelEntity(
            mesh: .generateBox(size: [0.5, 0.05, 0.05]),
            materials: [SimpleMaterial(color: .red, isMetallic: false)]
        )
        xAxis.position = [0.25, 0, 0]

        // Create a green axis for Y
        let yAxis = ModelEntity(
            mesh: .generateBox(size: [0.05, 0.5, 0.05]),
            materials: [SimpleMaterial(color: .green, isMetallic: false)]
        )
        yAxis.position = [0, 0.25, 0]

        // Create a blue axis for Z
        let zAxis = ModelEntity(
            mesh: .generateBox(size: [0.05, 0.05, 0.5]),
            materials: [SimpleMaterial(color: .blue, isMetallic: false)]
        )
        zAxis.position = [0, 0, 0.25]

        // Create origin sphere
        let sphere = ModelEntity(
            mesh: .generateSphere(radius: 0.05),
            materials: [SimpleMaterial(color: .black, isMetallic: false)]
        )
        sphere.position = [0, 0, 0]

        // Group axes into gizmo entity
        let gizmoEntity = Entity()
        gizmoEntity.addChild(xAxis)
        gizmoEntity.addChild(yAxis)
        gizmoEntity.addChild(zAxis)
        gizmoEntity.addChild(sphere)

        // Hide the gizmo until the first successful localization
        // Re-enabled by the gizmo update handler on localization success.
        gizmoEntity.isEnabled = false

        // Create anchor at origin
        let anchorEntity = AnchorEntity(world: [0, 0, 0])
        anchorEntity.addChild(gizmoEntity)

        // Add to scene
        arView.scene.anchors.append(anchorEntity)

        return (anchorEntity, gizmoEntity)
    }

    // MARK: - Lighting

    private func addLighting(to arView: ARView) {
        let directionalLight = DirectionalLight()
        directionalLight.light.color = .white
        directionalLight.light.intensity = 1000
        directionalLight.light.isRealWorldProxy = true

        directionalLight.position = [0, 2, 0]
        directionalLight.orientation = simd_quatf(angle: -.pi / 4, axis: [1, 0, 0])

        let lightAnchor = AnchorEntity(world: [0, 0, 0])
        lightAnchor.addChild(directionalLight)

        arView.scene.anchors.append(lightAnchor)
    }
}

// MARK: - Internal Gizmo Manager

internal class GizmoManager {
    var gizmoAnchor: AnchorEntity?
}
