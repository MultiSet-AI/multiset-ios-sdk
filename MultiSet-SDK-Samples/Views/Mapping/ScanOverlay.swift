/*
Copyright (c) 2026 MultiSet AI. All rights reserved.
Licensed under the MultiSet License. You may not use this file except in compliance with the License. and you can't re-distribute this file without a prior notice
For license details, visit www.multiset.ai.
Redistribution in source or binary forms must retain this notice.
*/

import SwiftUI
import MultiSetSDK

struct ScanOverlay: View {
    @ObservedObject var model: ScanViewModel
    let onStart: () -> Void
    let onStop: () -> Void
    let onBack: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: MSSpacing.md) {
                backButton
                if showsMeshControls {
                    ScanMeshControls(display: $model.meshDisplay)
                }
                Spacer(minLength: 0)
                if showsTimer {
                    ScanTimer(elapsed: model.elapsed, isRecording: model.phase == .mapping)
                }
            }
            .padding(MSSpacing.lg)
            // Fills the height above the bottom bar, so expanded mesh controls scroll within it.
            .frame(maxHeight: .infinity, alignment: .top)

            if model.showsMotionWarning {
                ScanBanner(text: "Move slower", systemImage: "exclamationmark.triangle.fill")
                    .padding(.bottom, MSSpacing.md)
            }

            bottomBar
                .padding(.bottom, MSSpacing.xl)
                .padding(.horizontal, MSSpacing.lg)
        }
        .msAnimation(MSMotion.standard, value: model.showsMotionWarning)
    }

    private var backButton: some View {
        Button(action: onBack) {
            Image(systemName: "chevron.left")
                .font(.system(size: 17, weight: .semibold))
                .frame(width: MSSize.minTouchTarget, height: MSSize.minTouchTarget)
        }
        .background(MSColor.AR.panel, in: Circle())
        .foregroundStyle(MSColor.AR.text)
        .disabled(model.isBusy)
        .accessibilityLabel("Close")
    }

    /// The reconstruction exists only while recording, so there is nothing to style before.
    private var showsMeshControls: Bool {
        model.phase == .preparing || model.phase == .mapping
    }

    private var showsTimer: Bool {
        switch model.phase {
        case .mapping, .exporting, .zipping, .finished: true
        default: false
        }
    }

    @ViewBuilder private var bottomBar: some View {
        switch model.phase {
        case .idle, .failed:
            HStack(alignment: .bottom) {
                status("Tap record to start scanning", systemImage: "record.circle")
                Spacer()
                RecordButton(isRecording: false, action: onStart)
            }
        case .preparing:
            HStack(alignment: .bottom) {
                status("Finding your position…", systemImage: "arrow.triangle.2.circlepath")
                Spacer()
                RecordButton(isRecording: false, action: {}).disabled(true).opacity(0.5)
            }
        case .mapping:
            HStack(alignment: .bottom) {
                status(model.canFinish
                       ? "Recording"
                       : "Keep going — \(Int((MappingLimits.minimumScanDuration - model.elapsed).rounded(.up))) s more",
                       systemImage: "record.circle.fill")
                Spacer()
                RecordButton(isRecording: true, action: onStop)
                    .disabled(!model.canFinish)
                    .opacity(model.canFinish ? 1 : 0.5)
                    .accessibilityHint(model.canFinish ? "" : "Available after ten seconds")
            }
        case .exporting:
            status("Saving the mesh…", systemImage: "cube")
        case .zipping:
            VStack(spacing: MSSpacing.sm) {
                Text("Packaging \(Int(model.zipProgress * 100))%")
                    .font(MSFont.captionEmphasis)
                ProgressView(value: model.zipProgress)
                    .frame(maxWidth: 240)
                    .tint(MSColor.AR.accent)
            }
            .padding(MSSpacing.md)
            .background(MSColor.AR.panel, in: RoundedRectangle(cornerRadius: MSRadius.md, style: .continuous))
            .foregroundStyle(MSColor.AR.text)
        case .finished:
            status(summary, systemImage: "checkmark.circle.fill")
        case .packagingCancelled:
            status("Packaging stopped", systemImage: "pause.circle")
        @unknown default:
            EmptyView()
        }
    }

    private var summary: String {
        let frames = "\(model.savedFrames) frame\(model.savedFrames == 1 ? "" : "s")"
        let chunks = "\(model.meshChunkCount) mesh chunk\(model.meshChunkCount == 1 ? "" : "s")"
        guard model.blurredFrames > model.savedFrames else { return "\(frames), \(chunks)" }
        return "\(frames), \(chunks) — \(model.blurredFrames) too blurred to keep"
    }

    private func status(_ text: String, systemImage: String) -> some View {
        ScanStatusLabel(text: text, systemImage: systemImage)
    }
}

/// The shutter: a glow, a white rim, a black gap, and a violet disc that becomes a red
/// square while recording — the way every camera app says "stop".
struct RecordButton: View {
    let isRecording: Bool
    let action: () -> Void

    private static let diameter: CGFloat = 76
    private static let rim: CGFloat = 3
    private static let gap: CGFloat = 8
    private static let disc = diameter - 2 * (rim + gap)
    private static let square: CGFloat = 26

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(isRecording ? MSColor.AR.bad.opacity(0.55) : MSColor.AR.recordGlow)
                    .frame(width: Self.diameter, height: Self.diameter)
                    .blur(radius: 14)
                Circle()
                    .fill(.black)
                    .frame(width: Self.diameter - 2 * Self.rim, height: Self.diameter - 2 * Self.rim)
                Circle()
                    .strokeBorder(MSColor.AR.text, lineWidth: Self.rim)
                    .frame(width: Self.diameter, height: Self.diameter)
                RoundedRectangle(
                    cornerRadius: isRecording ? 6 : Self.disc / 2,
                    style: .continuous
                )
                .fill(isRecording ? MSColor.AR.bad : MSColor.AR.record)
                .frame(
                    width: isRecording ? Self.square : Self.disc,
                    height: isRecording ? Self.square : Self.disc)
            }
        }
        .buttonStyle(.plain)
        .msAnimation(MSMotion.emphasis, value: isRecording)
        .accessibilityLabel(isRecording ? "Stop recording" : "Start recording")
    }
}
