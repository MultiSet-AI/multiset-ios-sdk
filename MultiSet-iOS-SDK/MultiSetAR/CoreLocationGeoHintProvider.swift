/*
Copyright (c) 2026 MultiSet AI. All rights reserved.
Licensed under the MultiSet License. You may not use this file except in compliance with the License. and you can't re-distribute this file without a prior notice
For license details, visit www.multiset.ai.
Redistribution in source or binary forms must retain this notice.
*/

import Foundation
import Combine
import CoreLocation
import MultiSetSDK

/// Supplies GPS coordinates for the `geoHint` request field, from CoreLocation
final class CoreLocationGeoHintProvider: NSObject, ObservableObject, CLLocationManagerDelegate {

    // MARK: - Published Properties

    @Published var gpsCoordinates = GeoCoordinates()
    @Published var isEnabled = false
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined

    // MARK: - Private Properties

    private var locationManager: CLLocationManager?
    private var permissionCallback: ((Bool) -> Void)?
    private var updatesRequested = false

    // MARK: - Computed Properties

    var isGpsOn: Bool {
        return isEnabled && locationManager != nil
    }

    var hasValidCoordinates: Bool {
        return gpsCoordinates.isValid()
    }

    // MARK: - Initialization

    override init() {
        super.init()
    }

    /// Created on first use, not in `init`: a new `CLLocationManager` reports its authorization
    /// straight away, and GPS must stay off until the SDK asks for it.
    private func makeLocationManagerIfNeeded() {
        guard locationManager == nil else { return }
        let manager = CLLocationManager()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 1.0
        locationManager = manager
    }

    // MARK: - Public Methods

    func hasLocationPermission() -> Bool {
        return authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways
    }

    func requestPermission(completion: ((Bool) -> Void)? = nil) {
        makeLocationManagerIfNeeded()
        permissionCallback = completion
        logLocationServicesStateIfDisabled()

        switch authorizationStatus {
        case .notDetermined:
            // No-op when authorization is already resolved, so this is safe before the
            // delegate has seeded `authorizationStatus` on the first run-loop turn.
            print("MultiSetSDK >> Requesting location permission")
            locationManager?.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            print("MultiSetSDK >> Location permission already granted")
            permissionCallback = nil
            completion?(true)
        case .denied, .restricted:
            print("MultiSetSDK >> Location permission denied")
            permissionCallback = nil
            completion?(false)
        @unknown default:
            permissionCallback = nil
            completion?(false)
        }
    }

    func startUpdates() {
        makeLocationManagerIfNeeded()
        updatesRequested = true

        switch authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            beginUpdates()
        case .notDetermined:
            // Status is delegate-seeded, so a caller can land here before it is known.
            // Defer instead of failing: the authorization delegate starts updates on grant.
            print("MultiSetSDK >> GPS start deferred until location authorization is known")
        case .denied, .restricted:
            print("MultiSetSDK >> Location permission not granted")
        @unknown default:
            break
        }
    }

    func stopUpdates() {
        updatesRequested = false
        locationManager?.stopUpdatingLocation()
        isEnabled = false
        print("MultiSetSDK >> GPS handler stopped")
    }

    func getCurrentCoordinates() -> GeoCoordinates {
        return GeoCoordinates(
            latitude: gpsCoordinates.latitude,
            longitude: gpsCoordinates.longitude,
            altitude: gpsCoordinates.altitude
        )
    }

    // MARK: - Private Methods

    private func beginUpdates() {
        locationManager?.startUpdatingLocation()
        isEnabled = true

        if let location = locationManager?.location {
            updateCoordinates(from: location)
            // print("MultiSetSDK >> Initial coordinates set from last known location")
        } else {
            print("MultiSetSDK >> No last known location available - waiting for GPS fix")
        }

        // print("MultiSetSDK >> GPS handler enabled")
    }

    /// `locationServicesEnabled()` blocks on an XPC round-trip, so it stays off the
    /// main thread and is used for diagnostics only — never to gate control flow.
    private func logLocationServicesStateIfDisabled() {
        DispatchQueue.global(qos: .utility).async {
            guard !CLLocationManager.locationServicesEnabled() else { return }
            print("MultiSetSDK >> Location services are disabled")
        }
    }

    private func updateCoordinates(from location: CLLocation) {
        gpsCoordinates = GeoCoordinates(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            // The API expects ellipsoidal heights; a negative verticalAccuracy means no altitude.
            altitude: location.verticalAccuracy < 0 ? nil : location.ellipsoidalAltitude
        )
        // print("MultiSetSDK >> GPS coordinates updated: \(gpsCoordinates.toGeoHintString())")
    }

    // MARK: - CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        updateCoordinates(from: location)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("MultiSetSDK >> Location error: \(error.localizedDescription)")
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        authorizationStatus = status

        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            print("MultiSetSDK >> Location permission granted")
            // A permission change made in Settings must not start GPS the SDK has not asked for
            if updatesRequested {
                beginUpdates()
            }
            permissionCallback?(true)
        case .denied, .restricted:
            print("MultiSetSDK >> Location permission denied")
            permissionCallback?(false)
        case .notDetermined:
            print("MultiSetSDK >> Location permission not determined")
        @unknown default:
            break
        }

        permissionCallback = nil
    }
}

extension CoreLocationGeoHintProvider: MultiSetGeoHintProvider {

    func requestAuthorization() {
        requestPermission()
    }

    func currentCoordinates() -> GeoCoordinates? {
        return getCurrentCoordinates()
    }
}
