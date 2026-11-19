/*
Copyright (c) 2026 MultiSet AI. All rights reserved.
Licensed under the MultiSet License. You may not use this file except in compliance with the License. and you can't re-distribute this file without a prior notice
For license details, visit www.multiset.ai.
Redistribution in source or binary forms must retain this notice.
*/

import SwiftUI

/// Semantic color tokens. Values are extracted from the MultiSet developer portal
/// (`multiset-dashboard/src/app/globals.css`), not approximated.
public enum MSColor {
    private enum Brand {
        static let violet700 = Color(hex: "#6D28D9")
        static let violet600 = Color(hex: "#7C3AED")
        static let violet500 = Color(hex: "#8B5CF6")
        static let violet400 = Color(hex: "#A78BFA")

        static let ink = Color(hex: "#111028")
        static let inkSecondary = Color(hex: "#4A4564")
        static let inkMuted = Color(hex: "#7D7896")
        /// `inkMuted` reads 3.95:1 on the light page, which passes for large text and
        /// fails for the small print it is actually used on — version strings, field
        /// captions, meta lines. This is the same hue at 4.8:1.
        static let inkMutedText = Color(hex: "#6F6A88")

        static let nightText = Color(hex: "#A8A3C0")

        static let red = Color(hex: "#EF4444")
        static let amber = Color(hex: "#F59E0B")
        static let green = Color(hex: "#10B981")
        static let blue = Color(hex: "#3B82F6")

        static let redBright = Color(hex: "#F87171")
        static let amberBright = Color(hex: "#FBBF24")
    }

    /// The developer portal's background ramp, light then dark. Surfaces are the one
    /// part of the palette shared with the portal verbatim, so the two read as one
    /// product; the accent, ink and status ramps above stay the app's own.
    private enum Portal {
        static let background = Color(hex: "#F6F8FB")
        static let backgroundDark = Color(hex: "#0D0D0F")
        static let surface = Color(hex: "#FFFFFF")
        static let surfaceDark = Color(hex: "#17171A")
        static let surface2 = Color(hex: "#F9F6FF")
        static let surface2Dark = Color(hex: "#1F1F23")
        static let surface3 = Color(hex: "#F1F5F9")
        static let surface3Dark = Color(hex: "#26262B")
        static let stage = Color(hex: "#F1F5F9")
        static let stageDark = Color(hex: "#050506")
        static let tint = Color(hex: "#EEE6FE")
        static let tintDark = Color(hex: "#241C2E")
        static let line = Color(hex: "#EBEFF2")
        static let lineDark = Color(hex: "#26262B")
        /// The edge of something you can type in or press. See `MSColor.controlBorder`.
        static let controlBorder = Color(hex: "#C9D0DB")
        static let controlBorderDark = Color(hex: "#3A3A43")
        static let thumbA = Color(hex: "#EEE6FE")
        static let thumbADark = Color(hex: "#241C2E")
        static let thumbB = Color(hex: "#D8C4F8")
        static let thumbBDark = Color(hex: "#3E3252")
    }

    public static let accent = Color.adaptive(light: Brand.violet600, dark: Brand.violet500)
    /// The accent as a *fill under a white label*, which is a different job from a
    /// stroke, a tint or a small mark. `accent`'s dark value puts `onAccent` at 4.23:1,
    /// measured off a rendered button — under the 4.5:1 a 17pt medium label needs — so a
    /// filled button takes violet 600 in both themes and reads 5.84:1 either way.
    public static let accentFill = Brand.violet600
    public static let accentPressed = Brand.violet700
    public static let onAccent = Color.white
    /// Tinted icon wells, pills and ghost buttons: a 12% wash of the accent over any surface.
    public static let accentSoft = Color.adaptive(
        light: Brand.violet600.opacity(0.12),
        dark: Brand.violet500.opacity(0.12)
    )
    /// Shadow and bloom under primary elements. Lighter on white, where a 50% wash reads as a smear.
    public static let accentGlow = Color.adaptive(
        light: Brand.violet600.opacity(0.35),
        dark: Brand.violet500.opacity(0.5)
    )

    /// Screens and scroll views.
    public static let appBackground = Color.adaptive(light: Portal.background, dark: Portal.backgroundDark)
    /// Cards, panels, sheets and bars — the step the content sits on.
    public static let surface = Color.adaptive(light: Portal.surface, dark: Portal.surfaceDark)
    /// Secondary fills and text fields, a half-step off `surface`.
    public static let surface2 = Color.adaptive(light: Portal.surface2, dark: Portal.surface2Dark)
    /// Chips, neutral pills and pressed rows.
    public static let surface3 = Color.adaptive(light: Portal.surface3, dark: Portal.surface3Dark)

    /// What a text field is filled with.
    ///
    /// Its own token because the page and the field must differ in *lightness*, not only
    /// in tint: fields used `surface2`, whose luminance is identical to the light page's
    /// — 1.00:1 — so the fill drew no boundary whatever. White in the light theme puts
    /// the field above the page; in the dark theme it sits a step above the card.
    public static let field = Color.adaptive(light: Portal.surface, dark: Portal.surface2Dark)
    /// The clear colour behind a 3D viewer. Darker than `appBackground` in dark mode, so
    /// a mesh lit at a low intensity exponent still separates from the void behind it.
    public static let stage = Color.adaptive(light: Portal.stage, dark: Portal.stageDark)
    /// The wash under a selected or active card. Opaque rather than an accent at low
    /// alpha, so a card keeps the same colour whatever it is laid over.
    public static let tint = Color.adaptive(light: Portal.tint, dark: Portal.tintDark)
    /// Dividers and control strokes.
    /// Hairlines between things: card edges, dividers, the rule beside a section label.
    ///
    /// Deliberately faint. A card is lifted by its fill and its shadow, and drawing a
    /// strong edge on every one of them makes a screen look like a spreadsheet — which
    /// is what happened when this token was strengthened to fix input fields. Those are
    /// a different job; see `controlBorder`.
    public static let line = Color.adaptive(light: Portal.line, dark: Portal.lineDark)

    /// The edge of something you can type in or press — a text field, an outline button.
    ///
    /// Strong enough to be a boundary, which `line` is not: at #EBEFF2 a field's border
    /// is 1.09:1 against the light page, so the field has no visible edge at all. These
    /// sit where the system's own control separators sit. Only controls use it; giving
    /// cards the same weight is what made them ugly.
    public static let controlBorder = Color.adaptive(light: Portal.controlBorder, dark: Portal.controlBorderDark)
    /// A card's own border. Clear in dark mode: there the surface step alone lifts the
    /// card, and a drawn edge on top of it reads as a second, competing outline.
    public static let cardLine = Color.adaptive(light: Portal.line, dark: .clear)
    /// The translucent pill that rides over a thumbnail, where the picture behind it
    /// decides the contrast rather than the appearance.
    public static let pill = Color.adaptive(
        light: Portal.surface.opacity(0.9),
        dark: Portal.backgroundDark.opacity(0.72)
    )
    public static let thumbA = Color.adaptive(light: Portal.thumbA, dark: Portal.thumbADark)
    public static let thumbB = Color.adaptive(light: Portal.thumbB, dark: Portal.thumbBDark)

    /// The gradient a thumbnail with no image falls back to.
    public static let thumbnailPlaceholder = LinearGradient(
        colors: [thumbA, thumbB],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    public static let textPrimary = Color.adaptive(light: Brand.ink, dark: Color(hex: "#F4F2FA"))
    public static let textSecondary = Color.adaptive(light: Brand.inkSecondary, dark: Brand.nightText)
    public static let textMuted = Color.adaptive(light: Brand.inkMutedText, dark: Color(hex: "#7E7898"))


    public static let danger = Color.adaptive(light: Brand.red, dark: Brand.redBright)
    public static let warning = Color.adaptive(light: Brand.amber, dark: Brand.amberBright)
    public static let success = Color.adaptive(light: Brand.green, dark: Color(hex: "#34D399"))
    public static let info = Color.adaptive(light: Brand.blue, dark: Color(hex: "#60A5FA"))

    /// A status colour as a *wash under text*, which is a different job from a mark or a
    /// label. One alpha cannot do both themes: 18 % amber is a soft cream banner on white
    /// and a muddy olive-brown over near-black, where it reads as a rendering fault rather
    /// than a warning. The dark values are a fraction of that and the edge carries the
    /// signal instead — measured off the studio's stat strip in both appearances.
    public static let warningWash = Color.adaptive(
        light: Brand.amber.opacity(0.18),
        dark: Brand.amberBright.opacity(0.06)
    )
    public static let warningEdge = Color.adaptive(
        light: Brand.amber.opacity(0.35),
        dark: Brand.amberBright.opacity(0.65)
    )
    public static let dangerWash = Color.adaptive(
        light: Brand.red.opacity(0.16),
        dark: Brand.redBright.opacity(0.07)
    )
    public static let dangerEdge = Color.adaptive(
        light: Brand.red.opacity(0.35),
        dark: Brand.redBright.opacity(0.65)
    )

    /// One hue per library category, so a card is recognisable by colour before its label
    /// is read. Soft variants are the icon wells behind the glyphs.
    public enum Category {
        public static let maps = accent
        public static let mapsSoft = accentSoft
        public static let mapSets = Color.adaptive(light: Color(hex: "#DB2777"), dark: Color(hex: "#F472B6"))
        public static let mapSetsSoft = Color.adaptive(light: Color(hex: "#FDF2F8"), dark: Color(hex: "#3B1F33"))
        public static let objects = Color.adaptive(light: Color(hex: "#059669"), dark: Color(hex: "#34D399"))
        public static let objectsSoft = Color.adaptive(light: Color(hex: "#ECFDF5"), dark: Color(hex: "#173B2E"))
        public static let spaces = Color.adaptive(light: Color(hex: "#0284C7"), dark: Color(hex: "#38BDF8"))
        public static let spacesSoft = Color.adaptive(light: Color(hex: "#F0F9FF"), dark: Color(hex: "#15304A"))
        public static let drafts = Color.adaptive(light: Color(hex: "#D97706"), dark: Color(hex: "#FBBF24"))
        public static let draftsSoft = Color.adaptive(light: Color(hex: "#FFFBEB"), dark: Color(hex: "#3E2E12"))
        public static let simulation = Color.adaptive(light: Color(hex: "#0D9488"), dark: Color(hex: "#2DD4BF"))
        public static let simulationSoft = Color.adaptive(light: Color(hex: "#F0FDFA"), dark: Color(hex: "#123A36"))
    }

    /// Tokens already resolved to a `UIColor`, for the UIKit, RealityKit and SceneKit
    /// call sites that have no SwiftUI environment to read an appearance from.
    ///
    /// RealityKit in particular cannot take a SwiftUI import at all: both modules
    /// declare a `Material`, and importing SwiftUI beside RealityKit makes every
    /// mention of it ambiguous. Handing those files a `UIColor` keeps the palette in
    /// one place without that.
    public enum Resolved {
        public static func stage(dark: Bool) -> UIColor {
            MSColor.stage.resolved(dark ? .dark : .light)
        }
    }

    /// AR overlays render against arbitrary camera feeds, so they use fixed
    /// high-contrast values rather than adapting to the interface style.
    public enum AR {
        public static let scrim = Color.black.opacity(0.55)
        public static let panel = Color.black.opacity(0.72)
        public static let panelBorder = Color.white.opacity(0.16)
        public static let text = Color.white
        public static let textDim = Color.white.opacity(0.66)
        public static let accent = Brand.violet400
        /// The shutter's disc. A step darker than `accent`, which is tuned for text and
        /// strokes over the camera rather than for a filled 54pt target.
        public static let record = Brand.violet500
        public static let recordGlow = Brand.violet500.opacity(0.55)
        public static let good = Color(hex: "#34D399")
        public static let poor = Color(hex: "#FBBF24")
        public static let bad = Color(hex: "#F87171")
    }
}
