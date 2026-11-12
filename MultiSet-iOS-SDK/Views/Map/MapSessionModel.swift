/*
Copyright (c) 2026 MultiSet AI. All rights reserved.
Licensed under the MultiSet License. You may not use this file except in compliance with the License. and you can't re-distribute this file without a prior notice
For license details, visit www.multiset.ai.
Redistribution in source or binary forms must retain this notice.
*/

import Foundation
import Combine
import MultiSetSDK

/// The device GPS track and the VPS GeoPose track the map draws side by side.
final class MapSessionModel: ObservableObject {

    @Published private(set) var gpsTrack: [GpsFix] = []
    @Published private(set) var vpsTrack: [VpsPoint] = []
    @Published private(set) var latestGps: GpsFix?
    @Published private(set) var latestVps: VpsPoint?
    @Published private(set) var vpsStatus: VpsStatus = .idle
    @Published private(set) var locationAvailable = false
    @Published private(set) var coarseOnly = false
    @Published var followMode = true

    /// Bumped to recentre once on the same target, after the sheet settles at a new height.
    @Published private(set) var recenterToken = 0

    private var lastFix: GpsFix?
    // The GPS track starts with the first localization, so both tracks cover the same walk.
    private var loggingStarted = false

    func requestRecenter() {
        recenterToken += 1
    }

    // MARK: - GPS

    func onGpsFix(_ fix: GpsFix) {
        lastFix = fix
        latestGps = fix
        locationAvailable = true
        coarseOnly = fix.coarseOnly
        if loggingStarted {
            gpsTrack.append(fix)
        }
    }

    func setLocationDenied() {
        locationAvailable = false
    }

    func startGpsLogging() {
        guard !loggingStarted else { return }
        loggingStarted = true
        if let fix = lastFix {
            gpsTrack.append(fix)
        }
    }

    // MARK: - VPS

    func setStatus(_ status: VpsStatus) {
        vpsStatus = status
    }

    func onLocalizationFailure() {
        vpsStatus = .failed
    }

    // A discarded pose stays off the track, where it would read as drift against the GPS.
    func onFalsePositive() {
        vpsStatus = .falsePositive
    }

    func onLocalizationSuccess(_ result: LocalizationResult) {
        guard let geoPose = result.geoPose, let position = geoPose.position else {
            vpsStatus = .notGeoReferenced
            return
        }

        let heading = geoPose.quaternion.map { q in
            GeoPoseMath.compassYaw(
                x: Double(q.x), y: Double(q.y), z: Double(q.z), w: Double(q.w),
                frame: geoPose.frameName
            )
        }

        let point = VpsPoint(
            latitude: position.latitude,
            longitude: position.longitude,
            confidence: result.confidence,
            headingDegrees: heading,
            timestamp: Date()
        )
        vpsTrack.append(point)
        latestVps = point
        vpsStatus = .active
    }
}
