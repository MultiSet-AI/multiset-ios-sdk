/*
Copyright (c) 2026 MultiSet AI. All rights reserved.
Licensed under the MultiSet License. You may not use this file except in compliance with the License. and you can't re-distribute this file without a prior notice
For license details, visit www.multiset.ai.
Redistribution in source or binary forms must retain this notice.
*/

import MultiSetSDK

/// Why a posed-RGB scan is not keeping frames, or is keeping them at risk, in words the
/// person can act on.
extension MappingTrackingStatus.Issue {
    var message: String {
        switch self {
        case .initializing: "Getting started — move slowly"
        case .relocalizing: "Recovering tracking — return to where you were"
        case .excessiveMotion: "Moving too fast — slow down"
        case .insufficientFeatures: "Not enough detail — aim at textured surfaces"
        case .unavailable: "Tracking unavailable"
        case .settling: "Hold steady — tracking is settling"
        case .lowDetail: "Low detail — aim at furniture, edges or posters"
        case .tooDark: "Too dark — add light"
        @unknown default: "Tracking is limited"
        }
    }

    var systemImage: String {
        switch self {
        case .initializing, .relocalizing, .settling: "arrow.triangle.2.circlepath"
        case .excessiveMotion: "tortoise.fill"
        case .insufficientFeatures, .lowDetail: "square.grid.3x3"
        case .tooDark: "moon.fill"
        case .unavailable: "exclamationmark.triangle.fill"
        @unknown default: "exclamationmark.triangle.fill"
        }
    }
}

extension MappingTrackingAdvice.Kind {
    var toast: MSToast {
        switch self {
        case .lowDetail: MSToast(message: "Low detail here — point at furniture, edges or posters")
        case .tooDark: MSToast(message: "Too dark to track well — turn on more lights")
        case .lost: MSToast(message: "Tracking lost — go back to an area you already scanned", tone: .failure)
        case .relocalizing: MSToast(message: "Tracking lost — return to where you were and hold still", tone: .failure)
        case .poseCorrected: MSToast(message: "Tracking corrected itself — the last second was removed")
        case .recovered: MSToast(message: "Tracking recovered — keep moving slowly", tone: .success)
        @unknown default: MSToast(message: "Tracking changed — keep moving slowly")
        }
    }
}
