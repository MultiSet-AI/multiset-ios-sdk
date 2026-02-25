/*
Copyright (c) 2026 MultiSet AI. All rights reserved.
Licensed under the MultiSet License. You may not use this file except in compliance with the License. and you can't re-distribute this file without a prior notice
For license details, visit www.multiset.ai.
Redistribution in source or binary forms must retain this notice.
*/

import Foundation
import SwiftUI
import Combine
import MultiSetSDK

/// Demo app delegate that receives SDK events
/// In a real app, the user would implement MultiSetCallback
class MultiSetSDKDelegate: ObservableObject, MultiSetCallback {

    // MARK: - Published Properties

    @Published var isSDKReady = false
    @Published var isAuthenticated = false
    @Published var isAuthenticating = false
    @Published var statusText = "Not authenticated"
    @Published var lastLocalizationResult: LocalizationResult?
    @Published var lastError: String?

    // MARK: - Callbacks for UI updates

    var onLocalizationSuccess: ((LocalizationResult) -> Void)?
    var onLocalizationFailure: ((String) -> Void)?
    var onTrackingChanged: ((TrackingState) -> Void)?
    var onMeshLoaded: ((String) -> Void)?

    // MARK: - MultiSetCallback Implementation

    func onSDKReady() {
        DispatchQueue.main.async {
            self.isSDKReady = true
            self.statusText = "SDK ready, authenticating..."
            print("MultiSetSDKDelegate >> SDK Ready")
        }
    }

    func onAuthenticationSuccess() {
        DispatchQueue.main.async {
            self.isAuthenticated = true
            self.isAuthenticating = false
            self.statusText = "Authenticated"
            print("MultiSetSDKDelegate >> Authentication Success")
        }
    }

    func onAuthenticationFailure(error: String) {
        DispatchQueue.main.async {
            self.isAuthenticated = false
            self.isAuthenticating = false
            self.statusText = "Authentication failed"
            self.lastError = error
            print("MultiSetSDKDelegate >> Authentication Failed: \(error)")
        }
    }

    func onLocalizationSuccess(result: LocalizationResult) {
        DispatchQueue.main.async {
            self.lastLocalizationResult = result
            self.onLocalizationSuccess?(result)
            print("MultiSetSDKDelegate >> Localization Success: mapCode=\(result.mapCode)")
        }
    }

    func onLocalizationFailure(error: String) {
        DispatchQueue.main.async {
            self.lastError = error
            self.onLocalizationFailure?(error)
            print("MultiSetSDKDelegate >> Localization Failed: \(error)")
        }
    }

    func onTrackingStateChanged(state: TrackingState) {
        DispatchQueue.main.async {
            self.onTrackingChanged?(state)
            print("MultiSetSDKDelegate >> Tracking State: \(state)")
        }
    }

    func onMeshLoaded(mapCode: String) {
        DispatchQueue.main.async {
            self.onMeshLoaded?(mapCode)
            print("MultiSetSDKDelegate >> Mesh Loaded: \(mapCode)")
        }
    }

    func onMeshLoadError(error: String) {
        DispatchQueue.main.async {
            self.lastError = error
            print("MultiSetSDKDelegate >> Mesh Load Error: \(error)")
        }
    }
}
