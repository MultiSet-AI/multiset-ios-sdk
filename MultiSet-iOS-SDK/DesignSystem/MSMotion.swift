/*
Copyright (c) 2026 MultiSet AI. All rights reserved.
Licensed under the MultiSet License. You may not use this file except in compliance with the License. and you can't re-distribute this file without a prior notice
For license details, visit www.multiset.ai.
Redistribution in source or binary forms must retain this notice.
*/

import SwiftUI

/// Named curves, so timing is a shared decision rather than a per-view guess.
///
/// Every curve resolves through `resolved(reduceMotion:)`, which is the only
/// place the accessibility setting is consulted. Views that check
/// `accessibilityReduceMotion` themselves each have to remember to.
public enum MSMotion {
    /// Touch feedback. Short enough to feel like a response, not an animation.
    public static let press = Animation.easeOut(duration: 0.12)
    /// A control or value changing state.
    public static let standard = Animation.easeInOut(duration: 0.28)
    /// Content arriving on screen.
    public static let entrance = Animation.easeOut(duration: 0.35)
    /// Success, toasts — the only curve allowed to overshoot.
    public static let emphasis = Animation.spring(response: 0.38, dampingFraction: 0.72)

    /// `nil` under reduce-motion, which SwiftUI treats as "apply the change
    /// immediately" — the state still updates, it just does not travel.
    public static func resolved(_ animation: Animation, reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : animation
    }
}

public extension View {
    /// Animates `value` with a named curve, honouring reduce-motion.
    func msAnimation<V: Equatable>(_ animation: Animation, value: V) -> some View {
        modifier(MSAnimationModifier(animation: animation, value: value))
    }

    /// Card-shaped tap targets. A large photographic card that does not respond
    /// to touch reads as an image rather than a control.
    func msPressable(scale: CGFloat = 0.97) -> some View {
        buttonStyle(MSPressableStyle(scale: scale))
    }
}

private struct MSAnimationModifier<V: Equatable>: ViewModifier {
    let animation: Animation
    let value: V
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.animation(MSMotion.resolved(animation, reduceMotion: reduceMotion), value: value)
    }
}

public struct MSPressableStyle: ButtonStyle {
    private let scale: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(scale: CGFloat = 0.97) {
        self.scale = scale
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(reduceMotion ? 1 : (configuration.isPressed ? scale : 1))
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(MSMotion.resolved(MSMotion.press, reduceMotion: reduceMotion), value: configuration.isPressed)
            .contentShape(Rectangle())
    }
}
