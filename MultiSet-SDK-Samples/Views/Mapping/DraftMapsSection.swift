/*
Copyright (c) 2026 MultiSet AI. All rights reserved.
Licensed under the MultiSet License. You may not use this file except in compliance with the License. and you can't re-distribute this file without a prior notice
For license details, visit www.multiset.ai.
Redistribution in source or binary forms must retain this notice.
*/

import Combine
import SwiftUI
import MultiSetSDK

/// What a draft's package on disk amounts to, for the card. Everything is optional
/// because the row has to render for a draft whose files were lost.
struct DraftPackageSummary: Equatable {
    var bytes: Int64?
    var packagedAt: Date?
    var frameCount: Int?
    var captureKind: MappingCaptureKind

    init(_ draft: MappingDraft) {
        bytes = draft.packageBytes
        packagedAt = draft.packagedAt
        frameCount = draft.frameCount
        captureKind = draft.captureKind
    }

    /// "LiDAR · 142 frames · 11 MB", or what remains when a part is unknown; nil when the
    /// package says nothing at all.
    var facts: String? {
        var parts: [String] = []
        if let frameCount, frameCount > 0 {
            parts.append("\(frameCount) frame\(frameCount == 1 ? "" : "s")")
        }
        if let bytes {
            parts.append(ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file))
        }
        return parts.isEmpty ? nil : ([captureKind.title] + parts).joined(separator: " · ")
    }

    /// "Scanned 7 Sep, 11:58 PM". The year is noise for a scan that is still on the phone.
    var scannedLine: String? {
        guard let packagedAt else { return nil }
        let calendar = Calendar.current
        let style: Date.FormatStyle = calendar.isDate(packagedAt, equalTo: .now, toGranularity: .year)
            ? .dateTime.day().month(.abbreviated).hour().minute()
            : .dateTime.day().month(.abbreviated).year().hour().minute()
        return "Scanned \(packagedAt.formatted(style))"
    }
}

/// Scans that live on this device and have not been uploaded yet, mirrored from the SDK.
@MainActor
final class DraftMapsModel: ObservableObject {
    @Published private(set) var drafts: [MappingDraft] = []
    @Published private(set) var uploadStates: [String: MappingUploadState] = [:]

    private var observers: Set<AnyCancellable> = []

    init() {
        let center = NotificationCenter.default
        center.publisher(for: .multiSetMappingDraftsDidChange)
            .sink { [weak self] _ in self?.reload() }
            .store(in: &observers)
        center.publisher(for: .multiSetMappingUploadsDidChange)
            .sink { [weak self] _ in self?.reloadUploadStates() }
            .store(in: &observers)
        reload()
    }

    func reload() {
        drafts = MultiSet.shared.mapping.drafts()
        reloadUploadStates()
    }

    func state(for draft: MappingDraft) -> MappingUploadState? {
        uploadStates[draft.id]
    }

    func upload(_ draft: MappingDraft) {
        Task { await MultiSet.shared.mapping.upload(draftID: draft.id) }
    }

    func delete(_ draft: MappingDraft) {
        MultiSet.shared.mapping.deleteDraft(id: draft.id)
    }

    func dismissFailure(for draft: MappingDraft) {
        MultiSet.shared.mapping.dismissUploadFailure(for: draft.id)
    }

    private func reloadUploadStates() {
        var states: [String: MappingUploadState] = [:]
        for draft in drafts {
            states[draft.id] = MultiSet.shared.mapping.uploadState(for: draft.id)
        }
        uploadStates = states
    }
}

struct DraftMapsSection: View {
    @ObservedObject var model: DraftMapsModel

    /// Each draft's mark comes from its id, so it stays put as the list changes, except
    /// that a card never repeats the one above it: two alike in a row read as one item.
    private var symbols: [String] {
        var result: [String] = []
        for draft in model.drafts {
            var index = DraftMapRow.symbolIndex(for: draft)
            if DraftMapRow.symbols[index] == result.last {
                index = (index + 1) % DraftMapRow.symbols.count
            }
            result.append(DraftMapRow.symbols[index])
        }
        return result
    }

    var body: some View {
        if !model.drafts.isEmpty {
            let symbols = symbols
            VStack(alignment: .leading, spacing: MSSpacing.sm) {
                ForEach(Array(model.drafts.enumerated()), id: \.element.id) { index, draft in
                    DraftMapRow(
                        draft: draft,
                        symbol: symbols[index],
                        summary: DraftPackageSummary(draft),
                        state: model.state(for: draft),
                        onUpload: { model.upload(draft) },
                        onDelete: { model.delete(draft) },
                        onDismissFailure: { model.dismissFailure(for: draft) })
                }
            }
        }
    }
}

struct DraftMapRow: View {
    let draft: MappingDraft
    let symbol: String
    let summary: DraftPackageSummary
    let state: MappingUploadState?
    let onUpload: () -> Void
    let onDelete: () -> Void
    let onDismissFailure: () -> Void

    @State private var showsDeleteConfirmation = false

    /// A draft has no thumbnail, so each card carries a mark from this set instead. It
    /// reads as places and scans, which is what a draft is.
    static let symbols = [
        "building.2", "house", "door.left.hand.open", "square.stack.3d.up",
        "cube.transparent", "point.3.connected.trianglepath.dotted", "map", "camera.viewfinder",
    ]

    /// A stable pick from the id. `hashValue` is seeded per launch and would reshuffle
    /// the marks every time the app opens.
    static func symbolIndex(for draft: MappingDraft) -> Int {
        let hash = draft.id.unicodeScalars.reduce(5381) { ($0 &* 33) &+ Int($1.value) }
        return abs(hash) % symbols.count
    }

    var body: some View {
        MSCard(padding: MSSpacing.lg) {
            VStack(alignment: .leading, spacing: MSSpacing.md) {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: MSSpacing.md) {
                        iconWell
                        details
                        Spacer(minLength: 0)
                    }
                    VStack(alignment: .leading, spacing: MSSpacing.md) {
                        iconWell
                        details
                    }
                }
                Divider().overlay(MSColor.line)
                progressOrActions
            }
        }
        .alert("Delete this scan?", isPresented: $showsDeleteConfirmation) {
            Button("Delete", role: .destructive, action: onDelete)
            Button("Keep", role: .cancel) {}
        } message: {
            Text("The capture is only on this device. Deleting it cannot be undone.")
        }
        .accessibilityElement(children: .contain)
    }

    private var iconWell: some View {
        RoundedRectangle(cornerRadius: MSRadius.md, style: .continuous)
            .fill(MSColor.Category.draftsSoft)
            .frame(width: 56, height: 56)
            .overlay {
                Image(systemName: symbol)
                    .font(.system(size: 24, weight: .regular))
                    .foregroundStyle(MSColor.Category.drafts)
            }
            .accessibilityHidden(true)
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: MSSpacing.xxs) {
            Text(draft.name)
                .font(MSFont.headline)
                .foregroundStyle(MSColor.textPrimary)
                .lineLimit(2)
            if let facts = summary.facts {
                Text(facts)
                    .font(MSFont.caption)
                    .foregroundStyle(MSColor.textSecondary)
            } else {
                Text("Package missing")
                    .font(MSFont.caption)
                    .foregroundStyle(MSColor.danger)
            }
            if let scanned = summary.scannedLine {
                Text(scanned)
                    .font(MSFont.caption)
                    .foregroundStyle(MSColor.textMuted)
            }
            status
                .padding(.top, MSSpacing.xxs)
        }
    }

    @ViewBuilder private var status: some View {
        switch state {
        case .preparing:
            MSStatusPill("Preparing", tone: .neutral, style: .quiet)
        case .uploading(let fraction):
            MSStatusPill("Uploading \(Int(fraction * 100))%", tone: .positive, style: .quiet)
        case .waiting:
            MSStatusPill("Queued", tone: .caution, style: .quiet)
        case .failed:
            MSStatusPill("Upload failed", tone: .negative, style: .quiet)
        case nil:
            MSStatusPill("Ready to upload", tone: .caution, style: .quiet)
        @unknown default:
            EmptyView()
        }
    }

    @ViewBuilder private var progressOrActions: some View {
        switch state {
        case .preparing:
            Label("Preparing the upload…", systemImage: "arrow.triangle.2.circlepath")
                .font(MSFont.caption)
                .foregroundStyle(MSColor.textSecondary)
        case .uploading(let fraction):
            VStack(alignment: .leading, spacing: MSSpacing.xs) {
                ProgressView(value: fraction)
                    .tint(MSColor.accent)
                Text("Uploading \(Int(fraction * 100))%. You can leave this screen.")
                    .font(MSFont.caption)
                    .foregroundStyle(MSColor.textSecondary)
            }
        case .waiting(let reason):
            VStack(alignment: .leading, spacing: MSSpacing.sm) {
                Label(reason, systemImage: "clock.arrow.circlepath")
                    .font(MSFont.caption)
                    .foregroundStyle(MSColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                actions(uploadTitle: "Retry now", uploadSymbol: "arrow.clockwise", onUpload)
            }
        case .failed(let message):
            VStack(alignment: .leading, spacing: MSSpacing.sm) {
                Label(message, systemImage: "exclamationmark.triangle")
                    .font(MSFont.caption)
                    .foregroundStyle(MSColor.danger)
                actions(uploadTitle: "Try again", uploadSymbol: "arrow.clockwise") {
                    onDismissFailure()
                    onUpload()
                }
            }
        case nil:
            actions(uploadTitle: "Upload", uploadSymbol: "icloud.and.arrow.up", onUpload)
        @unknown default:
            EmptyView()
        }
    }

    private func actions(uploadTitle: String, uploadSymbol: String, _ upload: @escaping () -> Void) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: MSSpacing.sm) {
                Button(action: upload) {
                    Label(uploadTitle, systemImage: uploadSymbol).fixedSize()
                }
                .msButton(.primary, fullWidth: false)
                Button("Delete") { showsDeleteConfirmation = true }
                    .msButton(.tertiary, fullWidth: false)
                Spacer(minLength: 0)
            }
            VStack(spacing: MSSpacing.sm) {
                Button(action: upload) {
                    Label(uploadTitle, systemImage: uploadSymbol)
                }
                .msButton(.primary)
                Button("Delete") { showsDeleteConfirmation = true }
                    .msButton(.tertiary)
            }
        }
    }
}
