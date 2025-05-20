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
                        //                        Spacer()
                        
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
                                print("Camera Position: \(position)")
                                print("Camera Rotation: \(rotation)")
                                
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
            
            print("width: \(width), height: \(height), fx: \(fx), fy: \(fy), px: \(px), py: \(py)")
            print("Image Data Size: \(resizedData.imageData.count) bytes")
            print("Resized Image Dimensions: \(width)x\(height)")
      
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
            
            print("Image Data Size: \(imageData?.count ?? 0) bytes")
        }
        
        // Use the parameters dictionary in your request
        print("Parameters: \(parameters)")
        
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
                    return
                }
                if let response = response as? HTTPURLResponse {
                    self.localizationMessage = "Status Code: \(response.statusCode)"
                    print("HTTP Status Code: \(response.statusCode)")
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
                            
                            print("Resulting Pose: \(resultPose)")
                            
                            self.toastMessage = selectedMapType == .map ? "Map Localized" : "MapSet Localized"
                            self.showToast = true
                            
                        } else {
                            print("Pose not found.")
                        }
                    } catch {
                        print("Failed to decode response: \(error)")
                    }
                }
                
            }
        }.resume()
    }
    
    
    func getCurrentCameraPose() -> (position: SIMD3<Float>, rotation: simd_quatf)? {
        guard let frame = viewModel.session?.currentFrame else {
            print("No current ARFrame available")
            return nil
        }
        
        // Extract position from the camera's transform
        let position = SIMD3<Float>(
            frame.camera.transform.columns.3.x,
            frame.camera.transform.columns.3.y,
            frame.camera.transform.columns.3.z
        )
        
        // Extract rotation as a quaternion
        let rotation = simd_quatf(frame.camera.transform)
        
        return (position, rotation)
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
        
        // Negate specific matrix elements to align with Three.js logic
        rotationMatrix.columns.1 *= -1 // Negate second column
        rotationMatrix.columns.2 *= -1 // Negate third column
        
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
        
        let resultRotation = simd_quatf(resultantMatrix)
        
        // Log the results
        print("Result Position: \(resultPosition)")
        print("Result Rotation: \(resultRotation)")
        
        // Update gizmo in the AR scene
        viewModel.localizeGizmo(position: resultPosition, rotation: resultRotation)
        
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
    
    func saveResizedImageDataAsJPG(imageData: Data, fileName: String) {
        // Get the app's document directory
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("Failed to access document directory")
            return
        }
        
        // Append the file name to the directory
        let fileURL = documentsDirectory.appendingPathComponent(fileName).appendingPathExtension("jpg")
        
        do {
            // Write the image data to the file
            try imageData.write(to: fileURL)
            print("Image saved successfully at \(fileURL.path)")
        } catch {
            print("Failed to save image: \(error)")
        }
    }
    
    //---------------------------------------------------------------------------------
   
    func createResizedImageDataAndAdjustIntrinsics(from frame: ARFrame) -> (imageData: Data, newWidth: Int, newHeight: Int, newPx: CGFloat, newPy: CGFloat, newFx: CGFloat, newFy: CGFloat)? {
        let ciImage = CIImage(cvPixelBuffer: frame.capturedImage)
        let context = CIContext()

        // Current resolution
        let currentWidth = ciImage.extent.width
        let currentHeight = ciImage.extent.height

        // Desired resolution (960x720)
        let targetWidth: CGFloat = 960
        let targetHeight: CGFloat = 720

        // Calculate scaling factors
        let scaleX = targetWidth / currentWidth
        let scaleY = targetHeight / currentHeight

        // Apply scaling transform
        let transform = CGAffineTransform(scaleX: scaleX, y: scaleY)
        let resizedImage = ciImage.transformed(by: transform)
  
        guard let imageData = context.jpegRepresentation(of: resizedImage, colorSpace: CGColorSpaceCreateDeviceRGB()) else {
            return nil
        }

        // Adjust camera intrinsic values
        let intrinsics = frame.camera.intrinsics
        let newFx = CGFloat(intrinsics[0][0]) * scaleX
        let newFy = CGFloat(intrinsics[1][1]) * scaleY
        let newPx = CGFloat(intrinsics[2][0]) * scaleX
        let newPy = CGFloat(intrinsics[2][1]) * scaleY

        return (imageData, Int(targetWidth), Int(targetHeight), newPx, newPy, newFx, newFy)
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
