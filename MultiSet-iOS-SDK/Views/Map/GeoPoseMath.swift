/*
Copyright (c) 2026 MultiSet AI. All rights reserved.
Licensed under the MultiSet License. You may not use this file except in compliance with the License. and you can't re-distribute this file without a prior notice
For license details, visit www.multiset.ai.
Redistribution in source or binary forms must retain this notice.
*/

import Foundation
import UIKit

enum GeoPoseMath {

    static func normalizeDegrees(_ degrees: Double) -> Double {
        let wrapped = degrees.truncatingRemainder(dividingBy: 360)
        return wrapped < 0 ? wrapped + 360 : wrapped
    }

    // ENU carries ARKit's camera (-Z forward); Y-Up-ENU carries Unity's (+Z forward, north on Z).
    static func compassYaw(x: Double, y: Double, z: Double, w: Double, frame: String?) -> Double {
        let plusZ = (x: 2 * (x * z + w * y), y: 2 * (y * z - w * x), z: 1 - 2 * (x * x + y * y))
        let bearing = frame == "Y-Up-ENU"
            ? atan2(plusZ.x, plusZ.z)
            : atan2(-plusZ.x, -plusZ.y)
        return normalizeDegrees(bearing * 180 / .pi)
    }

    // Red below 0.4, amber below 0.7, green above; no confidence reads as the worst case.
    static func confidenceUIColor(_ confidence: Float?) -> UIColor {
        guard let confidence = confidence, confidence >= 0.4 else {
            return UIColor(red: 0.90, green: 0.22, blue: 0.21, alpha: 1)
        }
        if confidence < 0.7 { return UIColor(red: 1.00, green: 0.70, blue: 0.00, alpha: 1) }
        return UIColor(red: 0.26, green: 0.63, blue: 0.28, alpha: 1)
    }

    static let gpsUIColor = UIColor(red: 0.12, green: 0.53, blue: 0.90, alpha: 1)
    static let vpsUIColor = UIColor(red: 0.26, green: 0.63, blue: 0.28, alpha: 1)
}
