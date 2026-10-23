/*
Copyright (c) 2026 MultiSet AI. All rights reserved.
Licensed under the MultiSet License. You may not use this file except in compliance with the License. and you can't re-distribute this file without a prior notice
For license details, visit www.multiset.ai.
Redistribution in source or binary forms must retain this notice.
*/

import SwiftUI

/// How the reconstruction is drawn while recording. Collapsed it names the current style;
/// expanded it switches between Surface and Wireframe.
struct ScanMeshControls: View {
    @Binding var display: ScanMeshDisplay

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: MSSpacing.sm) {
            header
            if isExpanded {
                ViewThatFits(in: .vertical) {
                    details
                    ScrollView { details }
                }
                .padding(.bottom, MSSpacing.md)
            }
        }
        .padding(.horizontal, MSSpacing.md)
        .frame(width: isExpanded ? 280 : nil, alignment: .leading)
        .background(MSColor.AR.panel, in: RoundedRectangle(cornerRadius: MSRadius.md, style: .continuous))
        .foregroundStyle(MSColor.AR.text)
        .environment(\.colorScheme, .dark)
        .msAnimation(MSMotion.standard, value: isExpanded)
    }

    private var header: some View {
        Button {
            isExpanded.toggle()
        } label: {
            HStack(spacing: MSSpacing.sm) {
                Image(systemName: "slider.horizontal.3")
                Text(isExpanded ? "Display" : display.title)
                    .font(MSFont.captionEmphasis)
                if isExpanded { Spacer(minLength: 0) }
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.caption.weight(.bold))
            }
            .frame(minHeight: MSSize.minTouchTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Mesh display")
        .accessibilityValue(display.title)
        .accessibilityHint(isExpanded ? "Hides the display options" : "Shows the display options")
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: MSSpacing.sm) {
            Picker("Mesh display", selection: $display) {
                ForEach(ScanMeshDisplay.allCases) { style in
                    Text(style.title).tag(style)
                }
            }
            .pickerStyle(.segmented)
            Text(display.hint)
                .font(MSFont.caption)
                .foregroundStyle(MSColor.AR.textDim)
        }
    }
}
