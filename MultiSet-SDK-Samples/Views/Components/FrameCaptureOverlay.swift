/*
Copyright (c) 2026 MultiSet AI. All rights reserved.
Licensed under the MultiSet License. You may not use this file except in compliance with the License. and you can't re-distribute this file without a prior notice
For license details, visit www.multiset.ai.
Redistribution in source or binary forms must retain this notice.
*/

import SwiftUI
import MultiSetSDK

/// Shown while frames are being captured for a run the user is waiting on. Ported from the
/// MultiSet iOS app.
///
/// Only while frames are actually being taken: the request that follows gets
/// `ServerWaitOverlay`, because by then there is nothing left for the user to do and an
/// animation that asks them to keep moving is a lie.
struct FrameCaptureOverlay: View {
    /// A room plate tells someone to sweep a space. That is right for localization and wrong for
    /// a tracked object, where the subject is one thing on a surface and the gesture is smaller.
    enum Backdrop {
        case room
        case object

        var imageName: String {
            switch self {
            case .room: "bg_ar"
            case .object: "bg_object"
            }
        }

        var size: CGSize {
            switch self {
            case .room: CGSize(width: 200, height: 100)
            case .object: CGSize(width: 132, height: 132)
            }
        }

        var travel: CGFloat {
            switch self {
            case .room: 60
            case .object: 44
            }
        }

        /// Object tracking takes one frame after a one-second settle. A two-second sweep would
        /// never finish inside that window, so this one moves at twice the pace.
        var period: Double {
            switch self {
            case .room: 2
            case .object: 1
            }
        }
    }

    let statusText: String?
    var title = "Hold steady and scan your surroundings"
    var backdrop = Backdrop.room

    @State private var phoneOffset: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Color.black.opacity(0.8).ignoresSafeArea()

            VStack(spacing: MSSpacing.xl) {
                ZStack {
                    Image(backdrop.imageName)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: backdrop.size.width, height: backdrop.size.height)
                    Image("phone_image")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 58, height: 77)
                        .offset(x: phoneOffset)
                }
                .frame(width: backdrop.size.width, height: max(backdrop.size.height, 77))
                .accessibilityHidden(true)

                VStack(spacing: MSSpacing.sm) {
                    Text(title)
                        .font(MSFont.headline)
                        .foregroundStyle(MSColor.AR.text)
                        .multilineTextAlignment(.center)
                    if let statusText {
                        Text(statusText)
                            .font(MSFont.mono)
                            .foregroundStyle(MSColor.AR.textDim)
                            .multilineTextAlignment(.center)
                    }
                }
            }
            .padding(MSSpacing.xl)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel([title, statusText].compactMap { $0 }.joined(separator: ". "))
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: backdrop.period).repeatForever(autoreverses: true)) {
                phoneOffset = backdrop.travel
            }
        }
    }

    /// The frame count under the title, for a stage that is capturing.
    static func captureStatus(for stage: LocalizationStage) -> String? {
        guard case .capturing(let captured, let required) = stage else { return nil }
        if required <= 1 { return captured == 0 ? "Capturing image…" : "Image captured" }
        return "Capturing image \(min(captured + 1, required)) of \(required)"
    }
}

/// Shown while a run the user is waiting on is with the server, after capture has finished.
struct ServerWaitOverlay: View {
    let statusText: String

    var body: some View {
        ZStack {
            Color.black.opacity(0.8).ignoresSafeArea()
            VStack(spacing: MSSpacing.lg) {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(MSColor.AR.accent)
                    .scaleEffect(1.5)
                Text(statusText)
                    .font(MSFont.callout)
                    .foregroundStyle(MSColor.AR.textDim)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, MSSpacing.xl)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(statusText)
    }
}

#if DEBUG
struct FrameCaptureOverlay_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            FrameCaptureOverlay(statusText: "Capturing image 2 of 4")
            FrameCaptureOverlay(statusText: "Capturing image…", title: "Hold steady on the object", backdrop: .object)
            ServerWaitOverlay(statusText: "Matching against the map…")
        }
    }
}
#endif
