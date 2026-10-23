/*
Copyright (c) 2026 MultiSet AI. All rights reserved.
Licensed under the MultiSet License. You may not use this file except in compliance with the License. and you can't re-distribute this file without a prior notice
For license details, visit www.multiset.ai.
Redistribution in source or binary forms must retain this notice.
*/

import SwiftUI

public struct MSToast: Equatable, Identifiable, Sendable {
    public enum Tone: Sendable { case success, failure, info }

    public let id = UUID()
    public let message: String
    public let tone: Tone

    public init(message: String, tone: Tone = .info) {
        self.message = message
        self.tone = tone
    }

    var symbol: String {
        switch tone {
        case .success: "checkmark.circle.fill"
        case .failure: "exclamationmark.triangle.fill"
        case .info: "info.circle.fill"
        }
    }

    var color: Color {
        switch tone {
        case .success: MSColor.success
        case .failure: MSColor.danger
        case .info: MSColor.info
        }
    }
}

/// The banner itself, placeable in a layout rather than only as a top overlay.
///
/// An AR screen's top edge is already its title, its state and its close button, and a
/// toast dropped over them hid all three. Those screens put this in their own stack
/// under the chrome instead, where it can never cover a control.
public struct MSToastBanner: View {
    @Binding private var toast: MSToast?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(_ toast: Binding<MSToast?>) {
        _toast = toast
    }

    public var body: some View {
        Group {
            if let toast {
                HStack(spacing: MSSpacing.sm) {
                    Image(systemName: toast.symbol).foregroundStyle(toast.color)
                    Text(toast.message)
                        .font(MSFont.callout)
                        .foregroundStyle(MSColor.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                }
                .padding(.horizontal, MSSpacing.lg)
                .padding(.vertical, MSSpacing.md)
                .background(MSColor.surface, in: Capsule())
                .overlay(Capsule().strokeBorder(MSColor.line, lineWidth: 1))
                .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
                .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
                .accessibilityAddTraits(.isStaticText)
                .task(id: toast.id) {
                    try? await Task.sleep(for: .seconds(3))
                    withAnimation { self.toast = nil }
                }
            }
        }
        // `.spring(duration:)` is iOS 17; this is the same critically damped spring.
        .animation(reduceMotion ? .none : .spring(response: 0.32, dampingFraction: 1), value: toast)
    }
}
