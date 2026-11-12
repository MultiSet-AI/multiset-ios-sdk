/*
Copyright (c) 2026 MultiSet AI. All rights reserved.
Licensed under the MultiSet License. You may not use this file except in compliance with the License. and you can't re-distribute this file without a prior notice
For license details, visit www.multiset.ai.
Redistribution in source or binary forms must retain this notice.
*/

import Foundation
import CoreLocation
import SwiftUI
import UIKit

struct GpsFix: Identifiable, Equatable {
    let id = UUID()
    let latitude: Double
    let longitude: Double
    let horizontalAccuracy: Double
    let timestamp: Date
    var coarseOnly: Bool = false

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

struct VpsPoint: Identifiable, Equatable {
    let id = UUID()
    let latitude: Double
    let longitude: Double
    let confidence: Float?
    /// Compass bearing the camera faced, clockwise from true north; nil without an orientation.
    let headingDegrees: Double?
    let timestamp: Date

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

/// Transient VPS state shown in the map's status chip.
enum VpsStatus {
    case idle
    case localizing
    case active
    case failed
    /// The server returned a pose that the SDK discarded — distinct from `.failed`,
    /// where no pose came back at all.
    case falsePositive
    /// Localized, but the response had no GeoPose: the map or MapSet is not geo-referenced.
    case notGeoReferenced

    var label: String {
        switch self {
        case .idle: return "VPS Idle"
        case .localizing: return "Localizing"
        case .active: return "VPS Active"
        case .failed: return "Failed"
        case .falsePositive: return "False Positive"
        case .notGeoReferenced: return "Not Geo-Referenced"
        }
    }

    var color: Color {
        switch self {
        case .idle: return .gray
        case .localizing: return Color(hex: "#FFB300")
        case .active: return Color(hex: "#43A047")
        case .failed: return Color(hex: "#E53935")
        case .falsePositive, .notGeoReferenced: return Color(hex: "#FB8C00")
        }
    }

    var symbol: String {
        switch self {
        case .idle: return "location.slash"
        case .localizing: return "location.circle"
        case .active: return "location.fill"
        case .failed: return "exclamationmark.triangle.fill"
        case .falsePositive: return "location.slash.fill"
        case .notGeoReferenced: return "mappin.slash"
        }
    }
}

// Light and dark are the standard Apple map drawn in a forced interface style.
enum MapStyleMode: String, CaseIterable, Identifiable {
    case street
    case satellite
    case light
    case dark

    var id: String { rawValue }

    var label: String {
        switch self {
        case .street: return "Street"
        case .satellite: return "Satellite"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    var symbol: String {
        switch self {
        case .street: return "map"
        case .satellite: return "globe.americas.fill"
        case .light: return "sun.max"
        case .dark: return "moon"
        }
    }

    /// Forced appearance for the map, or `.unspecified` to follow the system.
    var interfaceStyle: UIUserInterfaceStyle {
        switch self {
        case .street, .satellite: return .unspecified
        case .light: return .light
        case .dark: return .dark
        }
    }
}
