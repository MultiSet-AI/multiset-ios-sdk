/*
Copyright (c) 2026 MultiSet AI. All rights reserved.
Licensed under the MultiSet License. You may not use this file except in compliance with the License. and you can't re-distribute this file without a prior notice
For license details, visit www.multiset.ai.
Redistribution in source or binary forms must retain this notice.
*/

import SwiftUI
import MultiSetSDK

extension MappingLimits {
    static let finalMinuteStart = maximumScanDuration - 60
    static let finalMinuteWarning =
        "One minute left — the scan stops itself at \(ScanTimer.clock(maximumScanDuration))"
}

/// The scan clock out of the maximum, amber until the minimum is reached.
struct ScanTimer: View {
    let elapsed: TimeInterval
    let isRecording: Bool

    var body: some View {
        VStack(alignment: .trailing, spacing: MSSpacing.sm) {
            HStack(spacing: MSSpacing.sm) {
                if isRecording {
                    Circle().fill(MSColor.AR.bad).frame(width: 10, height: 10)
                        .opacity(Int(elapsed * 2) % 2 == 0 ? 1 : 0.3)
                }
                Text("\(Self.clock(elapsed)) / \(Self.clock(MappingLimits.maximumScanDuration))")
                    .font(MSFont.monoLarge)
                    .foregroundStyle(MSColor.AR.text)
                    .monospacedDigit()
            }
            ProgressView(value: min(elapsed / MappingLimits.maximumScanDuration, 1))
                .frame(width: 200)
                .tint(elapsed < MappingLimits.minimumScanDuration ? MSColor.AR.poor : MSColor.AR.accent)
        }
        .padding(MSSpacing.md)
        .background(MSColor.AR.panel, in: RoundedRectangle(cornerRadius: MSRadius.md, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Scanning for \(Int(elapsed)) seconds of a ten minute maximum")
    }

    static func clock(_ interval: TimeInterval) -> String {
        String(format: "%02d:%02d", Int(interval) / 60, Int(interval) % 60)
    }
}

struct ScanStatusLabel: View {
    let text: String
    let systemImage: String

    var body: some View {
        Label(text, systemImage: systemImage)
            .font(MSFont.captionEmphasis)
            .padding(.horizontal, MSSpacing.lg)
            .padding(.vertical, MSSpacing.md)
            .background(MSColor.AR.panel, in: Capsule())
            .foregroundStyle(MSColor.AR.text)
    }
}

/// A short warning over the scene: amber for "do something", as the motion banner is.
struct ScanBanner: View {
    let text: String
    let systemImage: String

    var body: some View {
        Label(text, systemImage: systemImage)
            .font(MSFont.captionEmphasis)
            .padding(.horizontal, MSSpacing.md)
            .padding(.vertical, MSSpacing.sm)
            .background(MSColor.AR.poor, in: Capsule())
            .foregroundStyle(.black)
            .transition(.opacity)
    }
}
