/*
Copyright (c) 2026 MultiSet AI. All rights reserved.
Licensed under the MultiSet License. You may not use this file except in compliance with the License. and you can't re-distribute this file without a prior notice
For license details, visit www.multiset.ai.
Redistribution in source or binary forms must retain this notice.
*/

import SwiftUI

/// Named type roles. SF Pro and SF Mono only — the App Clip byte budget forbids
/// bundled faces, and per-target font divergence would make the App and Clip
/// look like different products.
public enum MSFont {
    public static let display = Font.system(.largeTitle, design: .default, weight: .bold)
    public static let eyebrow = Font.system(.caption2, design: .monospaced, weight: .semibold)
    public static let title = Font.system(.title2, design: .default, weight: .semibold)
    public static let headline = Font.system(.headline, design: .default, weight: .semibold)
    /// Between `body` and `title`. Instructional copy that has to carry a card on its
    /// own, where `body` reads small and `title` reads like a heading.
    public static let subtitle = Font.system(.title3, design: .default)
    public static let body = Font.system(.body, design: .default)
    public static let bodyEmphasis = Font.system(.body, design: .default, weight: .medium)
    public static let callout = Font.system(.callout, design: .default)
    public static let caption = Font.system(.caption, design: .default)
    public static let captionEmphasis = Font.system(.caption, design: .default, weight: .semibold)

    /// Engineering data — map codes, pose values, confidence, latency.
    public static let mono = Font.system(.footnote, design: .monospaced)
    public static let monoSmall = Font.system(.caption2, design: .monospaced)
    public static let monoLarge = Font.system(.title3, design: .monospaced, weight: .medium)
    public static let monoDisplay = Font.system(.largeTitle, design: .monospaced, weight: .semibold)
}

/// Optical tracking. SF tightens as it grows; leaving large text at default
/// tracking is most of what makes system type read as unstyled.
public enum MSTracking {
    public static let display: CGFloat = -0.5
    public static let title: CGFloat = -0.3
    /// Uppercase needs the opposite treatment — it opens up rather than tightens.
    public static let eyebrow: CGFloat = 0.8
}

public extension View {
    /// The uppercase monospaced label used above a headline. This is the app's
    /// most distinctive non-AR type treatment, so it is a token rather than
    /// three hand-tuned copies.
    func msEyebrow() -> some View {
        font(MSFont.eyebrow)
            .tracking(MSTracking.eyebrow)
            .textCase(.uppercase)
    }
}
