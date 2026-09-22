/*
Copyright (c) 2026 MultiSet AI. All rights reserved.
Licensed under the MultiSet License. You may not use this file except in compliance with the License. and you can't re-distribute this file without a prior notice
For license details, visit www.multiset.ai.
Redistribution in source or binary forms must retain this notice.
*/

import Foundation
import MultiSetSDK

/// Demo App Configuration
/// SDK users should modify this file with their own credentials and settings
struct SDKConfig {

    // MARK: - API Environment
    static let baseURL = MultiSetConfig.productionBaseURL  // e.g. "https://api.multiset.ai"

    // MARK: - Authentication Credentials
    // Get your credentials at: https://developer.multiset.ai/credentials

    static let clientId = "YOUR_CLIENT_ID"
    static let clientSecret = "YOUR_CLIENT_SECRET"

    // MARK: - Map Configuration
    // Use either mapCode OR mapSetCode (not both)

    static let mapCode = "YOUR_MAP_CODE"
    static let mapSetCode = ""

    // MARK: - Object Tracking Configuration
    // Add object codes for object tracking mode (max 10)

    static let objectCodes: [String] = []  // e.g. ["OBJ_CODE1", "OBJ_CODE2"]

    // MARK: - Helper Methods

    static func hasCredentials() -> Bool {
        return !clientId.isEmpty && clientId != "YOUR_CLIENT_ID" &&
               !clientSecret.isEmpty && clientSecret != "YOUR_CLIENT_SECRET"
    }

    static func hasMapConfiguration() -> Bool {
        return (!mapCode.isEmpty && mapCode != "YOUR_MAP_CODE") || !mapSetCode.isEmpty
    }

    static func hasObjectTrackingConfiguration() -> Bool {
        return !objectCodes.isEmpty
    }

    static func getActiveMapType() -> MapType {
        if !mapSetCode.isEmpty {
            return .mapSet
        }
        return .map
    }

    // MARK: - SDK Configuration Builder

    /// Build the SDK configuration with your preferred settings
    /// Modify the values below to customize SDK behavior
    static func buildConfig() -> MultiSetConfig {
        // Behavioral parameters come from the user-editable Settings screen
        // (persisted via ConfigStore). Credentials, map codes and object codes
        // stay sourced from this file. Editing the values here is still supported
        // for SDK users who don't use the Settings UI — but a saved Settings value
        // will override them on the next run.
        let store = ConfigStore.shared

        var config = MultiSetConfig(
            clientId: clientId,
            clientSecret: clientSecret,
            mapCode: mapCode,
            mapSetCode: mapSetCode,
            baseURL: baseURL
        )

        // ═══════════════════════════════════════════════════════════════
        // LOCALIZATION MODE
        // ═══════════════════════════════════════════════════════════════
        // Single frame is the default: one image means one upload and one match,
        // so the response comes back noticeably faster. Switch to .multiFrame
        // (or flip the Mode picker on the landing screen) when a scene needs the
        // extra robustness of 4-6 frames.
        config.localizationMode = .singleFrame  // .singleFrame or .multiFrame

        // Which matching pipeline single-frame queries use. Editable in Settings.
        // No effect in .multiFrame mode — multi-frame always runs on VPS-1.
        config.queryMode = store.queryMode

        // ═══════════════════════════════════════════════════════════════
        // AUTO LOCALIZATION (editable in Settings)
        // ═══════════════════════════════════════════════════════════════
        config.autoLocalize = store.autoLocalize
        config.backgroundLocalization = store.backgroundLocalization
        config.bgLocalizationDurationSeconds = Float(store.bgLocalizationIntervalSeconds)
        config.relocalization = store.relocalization
        config.firstLocalizationUntilSuccess = store.firstLocalizationUntilSuccess

        // ═══════════════════════════════════════════════════════════════
        // MULTI-FRAME CAPTURE SETTINGS
        // ═══════════════════════════════════════════════════════════════
        config.numberOfFrames = store.numberOfFrames   // Frames to capture (4-6), editable in Settings
        config.frameCaptureIntervalMs = 500            // Interval between captures (300-800ms)

        // ═══════════════════════════════════════════════════════════════
        // CONFIDENCE SETTINGS (editable in Settings)
        // ═══════════════════════════════════════════════════════════════
        config.confidenceCheck = store.confidenceCheck
        config.confidenceThreshold = Float(store.confidenceThreshold)

        // ═══════════════════════════════════════════════════════════════
        // POSE CONSISTENCY / FALSE-POSITIVE GATE (editable in Settings)
        // ═══════════════════════════════════════════════════════════════
        // OFF: every localization response the server returns is accepted.
        // ON:  a response has to out-vote the current anchor across separated query
        //      viewpoints before the scene moves. One that cannot is discarded and
        //      `onLocalizationFalsePositive` fires instead of `onLocalizationSuccess`,
        //      with the gizmo and mesh left alone. The two limits below are applied flat
        //      and independently: a response inside the distance can still fail heading.
        config.poseConsistencyCheck = store.poseConsistencyCheck
        config.poseConsistencyThreshold = Float(store.poseConsistencyThreshold)
        config.poseConsistencyYawThreshold = Float(store.poseConsistencyYawThreshold)

        // ═══════════════════════════════════════════════════════════════
        // GPS / HINT SETTINGS (editable in Settings)
        // ═══════════════════════════════════════════════════════════════
        config.passGeoPose = store.enableGeoHint
        config.geoCoordinatesInResponse = store.includeGeoCoordinatesInResponse
        config.hintRadius = store.hintRadius
        config.use2DFiltering = store.use2DFiltering
        config.hintMapCodes = store.hintMapCodesList
        config.hintPosition = store.hintPosition
        config.hintFloorHeight = store.hintFloorHeight

        // ═══════════════════════════════════════════════════════════════
        // UI SETTINGS
        // ═══════════════════════════════════════════════════════════════
        config.showAlerts = true                       // Show success/failure alerts
        config.meshVisualization = true                // Show 3D mesh after localization

        // ═══════════════════════════════════════════════════════════════
        // IMAGE QUALITY
        // ═══════════════════════════════════════════════════════════════
        config.imageQuality = 90                       // JPEG quality (50-100)

        // ═══════════════════════════════════════════════════════════════
        // OBJECT TRACKING (behavior editable in Settings; codes from this file)
        // ═══════════════════════════════════════════════════════════════
        config.objectCodes = objectCodes                       // Object codes to track (max 10)
        config.autoObjectTracking = store.autoTracking
        config.backgroundObjectTracking = store.backgroundTracking
        config.bgObjectTrackingDurationSeconds = Float(store.bgTrackingDurationSeconds)
        config.restartObjectTracking = store.restartTracking
        config.objectTrackingCaptureDelay = 1.0                // Delay before capture (seconds)
        config.firstObjectTrackingUntilSuccess = store.firstTrackingUntilSuccess

        return config
    }
}
