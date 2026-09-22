/*
Copyright (c) 2026 MultiSet AI. All rights reserved.
Licensed under the MultiSet License. You may not use this file except in compliance with the License. and you can't re-distribute this file without a prior notice
For license details, visit www.multiset.ai.
Redistribution in source or binary forms must retain this notice.
*/

import Foundation
import SwiftUI
import Combine
import simd
import MultiSetSDK

/// Demo app delegate that receives SDK events
/// In a real app, the user would implement MultiSetCallback. The SDK calls every method on
/// the main actor, so `@Published` state is updated directly.
class MultiSetSDKDelegate: ObservableObject, MultiSetCallback {

    // MARK: - Published Properties

    @Published var isSDKReady = false
    @Published var isAuthenticated = false
    @Published var isAuthenticating = false
    @Published var statusText = "Not authenticated"
    @Published var lastLocalizationResult: LocalizationResult?
    @Published var lastError: String?
    @Published var lastFalsePositive: FalsePositiveInfo?
    @Published var anchorTrust: AnchorTrust = .provisional

    // MARK: - Callbacks for UI updates

    var onLocalizationSuccess: ((LocalizationResult) -> Void)?
    var onLocalizationFailure: ((String) -> Void)?
    var onLocalizationFalsePositive: ((FalsePositiveInfo) -> Void)?
    var onLocalizationCorrected: ((AnchorPose, AnchorPose, AnchorTrust) -> Void)?
    var onAnchorTrustChanged: ((AnchorTrust) -> Void)?
    var onTrackingChanged: ((TrackingState) -> Void)?
    var onMeshLoaded: ((String) -> Void)?
    var onObjectTrackingSuccess: ((String, Double) -> Void)?
    var onObjectTrackingFailure: ((String) -> Void)?
    var onObjectMeshLoaded: ((String) -> Void)?

    // MARK: - MultiSetCallback Implementation

    func onSDKReady() {
        self.isSDKReady = true
        self.statusText = "SDK ready, authenticating..."
        print("MultiSetSDKDelegate >> SDK Ready")
    }

    func onAuthenticationSuccess() {
        self.isAuthenticated = true
        self.isAuthenticating = false
        self.statusText = "Authenticated"
        print("MultiSetSDKDelegate >> Authentication Success")
    }

    func onAuthenticationFailure(error: String) {
        self.isAuthenticated = false
        self.isAuthenticating = false
        self.statusText = "Authentication failed"
        self.lastError = error
        print("MultiSetSDKDelegate >> Authentication Failed: \(error)")
    }

    func onLocalizationSuccess(result: LocalizationResult) {
        self.lastLocalizationResult = result
        self.onLocalizationSuccess?(result)
        print("MultiSetSDKDelegate >> Localization Success: \(result)")
    }

    func onLocalizationFailure(error: String) {
        self.lastError = error
        self.onLocalizationFailure?(error)
        print("MultiSetSDKDelegate >> Localization Failed: \(error)")
    }

    /// The server answered with a pose, but the SDK threw it away because it
    /// contradicts the device's own motion. Nothing in the AR scene moved — this is
    /// the only callback fired for such a response.
    func onLocalizationFalsePositive(info: FalsePositiveInfo) {
        self.lastFalsePositive = info
        self.onLocalizationFalsePositive?(info)
        print("MultiSetSDKDelegate >> Localization False Positive: \(info.summary)")
    }

    /// A challenger out-voted the anchor: the map frame moved, and anything the app
    /// placed in world space against the old frame is now in the wrong place.
    func onLocalizationCorrected(from: AnchorPose, to: AnchorPose, trust: AnchorTrust) {
        self.anchorTrust = trust
        self.onLocalizationCorrected?(from, to, trust)
        print("MultiSetSDKDelegate >> Anchor corrected by \(simd_distance(from.position, to.position)) m, trust now \(trust)")
    }

    func onAnchorTrustChanged(_ trust: AnchorTrust) {
        self.anchorTrust = trust
        self.onAnchorTrustChanged?(trust)
    }

    func onTrackingStateChanged(state: TrackingState) {
        self.onTrackingChanged?(state)
        print("MultiSetSDKDelegate >> Tracking State: \(state)")
    }

    func onMeshLoaded(mapCode: String) {
        self.onMeshLoaded?(mapCode)
        print("MultiSetSDKDelegate >> Mesh Loaded: \(mapCode)")
    }

    func onMeshLoadError(error: String) {
        self.lastError = error
        print("MultiSetSDKDelegate >> Mesh Load Error: \(error)")
    }

    func onObjectTrackingSuccess(objectCode: String, confidence: Double) {
        self.onObjectTrackingSuccess?(objectCode, confidence)
        print("MultiSetSDKDelegate >> Object Tracking Success: \(objectCode), confidence: \(confidence)")
    }

    func onObjectTrackingFailure(error: String) {
        self.lastError = error
        self.onObjectTrackingFailure?(error)
        print("MultiSetSDKDelegate >> Object Tracking Failed: \(error)")
    }

    func onObjectMeshLoaded(objectCode: String) {
        self.onObjectMeshLoaded?(objectCode)
        print("MultiSetSDKDelegate >> Object Mesh Loaded: \(objectCode)")
    }
}
