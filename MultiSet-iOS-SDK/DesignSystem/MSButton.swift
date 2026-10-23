/*
Copyright (c) 2026 MultiSet AI. All rights reserved.
Licensed under the MultiSet License. You may not use this file except in compliance with the License. and you can't re-distribute this file without a prior notice
For license details, visit www.multiset.ai.
Redistribution in source or binary forms must retain this notice.
*/

import SwiftUI

public enum MSButtonKind: Sendable {
    case primary, secondary, tertiary, destructive
}

/// A button's outline. `.capsule` is for floating chrome, where a rounded rectangle
/// beside capsule chips reads as a second shape language.
public enum MSButtonShape: Sendable {
    case rounded, capsule

    var cornerRadius: CGFloat { self == .capsule ? MSRadius.pill : MSRadius.md }
}

public struct MSButtonStyle: ButtonStyle {
    private let kind: MSButtonKind
    private let fullWidth: Bool
    private let shape: MSButtonShape

    /// `ButtonStyle.Configuration` carries no enablement, so it is read from the
    /// environment. Deriving it from the configuration silently renders every
    /// disabled button at full strength.
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(kind: MSButtonKind = .primary, fullWidth: Bool = true, shape: MSButtonShape = .rounded) {
        self.kind = kind
        self.fullWidth = fullWidth
        self.shape = shape
    }

    public func makeBody(configuration: Configuration) -> some View {
        let outline = RoundedRectangle(cornerRadius: shape.cornerRadius, style: .continuous)

        return configuration.label
            .font(MSFont.bodyEmphasis)
            .foregroundStyle(foreground)
            .frame(maxWidth: fullWidth ? .infinity : nil, minHeight: MSSize.control)
            .padding(.horizontal, MSSpacing.lg)
            .background(background(pressed: configuration.isPressed), in: outline)
            .clipShape(outline)
            // After the clip, so the stroke keeps its full width instead of
            // losing the outer half to the corner radius.
            .overlay(outline.strokeBorder(border, lineWidth: kind == .secondary ? 1 : 0))
            .contentShape(Rectangle())
            .scaleEffect(pressScale(configuration))
            .animation(MSMotion.resolved(MSMotion.press, reduceMotion: reduceMotion), value: configuration.isPressed)
    }

    private func pressScale(_ configuration: Configuration) -> CGFloat {
        guard !reduceMotion, isEnabled, configuration.isPressed else { return 1 }
        return 0.97
    }

    /// Disabled is drawn, not dimmed.
    ///
    /// Fading the whole button took its label down with its fill: a disabled primary
    /// landed at about 1.3:1, which is a button whose own word cannot be read. A
    /// disabled control still has to say what it is, so the fill and the label are
    /// chosen separately and both stay legible.
    private var foreground: Color {
        guard isEnabled else { return MSColor.textMuted }
        switch kind {
        case .primary: return MSColor.onAccent
        case .secondary, .tertiary: return MSColor.textPrimary
        case .destructive: return .white
        }
    }

    private func background(pressed: Bool) -> Color {
        guard isEnabled else {
            // Tertiary has no fill when it is live and gains none by being disabled.
            return kind == .tertiary ? .clear : MSColor.surface3
        }
        switch kind {
        case .primary: return pressed ? MSColor.accentPressed : MSColor.accentFill
        // A fill, not only an outline: on a near-white page an outline alone was a
        // hairline around nothing, and "Skip for now" did not read as a control.
        case .secondary: return pressed ? MSColor.surface3 : MSColor.surface
        case .tertiary: return pressed ? MSColor.surface3 : .clear
        case .destructive: return MSColor.danger.opacity(pressed ? 0.8 : 1)
        }
    }

    private var border: Color {
        guard kind == .secondary else { return .clear }
        return isEnabled ? MSColor.controlBorder : MSColor.controlBorder.opacity(0.6)
    }
}

public extension View {
    func msButton(_ kind: MSButtonKind = .primary, fullWidth: Bool = true, shape: MSButtonShape = .rounded) -> some View {
        buttonStyle(MSButtonStyle(kind: kind, fullWidth: fullWidth, shape: shape))
    }

    /// The primary button as Liquid Glass, and as the filled accent button below iOS 26.
    ///
    /// For a control over the camera: a flat violet slab beside the dark circular AR
    /// chrome reads as a sticker on the picture, where glass takes the room's own light.
    /// The tint keeps it the primary action rather than another piece of chrome.
    func msGlassButton(fullWidth: Bool = false, shape: MSButtonShape = .rounded) -> some View {
        modifier(MSGlassButtonStyle(fullWidth: fullWidth, shape: shape))
    }
}

private struct MSGlassButtonStyle: ViewModifier {
    let fullWidth: Bool
    let shape: MSButtonShape

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .font(MSFont.bodyEmphasis)
                .buttonStyle(.glassProminent)
                .buttonBorderShape(.capsule)
                // The default control size draws a 34pt capsule, which beside the 44pt
                // circles of the AR chrome reads as a smaller-than-minimum target.
                .controlSize(.large)
                .tint(MSColor.accentFill)
                .frame(maxWidth: fullWidth ? .infinity : nil)
        } else {
            content.msButton(.primary, fullWidth: fullWidth, shape: shape)
        }
    }
}

#Preview("Buttons") {
    VStack(spacing: MSSpacing.lg) {
        Button("Primary") {}.msButton(.primary)
        Button("Primary, disabled") {}.msButton(.primary).disabled(true)
        Button("Secondary") {}.msButton(.secondary)
        Button("Secondary, disabled") {}.msButton(.secondary).disabled(true)
        Button("Destructive") {}.msButton(.destructive)
    }
    .padding(MSSpacing.xl)
    .frame(maxHeight: .infinity)
    .background(MSColor.appBackground)
}
