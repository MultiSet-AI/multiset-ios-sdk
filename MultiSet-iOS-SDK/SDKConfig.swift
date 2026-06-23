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
            mapSetCode: mapSetCode
        )

        // ═══════════════════════════════════════════════════════════════
        // LOCALIZATION MODE
        // ═══════════════════════════════════════════════════════════════
        config.localizationMode = .multiFrame  // .singleFrame or .multiFrame

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
