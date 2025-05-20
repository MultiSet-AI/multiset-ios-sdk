/*
Copyright (c) 2025 MultiSet AI. All rights reserved.
Licensed under the MultiSet License. You may not use this file except in compliance with the License. and you can’t re-distribute this file without a prior notice
For license details, visit www.multiset.ai.
Redistribution in source or binary forms must retain this notice.
*/


import Foundation
import Combine
import ARKit
import RealityKit


class ARViewModel : NSObject, ARSessionDelegate, ObservableObject {
    
    var arViewContainer: ARViewContainer?
    
    @Published var appState = AppState()
    var session: ARSession? = nil
    var arView: ARView? = nil
    
    var gizmoAnchor: AnchorEntity?
    
    var cancellables = Set<AnyCancellable>()
    
    //---------------------------------------------------------------------------------
    func localizeGizmo2(position: SIMD3<Float>, rotation: simd_quatf) {
        
        gizmoAnchor?.transform.translation = position
        gizmoAnchor?.transform.rotation = rotation
        
        print("Gizmo updated to Position: \(position), Rotation: \(rotation)")
    }
    
    func localizeGizmo(position: SIMD3<Float>, rotation: simd_quatf) {
        
        guard let gizmoAnchor = gizmoAnchor else {
            print("Gizmo anchor is not initialized")
            return
        }
        guard position.x.isFinite, position.y.isFinite, position.z.isFinite else {
            print("Invalid position: \(position)")
            return
        }
        guard rotation.vector.x.isFinite, rotation.vector.y.isFinite, rotation.vector.z.isFinite, rotation.vector.w.isFinite else {
            print("Invalid rotation: \(rotation)")
            return
        }
        
        gizmoAnchor.transform.translation = position
        gizmoAnchor.transform.rotation = rotation
        
        print("Gizmo updated to Position: \(position), Rotation: \(rotation)")
    }
    
    
    func resetWorldOrigin() {
        session?.pause()
        let config = createARConfiguration()
        session?.run(config, options: [.resetTracking])
        arViewContainer?.resetGizmoPosition()
    }
    
    
    func createARConfiguration() -> ARWorldTrackingConfiguration {
        let configuration = ARWorldTrackingConfiguration()
        configuration.worldAlignment = .gravity
        if type(of: configuration).supportsFrameSemantics(.sceneDepth) {
            // Activate sceneDepth
            configuration.frameSemantics = .sceneDepth
        }
        return configuration
    }
    //---------------------------------------------------------------------------------
    
    func session(
        _ session: ARSession,
        didUpdate frame: ARFrame
    ) {
        //        frameSubject.send(frame)
    }
    
    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        self.appState.trackingState = trackingStateToString(camera.trackingState)
    }
    
    func trackingStateToString(_ trackingState: ARCamera.TrackingState) -> String {
        switch trackingState {
        case .notAvailable: return "Not Available"
        case .normal: return "Tracking Normal"
        case .limited(.excessiveMotion): return "Excessive Motion"
        case .limited(.initializing): return "Tracking Initializing"
        case .limited(.insufficientFeatures): return  "Insufficient Features"
        default: return "Unknown"
        }
    }
}
