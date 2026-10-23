/*
Copyright (c) 2026 MultiSet AI. All rights reserved.
Licensed under the MultiSet License. You may not use this file except in compliance with the License. and you can't re-distribute this file without a prior notice
For license details, visit www.multiset.ai.
Redistribution in source or binary forms must retain this notice.
*/

import SwiftUI

public struct MSCard<Content: View>: View {
    private let padding: CGFloat
    private let elevation: MSElevation
    private let content: Content

    public init(
        padding: CGFloat = MSSpacing.lg,
        elevation: MSElevation = .raised,
        @ViewBuilder content: () -> Content
    ) {
        self.padding = padding
        self.elevation = elevation
        self.content = content()
    }

    public var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .msSurface(elevation)
    }
}

public struct MSSectionHeader<Accessory: View>: View {
    private let title: String
    private let subtitle: String?
    private let accessory: Accessory

    public init(
        _ title: String,
        subtitle: String? = nil,
        @ViewBuilder accessory: () -> Accessory
    ) {
        self.title = title
        self.subtitle = subtitle
        self.accessory = accessory()
    }

    public var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: MSSpacing.md) {
            VStack(alignment: .leading, spacing: MSSpacing.xxs) {
                Text(title)
                    .font(MSFont.headline)
                    .tracking(MSTracking.title)
                    .foregroundStyle(MSColor.textPrimary)
                if let subtitle {
                    Text(subtitle)
                        .font(MSFont.caption)
                        .foregroundStyle(MSColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
            accessory
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isHeader)
    }
}

public extension MSSectionHeader where Accessory == EmptyView {
    init(_ title: String, subtitle: String? = nil) {
        self.init(title, subtitle: subtitle) { EmptyView() }
    }
}
