/*
Copyright (c) 2026 MultiSet AI. All rights reserved.
Licensed under the MultiSet License. You may not use this file except in compliance with the License. and you can't re-distribute this file without a prior notice
For license details, visit www.multiset.ai.
Redistribution in source or binary forms must retain this notice.
*/

import SwiftUI

/// A thin progress strip for the mesh a fix has just asked for. Ported from the MultiSet iOS app.
///
/// A row in the controls rather than an overlay: a mesh takes three requests and can be tens of
/// megabytes, so it arrives well after the fix that asked for it, and the wait is no reason to
/// take the camera away.
struct MeshLoadingBar: View {
    let label: String

    var body: some View {
        HStack(spacing: MSSpacing.sm) {
            Image(systemName: "arrow.down.circle")
                .font(.system(size: 12, weight: .semibold))
            VStack(alignment: .leading, spacing: MSSpacing.xs) {
                Text(label)
                    .font(MSFont.caption)
                // The SDK reports no download size, so a sweeping segment says "still working"
                // without claiming a position.
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(MSColor.AR.text.opacity(0.2))
                        IndeterminateSweep(width: proxy.size.width)
                    }
                }
                .frame(height: 3)
            }
        }
        .foregroundStyle(MSColor.AR.text)
        .padding(.horizontal, MSSpacing.md)
        .padding(.vertical, MSSpacing.sm)
        .frame(maxWidth: 240, alignment: .leading)
        .background(MSColor.AR.panel, in: Capsule())
        .overlay(Capsule().strokeBorder(MSColor.AR.panelBorder, lineWidth: 1))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue("in progress")
    }
}

private struct IndeterminateSweep: View {
    let width: CGFloat
    @State private var start = false

    var body: some View {
        Capsule()
            .fill(MSColor.AR.accent)
            .frame(width: width * 0.35)
            .offset(x: start ? width * 0.65 : 0)
            .animation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true), value: start)
            .onAppear { start = true }
    }
}

#if DEBUG
struct MeshLoadingBar_Previews: PreviewProvider {
    static var previews: some View {
        MeshLoadingBar(label: "Loading the map mesh…")
            .padding()
            .background(Color.gray)
    }
}
#endif
