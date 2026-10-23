/*
Copyright (c) 2026 MultiSet AI. All rights reserved.
Licensed under the MultiSet License. You may not use this file except in compliance with the License. and you can't re-distribute this file without a prior notice
For license details, visit www.multiset.ai.
Redistribution in source or binary forms must retain this notice.
*/

import SwiftUI

/// An empty state is an invitation with an action, not an apology.
struct MSEmptyState<Action: View>: View {
    private let imageName: String
    private let tint: Color?
    private let title: String
    private let message: String
    private let action: Action

    /// `tint` is the feature's category colour; nil draws the art in the accent.
    init(
        imageName: String,
        tint: Color? = nil,
        title: String,
        message: String,
        @ViewBuilder action: () -> Action
    ) {
        self.imageName = imageName
        self.tint = tint
        self.title = title
        self.message = message
        self.action = action()
    }

    var body: some View {
        VStack(spacing: MSSpacing.lg) {
            Image(imageName)
                .renderingMode(.template)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 120, height: 120)
                .foregroundStyle(tint ?? MSColor.accent)
                .accessibilityHidden(true)
            VStack(spacing: MSSpacing.sm) {
                Text(title)
                    .font(MSFont.title)
                    .foregroundStyle(MSColor.textPrimary)
                    .multilineTextAlignment(.center)
                Text(message)
                    .font(MSFont.callout)
                    .foregroundStyle(MSColor.textSecondary)
                    .multilineTextAlignment(.center)
            }
            action
        }
        .padding(MSSpacing.xl)
        .frame(maxWidth: 420)
    }
}

extension MSEmptyState where Action == EmptyView {
    init(imageName: String, tint: Color? = nil, title: String, message: String) {
        self.init(imageName: imageName, tint: tint, title: title, message: message) { EmptyView() }
    }
}
