/*
Copyright (c) 2025 MultiSet AI. All rights reserved.
Licensed under the MultiSet License. You may not use this file except in compliance with the License. and you can’t re-distribute this file without a prior notice
For license details, visit www.multiset.ai.
Redistribution in source or binary forms must retain this notice.
*/

import SwiftUI
import RealityKit
import ARKit

class GizmoManager {
    var gizmoAnchor: AnchorEntity?
}

struct ARViewContainer: UIViewRepresentable {
    @ObservedObject var viewModel: ARViewModel
    
    private var gizmoManager = GizmoManager() // Use the mutable wrapper
    
    // Keep a reference to the anchor entity for the gizmo
    private var gizmoAnchor: AnchorEntity?
    
    
    init(_ vm: ARViewModel) {
        viewModel = vm
    }
    
    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        let configuration = viewModel.createARConfiguration()
        configuration.worldAlignment = .gravity
        configuration.isAutoFocusEnabled = true
        
        //        arView.debugOptions = [.showWorldOrigin]
#if !targetEnvironment(simulator)
        arView.session.run(configuration)
#endif
        arView.session.delegate = viewModel
        viewModel.session = arView.session
        viewModel.arView = arView
        
        // Add custom gizmo at the origin
        gizmoManager.gizmoAnchor = addGizmo(to: arView)
        viewModel.gizmoAnchor = gizmoManager.gizmoAnchor
        
        // Add lighting
        addLighting(to: arView)
        
        return arView
    }
    
    private func addLighting(to arView: ARView) {
        // Create a directional light
        let directionalLight = DirectionalLight()
        directionalLight.light.color = .white
        directionalLight.light.intensity = 1000 // Adjust intensity
        directionalLight.light.isRealWorldProxy = true
        
        
        // Position and orient the light
        directionalLight.position = [0, 2, 0]
        directionalLight.orientation = simd_quatf(angle: -.pi / 4, axis: [1, 0, 0])
        
        // Add the light to an anchor
        let lightAnchor = AnchorEntity(world: [0, 0, 0])
        lightAnchor.addChild(directionalLight)
        
        // Attach the light anchor to the ARView
        arView.scene.anchors.append(lightAnchor)
    }
    
    
    // Reset the gizmo position to the origin
    func resetGizmoPosition() {
        
        gizmoAnchor?.transform.translation = [0, 0, 0]
        gizmoAnchor?.transform.rotation = simd_quatf(angle: 0, axis: [0, 1, 0])
    }
    
    
    // Add a gizmo to the ARView and return the anchor
    private func addGizmo(to arView: ARView) -> AnchorEntity {
        // Create a red axis for X
        let xAxis = ModelEntity(mesh: .generateBox(size: [0.5, 0.05, 0.05]), materials: [SimpleMaterial(color: .red, isMetallic: false)])
        xAxis.position = [0.25, 0, 0]
        
        // Create a green axis for Y
        let yAxis = ModelEntity(mesh: .generateBox(size: [0.05, 0.5, 0.05]), materials: [SimpleMaterial(color: .green, isMetallic: false)])
        yAxis.position = [0, 0.25, 0]
        
        // Create a blue axis for Z
        let zAxis = ModelEntity(mesh: .generateBox(size: [0.05, 0.05, 0.5]), materials: [SimpleMaterial(color: .blue, isMetallic: false)])
        zAxis.position = [0, 0, 0.25]
        
        let sphere = ModelEntity(mesh: .generateSphere(radius: 0.05), materials: [SimpleMaterial(color: .black, isMetallic: false)])
        sphere.position = [0, 0, 0]
        
        // Group the axes into one entity
        let gizmoEntity = Entity()
        gizmoEntity.addChild(xAxis)
        gizmoEntity.addChild(yAxis)
        gizmoEntity.addChild(zAxis)
        gizmoEntity.addChild(sphere)
        
        // Create an anchor at the origin and attach the gizmo to it
        let anchorEntity = AnchorEntity(world: [0, 0, 0])
        anchorEntity.addChild(gizmoEntity)
        
        // Add the anchor to the ARView's scene
        arView.scene.anchors.append(anchorEntity)
        
        return anchorEntity
    }
    
    
    func updateUIView(_ uiView: ARView, context: Context) {}
}
