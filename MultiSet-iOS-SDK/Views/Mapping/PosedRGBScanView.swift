/*
Copyright (c) 2026 MultiSet AI. All rights reserved.
Licensed under the MultiSet License. You may not use this file except in compliance with the License. and you can't re-distribute this file without a prior notice
For license details, visit www.multiset.ai.
Redistribution in source or binary forms must retain this notice.
*/

import SwiftUI
import MultiSetSDK

/// The scan from camera images and their poses, for any device that tracks the world.
/// Landscape throughout, like `ScanView`, because the intrinsics beside every frame describe
/// a landscape image; the name card, the draft and the upload are the same completion flow.
struct PosedRGBScanView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model = PosedRGBScanViewModel()
    @State private var showsDiscardConfirmation = false
    @State private var showsFinishedDiscard = false
    @State private var showsCancelPackaging = false
    @State private var showsRotateCard = true
    @State private var showsNameCard = false

    var body: some View {
        ZStack {
            MultiSetMappingARView(source: model.source)
                .ignoresSafeArea()
            PosedRGBOverlay(
                model: model,
                onStart: { Task { await model.start() } },
                onFinish: { Task { await model.finish() } },
                onCancelPackaging: {
                    model.cancelPackaging()
                    showsCancelPackaging = true
                },
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
        .alert("Discard this scan?", isPresented: $showsCancelPackaging) {
            Button("Discard", role: .destructive) {
                Task { await model.discard() }
            }
            Button("Keep", role: .cancel) {
                Task { await model.resumePackaging() }
            }
        } message: {
            Text("Packaging has stopped. Keep it to package the scan again, or discard everything captured.")
        }
        .alert(item: $model.notice) { notice in
            Alert(title: Text(notice.title), message: Text(notice.message), dismissButton: .default(Text("OK")))
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
            Text(failure?.message ?? "")
        }
        .msARDialogTint()
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

    /// A camera that was never granted is not a failed scan — nothing was scanned yet.
    private var failureTitle: String {
        failure?.reason == .cameraAccessDenied ? "Camera access is off" : "Scan failed"
    }
}
