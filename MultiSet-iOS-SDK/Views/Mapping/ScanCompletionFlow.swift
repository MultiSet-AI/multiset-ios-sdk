/*
Copyright (c) 2026 MultiSet AI. All rights reserved.
Licensed under the MultiSet License. You may not use this file except in compliance with the License. and you can't re-distribute this file without a prior notice
For license details, visit www.multiset.ai.
Redistribution in source or binary forms must retain this notice.
*/

import Combine
import SwiftUI
import MultiSetSDK

extension View {
    /// What follows a finished scan on either scan screen: the name card, the draft, the
    /// upload card and the alerts that end them. `showsNameCard` opens on its own when the
    /// scan finishes; a screen sets it to reopen a card that was closed.
    func scanCompletionFlow(isFinished: Bool, showsNameCard: Binding<Bool>) -> some View {
        modifier(ScanCompletionFlow(isFinished: isFinished, showsNameCard: showsNameCard))
    }
}

private struct ScanCompletionFlow: ViewModifier {
    let isFinished: Bool
    @Binding var showsNameCard: Bool

    @Environment(\.dismiss) private var dismiss
    @StateObject private var upload = ScanUploadModel()
    @State private var saveError: String?

    func body(content: Content) -> some View {
        content
            .overlay {
                ZStack {
                    if showsNameCard, isFinished {
                        MapNameCard(
                            onSubmit: { name in saveDraft(named: name, thenUpload: true) },
                            onSaveDraft: { name in saveDraft(named: name, thenUpload: false) },
                            onClose: { showsNameCard = false })
                    }
                    if let draft = upload.draft {
                        UploadProgressCard(draft: draft, state: upload.state) {
                            upload.stopFollowing()
                            showsNameCard = false
                            dismiss()
                        }
                    }
                }
            }
            .onChange(of: isFinished) { finished in
                if finished { showsNameCard = true }
            }
            .alert("Couldn't save the scan", isPresented: .init(get: { saveError != nil }, set: { if !$0 { saveError = nil } })) {
                Button("OK") {}
            } message: {
                Text(saveError ?? "")
            }
            .alert("Map uploaded", isPresented: .init(get: { upload.uploadedName != nil }, set: { if !$0 { upload.uploadedName = nil } })) {
                Button("Done") {
                    upload.stopFollowing()
                    dismiss()
                }
            } message: {
                Text("\"\(upload.uploadedName ?? "")\" was uploaded and is now processing. It will appear in your maps as Pending until the build finishes.")
            }
    }

    /// The draft is saved first either way: an upload that fails mid-way must not cost
    /// the scan.
    private func saveDraft(named name: String, thenUpload: Bool) {
        do {
            let draft = try MultiSet.shared.mapping.saveDraft(named: name)
            if thenUpload {
                upload.follow(draft)
            } else {
                showsNameCard = false
                dismiss()
            }
        } catch {
            saveError = error.localizedDescription
        }
    }
}

/// The upload a scan screen started and is following, mirrored from `MultiSet.shared.mapping`.
@MainActor
private final class ScanUploadModel: ObservableObject {
    @Published private(set) var draft: MappingDraft?
    @Published private(set) var state: MappingUploadState?
    @Published var uploadedName: String?

    private var observers: Set<AnyCancellable> = []
    private var mapping: MultiSetMapping { MultiSet.shared.mapping }

    init() {
        let center = NotificationCenter.default
        center.publisher(for: .multiSetMappingUploadsDidChange)
            .merge(with: center.publisher(for: .multiSetMappingDraftsDidChange))
            .sink { [weak self] _ in self?.refresh() }
            .store(in: &observers)
    }

    func follow(_ draft: MappingDraft) {
        self.draft = draft
        state = .preparing
        Task {
            await mapping.upload(draftID: draft.id)
            refresh()
        }
    }

    func stopFollowing() {
        if let draft {
            mapping.dismissUploadFailure(for: draft.id)
        }
        draft = nil
        state = nil
    }

    /// A successful upload deletes its draft, so "no state and no draft" means it arrived.
    private func refresh() {
        guard let draft else { return }
        state = mapping.uploadState(for: draft.id)
        if state == nil, !mapping.drafts().contains(where: { $0.id == draft.id }) {
            uploadedName = draft.name
        }
    }
}
