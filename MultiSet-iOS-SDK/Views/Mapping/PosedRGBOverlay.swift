/*
Copyright (c) 2026 MultiSet AI. All rights reserved.
Licensed under the MultiSet License. You may not use this file except in compliance with the License. and you can't re-distribute this file without a prior notice
For license details, visit www.multiset.ai.
Redistribution in source or binary forms must retain this notice.
*/

import SwiftUI
import MultiSetSDK

/// The posed-RGB scan's controls: the LiDAR scan's back button, clock and shutter, with a
/// guidance panel where the mesh controls were — frames kept, how much has been walked,
/// and why frames are not being kept, if they are not.
struct PosedRGBOverlay: View {
    @ObservedObject var model: PosedRGBScanViewModel
    let onStart: () -> Void
    let onFinish: () -> Void
    let onCancelPackaging: () -> Void
    let onBack: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: MSSpacing.sm) {
                HStack(alignment: .top, spacing: MSSpacing.md) {
                    backButton
                    if model.phase == .mapping { guidance }
                    Spacer(minLength: 0)
                    VStack(alignment: .trailing, spacing: MSSpacing.sm) {
                        if showsTimer {
                            ScanTimer(elapsed: model.elapsed, isRecording: model.phase == .mapping)
                        }
                        if let tracking = model.tracking {
                            TrackingIndicator(level: tracking.level)
                        }
                    }
                }
                MSToastBanner($model.toast)
            }
            .padding(MSSpacing.lg)
            .frame(maxHeight: .infinity, alignment: .top)

            VStack(spacing: MSSpacing.sm) {
                if model.isInFinalMinute {
                    ScanBanner(text: MappingLimits.finalMinuteWarning, systemImage: "timer")
                }
                if model.phase == .mapping, model.isCapturingSlowly {
                    ScanBanner(text: "Device is warm — capturing more slowly", systemImage: "thermometer.sun.fill")
                }
                if model.showsMotionWarning {
                    ScanBanner(text: "Move slower", systemImage: "exclamationmark.triangle.fill")
                }
            }
            .padding(.bottom, MSSpacing.md)

            bottomBar
                .padding(.bottom, MSSpacing.xl)
                .padding(.horizontal, MSSpacing.lg)
        }
        .msAnimation(MSMotion.standard, value: model.showsMotionWarning)
        .msAnimation(MSMotion.standard, value: model.isInFinalMinute)
    }

    private var backButton: some View {
        Button(action: onBack) {
            Image(systemName: "chevron.left")
                .font(.system(size: 17, weight: .semibold))
                .frame(width: MSSize.minTouchTarget, height: MSSize.minTouchTarget)
        }
        .background(MSColor.AR.panel, in: Circle())
        .foregroundStyle(MSColor.AR.text)
        .disabled(model.phase == .zipping || model.phase == .packagingCancelled)
        .accessibilityLabel("Close")
    }

    private var showsTimer: Bool {
        switch model.phase {
        case .mapping, .zipping, .packagingCancelled, .finished: true
        default: false
        }
    }

    private var guidance: some View {
        VStack(alignment: .leading, spacing: MSSpacing.xs) {
            Label("\(model.savedFrames) frame\(model.savedFrames == 1 ? "" : "s") kept", systemImage: "photo.stack")
                .font(MSFont.captionEmphasis)
            Label(coverageHint, systemImage: "figure.walk")
                .font(MSFont.caption)
                .foregroundStyle(MSColor.AR.textDim)
            if let tracking = model.tracking, let issue = tracking.issue {
                Label(issue.message, systemImage: issue.systemImage)
                    .font(MSFont.captionEmphasis)
                    .foregroundStyle(tracking.level == .lost ? MSColor.AR.bad : MSColor.AR.poor)
            }
        }
        .foregroundStyle(MSColor.AR.text)
        .padding(MSSpacing.md)
        .background(MSColor.AR.panel, in: RoundedRectangle(cornerRadius: MSRadius.md, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private var coverageHint: String {
        guard let area = model.walkedArea else { return "Move around the space" }
        return "Walked about \(Int(area.rounded())) m² — reach the edges too"
    }

    @ViewBuilder private var bottomBar: some View {
        switch model.phase {
        case .idle, .failed:
            HStack(alignment: .bottom) {
                ScanStatusLabel(text: "Tap record to start scanning", systemImage: "record.circle")
                Spacer()
                RecordButton(isRecording: false, action: onStart)
            }
        case .preparing:
            HStack(alignment: .bottom) {
                ScanStatusLabel(text: "Finding your position…", systemImage: "arrow.triangle.2.circlepath")
                Spacer()
                RecordButton(isRecording: false, action: {}).disabled(true).opacity(0.5)
            }
        case .mapping:
            HStack(alignment: .bottom) {
                ScanStatusLabel(
                    text: model.canFinish
                        ? "Recording"
                        : "Keep going — \(Int((MappingLimits.minimumScanDuration - model.elapsed).rounded(.up))) s more",
                    systemImage: "record.circle.fill")
                Spacer()
                RecordButton(isRecording: true, action: onFinish)
                    .disabled(!model.canFinish)
                    .opacity(model.canFinish ? 1 : 0.5)
                    .accessibilityHint(model.canFinish ? "" : "Available after ten seconds")
            }
        case .zipping:
            HStack(spacing: MSSpacing.md) {
                VStack(spacing: MSSpacing.sm) {
                    Text("Packaging \(Int(model.zipProgress * 100))%")
                        .font(MSFont.captionEmphasis)
                    ProgressView(value: model.zipProgress)
                        .frame(maxWidth: 240)
                        .tint(MSColor.AR.accent)
                }
                Button("Cancel", action: onCancelPackaging)
                    .msButton(.secondary)
                    .fixedSize()
            }
            .padding(MSSpacing.md)
            .background(MSColor.AR.panel, in: RoundedRectangle(cornerRadius: MSRadius.md, style: .continuous))
            .foregroundStyle(MSColor.AR.text)
            .environment(\.colorScheme, .dark)
        case .packagingCancelled:
            ScanStatusLabel(text: "Packaging stopped", systemImage: "pause.circle")
        case .finished:
            ScanStatusLabel(text: summary, systemImage: "checkmark.circle.fill")
        case .exporting:
            EmptyView()
        @unknown default:
            EmptyView()
        }
    }

    private var summary: String {
        var parts = ["\(model.savedFrames) frame\(model.savedFrames == 1 ? "" : "s")"]
        if model.blurredFrames > model.savedFrames {
            parts.append("\(model.blurredFrames) too blurred to keep")
        }
        if model.discardedFrames > 0 {
            parts.append("\(model.discardedFrames) removed after tracking trouble")
        }
        return parts.joined(separator: " — ")
    }
}

/// How well tracking is going, at a glance: green while frames are kept safely, amber while
/// they are paused or at risk, red while tracking is lost.
private struct TrackingIndicator: View {
    let level: MappingTrackingStatus.Level

    var body: some View {
        HStack(spacing: MSSpacing.xs) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(title)
                .font(MSFont.captionEmphasis)
        }
        .padding(.horizontal, MSSpacing.md)
        .padding(.vertical, MSSpacing.sm)
        .background(MSColor.AR.panel, in: Capsule())
        .foregroundStyle(MSColor.AR.text)
        .accessibilityElement(children: .combine)
        .msAnimation(MSMotion.standard, value: level)
    }

    private var title: String {
        switch level {
        case .good: "Tracking good"
        case .weak: "Tracking weak"
        case .lost: "Tracking lost"
        @unknown default: "Tracking weak"
        }
    }

    private var color: Color {
        switch level {
        case .good: MSColor.AR.good
        case .weak: MSColor.AR.poor
        case .lost: MSColor.AR.bad
        @unknown default: MSColor.AR.poor
        }
    }
}
