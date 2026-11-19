/*
Copyright (c) 2026 MultiSet AI. All rights reserved.
Licensed under the MultiSet License. You may not use this file except in compliance with the License. and you can't re-distribute this file without a prior notice
For license details, visit www.multiset.ai.
Redistribution in source or binary forms must retain this notice.
*/

import SwiftUI

/// The five scanning instructions, swipeable. Shown before every scan unless the user asks
/// not to see it again.
///
/// This view never presents the scan itself. `onStart` hands over to `MappingFlowView`,
/// which swaps the scan in as the same cover's content.
struct MappingInstructionsView: View {
    let onStart: () -> Void
    let onCancel: () -> Void

    private struct Page: Identifiable {
        let id: Int
        let tag: String
        let text: String
        let image: InstructionImage
    }

    private static let pages: [Page] = [
        Page(id: 0, tag: "Distance", text: "Move slowly and capture the object from 1–5 meters of distance.", image: .distance),
        Page(id: 1, tag: "Coverage", text: "Cover an area only once — don't capture the same area multiple times in a session.", image: .coverOnce),
        Page(id: 2, tag: "Pacing", text: "Move at a steady speed in a continuous up-and-down motion for best results.", image: .steadySpeed),
        Page(id: 3, tag: "Stability", text: "Avoid rapid movements or rotations to prevent warped reconstructions.", image: .avoidRapid),
        Page(id: 4, tag: "Vertical sweep", text: "To capture floor and ceiling, move the device up and down.", image: .floorCeiling),
    ]

    static let suppressKey = "ai.multiset.sdk.hideMappingInstructions"

    static var isSuppressed: Bool { UserDefaults.standard.bool(forKey: suppressKey) }

    /// The illustrations' own near-black field (#07060E), so the letterboxing a square
    /// image leaves in a 4:3 slot reads as part of the artwork rather than as a frame
    /// around it. Sampled from the art, and fixed in both themes because the art is
    /// opaque dark JPEG: on a light page the plate is media, not a surface.
    private static let illustrationGround = Color(red: 0.027, green: 0.024, blue: 0.055)

    @State private var page = 0
    @State private var dontShowAgain = UserDefaults.standard.bool(forKey: MappingInstructionsView.suppressKey)

    private var isLast: Bool { page == Self.pages.count - 1 }

    var body: some View {
        ZStack {
            MSColor.appBackground.ignoresSafeArea()
            VStack(spacing: 0) {
                header
                TabView(selection: $page) {
                    ForEach(Self.pages) { item in
                        card(item)
                            .padding(.horizontal, MSSpacing.lg)
                            .tag(item.id)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(maxHeight: .infinity)
                pager
                    .padding(.top, MSSpacing.md)
                footer
                    .padding(.top, MSSpacing.xl)
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        ZStack {
            Text("Before you scan")
                .font(MSFont.headline)
                .foregroundStyle(MSColor.textPrimary)
            HStack {
                Button { onCancel() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(MSColor.textSecondary)
                        .frame(width: MSSize.minTouchTarget, height: MSSize.minTouchTarget)
                        .background(MSColor.surface, in: Circle())
                        .overlay(Circle().strokeBorder(MSColor.line, lineWidth: 1))
                }
                .accessibilityLabel("Close")
                Spacer()
                Button("Skip") { begin() }
                    .font(MSFont.captionEmphasis)
                    .foregroundStyle(MSColor.textSecondary)
                    .padding(.horizontal, MSSpacing.md)
                    .frame(minHeight: 36)
                    .background(MSColor.surface, in: Capsule())
                    .overlay(Capsule().strokeBorder(MSColor.line, lineWidth: 1))
                    .accessibilityHint("Skips the instructions and starts the scan")
            }
        }
        .padding(.horizontal, MSSpacing.lg)
        .padding(.top, MSSpacing.sm)
        .padding(.bottom, MSSpacing.md)
    }

    // MARK: - Card

    /// Illustration, then the words, on the page's own ground.
    ///
    /// There is no card: the artwork's field already matches the background, so a
    /// bordered container around it and a second fill behind the text were two boxes
    /// drawn around content that was never separate from the page.
    private func card(_ item: Page) -> some View {
        VStack(alignment: .leading, spacing: MSSpacing.xl) {
            illustration(item)
            textStrip(item)
        }
        // Centred rather than top-aligned: with the illustration no longer filling the
        // column, the slack has to go somewhere, and splitting it above and below reads
        // as breathing room where pooling it all above the pager read as a dead gap.
        .frame(maxHeight: .infinity, alignment: .center)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Step \(item.id + 1) of \(Self.pages.count), \(item.tag). \(item.text)")
    }

    /// Held to 4:3 so the square artwork sits at three quarters of the column's width
    /// rather than filling it. Letting it take the width made one illustration half the
    /// screen and pushed everything else into the bottom third.
    private func illustration(_ item: Page) -> some View {
        ZStack {
            Self.illustrationGround
            if let image = item.image.image {
                image.resizable().scaledToFit()
            }
        }
        .aspectRatio(4 / 3, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: MSRadius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: MSRadius.lg, style: .continuous)
                .strokeBorder(MSColor.line, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.12), radius: 14, y: 6)
    }

    /// Every page reserves the height of the tallest instruction, so the illustration
    /// stops resizing under the reader as pages of two and three lines swipe past. The
    /// other four are laid out invisibly rather than approximated by a constant, which
    /// would drift with Dynamic Type and with translation.
    private func textStrip(_ item: Page) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(Self.pages) { other in
                instruction(other)
                    .opacity(other.id == item.id ? 1 : 0)
                    .accessibilityHidden(other.id != item.id)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private func instruction(_ item: Page) -> some View {
        VStack(alignment: .leading, spacing: MSSpacing.sm) {
            HStack(spacing: MSSpacing.sm) {
                Text("\(item.id + 1)/\(Self.pages.count)")
                    .font(MSFont.captionEmphasis)
                    .foregroundStyle(MSColor.accent)
                Text(item.tag)
                    .font(MSFont.captionEmphasis)
                    .tracking(MSTracking.eyebrow)
                    .textCase(.uppercase)
                    .foregroundStyle(MSColor.textMuted)
            }
            Text(item.text)
                .font(MSFont.subtitle)
                .foregroundStyle(MSColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Pager

    private var pager: some View {
        HStack {
            pillButton("Previous", symbol: "chevron.left", leading: true, enabled: page > 0) {
                withAnimation { page -= 1 }
            }
            Spacer()
            HStack(spacing: MSSpacing.sm) {
                ForEach(Self.pages) { item in
                    Capsule()
                        .fill(page == item.id ? MSColor.accent : MSColor.line)
                        .frame(width: page == item.id ? 28 : 8, height: 8)
                        .animation(MSMotion.standard, value: page)
                }
            }
            Spacer()
            pillButton("Next", symbol: "chevron.right", leading: false, enabled: !isLast) {
                withAnimation { page += 1 }
            }
        }
        .padding(.horizontal, MSSpacing.lg)
        .padding(.top, MSSpacing.lg)
    }

    private func pillButton(_ title: String, symbol: String, leading: Bool, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: MSSpacing.xs) {
                if leading { Image(systemName: symbol).font(.system(size: 12, weight: .semibold)) }
                Text(title)
                if !leading { Image(systemName: symbol).font(.system(size: 12, weight: .semibold)) }
            }
            .font(MSFont.bodyEmphasis)
            .foregroundStyle(leading ? MSColor.textSecondary : MSColor.accent)
            .padding(.horizontal, MSSpacing.lg)
            .frame(minHeight: MSSize.minTouchTarget)
            .background(MSColor.surface, in: Capsule())
            .overlay(Capsule().strokeBorder(MSColor.line, lineWidth: 1))
        }
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.35)
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: MSSpacing.md) {
            Button {
                begin()
            } label: {
                Label("Start scanning", systemImage: "viewfinder")
            }
            .msButton(.primary)
            .shadow(color: MSColor.accentGlow, radius: 18, y: 8)

            Toggle(isOn: $dontShowAgain) {
                Text("Don't show this again")
                    .font(MSFont.callout)
                    .foregroundStyle(MSColor.textSecondary)
            }
            .toggleStyle(CheckboxToggleStyle())
            .onChange(of: dontShowAgain) { UserDefaults.standard.set($0, forKey: Self.suppressKey) }
        }
        .padding(.horizontal, MSSpacing.lg)
        .padding(.bottom, MSSpacing.md)
    }

    private func begin() {
        onStart()
    }
}

private struct CheckboxToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button { configuration.isOn.toggle() } label: {
            HStack(spacing: MSSpacing.sm) {
                Image(systemName: configuration.isOn ? "checkmark.square.fill" : "square")
                    .font(.system(size: 20))
                    .foregroundStyle(configuration.isOn ? MSColor.accent : MSColor.textMuted)
                configuration.label
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .frame(minHeight: MSSize.minTouchTarget)
    }
}
