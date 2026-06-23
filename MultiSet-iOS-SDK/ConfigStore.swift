/*
Copyright (c) 2026 MultiSet AI. All rights reserved.
Licensed under the MultiSet License. You may not use this file except in compliance with the License. and you can't re-distribute this file without a prior notice
For license details, visit www.multiset.ai.
Redistribution in source or binary forms must retain this notice.
*/

import Foundation
import Combine

/// Holds the demo app's editable, behavioral localization & object-tracking
/// parameters and persists them to `UserDefaults` so user adjustments survive
/// app restarts.
///
/// This is the iOS analog of the Android sample app's `ConfigStore` +
/// `LocalizationConfig` + `ObjectTrackingConfig`. It lives in the **app** module
/// (NOT the SDK): the SDK exposes a plain `MultiSetConfig` value type, and it is
/// up to the host app to decide how/whether to persist user preferences.
///
/// Usage:
///  - `ConfigStore.shared.load()` is called once at app startup (see `AppDelegate`)
///    so saved values are applied before any AR view reads them.
///  - `SDKConfig.buildConfig()` reads these values when constructing the
///    `MultiSetConfig`, so saved settings take effect on the next localization /
///    tracking run.
///  - The Settings screen edits a draft copy and calls `save()` / `resetToDefaults()`.
///
/// Note: credentials and map/object codes are intentionally NOT stored here —
/// those come from `SDKConfig` (the existing config/plist mechanism).
final class ConfigStore: ObservableObject {

    /// Persistent singleton read by `SDKConfig.buildConfig()`.
    static let shared = ConfigStore()

    // MARK: - Defaults

    enum Defaults {
        // Localization
        static let autoLocalize = true
        static let backgroundLocalization = true
        static let bgLocalizationIntervalSeconds: Double = 30
        static let relocalization = true
        static let firstLocalizationUntilSuccess = true
        static let numberOfFrames = 4
        static let confidenceCheck = true
        static let confidenceThreshold: Double = 0.3
        static let enableGeoHint = false
        static let includeGeoCoordinatesInResponse = false
        static let hintRadius = 25
        static let use2DFiltering = false
        static let hintMapCodes = ""
        static let hintPosition = ""
        static let hintFloorHeight = ""

        // Object tracking
        static let autoTracking = true
        static let backgroundTracking = true
        static let bgTrackingDurationSeconds: Double = 15
        static let restartTracking = true
        static let firstTrackingUntilSuccess = true
    }

    // MARK: - Localization parameters

    @Published var autoLocalize = Defaults.autoLocalize
    @Published var backgroundLocalization = Defaults.backgroundLocalization
    @Published var bgLocalizationIntervalSeconds = Defaults.bgLocalizationIntervalSeconds
    @Published var relocalization = Defaults.relocalization
    @Published var firstLocalizationUntilSuccess = Defaults.firstLocalizationUntilSuccess
    @Published var numberOfFrames = Defaults.numberOfFrames
    @Published var confidenceCheck = Defaults.confidenceCheck
    @Published var confidenceThreshold = Defaults.confidenceThreshold
    @Published var enableGeoHint = Defaults.enableGeoHint
    @Published var includeGeoCoordinatesInResponse = Defaults.includeGeoCoordinatesInResponse
    @Published var hintRadius = Defaults.hintRadius
    @Published var use2DFiltering = Defaults.use2DFiltering
    /// Comma-separated map codes, e.g. "MAP_A, MAP_B". Parsed via `hintMapCodesList`.
    @Published var hintMapCodes = Defaults.hintMapCodes
    @Published var hintPosition = Defaults.hintPosition
    @Published var hintFloorHeight = Defaults.hintFloorHeight

    // MARK: - Object tracking parameters

    @Published var autoTracking = Defaults.autoTracking
    @Published var backgroundTracking = Defaults.backgroundTracking
    @Published var bgTrackingDurationSeconds = Defaults.bgTrackingDurationSeconds
    @Published var restartTracking = Defaults.restartTracking
    @Published var firstTrackingUntilSuccess = Defaults.firstTrackingUntilSuccess

    // MARK: - Derived

    /// `hintMapCodes` parsed into a trimmed, non-empty list for the SDK request.
    var hintMapCodesList: [String] {
        hintMapCodes
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    private init() {}

    // MARK: - Persistence keys

    /// Single namespaced key prefix for all persisted values.
    private static let prefix = "multiset.config."
    private enum Key {
        static let autoLocalize = prefix + "loc.autoLocalize"
        static let backgroundLocalization = prefix + "loc.backgroundLocalization"
        static let bgInterval = prefix + "loc.bgIntervalSeconds"
        static let relocalization = prefix + "loc.relocalization"
        static let firstUntil = prefix + "loc.firstUntilSuccess"
        static let numberOfFrames = prefix + "loc.numberOfFrames"
        static let confidenceCheck = prefix + "loc.confidenceCheck"
        static let confidenceThreshold = prefix + "loc.confidenceThreshold"
        static let enableGeoHint = prefix + "loc.enableGeoHint"
        static let geoInResponse = prefix + "loc.includeGeoInResponse"
        static let hintRadius = prefix + "loc.hintRadius"
        static let use2DFiltering = prefix + "loc.use2DFiltering"
        static let hintMapCodes = prefix + "loc.hintMapCodes"
        static let hintPosition = prefix + "loc.hintPosition"
        static let hintFloorHeight = prefix + "loc.hintFloorHeight"

        static let autoTracking = prefix + "obj.autoTracking"
        static let backgroundTracking = prefix + "obj.backgroundTracking"
        static let bgTrackingDuration = prefix + "obj.bgDurationSeconds"
        static let restartTracking = prefix + "obj.restartTracking"
        static let firstTrackingUntil = prefix + "obj.firstUntilSuccess"
    }

    /// Marker key used to detect whether anything has been saved yet.
    private static let savedMarker = prefix + "saved"

    private var defaults: UserDefaults { .standard }

    /// True once values have been persisted at least once.
    var hasSavedConfig: Bool { defaults.bool(forKey: Self.savedMarker) }

    // MARK: - Load / Save / Reset

    /// Load persisted values into this store. No-op (defaults kept) if nothing
    /// has been saved yet. Always re-clamps to valid ranges as a backstop.
    func load() {
        guard hasSavedConfig else { return }
        let d = defaults

        autoLocalize = d.bool(forKey: Key.autoLocalize)
        backgroundLocalization = d.bool(forKey: Key.backgroundLocalization)
        bgLocalizationIntervalSeconds = d.double(forKey: Key.bgInterval)
        relocalization = d.bool(forKey: Key.relocalization)
        firstLocalizationUntilSuccess = d.bool(forKey: Key.firstUntil)
        numberOfFrames = d.integer(forKey: Key.numberOfFrames)
        confidenceCheck = d.bool(forKey: Key.confidenceCheck)
        confidenceThreshold = d.double(forKey: Key.confidenceThreshold)
        enableGeoHint = d.bool(forKey: Key.enableGeoHint)
        includeGeoCoordinatesInResponse = d.bool(forKey: Key.geoInResponse)
        hintRadius = d.integer(forKey: Key.hintRadius)
        use2DFiltering = d.bool(forKey: Key.use2DFiltering)
        hintMapCodes = d.string(forKey: Key.hintMapCodes) ?? Defaults.hintMapCodes
        hintPosition = d.string(forKey: Key.hintPosition) ?? Defaults.hintPosition
        hintFloorHeight = d.string(forKey: Key.hintFloorHeight) ?? Defaults.hintFloorHeight

        autoTracking = d.bool(forKey: Key.autoTracking)
        backgroundTracking = d.bool(forKey: Key.backgroundTracking)
        bgTrackingDurationSeconds = d.double(forKey: Key.bgTrackingDuration)
        restartTracking = d.bool(forKey: Key.restartTracking)
        firstTrackingUntilSuccess = d.bool(forKey: Key.firstTrackingUntil)

        validate()
    }

    /// Clamp to valid ranges, then persist every value.
    func save() {
        validate()
        let d = defaults

        d.set(autoLocalize, forKey: Key.autoLocalize)
        d.set(backgroundLocalization, forKey: Key.backgroundLocalization)
        d.set(bgLocalizationIntervalSeconds, forKey: Key.bgInterval)
        d.set(relocalization, forKey: Key.relocalization)
        d.set(firstLocalizationUntilSuccess, forKey: Key.firstUntil)
        d.set(numberOfFrames, forKey: Key.numberOfFrames)
        d.set(confidenceCheck, forKey: Key.confidenceCheck)
        d.set(confidenceThreshold, forKey: Key.confidenceThreshold)
        d.set(enableGeoHint, forKey: Key.enableGeoHint)
        d.set(includeGeoCoordinatesInResponse, forKey: Key.geoInResponse)
        d.set(hintRadius, forKey: Key.hintRadius)
        d.set(use2DFiltering, forKey: Key.use2DFiltering)
        d.set(hintMapCodes, forKey: Key.hintMapCodes)
        d.set(hintPosition, forKey: Key.hintPosition)
        d.set(hintFloorHeight, forKey: Key.hintFloorHeight)

        d.set(autoTracking, forKey: Key.autoTracking)
        d.set(backgroundTracking, forKey: Key.backgroundTracking)
        d.set(bgTrackingDurationSeconds, forKey: Key.bgTrackingDuration)
        d.set(restartTracking, forKey: Key.restartTracking)
        d.set(firstTrackingUntilSuccess, forKey: Key.firstTrackingUntil)

        d.set(true, forKey: Self.savedMarker)
    }

    /// Restore all in-memory values to their defaults.
    func resetToDefaults() {
        autoLocalize = Defaults.autoLocalize
        backgroundLocalization = Defaults.backgroundLocalization
        bgLocalizationIntervalSeconds = Defaults.bgLocalizationIntervalSeconds
        relocalization = Defaults.relocalization
        firstLocalizationUntilSuccess = Defaults.firstLocalizationUntilSuccess
        numberOfFrames = Defaults.numberOfFrames
        confidenceCheck = Defaults.confidenceCheck
        confidenceThreshold = Defaults.confidenceThreshold
        enableGeoHint = Defaults.enableGeoHint
        includeGeoCoordinatesInResponse = Defaults.includeGeoCoordinatesInResponse
        hintRadius = Defaults.hintRadius
        use2DFiltering = Defaults.use2DFiltering
        hintMapCodes = Defaults.hintMapCodes
        hintPosition = Defaults.hintPosition
        hintFloorHeight = Defaults.hintFloorHeight

        autoTracking = Defaults.autoTracking
        backgroundTracking = Defaults.backgroundTracking
        bgTrackingDurationSeconds = Defaults.bgTrackingDurationSeconds
        restartTracking = Defaults.restartTracking
        firstTrackingUntilSuccess = Defaults.firstTrackingUntilSuccess
    }

    /// Remove every persisted value so the next launch starts from defaults.
    func clearPersisted() {
        let d = defaults
        let keys = [
            Key.autoLocalize, Key.backgroundLocalization, Key.bgInterval, Key.relocalization,
            Key.firstUntil, Key.numberOfFrames, Key.confidenceCheck, Key.confidenceThreshold,
            Key.enableGeoHint, Key.geoInResponse, Key.hintRadius, Key.use2DFiltering,
            Key.hintMapCodes, Key.hintPosition, Key.hintFloorHeight,
            Key.autoTracking, Key.backgroundTracking, Key.bgTrackingDuration,
            Key.restartTracking, Key.firstTrackingUntil, Self.savedMarker
        ]
        keys.forEach { d.removeObject(forKey: $0) }
    }

    /// Clamp every range-bound value to the limits the sliders enforce. Acts as a
    /// backstop so out-of-range values can never reach the SDK.
    func validate() {
        bgLocalizationIntervalSeconds = bgLocalizationIntervalSeconds.clamped(to: 15...180)
        numberOfFrames = numberOfFrames.clamped(to: 4...6)
        confidenceThreshold = confidenceThreshold.clamped(to: 0.2...0.8)
        hintRadius = hintRadius.clamped(to: 1...100)
        bgTrackingDurationSeconds = bgTrackingDurationSeconds.clamped(to: 5...30)
    }

    /// Copy the current values into a fresh, independent instance for editing.
    func makeDraft() -> ConfigStore {
        let draft = ConfigStore()
        draft.apply(from: self)
        return draft
    }

    /// Overwrite this store's values with another's (e.g. draft → shared on Save).
    func apply(from other: ConfigStore) {
        autoLocalize = other.autoLocalize
        backgroundLocalization = other.backgroundLocalization
        bgLocalizationIntervalSeconds = other.bgLocalizationIntervalSeconds
        relocalization = other.relocalization
        firstLocalizationUntilSuccess = other.firstLocalizationUntilSuccess
        numberOfFrames = other.numberOfFrames
        confidenceCheck = other.confidenceCheck
        confidenceThreshold = other.confidenceThreshold
        enableGeoHint = other.enableGeoHint
        includeGeoCoordinatesInResponse = other.includeGeoCoordinatesInResponse
        hintRadius = other.hintRadius
        use2DFiltering = other.use2DFiltering
        hintMapCodes = other.hintMapCodes
        hintPosition = other.hintPosition
        hintFloorHeight = other.hintFloorHeight

        autoTracking = other.autoTracking
        backgroundTracking = other.backgroundTracking
        bgTrackingDurationSeconds = other.bgTrackingDurationSeconds
        restartTracking = other.restartTracking
        firstTrackingUntilSuccess = other.firstTrackingUntilSuccess
    }
}

// MARK: - Clamping helper

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
