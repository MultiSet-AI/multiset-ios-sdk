/*
Copyright (c) 2026 MultiSet AI. All rights reserved.
Licensed under the MultiSet License. You may not use this file except in compliance with the License. and you can't re-distribute this file without a prior notice
For license details, visit www.multiset.ai.
Redistribution in source or binary forms must retain this notice.
*/

import SwiftUI
import ARKit
import RealityKit
import Combine
import MultiSetSDK

/// AR view for Object Tracking mode
struct ARObjectTrackingView: View {
    // MARK: - Properties

    @ObservedObject var sdkDelegate: MultiSetSDKDelegate

    @Environment(\.dismiss) private var dismiss

    // UI State
    @State private var showCloseConfirmation = false
    @State private var showToast = false
    @State private var toastMessage = ""
    @State private var toastSuccess = true
    @State private var showFailureAlert = false
    @State private var failureAlertMessage = ""
    @State private var isTrackingNormal = false
    @State private var hasTrackedObject = false
    @State private var isObjectTrackingActive = false
    @State private var isShowingOverlay = false
    @State private var trackedObjectCode = ""
    @State private var autoTrackingTask: Task<Void, Never>?
    @State private var isMeshVisible = true
    @State private var hasObjectMesh = false
    @State private var isMeshLoading = false
    @State private var watermarkClearance: CGFloat = 0
    @State private var stage: LocalizationStage = .idle
    @State private var isForegroundRun = false
    @StateObject private var runStatus = RunStatusIndicator()

    // Timer for state polling
    let stateTimer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

    // MARK: - Body

    var body: some View {
        ZStack {
            // AR View from SDK (full screen)
            MultiSetARView()
                .ignoresSafeArea()

            // For a capture the user asked for; a background re-track reports on the status card
            // alone. Under the controls, so the close button and the card stay reachable.
            if isForegroundRun || isShowingOverlay {
                if let status = FrameCaptureOverlay.captureStatus(for: stage) {
                    FrameCaptureOverlay(statusText: status, title: "Hold steady on the object", backdrop: .object)
                } else {
                    ServerWaitOverlay(statusText: stage == .uploading ? "Uploading…" : "Finding the object…")
                }
            }

            // Top controls
            VStack {
                HStack {
                    // After the object code badge, so that stays put as runs come and go.
                    HStack(spacing: 12) {
                        if !trackedObjectCode.isEmpty {
                            Text(trackedObjectCode)
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color(hex: "#00BCD4").opacity(0.8))
                                .cornerRadius(16)
                        }
                        if runStatus.state != .hidden {
                            RunStatusCard(state: runStatus.state)
                        }
                    }
                    .padding(.leading, 16)
                    .padding(.top, 16)

                    Spacer()

                    HStack(spacing: 12) {
                        if hasTrackedObject {
                            circleButton("arrow.counterclockwise", "Clear the outline and track again", action: resetTracking)
                        }
                        circleButton("xmark", "Close") { showCloseConfirmation = true }
                    }
                    .padding(.trailing, 16)
                    .padding(.top, 16)
                }

                Spacer()
            }

            // Bottom controls
            VStack {
                Spacer()

                HStack {
                    // Waits for the outline to be in the scene; offered earlier it would hide nothing.
                    if isMeshLoading {
                        MeshLoadingBar(label: "Loading the object mesh…")
                            .padding(.leading, 16)
                    } else if hasObjectMesh {
                        MeshVisibilityToggle(isOn: isMeshVisible, action: setMeshVisible)
                            .padding(.leading, 16)
                    }

                    Spacer()

                    // Track Button (right). Under a capture's overlay it is hidden; through a
                    // background re-track it stays in place, disabled.
                    if !isShowingOverlay && !isForegroundRun {
                        Button(action: startTracking) {
                            Image("capture_button")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 72, height: 72)
                        }
                        .disabled(!canTrack)
                        .opacity(canTrack ? 1.0 : 0.5)
                        .padding(.trailing, 16)
                    }
                }
                .padding(.bottom, max(24, watermarkClearance + 12))
            }
        }
        .preferredColorScheme(.dark)
        .toast(
            isPresented: $showToast,
            message: toastMessage,
            isSuccess: toastSuccess,
            bottomInset: ToastInset.aboveARControls(watermarkClearance: watermarkClearance)
        )
        .alert("Close Object Tracking", isPresented: $showCloseConfirmation) {
            Button("Yes", role: .destructive) {
                cleanup()
                dismiss()
            }
            Button("No", role: .cancel) {}
        } message: {
            Text("Would you like to close the Object Tracking scene?")
        }
        .alert("Object Tracking Failed", isPresented: $showFailureAlert) {
            Button("Retry") { startTracking() }
            Button("OK", role: .cancel) {}
        } message: {
            Text(failureAlertMessage)
        }
        .onAppear {
            // The renderer is shared by both AR screens, so each one opens with meshes shown.
            setMeshVisible(true)
            MultiSet.shared.setGizmoVisible(false)
            setupCallbacks()
            startAutoTrackingIfNeeded()
        }
        .onDisappear {
            cleanup()
            MultiSet.shared.setGizmoVisible(true)
        }
        .onReceive(stateTimer) { _ in
            isObjectTrackingActive = MultiSet.shared.isObjectTrackingActive
            isShowingOverlay = MultiSet.shared.isShowingObjectTrackingOverlay
            hasTrackedObject = MultiSet.shared.hasTrackedObject
            hasObjectMesh = MultiSet.shared.hasObjectMesh
            isMeshLoading = MultiSet.shared.isObjectMeshLoading
            watermarkClearance = MultiSet.shared.watermarkClearance
            if isShowingOverlay && stage == .idle {
                runStatus.keepOpen()
            }
        }
    }

    private var canTrack: Bool {
        isTrackingNormal && !isObjectTrackingActive
    }

    // MARK: - Setup

    private func setupCallbacks() {
        sdkDelegate.onObjectTrackingStageChanged = { newStage, isBackground in
            stage = newStage
            isForegroundRun = newStage != .idle && !isBackground
            isShowingOverlay = MultiSet.shared.isShowingObjectTrackingOverlay
            runStatus.receive(RunStatusState(newStage))
        }

        sdkDelegate.onObjectTrackingSuccess = { objectCode, confidence in
            runStatus.receive(.succeeded)
            trackedObjectCode = objectCode
            hasTrackedObject = true
            if MultiSet.shared.config?.showAlerts == true {
                showToastMessage("Object tracked", success: true)
            }
        }

        sdkDelegate.onObjectTrackingFailure = { error in
            runStatus.receive(.failed)
            if MultiSet.shared.config?.showAlerts == true {
                failureAlertMessage = userFriendlyTrackingMessage(for: error)
                showFailureAlert = true
            }
        }

        sdkDelegate.onTrackingChanged = { state in
            isTrackingNormal = (state == .tracking)
        }

        sdkDelegate.onObjectMeshLoaded = { _ in }
    }

    private func startAutoTrackingIfNeeded() {
        guard MultiSet.shared.config?.autoObjectTracking == true else { return }
        guard MultiSet.shared.isAuthenticated else { return }
        guard MultiSet.shared.config?.objectCodes.isEmpty == false else { return }

        // Poll for AR tracking readiness 
        autoTrackingTask = Task {
            // Initial delay for AR session startup
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2s

            // Wait for AR tracking to be ready, polling every 0.5s up to 30s
            let maxWait: Double = 30.0
            var elapsed: Double = 0.0
            while !isTrackingNormal {
                guard !Task.isCancelled else { return }
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s
                elapsed += 0.5
                if elapsed >= maxWait {
                    return
                }
            }

            guard !Task.isCancelled else { return }

            await MainActor.run {
                if !MultiSet.shared.isObjectTrackingActive {
                    MultiSet.shared.startObjectTracking()
                }
            }
        }
    }

    // MARK: - Actions

    private func startTracking() {
        MultiSet.shared.startObjectTracking()
    }

    private func resetTracking() {
        autoTrackingTask?.cancel()
        autoTrackingTask = nil
        MultiSet.shared.stopObjectTracking()
        MultiSet.shared.clearObjectMeshes()
        hasTrackedObject = false
        trackedObjectCode = ""
        showToastMessage("Tracking reset", success: true)

        startAutoTrackingIfNeeded()
    }

    private func setMeshVisible(_ visible: Bool) {
        isMeshVisible = visible
        MultiSet.shared.setMeshVisible(visible)
    }

    private func cleanup() {
        autoTrackingTask?.cancel()
        autoTrackingTask = nil
        MultiSet.shared.stopObjectTracking()
    }

    private func circleButton(_ symbol: String, _ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 40, height: 40)
                .background(Color(hex: "#7B2CBF"))
                .clipShape(Circle())
        }
        .accessibilityLabel(label)
    }

    private func showToastMessage(_ message: String, success: Bool) {
        toastMessage = message
        toastSuccess = success
        showToast = true
    }

    private func userFriendlyTrackingMessage(for error: String) -> String {
        let lower = error.lowercased()
        if lower.contains("object not found") {
            return "No matching object was detected. Point the camera at the object and try again."
        } else if lower.contains("low confidence") {
            return "Object tracking confidence is too low. Try a different angle or move closer."
        } else if lower.contains("api error") || lower.contains("http") {
            return "Unable to reach the server. Please check your internet connection and try again."
        }
        return error
    }
}

#if DEBUG
struct ARObjectTrackingView_Previews: PreviewProvider {
    static var previews: some View {
        ARObjectTrackingView(sdkDelegate: MultiSetSDKDelegate())
    }
}
#endif
