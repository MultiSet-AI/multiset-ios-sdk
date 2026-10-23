/*
Copyright (c) 2026 MultiSet AI. All rights reserved.
Licensed under the MultiSet License. You may not use this file except in compliance with the License. and you can't re-distribute this file without a prior notice
For license details, visit www.multiset.ai.
Redistribution in source or binary forms must retain this notice.
*/

import SwiftUI
import MultiSetSDK

/// The capture screen. Landscape for the whole time it is on screen, because the
/// intrinsics written beside every frame describe a landscape image and nothing
/// downstream re-derives them.
struct ScanView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model = ScanViewModel()
    @State private var showsDiscardConfirmation = false
    @State private var showsFinishedDiscard = false
    @State private var showsRotateCard = true
    @State private var showsNameCard = false
    @State private var showsTooShort = false

    var body: some View {
        ZStack {
            MultiSetMappingARView(source: model.source)
                .ignoresSafeArea()
            ScanOverlay(
                model: model,
                onStart: { Task { await model.start() } },
                onStop: stop,
                onBack: back)

            if showsRotateCard {
                RotateToLandscapeCard { showsRotateCard = false }
            }
        }
        .scanCompletionFlow(isFinished: model.phase == .finished, showsNameCard: $showsNameCard)
        .statusBarHidden()
        .onAppear {
            OrientationLock.shared.set(.landscape, preferred: .landscapeRight)
            model.appear()
        }
        .onDisappear {
            model.disappear()
            OrientationLock.shared.restoreDefault()
        }
        .alert("Discard this scan?", isPresented: $showsDiscardConfirmation) {
            Button("Discard", role: .destructive, action: discardAndClose)
            Button("Keep scanning", role: .cancel) {}
        } message: {
            Text("Nothing captured so far will be kept.")
        }
        .alert("Discard this scan?", isPresented: $showsFinishedDiscard) {
            Button("Name and save") { showsNameCard = true }
            Button("Discard", role: .destructive, action: discardAndClose)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This scan has not been saved. Discarding it cannot be undone.")
        }
        .alert("Scan too short", isPresented: $showsTooShort) {
            Button("Scan again") {}
        } message: {
            Text("A scan needs at least \(Int(MappingLimits.minimumScanDuration)) seconds to build a map. This one has been discarded — start again and keep going.")
        }
        .alert(failureTitle, isPresented: failureBinding) {
            if failure?.reason == .cameraAccessDenied {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                    discardAndClose()
                }
                Button("Close", role: .cancel, action: discardAndClose)
            } else {
                Button("OK") {}
            }
        } message: {
            Text(failureMessage)
        }
        .msARDialogTint()
    }

    private func stop() {
        Task {
            if await model.stop() == .discardedTooShort {
                showsTooShort = true
            }
        }
    }

    private func back() {
        switch model.phase {
        case .preparing, .mapping:
            showsDiscardConfirmation = true
        case .exporting, .zipping, .packagingCancelled:
            break
        case .finished:
            showsFinishedDiscard = true
        case .idle, .failed:
            discardAndClose()
        @unknown default:
            break
        }
    }

    private func discardAndClose() {
        Task {
            await model.discard()
            dismiss()
        }
    }

    private var failure: MappingFailure? {
        if case .failed(let failure) = model.phase { return failure }
        return nil
    }

    private var failureBinding: Binding<Bool> {
        Binding(
            get: { failure != nil },
            set: { presented in if !presented { model.acknowledgeFailure() } })
    }

    private var failureMessage: String {
        failure?.message ?? ""
    }

    /// A camera that was never granted is not a failed scan — nothing was scanned yet.
    private var failureTitle: String {
        failure?.reason == .cameraAccessDenied ? "Camera access is off" : "Scan failed"
    }
}

/// The Unity scene's entry alert. The screen is landscape-locked, so this is a reminder
/// of what the phone is about to do rather than a request.
struct RotateToLandscapeCard: View {
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            MSColor.AR.scrim.ignoresSafeArea()
            VStack(spacing: MSSpacing.lg) {
                Image(systemName: "rotate.right")
                    .font(.system(size: 44, weight: .regular))
                    .foregroundStyle(MSColor.AR.accent)
                Text("Please rotate device to\nlandscape mode")
                    .font(MSFont.headline)
                    .foregroundStyle(MSColor.AR.text)
                    .multilineTextAlignment(.center)
                Button {
                    onDismiss()
                } label: {
                    HStack {
                        Spacer()
                        Text("Got it")
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                }
                .msButton()
                .frame(maxWidth: 320)
            }
            .padding(MSSpacing.xl)
            .frame(maxWidth: 420)
            .background(MSColor.AR.panel, in: RoundedRectangle(cornerRadius: MSRadius.lg, style: .continuous))
        }
    }
}

/// The save-map card: a name of at least three characters, then upload now or keep it.
struct MapNameCard: View {
    let onSubmit: (String) -> Void
    let onSaveDraft: (String) -> Void
    let onClose: () -> Void

    @State private var name = ""
    @FocusState private var isFocused: Bool

    private var trimmed: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var isValid: Bool { trimmed.count >= MappingLimits.minimumMapNameLength }

    var body: some View {
        ZStack {
            MSColor.AR.scrim.ignoresSafeArea()
            VStack(spacing: MSSpacing.lg) {
                HStack {
                    Spacer()
                    Text("Enter Map Name")
                        .font(MSFont.headline)
                        .foregroundStyle(MSColor.AR.text)
                    Spacer()
                    Button(action: onClose) {
                        Image(systemName: "xmark.circle")
                            .font(.system(size: 22))
                            .foregroundStyle(MSColor.AR.textDim)
                    }
                    .accessibilityLabel("Close")
                }
                TextField("Map name", text: $name)
                    .font(MSFont.body)
                    .foregroundStyle(MSColor.AR.text)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .focused($isFocused)
                    .padding(MSSpacing.md)
                    .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: MSRadius.md, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: MSRadius.md, style: .continuous).strokeBorder(MSColor.AR.panelBorder, lineWidth: 1))
                if !trimmed.isEmpty, !isValid {
                    Text("Name should be at least \(MappingLimits.minimumMapNameLength) characters long")
                        .font(MSFont.caption)
                        .foregroundStyle(MSColor.AR.bad)
                }
                Button("Submit Map Data") { onSubmit(trimmed) }
                    .msButton(.primary)
                    .disabled(!isValid)
                Button("Upload Later (Draft)") { onSaveDraft(trimmed) }
                    .msButton(.secondary)
                    .disabled(!isValid)
            }
            .padding(MSSpacing.xl)
            .frame(maxWidth: 420)
            .background(MSColor.AR.panel, in: RoundedRectangle(cornerRadius: MSRadius.lg, style: .continuous))
            // The panel is black in either appearance, so the tokens inside it must
            // resolve dark too: in light mode the secondary button's ink-on-black label vanished.
            .environment(\.colorScheme, .dark)
        }
        .onAppear { isFocused = true }
    }
}

/// Upload progress over the scene, then the failure with a way out. Success is the
/// alert the screen shows, because a finished upload leaves the screen.
struct UploadProgressCard: View {
    let draft: MappingDraft
    let state: MappingUploadState?
    let onFailureDismissed: () -> Void

    var body: some View {
        ZStack {
            MSColor.AR.scrim.ignoresSafeArea()
            VStack(spacing: MSSpacing.lg) {
                switch state {
                case .preparing, .none:
                    ProgressView().tint(MSColor.AR.text)
                    Text("Preparing \"\(draft.name)\"…")
                        .font(MSFont.headline)
                        .foregroundStyle(MSColor.AR.text)
                case .uploading(let fraction):
                    Text("Uploading \"\(draft.name)\"")
                        .font(MSFont.headline)
                        .foregroundStyle(MSColor.AR.text)
                    ProgressView(value: fraction)
                        .tint(MSColor.AR.accent)
                        .frame(maxWidth: 320)
                    Text("\(Int(fraction * 100))% — the upload continues if you leave the app")
                        .font(MSFont.caption)
                        .foregroundStyle(MSColor.AR.textDim)
                case .waiting(let reason):
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 36))
                        .foregroundStyle(MSColor.AR.textDim)
                    Text("Upload queued")
                        .font(MSFont.headline)
                        .foregroundStyle(MSColor.AR.text)
                    Text("\(reason)\n\nIt is safe to leave: the scan is in your drafts and uploads on its own once it can.")
                        .font(MSFont.caption)
                        .foregroundStyle(MSColor.AR.textDim)
                        .multilineTextAlignment(.center)
                    Button("Done", action: onFailureDismissed).msButton()
                case .failed(let message):
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(MSColor.AR.bad)
                    Text("Upload failed")
                        .font(MSFont.headline)
                        .foregroundStyle(MSColor.AR.text)
                    Text("\(message)\n\nThe scan is saved in your drafts; you can retry from there.")
                        .font(MSFont.caption)
                        .foregroundStyle(MSColor.AR.textDim)
                        .multilineTextAlignment(.center)
                    Button("OK", action: onFailureDismissed).msButton()
                @unknown default:
                    EmptyView()
                }
            }
            .padding(MSSpacing.xl)
            .frame(maxWidth: 420)
            .background(MSColor.AR.panel, in: RoundedRectangle(cornerRadius: MSRadius.lg, style: .continuous))
        }
    }
}
