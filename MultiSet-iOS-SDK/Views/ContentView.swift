/*
 Copyright (c) 2025 MultiSet AI. All rights reserved.
 Licensed under the MultiSet License. You may not use this file except in compliance with the License. and you can’t re-distribute this file without a prior notice
 For license details, visit www.multiset.ai.
 Redistribution in source or binary forms must retain this notice.
 */

import SwiftUI
import ARKit
import RealityKit
import simd

enum MapType {
    case map
    case mapSet
}

struct ContentView: View {
    
    @StateObject private var viewModel: ARViewModel
    @StateObject private var authManager = AuthManager()
    @State private var showAuthMessage: Bool = false
    
    @State private var localizationMessage: String? = nil
    
    @State private var camPos = SIMD3<Float>(0, 0, 0) // Camera position as state
    @State private var camRot = simd_quatf(angle: 0, axis: SIMD3<Float>(0, 1, 0)) // Camera rotation as state
    
    @State private var authenticationStatus: String? = nil
    // State to control button visibility
    @State private var isAuthenticated: Bool = false
    
    @State private var isLoading: Bool = false // Loader state variable
    
    @State private var toastMessage: String? = nil
    @State private var showToast: Bool = false
    
    
    //Select Between map and mapSet
    @State private var selectedMapType: MapType = .map // Default to `.map`
    
    
    init(viewModel vm: ARViewModel) {
        _viewModel = StateObject(wrappedValue: vm)
    }
    
    var body: some View {
        ZStack {
            ZStack(alignment: .topTrailing) {
                ARViewContainer(viewModel).edgesIgnoringSafeArea(.all)
                VStack() {
                    ZStack() {
                        
                    }.padding(8)
                    HStack() {
                        
                        VStack(alignment:.leading) {
                            
                            // Existing tracking text
                            Text("\(viewModel.appState.trackingState)")
                            
                            Spacer()
                            
                        }.padding()
                    }
                }
            }
            VStack {
                Spacer()
                
                if showToast, let message = toastMessage {
                    ToastView(message: message)
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                self.showToast = false
                            }
                        }
                }
                
                // Display authentication status if available
                if let authStatus = authenticationStatus {
                    Text(authStatus)
                        .padding(8)
                        .foregroundColor(.white)
                        .background(Color.purple.opacity(0.5))
                        .cornerRadius(10)
                }
                
                HStack(spacing: 20) {
                    Spacer()
                    
                    if !isAuthenticated {
                        Button(action: {
                            
                            guard !SDKConfig.clientId.isEmpty, !SDKConfig.clientSecret.isEmpty else {
                                authenticationStatus = "Please enter ClientId and ClientSecret in SDKConfig file"
                                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                    authenticationStatus = nil
                                }
                                return
                            }
                            
                            
                            authenticationStatus = "Authenticating..."
                            
                            authManager.authUser { success in
                                showAuthMessage = true
                                
                                if success {
                                    authenticationStatus = "Authenticated"
                                    isAuthenticated = true
                                    // Optionally clear after a delay
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                                        authenticationStatus = nil
                                    }
                                } else {
                                    authenticationStatus = "Authentication Failed!"
                                    // Optionally clear after a delay
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                        authenticationStatus = nil
                                    }
                                }
                            }
                        }) {
                            Text("Auth")
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                        }
                        .buttonStyle(.borderedProminent)
                        .buttonBorderShape(.capsule)
                        
                    }
                    if isAuthenticated {
                        Button(action: {
                            viewModel.resetWorldOrigin()
                            
                        }) {
                            Text("Reset")
                                .foregroundColor(.orange    )
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                        }
                        .buttonStyle(.borderedProminent)
                        .buttonBorderShape(.capsule)
                        
                        Button(action: {
                            
                            switch selectedMapType {
                            case .map:
                                guard !SDKConfig.mapCode.isEmpty else {
                                    toastMessage = "Please enter mapCode in SDKConfig file"
                                    showToast = true
                                    return
                                }
                            case .mapSet:
                                guard !SDKConfig.mapSetCode.isEmpty else {
                                    toastMessage = "Please enter mapSetCode in SDKConfig file"
                                    showToast = true
                                    return
                                }
                            }
                            
                            
                            if let (position, rotation) = getCurrentCameraPose() {
                                camPos = position
                                camRot = rotation
                            }
                            
                            if let frame = viewModel.session?.currentFrame {
                                sendLocalizationRequest(frame: frame)
                            }
                        }) {
                            Text("Localize")
                                .padding(.horizontal, 20)
                                .padding(.vertical, 5)
                        }
                        .buttonStyle(.borderedProminent)
                        .buttonBorderShape(.capsule)
                    }
                }
                .padding()
            }
            
            .preferredColorScheme(.dark)
            // Loader view
            if isLoading {
                ZStack {
                    Color.black.opacity(0.5).edgesIgnoringSafeArea(.all)
                    VStack {
                        ProgressView(selectedMapType == .map ? "Localizing Map..." : "Localizing MapSet...")
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.black.opacity(0.6))
                            .cornerRadius(10)
                    }
                }
            }
            
        }
        
    }
    
    //------------------------------------------------------------------------------------------------------------------------
    
    
    func getCurrentCameraPose() -> (position: SIMD3<Float>, rotation: simd_quatf)? {
        guard let frame = viewModel.session?.currentFrame
        else {
            print("No current ARFrame available")
            return nil
        }
        
        // Check if tracking is ready
        guard case .normal = frame.camera.trackingState else {
            print("AR tracking is not in normal state: \(frame.camera.trackingState)")
            return nil
        }
        
        // Get the current device orientation
        let interfaceOrientation = UIApplication
            .shared
            .windows
            .first?
            .windowScene?
            .interfaceOrientation ?? .portrait
        
        // Extract position from the camera's transform (this remains the same)
        let position = SIMD3<Float>(
            frame.camera.transform.columns.3.x,
            frame.camera.transform.columns.3.y,
            frame.camera.transform.columns.3.z
        )
        
        // Extract rotation as a quaternion
        var rotation = simd_quatf(frame.camera.transform)
        
        // Apply orientation correction to match Unity ARFoundation behavior
        // Unity ARFoundation always reports camera rotation relative to landscape orientation
        if interfaceOrientation.isPortrait {
            // In portrait mode, we need to remove the extra 90-degree rotation
            // Create a quaternion for -90 degrees around Z axis (counter-clockwise)
            let orientationCorrection = simd_quatf(angle: .pi / 2, axis: SIMD3<Float>(0, 0, 1))
            
            // Apply the correction to make portrait rotation match landscape
            rotation = rotation * orientationCorrection
        }
        
        // Validate that we have reasonable values (not near zero)
        let positionMagnitude = length(position)
        if positionMagnitude < 1e-6 {
            print("Camera position is too close to origin, AR might not be initialized yet")
            return nil
        }
        
        return (position, rotation)
    }
    
    
    //------------------------------------------------------------------------------------------------------------------------
    
    func sendLocalizationRequest(frame: ARFrame) {
        isLoading = true // Show loader when the request starts
        
        
        // Ensure the authentication token exists
        guard let token = authManager.token else {
            localizationMessage = "Authentication token is missing. Please authenticate first."
            print(localizationMessage ?? "")
            isLoading = false // Hide loader on failure
            return
        }
        
        var parameters: [String: String] = [:]
        var imageData: Data? = nil
        
        if let resizedData = createResizedImageDataAndAdjustIntrinsics(from: frame) {
            
            let width = resizedData.newWidth
            let height = resizedData.newHeight
            let fx = resizedData.newFx
            let fy = resizedData.newFy
            let px = resizedData.newPx
            let py = resizedData.newPy
            
            // Dynamically create the parameters dictionary
            parameters = [
                "isRightHanded": "true",
                "px": "\(px)",
                "py": "\(py)",
                "fx": "\(fx)",
                "fy": "\(fy)",
                "width": "\(width)",
                "height": "\(height)"
            ]
            
            switch selectedMapType {
            case .map:
                parameters["mapCode"] = SDKConfig.mapCode
            case .mapSet:
                parameters["mapSetCode"] = SDKConfig.mapSetCode
            }
            
            imageData = resizedData.imageData
        }
        
        // Create the URLRequest
        var request = URLRequest(url: URL(string: SDKConfig.queryURL)!)
        request.httpMethod = "POST"
        
        // Set Authorization header
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        // Generate boundary string
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        // Create multipart form body
        let httpBody = createBody(parameters: parameters,
                                  boundary: boundary,
                                  dataFieldName: "queryImage",
                                  data: imageData!,
                                  mimeType: "image/jpeg",
                                  filename: "frame.jpg")
        request.httpBody = httpBody
        
        // Send the request
        let session = URLSession.shared
        session.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                
                isLoading = false // Hide loader once the request completes
                
                if let error = error {
                    self.localizationMessage = "Localization failed: \(error.localizedDescription)"
                    print("Error: \(error.localizedDescription)")
                    // Show error alert
                    self.toastMessage = "Localization failed"
                    self.showToast = true
                    return
                }
                
                if let response = response as? HTTPURLResponse {
                    self.localizationMessage = "Status Code: \(response.statusCode)"
                    print("HTTP Status Code: \(response.statusCode)")
                    
                    // Check for non-200 status code
                    if response.statusCode != 200 {
                        self.toastMessage = "Localization failed"
                        self.showToast = true
                        return
                    }
                }
                
                if let data = data {
                    do {
                        if let responseString = String(data: data, encoding: .utf8) {
                            self.localizationMessage = "Localization successful: \(responseString)"
                            print("Response Body: \(responseString)")
                        }
                        
                        let localizationResponse = try JSONDecoder().decode(LocalizationResponse.self, from: data)
                        
                        if localizationResponse.poseFound {
                            
                            let resultPose = poseHandler(localizationResponse: localizationResponse, camPos: camPos, camRot: camRot)
                            
                            // Show success toast
                            self.toastMessage = "Localization Success"
                            self.showToast = true
                        } else {
                            // Show failure toast when pose is not found
                            self.toastMessage = "Localization failed"
                            self.showToast = true
                            print("Pose not found.")
                        }
                    } catch {
                        // Show error toast for decoding issues
                        self.toastMessage = "Localization failed"
                        self.showToast = true
                        print("Failed to decode response: \(error)")
                    }
                }
            }
        }.resume()
    }
    
    
    //---------------------------------------------------------------------------------
    
    func createResizedImageDataAndAdjustIntrinsics(
        from frame: ARFrame
    ) -> (imageData: Data,
          newWidth: Int,
          newHeight: Int,
          newPx: CGFloat,
          newPy: CGFloat,
          newFx: CGFloat,
          newFy: CGFloat)?
    {
        let ciImage = CIImage(cvPixelBuffer: frame.capturedImage)
        let context = CIContext()
        
        // 1) Determine UI orientation
        let interfaceOrientation = UIApplication
            .shared
            .windows
            .first?
            .windowScene?
            .interfaceOrientation ?? .portrait
        
        // 2) Rotate the image if we're in portrait
        let orientedCI: CIImage
        if interfaceOrientation.isPortrait {
            // 90° CCW
            orientedCI = ciImage.transformed(
                by: CGAffineTransform(rotationAngle: -.pi / 2)
            )
        } else {
            orientedCI = ciImage
        }
        
        // 3) Pick target dims (swap for portrait)
        let targetLandscape = CGSize(width: 960, height: 720)
        let targetPortrait  = CGSize(width: 720, height: 960)
        let targetSize = interfaceOrientation.isPortrait
        ? targetPortrait
        : targetLandscape
        
        // 4) Compute scale factors & print them
        let oSize = orientedCI.extent.size
        let scaleX = targetSize.width  / oSize.width
        let scaleY = targetSize.height / oSize.height
        
        // 5) Scale the CIImage
        let resizedCI = orientedCI.transformed(
            by: CGAffineTransform(scaleX: scaleX, y: scaleY)
        )
        
        // 6) JPEG encode
        guard let imageData = context.jpegRepresentation(
            of: resizedCI,
            colorSpace: CGColorSpaceCreateDeviceRGB()
        ) else {
            return nil
        }
        
        // 7) Pull out original intrinsics + buffer resolution
        let intr = frame.camera.intrinsics
        let fx = CGFloat(intr[0][0])
        let fy = CGFloat(intr[1][1])
        let cx = CGFloat(intr[2][0])
        let cy = CGFloat(intr[2][1])
        
        let buffer = frame.capturedImage
        let origW = CGFloat(CVPixelBufferGetWidth(buffer))
        let origH = CGFloat(CVPixelBufferGetHeight(buffer))
        
        // 8) Adjust intrinsics just like your Unity code
        let newFx: CGFloat
        let newFy: CGFloat
        let newPx: CGFloat
        let newPy: CGFloat
        
        if interfaceOrientation.isPortrait {
            // swap focal lengths, flip cx/ cy per rotation
            newFx = fy * scaleX
            newFy = fx * scaleY
            newPx = (origH - cy) * scaleX
            newPy = cx * scaleY
            
        } else {
            // no swap in landscape
            newFx = fx * scaleX
            newFy = fy * scaleY
            newPx = cx * scaleX
            newPy = cy * scaleY
        }
        
        // 9) Return with final ints
        return (
            imageData,
            Int(targetSize.width),
            Int(targetSize.height),
            newPx,
            newPy,
            newFx,
            newFy
        )
    }
    
    //------------------------------------------------------------------------------------------------------------------------
    
    func poseHandler(localizationResponse: LocalizationResponse, camPos: SIMD3<Float>, camRot: simd_quatf) -> simd_float4x4 {
        
        // Parse the response data for position and rotation
        let resPosition = SIMD3<Float>(
            localizationResponse.position.x,
            localizationResponse.position.y,
            localizationResponse.position.z
        )
        
        let resRotation = simd_quatf(
            ix: localizationResponse.rotation.x,
            iy: localizationResponse.rotation.y,
            iz: localizationResponse.rotation.z,
            r: localizationResponse.rotation.w
        )
        
        // Create rotation matrix from quaternion
        var rotationMatrix = simd_float4x4(resRotation)

        // Create negated response matrix (translation included)
        var negatedResponseMatrix = rotationMatrix
        negatedResponseMatrix.columns.3 = SIMD4<Float>(
            resPosition.x,
            resPosition.y,
            resPosition.z,
            1.0
        )
        
        // Invert the negated response matrix
        let invNegatedResponseMatrix = negatedResponseMatrix.inverse
        
        // Create the tracker space matrix (from camera position and rotation)
        let trackerSpaceMatrix = simd_float4x4(translation: camPos) * simd_float4x4(camRot)
        
        // Calculate the resultant matrix
        let resultantMatrix = trackerSpaceMatrix * invNegatedResponseMatrix
        
        // Decompose the resultant matrix into position, rotation, and scale
        let resultPosition = SIMD3<Float>(
            resultantMatrix.columns.3.x,
            resultantMatrix.columns.3.y,
            resultantMatrix.columns.3.z
        )
        
        let resultRotationRaw = simd_quatf(resultantMatrix)
        
        // Update gizmo in the AR scene
        viewModel.localizeGizmo(position: resultPosition, rotation: resultRotationRaw)
        
        return resultantMatrix
    }
    
    //------------------------------------------------------------------------------------------------------------------------
    
    func createBody(parameters: [String: String],
                    boundary: String,
                    dataFieldName: String,
                    data: Data,
                    mimeType: String,
                    filename: String) -> Data {
        var body = Data()
        let lineBreak = "\r\n"
        
        // Add parameters
        for (key, value) in parameters {
            body.append("--\(boundary)\(lineBreak)".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(key)\"\(lineBreak)\(lineBreak)".data(using: .utf8)!)
            body.append("\(value)\(lineBreak)".data(using: .utf8)!)
        }
        
        // Add image data
        body.append("--\(boundary)\(lineBreak)".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"\(dataFieldName)\"; filename=\"\(filename)\"\(lineBreak)".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\(lineBreak)\(lineBreak)".data(using: .utf8)!)
        body.append(data)
        body.append(lineBreak.data(using: .utf8)!)
        
        body.append("--\(boundary)--\(lineBreak)".data(using: .utf8)!)
        return body
    }
    //---------------------------------------------------------------------------------
    
}

struct LocalizationResponse: Codable {
    struct Position: Codable {
        let x: Float
        let y: Float
        let z: Float
    }
    
    struct Rotation: Codable {
        let x: Float
        let y: Float
        let z: Float
        let w: Float
    }
    
    let poseFound: Bool
    let position: Position
    let rotation: Rotation
    let confidence: Float
    let mapIds: [String]
}


extension simd_float4x4 {
    /// Create a transformation matrix from a translation vector
    init(translation: SIMD3<Float>) {
        self = matrix_identity_float4x4
        self.columns.3 = SIMD4<Float>(translation.x, translation.y, translation.z, 1.0)
    }
    
    /// Create a transformation matrix from a quaternion rotation
    init(_ rotation: simd_quatf) {
        let q = rotation.vector
        let x = q.x, y = q.y, z = q.z, w = q.w
        
        self.init(rows: [
            SIMD4<Float>(1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w), 0),
            SIMD4<Float>(2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w), 0),
            SIMD4<Float>(2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y), 0),
            SIMD4<Float>(0, 0, 0, 1)
        ])
    }
}


//TOAST Message
struct ToastView: View {
    let message: String
    
    var body: some View {
        Text(message)
            .padding()
            .background(Color.black.opacity(0.7))
            .foregroundColor(.white)
            .cornerRadius(10)
            .padding(.bottom, 50)
            .transition(.opacity)
            .animation(.easeInOut(duration: 0.5), value: 1)
    }
}


#if DEBUG
struct ContentView_Previews : PreviewProvider {
    static var previews: some View {
        ContentView(viewModel: ARViewModel())
            .previewInterfaceOrientation(.portrait)
    }
}
#endif
