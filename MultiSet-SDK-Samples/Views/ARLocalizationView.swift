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
import simd
import MultiSetSDK

/// AR Localization View using MultiSetSDK framework
struct ARLocalizationView: View {
    // MARK: - Properties

    @ObservedObject var sdkDelegate: MultiSetSDKDelegate
    let localizationMode: LocalizationMode

    @Environment(\.dismiss) private var dismiss

    // UI State
    @State private var showCloseConfirmation = false
    @State private var showToast = false
    @State private var toastMessage = ""
    @State private var toastSuccess = true
    @State private var showFailureAlert = false
    @State private var failureAlertMessage = ""
    @State private var showFalsePositiveAlert = false
    @State private var falsePositiveMessage = ""
    @State private var isTrackingNormal = false
    @State private var hasLocalized = false
    @State private var isMeshVisible = true

    // SDK State (polled)
    @State private var isLocalizing = false
    @State private var isShowingOverlay = false
    @State private var hasMapMesh = false
    @State private var isMeshLoading = false
    @State private var watermarkClearance: CGFloat = 0

    // SDK State (from callbacks)
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

            // Under the controls, so the close button and the status card stay reachable.
            if isForegroundRun || isShowingOverlay {
                if let status = FrameCaptureOverlay.captureStatus(for: stage) {
                    FrameCaptureOverlay(statusText: status)
                } else {
                    ServerWaitOverlay(statusText: stage == .uploading ? "Uploading…" : "Matching against the map…")
                }
            }

            // Top controls
            VStack {
                HStack {
                    // After the GPS indicator, so that stays put as runs come and go.
                    HStack(spacing: 12) {
                        if MultiSet.shared.config?.passGeoPose == true {
                            GpsIndicator(isActive: false) // GPS state managed by SDK
                        }
                        if runStatus.state != .hidden {
                            RunStatusCard(state: runStatus.state)
                        }
                    }
                    .padding(.leading, 16)
                    .padding(.top, 16)

                    Spacer()

                    HStack(spacing: 12) {
                        if hasLocalized {
                            circleButton("arrow.counterclockwise", "Reset the session and start over", action: resetWorldOrigin)
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
                    // Waits for the mesh to be in the scene; offered earlier it would hide nothing.
                    if isMeshLoading {
                        MeshLoadingBar(label: "Loading the map mesh…")
                            .padding(.leading, 16)
                    } else if hasMapMesh {
                        MeshVisibilityToggle(isOn: isMeshVisible, action: setMeshVisible)
                            .padding(.leading, 16)
                    }

                    Spacer()

                    // Localize Button (right). Under a run's overlay it is hidden; through a
                    // background run it stays in place, disabled.
                    if !isShowingOverlay && !isForegroundRun {
                        Button(action: startLocalization) {
                            Image("capture_button")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 72, height: 72)
                        }
                        .disabled(!canLocalize)
                        .opacity(canLocalize ? 1.0 : 0.5)
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
        .alert("Close Localization", isPresented: $showCloseConfirmation) {
            Button("Yes", role: .destructive) {
                cleanup()
                dismiss()
            }
            Button("No", role: .cancel) {}
        } message: {
            Text("Would you like to close the Localization scene?")
        }
        .alert("Localization Failed", isPresented: $showFailureAlert) {
            Button("Retry") { startLocalization() }
            Button("OK", role: .cancel) {}
        } message: {
            Text(failureAlertMessage)
        }
        .alert("False Positive Detected", isPresented: $showFalsePositiveAlert) {
            Button("Localize Again") { startLocalization() }
            // The anchor being defended can itself be the wrong one — a first fix is
            // bootstrapped unchecked — in which case localizing again just earns another
            // rejection. Starting over is the only exit, so offer it from the alert.
            Button("Reset & Start Over") { resetWorldOrigin() }
            Button("Dismiss", role: .cancel) {}
        } message: {
            Text(falsePositiveMessage)
        }
        .onAppear {
            // The renderer is shared by both AR screens, so each one opens with meshes shown.
            setMeshVisible(true)
            setupCallbacks()
            startAutoLocalizationIfNeeded()
        }
        .onDisappear {
            cleanup()
        }
        .onReceive(stateTimer) { _ in
            // Poll SDK state for UI updates
            isLocalizing = MultiSet.shared.isLocalizing
            isShowingOverlay = MultiSet.shared.isShowingOverlay
            hasMapMesh = MultiSet.shared.hasMapMesh
            isMeshLoading = MultiSet.shared.isMapMeshLoading
            watermarkClearance = MultiSet.shared.watermarkClearance
            if isShowingOverlay && stage == .idle {
                runStatus.keepOpen()
            }
        }
    }

    private var canLocalize: Bool {
        isTrackingNormal && !isLocalizing
    }

    // MARK: - Setup

    private func setupCallbacks() {
        // Setup localization result callback
        sdkDelegate.onLocalizationStageChanged = { newStage, isBackground in
            stage = newStage
            isForegroundRun = newStage != .idle && !isBackground
            isShowingOverlay = MultiSet.shared.isShowingOverlay
            runStatus.receive(RunStatusState(newStage))
        }

        sdkDelegate.onLocalizationSuccess = { result in
            hasLocalized = true
            runStatus.receive(.succeeded)
            if MultiSet.shared.config?.showAlerts == true {
                showToastMessage("Localization successful", success: true)
            }
        }

        sdkDelegate.onLocalizationFailure = { error in
            runStatus.receive(.failed)
            if MultiSet.shared.config?.showAlerts == true {
                failureAlertMessage = userFriendlyMessage(for: error)
                showFailureAlert = true
            }
        }

        // The server found a pose, so the request itself succeeded — but the SDK
        // discarded it, and nothing in the scene moved. Two messages, in that order:
        // the toast reports what came back, the alert reports what was done with it.
        sdkDelegate.onLocalizationFalsePositive = { info in
            runStatus.receive(.failed)
            guard MultiSet.shared.config?.showAlerts == true else { return }
            showToastMessage("Localization response received", success: true)
            falsePositiveMessage = falsePositiveText(for: info)
            showFalsePositiveAlert = true
        }

        // The anchor moved under content already placed against the old frame. The
        // gizmo and mesh follow it automatically; anything the host placed does not.
        sdkDelegate.onLocalizationCorrected = { from, to, trust in
            guard MultiSet.shared.config?.showAlerts == true else { return }
            showToastMessage(
                String(format: "Map re-anchored %.1f m (%@)", simd_distance(from.position, to.position), String(describing: trust)),
                success: true
            )
        }

        sdkDelegate.onTrackingChanged = { state in
            isTrackingNormal = (state == .tracking)
        }

        sdkDelegate.onMeshLoaded = { mapCode in
            print("ARLocalizationView >> Mesh loaded for map: \(mapCode)")
        }

        // Start GPS if needed
        if MultiSet.shared.config?.passGeoPose == true {
            MultiSet.shared.startGpsUpdates()
        }
    }

    private func startAutoLocalizationIfNeeded() {
        guard MultiSet.shared.config?.autoLocalize == true else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            if !MultiSet.shared.isLocalizing {
                MultiSet.shared.localize()
            }
        }
    }

    // MARK: - Actions

    private func startLocalization() {
        MultiSet.shared.localize()
    }

    private func resetWorldOrigin() {
        MultiSet.shared.resetSession()
        hasLocalized = false
        showToastMessage("World origin reset", success: true)

        // Restart auto-localization if enabled
        startAutoLocalizationIfNeeded()
    }

    private func setMeshVisible(_ visible: Bool) {
        isMeshVisible = visible
        MultiSet.shared.setMeshVisible(visible)
    }

    private func cleanup() {
        MultiSet.shared.stopLocalization()
        MultiSet.shared.stopGpsUpdates()
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

    /// What happened and what to do next. The numbers behind the discard stay in the SDK's
    /// log (`MultiSetSDK >> Discarded …`), where a tester can read them.
    private func falsePositiveText(for info: FalsePositiveInfo) -> String {
        // Suspected aliasing is a different problem and needs a different instruction.
        // The space genuinely looks the same from two places, so moving and asking again
        // returns the same wrong answer with more confidence behind it. Send the user
        // straight to the reset button instead of to another lap of the building.
        if info.rejection == .suspectedAliasing {
            return [
                "This part of the space looks the same as another part of the map, and the server keeps matching the wrong one.",
                "Localizing again will not help here. Tap the reset button at the top if the map looks misplaced, or move to a visibly different area first."
            ].joined(separator: "\n\n")
        }

        var lines = [
            "The server matched your camera image to a different part of the space.",
            "Move a few steps, point at a well-lit, distinctive area and localize again."
        ]

        // Nothing overrules an anchor the device still vouches for on its own, so after a
        // run of rejections the user needs to know how to start over — the anchor itself
        // may be the wrong one.
        if info.consecutiveCount >= 3 {
            lines.append("If the map itself looks misplaced, tap the reset button at the top — the next response will be trusted as the new anchor.")
        }

        return lines.joined(separator: "\n\n")
    }

    private func userFriendlyMessage(for error: String) -> String {
        let lower = error.lowercased()
        if lower.contains("pose not found") {
            return "Could not determine your position. Try pointing at a well-lit, textured area and try again."
        } else if lower.contains("low confidence") {
            return "Localization confidence is too low. Move to a different angle and try again."
        } else if lower.contains("no frames captured") {
            return "No camera frames were captured. Ensure the camera is not obstructed."
        } else if lower.contains("api error") || lower.contains("http") {
            return "Unable to reach the server. Please check your internet connection and try again."
        } else if lower.contains("missing pose data") {
            return "Received an incomplete response from the server. Please try again."
        }
        return error
    }
}

#if DEBUG
struct ARLocalizationView_Previews: PreviewProvider {
    static var previews: some View {
        ARLocalizationView(
            sdkDelegate: MultiSetSDKDelegate(),
            localizationMode: .singleFrame
        )
    }
}
#endif
