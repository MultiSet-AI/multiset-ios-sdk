/*
Copyright (c) 2026 MultiSet AI. All rights reserved.
Licensed under the MultiSet License. You may not use this file except in compliance with the License. and you can't re-distribute this file without a prior notice
For license details, visit www.multiset.ai.
Redistribution in source or binary forms must retain this notice.
*/

import SwiftUI

/// Where a run reports, step by step: a camera flash for each frame taken, an arc chasing round
/// the card while they are sent, the loader while the server searches, then a tick or a red mark
/// that fades. Ported from the MultiSet iOS app's `BackgroundStatusFace`.
struct RunStatusCard: View {
    let state: RunStatusState

    static let diameter: CGFloat = 36
    private static let glyph: CGFloat = 14
    private static let ringWidth: CGFloat = 2.5

    var body: some View {
        ZStack {
            Circle().fill(MSColor.AR.panel)
            Circle().strokeBorder(MSColor.AR.panelBorder, lineWidth: 1)
            content
            if state == .uploading {
                UploadRing(lineWidth: Self.ringWidth)
                    .transition(.opacity)
            }
        }
        .frame(width: Self.diameter, height: Self.diameter)
        .animation(.easeOut(duration: 0.25), value: state)
        .accessibilityElement()
        .accessibilityLabel(state.accessibilityText)
    }

    @ViewBuilder
    private var content: some View {
        switch state {
        case .hidden:
            EmptyView()
        case .working:
            ProgressView()
                .progressViewStyle(.circular)
                .tint(MSColor.AR.textDim)
                .scaleEffect(0.6)
                .transition(.opacity)
        case .capturing(let shots):
            ShutterGlyph(shots: shots, size: Self.glyph, flashDiameter: Self.diameter - 2)
                .transition(.opacity)
        case .uploading:
            UploadGlyph(size: Self.glyph)
                .transition(.opacity)
        case .succeeded:
            StatusMark.succeeded(size: Self.glyph)
        case .failed:
            StatusMark.failed(size: Self.glyph)
        }
    }
}

private enum StatusMark {
    static func succeeded(size: CGFloat) -> some View {
        mark("checkmark.circle.fill", MSColor.AR.good, size: size)
    }

    static func failed(size: CGFloat) -> some View {
        mark("exclamationmark.circle.fill", MSColor.AR.bad, size: size)
    }

    private static func mark(_ name: String, _ color: Color, size: CGFloat) -> some View {
        Image(systemName: name)
            .font(.system(size: size, weight: .semibold))
            .foregroundStyle(color)
            .transition(.opacity)
    }
}

/// A camera that flashes and clicks as each frame is taken.
private struct ShutterGlyph: View {
    let shots: Int
    let size: CGFloat
    let flashDiameter: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        // The capture step opens at 0 frames, which is not a frame: flashing there gave a single
        // frame two flashes.
        let fires = shots > 0
        // A new identity per frame replays the flash; a view animates from its first render.
        ZStack {
            ShutterFlash(peak: fires ? (reduceMotion ? 0.3 : 0.85) : 0)
                .frame(width: flashDiameter, height: flashDiameter)
            ShutterClick(pressedScale: fires && !reduceMotion ? 0.75 : 1) {
                Image(systemName: "camera.fill")
                    .font(.system(size: size, weight: .semibold))
                    .foregroundStyle(MSColor.AR.text)
            }
        }
        .id(shots)
        .transition(.identity)
    }
}

private struct ShutterFlash: View {
    let peak: Double
    @State private var opacity: Double?

    var body: some View {
        Circle()
            .fill(Color.white)
            .opacity(opacity ?? peak)
            .onAppear {
                withAnimation(.easeOut(duration: 0.45)) { opacity = 0 }
            }
    }
}

private struct ShutterClick<Content: View>: View {
    let pressedScale: CGFloat
    @ViewBuilder let content: Content
    @State private var scale: CGFloat?

    var body: some View {
        content
            .scaleEffect(scale ?? pressedScale)
            .onAppear {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) { scale = 1 }
            }
    }
}

/// An arrow rising off a base line, over and over, while the frames go out.
private struct UploadGlyph: View {
    let size: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private static let period: TimeInterval = 0.9

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { context in
            let phase = reduceMotion
                ? 0.5
                : context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: Self.period) / Self.period
            VStack(spacing: size * 0.08) {
                Image(systemName: "arrow.up")
                    .font(.system(size: size * 0.72, weight: .bold))
                    .offset(y: size * 0.28 * (1 - 2 * phase))
                    .opacity(reduceMotion ? 1 : min(1, 2.5 * sin(.pi * phase)))
                    .frame(height: size * 0.8)
                Capsule()
                    .frame(width: size * 0.78, height: max(2, size * 0.12))
            }
            .foregroundStyle(MSColor.AR.text)
        }
        .frame(width: size, height: size)
    }
}

/// The query going out, as an arc chasing round the card's rim. Indeterminate: the SDK cannot
/// tell when the body has left the phone, so it shows this step for a fixed 2 s.
private struct UploadRing: View {
    let lineWidth: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private static let period: TimeInterval = 1
    private static let arc = 0.28

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60, paused: reduceMotion)) { context in
            let turn = reduceMotion
                ? 0
                : context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: Self.period) / Self.period
            ZStack {
                Circle().stroke(MSColor.AR.accent.opacity(0.22), lineWidth: lineWidth)
                Circle()
                    .trim(from: 0, to: Self.arc)
                    .stroke(MSColor.AR.accent, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90 + 360 * turn))
            }
        }
        .padding(lineWidth / 2)
    }
}

#if DEBUG
struct RunStatusCard_Previews: PreviewProvider {
    static var previews: some View {
        HStack(spacing: MSSpacing.md) {
            RunStatusCard(state: .capturing(shots: 1))
            RunStatusCard(state: .uploading)
            RunStatusCard(state: .working)
            RunStatusCard(state: .succeeded)
            RunStatusCard(state: .failed)
        }
        .padding()
        .background(Color.gray)
    }
}
#endif
