/*
Copyright (c) 2026 MultiSet AI. All rights reserved.
Licensed under the MultiSet License. You may not use this file except in compliance with the License. and you can't re-distribute this file without a prior notice
For license details, visit www.multiset.ai.
Redistribution in source or binary forms must retain this notice.
*/

import SwiftUI

public enum MSStatusTone: Sendable {
    case neutral, positive, caution, negative, accent

    var color: Color {
        switch self {
        case .neutral: MSColor.textMuted
        case .positive: MSColor.success
        case .caution: MSColor.warning
        case .negative: MSColor.danger
        case .accent: MSColor.accent
        }
    }
}

public enum MSStatusPillStyle: Sendable {
    /// Fill, border and weight. Reserve for the one status that carries the row.
    case solid
    /// A tinted dot and a label. Three solid pills on a row is chrome competing
    /// with the name the row is actually about.
    case quiet
}

public struct MSStatusPill: View {
    private let label: String
    private let tone: MSStatusTone
    private let systemImage: String?
    private let style: MSStatusPillStyle

    public init(
        _ label: String,
        tone: MSStatusTone = .neutral,
        systemImage: String? = nil,
        style: MSStatusPillStyle = .solid
    ) {
        self.label = label
        self.tone = tone
        self.systemImage = systemImage
        self.style = style
    }

    public var body: some View {
        switch style {
        case .solid: solid
        case .quiet: quiet
        }
    }

    private var solid: some View {
        HStack(spacing: MSSpacing.xs) {
            if let systemImage {
                Image(systemName: systemImage).font(.system(size: 9, weight: .bold))
            }
            Text(label)
        }
        .font(MSFont.captionEmphasis)
        .foregroundStyle(tone.color)
        .padding(.horizontal, MSSpacing.sm)
        .padding(.vertical, MSSpacing.xxs + 1)
        .background(tone.color.opacity(0.12), in: Capsule())
        .overlay(Capsule().strokeBorder(tone.color.opacity(0.24), lineWidth: 1))
        .accessibilityLabel(label)
    }

    private var quiet: some View {
        HStack(spacing: MSSpacing.xs) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(tone.color)
            } else {
                Circle()
                    .fill(tone.color)
                    .frame(width: 6, height: 6)
            }
            Text(label)
                .font(MSFont.caption)
                .foregroundStyle(MSColor.textSecondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label)
    }
}

/// A monospaced key/value row for engineering data. Long-press copies the value.
public struct MSMonoValue: View {
    private let label: String
    private let value: String
    private let tone: Color?

    public init(_ label: String, _ value: String, tone: Color? = nil) {
        self.label = label
        self.value = value
        self.tone = tone
    }

    public var body: some View {
        // Side by side while both fit; at accessibility sizes the value drops under its
        // label rather than hyphenating.
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: MSSpacing.sm) {
                labelText
                Spacer(minLength: MSSpacing.sm)
                valueText.multilineTextAlignment(.trailing).lineLimit(1)
            }
            VStack(alignment: .leading, spacing: MSSpacing.xxs) {
                labelText
                valueText.frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label), \(value)")
    }

    private var labelText: some View {
        Text(label)
            .font(MSFont.monoSmall)
            .foregroundStyle(MSColor.textMuted)
    }

    private var valueText: some View {
        Text(value)
            .font(MSFont.mono)
            .foregroundStyle(tone ?? MSColor.textPrimary)
            .textSelection(.enabled)
    }
}
