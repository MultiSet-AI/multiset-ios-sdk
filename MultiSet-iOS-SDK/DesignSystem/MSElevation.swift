/*
Copyright (c) 2026 MultiSet AI. All rights reserved.
Licensed under the MultiSet License. You may not use this file except in compliance with the License. and you can't re-distribute this file without a prior notice
For license details, visit www.multiset.ai.
Redistribution in source or binary forms must retain this notice.
*/

import SwiftUI

/// How far a surface sits above the one behind it.
///
/// Depth is a token rather than a per-view `shadow` because the two appearances
/// need different mechanisms: in light mode a card is lifted by a hairline border
/// and a shadow, while in dark mode the step from `appBackground` to `surface` does
/// the lifting on its own — a black shadow has nothing to darken there, and an edge
/// drawn over the step reads as a second, competing outline. Views that hand-roll a
/// shadow get this wrong in one appearance or the other.
public enum MSElevation: Sendable {
    case flat
    case raised
    case floating
    /// Home's hero and feature cards — the only accent-tinted depth in the app.
    case showpiece
}

private struct MSShadow {
    let color: Color
    let radius: CGFloat
    let y: CGFloat

    static let none = MSShadow(color: .clear, radius: 0, y: 0)
}

extension MSElevation {
    fileprivate func shadow(dark: Bool) -> MSShadow {
        switch self {
        case .flat:
            return .none
        case .raised:
            return dark ? .none : MSShadow(color: .black.opacity(0.06), radius: 8, y: 2)
        case .floating:
            return dark
                ? MSShadow(color: .black.opacity(0.46), radius: 18, y: 8)
                : MSShadow(color: .black.opacity(0.12), radius: 16, y: 6)
        case .showpiece:
            return MSShadow(color: MSColor.accent.opacity(dark ? 0.22 : 0.14), radius: 20, y: 10)
        }
    }

    /// A card's edge is `cardLine`, which is clear in dark mode. Only `floating` — a
    /// dialog or a sheet over content rather than a card in a list — still draws an
    /// edge there, because it has no surface step beneath it to separate it.
    fileprivate func border(dark: Bool) -> Color {
        switch self {
        case .flat, .raised:
            return MSColor.cardLine
        case .floating:
            return dark ? Color.white.opacity(0.14) : MSColor.cardLine
        case .showpiece:
            return Color.white.opacity(0.12)
        }
    }
}

private struct MSSurface<Fill: ShapeStyle>: ViewModifier {
    let elevation: MSElevation
    let radius: CGFloat
    let fill: Fill
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        let dark = colorScheme == .dark
        let shadow = elevation.shadow(dark: dark)
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)

        return content
            .background(fill, in: shape)
            .clipShape(shape)
            .overlay(shape.strokeBorder(elevation.border(dark: dark), lineWidth: 1))
            .shadow(color: shadow.color, radius: shadow.radius, y: shadow.y)
    }
}

public extension View {
    /// Fills, clips, borders and lifts a surface as one unit, so the three cannot
    /// drift apart the way they do when each view applies them separately.
    func msSurface(
        _ elevation: MSElevation = .raised,
        radius: CGFloat = MSRadius.lg,
        fill: some ShapeStyle = MSColor.surface
    ) -> some View {
        modifier(MSSurface(elevation: elevation, radius: radius, fill: fill))
    }
}

#Preview("Elevation") {
    VStack(spacing: MSSpacing.xl) {
        ForEach(
            [
                ("flat", MSElevation.flat),
                ("raised", .raised),
                ("floating", .floating),
                ("showpiece", .showpiece)
            ],
            id: \.0
        ) { name, elevation in
            Text(name)
                .font(MSFont.bodyEmphasis)
                .foregroundStyle(MSColor.textPrimary)
                .frame(maxWidth: .infinity, minHeight: 64)
                .msSurface(elevation)
        }
    }
    .padding(MSSpacing.xl)
    .frame(maxHeight: .infinity)
    .background(MSColor.appBackground)
}
