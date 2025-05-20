/*
Copyright (c) 2025 MultiSet AI. All rights reserved.
Licensed under the MultiSet License. You may not use this file except in compliance with the License. and you can’t re-distribute this file without a prior notice
For license details, visit www.multiset.ai.
Redistribution in source or binary forms must retain this notice.
*/

import Foundation

class AuthManager: ObservableObject {
    @Published var authMessage: String = ""
    var token: String?
    
    func authUser(completion: @escaping (Bool) -> Void) {
        let url = URL(string: SDKConfig.sdkAuthURL)!
        var request = URLRequest(url: url, timeoutInterval: Double.infinity)
        
        // Use username and password from SDKConfig
        let clientId = SDKConfig.clientId
        let clientSecret = SDKConfig.clientSecret
        let authString = "\(clientId):\(clientSecret)"
        let authData = authString.data(using: .utf8)?.base64EncodedString() ?? ""
        request.addValue("Basic \(authData)", forHTTPHeaderField: "Authorization")
        
        request.httpMethod = "POST"
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                guard let data = data, error == nil else {
                    self.authMessage = "Authentication Failed: \(error?.localizedDescription ?? "Unknown Error")"
                    completion(false)
                    return
                }
                
                do {
                    // Decode JSON response
                    let decodedResponse = try JSONDecoder().decode(AuthResponse.self, from: data)
                    self.token = decodedResponse.token
                    print("Token: \(self.token!)")
                    self.authMessage = "Authentication Successful."
                    completion(true)
                } catch {
                    self.authMessage = "Authentication Failed: Unable to parse response"
                    completion(false)
                }
            }
        }
        task.resume()
    }
}

// Struct to decode JSON response
struct AuthResponse: Codable {
    let token: String
    let expiresOn: String
}
