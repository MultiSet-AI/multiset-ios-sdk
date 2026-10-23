/*
Copyright (c) 2026 MultiSet AI. All rights reserved.
Licensed under the MultiSet License. You may not use this file except in compliance with the License. and you can't re-distribute this file without a prior notice
For license details, visit www.multiset.ai.
Redistribution in source or binary forms must retain this notice.
*/

import SwiftUI

extension Color {
    /// Creates a color from a `#RRGGBB` or `#RRGGBBAA` string. Invalid input yields magenta
    /// so a bad token is visible in review rather than silently transparent.
    public init(hex: String) {
        let raw = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        guard let value = UInt64(raw, radix: 16), raw.count == 6 || raw.count == 8 else {
            self = .init(red: 1, green: 0, blue: 1)
            return
        }
        let shift = raw.count == 8 ? 8 : 0
        let alpha = raw.count == 8 ? Double(value & 0xFF) / 255 : 1
        self.init(
            .sRGB,
            red: Double((value >> (16 + shift)) & 0xFF) / 255,
            green: Double((value >> (8 + shift)) & 0xFF) / 255,
            blue: Double((value >> shift) & 0xFF) / 255,
            opacity: alpha
        )
    }

    /// Resolves to `light` or `dark` from the rendering trait collection.
    public static func adaptive(light: Color, dark: Color) -> Color {
        Color(UIColor { traits in
            UIColor(traits.userInterfaceStyle == .dark ? dark : light)
        })
    }

    /// Resolves an adaptive token against an explicit appearance, for the UIKit,
    /// RealityKit and SceneKit call sites that have no SwiftUI environment to read.
    public func resolved(_ style: UIUserInterfaceStyle) -> UIColor {
        UIColor(self).resolvedColor(with: UITraitCollection(userInterfaceStyle: style))
    }
}
