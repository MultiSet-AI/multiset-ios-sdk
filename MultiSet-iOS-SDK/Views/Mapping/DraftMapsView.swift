/*
Copyright (c) 2026 MultiSet AI. All rights reserved.
Licensed under the MultiSet License. You may not use this file except in compliance with the License. and you can't re-distribute this file without a prior notice
For license details, visit www.multiset.ai.
Redistribution in source or binary forms must retain this notice.
*/

import SwiftUI
import MultiSetSDK

/// Scans still on this device. Uploading needs the SDK to be authenticated; scanning does not.
struct DraftMapsView: View {
    @StateObject private var drafts = DraftMapsModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MSSpacing.lg) {
                if drafts.drafts.isEmpty {
                    MSEmptyState(
                        imageName: "empty-no-drafts",
                        tint: MSColor.Category.drafts,
                        title: "No drafts on this device",
                        message: "A scan you save without uploading waits here until you send it to your account."
                    )
                    .padding(.top, MSSpacing.xxl)
                    .frame(maxWidth: .infinity)
                } else {
                    Text("\(drafts.drafts.count) scan\(drafts.drafts.count == 1 ? "" : "s") on this device, waiting to be uploaded")
                        .font(MSFont.caption)
                        .foregroundStyle(MSColor.textSecondary)
                        .padding(.horizontal, MSSpacing.xs)
                    DraftMapsSection(model: drafts)
                }
            }
            .padding(.horizontal, MSSpacing.lg)
            .padding(.bottom, MSSpacing.xl)
        }
        .background(MSColor.appBackground.ignoresSafeArea())
        .navigationTitle("Draft maps")
        .navigationBarTitleDisplayMode(.inline)
        .task { await refresh() }
        .refreshable { await refresh() }
    }

    private func refresh() async {
        drafts.reload()
        await MultiSet.shared.mapping.resumeUploads()
    }
}
