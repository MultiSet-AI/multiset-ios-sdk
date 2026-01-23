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

    // MARK: - Helper Methods

    static func hasCredentials() -> Bool {
        return !clientId.isEmpty && clientId != "YOUR_CLIENT_ID" &&
               !clientSecret.isEmpty && clientSecret != "YOUR_CLIENT_SECRET"
    }

    static func hasMapConfiguration() -> Bool {
        return (!mapCode.isEmpty && mapCode != "YOUR_MAP_CODE") || !mapSetCode.isEmpty
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
        // AUTO LOCALIZATION
        // ═══════════════════════════════════════════════════════════════
        config.autoLocalize = true                     // Auto-start localization when AR begins
        config.backgroundLocalization = true           // Continue localizing at intervals
        config.bgLocalizationDurationSeconds = 30.0    // Interval between background localizations (15-180s)
        config.relocalization = true                   // Re-localize when tracking is lost
        config.firstLocalizationUntilSuccess = true    // Retry first localization until success

        // ═══════════════════════════════════════════════════════════════
        // MULTI-FRAME CAPTURE SETTINGS
        // ═══════════════════════════════════════════════════════════════
        config.numberOfFrames = 4                      // Frames to capture (4-6)
        config.frameCaptureIntervalMs = 500            // Interval between captures (300-800ms)

        // ═══════════════════════════════════════════════════════════════
        // CONFIDENCE SETTINGS
        // ═══════════════════════════════════════════════════════════════
        config.confidenceCheck = true                 // Enable confidence threshold check
        config.confidenceThreshold = 0.3               // Minimum confidence (0.2-0.8)

        // ═══════════════════════════════════════════════════════════════
        // GPS SETTINGS
        // ═══════════════════════════════════════════════════════════════
        config.passGeoPose = false                     // Send GPS coordinates as hint
        config.geoCoordinatesInResponse = false        // Include geo coordinates in response

        // ═══════════════════════════════════════════════════════════════
        // UI SETTINGS
        // ═══════════════════════════════════════════════════════════════
        config.showAlerts = true                       // Show success/failure alerts
        config.meshVisualization = true                // Show 3D mesh after localization

        // ═══════════════════════════════════════════════════════════════
        // IMAGE QUALITY
        // ═══════════════════════════════════════════════════════════════
        config.imageQuality = 90                       // JPEG quality (50-100)

        return config
    }
}
