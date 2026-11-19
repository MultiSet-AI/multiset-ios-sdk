/*
Copyright (c) 2026 MultiSet AI. All rights reserved.
Licensed under the MultiSet License. You may not use this file except in compliance with the License. and you can't re-distribute this file without a prior notice
For license details, visit www.multiset.ai.
Redistribution in source or binary forms must retain this notice.
*/

import Foundation
import CoreLocation
import Combine

// Not the adapter's geo-hint provider: the map needs horizontalAccuracy for its accuracy circle.
final class LocationTracker: NSObject, ObservableObject, CLLocationManagerDelegate {

    /// Most recent fix, or nil until the first one arrives.
    @Published private(set) var latest: GpsFix?

    /// True when the user denied or restricted location access.
    @Published private(set) var authorizationDenied = false

    /// True when only reduced (coarse) accuracy was granted. Fixes still flow, with a
    /// much larger accuracy radius.
    @Published private(set) var coarseOnly = false

    /// Called on the main queue for every fix, so the session model can accumulate the
    /// track without observing `latest` separately.
    var onFix: ((GpsFix) -> Void)?

    private let manager = CLLocationManager()
    private var isRunning = false

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = kCLDistanceFilterNone
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false
        manager.stopUpdatingLocation()
    }

    // MARK: - CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }

        // A negative accuracy means CoreLocation marked the fix invalid.
        guard location.horizontalAccuracy >= 0 else { return }

        let fix = GpsFix(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            horizontalAccuracy: location.horizontalAccuracy,
            timestamp: location.timestamp,
            coarseOnly: coarseOnly
        )

        latest = fix
        onFix?(fix)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("LocationTracker >> Location error: \(error.localizedDescription)")
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .denied, .restricted:
            authorizationDenied = true
        case .authorizedWhenInUse, .authorizedAlways:
            authorizationDenied = false
            // Re-issue the start now that permission exists; a startUpdatingLocation()
            // issued before the grant produces no fixes.
            if isRunning { manager.startUpdatingLocation() }
        case .notDetermined:
            authorizationDenied = false
        @unknown default:
            authorizationDenied = false
        }

        coarseOnly = (manager.accuracyAuthorization == .reducedAccuracy)
        if coarseOnly {
            print("LocationTracker >> Reduced accuracy granted — GPS track will be coarse")
        }
    }
}
