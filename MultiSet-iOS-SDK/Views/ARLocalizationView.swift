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
    @State private var isCapturingFrames = false
    @State private var hasMapMesh = false
    @State private var watermarkClearance: CGFloat = 0

    // Timer for state polling
    let stateTimer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

    // MARK: - Body

    var body: some View {
        ZStack {
            // AR View from SDK (full screen)
            MultiSetARView()
                .ignoresSafeArea()

            // Top controls
            VStack {
                HStack {
                    // GPS Indicator (left)
                    if MultiSet.shared.config?.passGeoPose == true {
                        GpsIndicator(isActive: false) // GPS state managed by SDK
                            .padding(.leading, 16)
                            .padding(.top, 16)
                    }

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
                    if hasMapMesh {
                        MeshVisibilityToggle(isOn: isMeshVisible, action: setMeshVisible)
                            .padding(.leading, 16)
                    }

                    Spacer()

                    // Localize Button (right)
                    if !isShowingOverlay && !isLocalizing {
                        Button(action: startLocalization) {
                            Image("capture_button")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 72, height: 72)
                        }
                        .disabled(!isTrackingNormal)
                        .opacity(isTrackingNormal ? 1.0 : 0.5)
                        .padding(.trailing, 24)
                    }
                }
                .padding(.bottom, max(24, watermarkClearance + 12))
            }

            // Localization Overlay (frame capture animation)
            if isCapturingFrames {
                LocalizationOverlay(
                    isCapturing: true,
                    statusText: "Capturing frames..."
                )
            }

            // API Loading Overlay (waiting for server response)
            if isShowingOverlay && !isCapturingFrames {
                APILoadingOverlay()
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
            isCapturingFrames = MultiSet.shared.isCapturingFrames
            hasMapMesh = MultiSet.shared.hasMapMesh
            watermarkClearance = MultiSet.shared.watermarkClearance
        }
    }

    // MARK: - Setup

    private func setupCallbacks() {
        // Setup localization result callback
        sdkDelegate.onLocalizationSuccess = { result in
            hasLocalized = true
            if MultiSet.shared.config?.showAlerts == true {
                showToastMessage("Localization successful", success: true)
            }
        }

        sdkDelegate.onLocalizationFailure = { error in
            if MultiSet.shared.config?.showAlerts == true {
                failureAlertMessage = userFriendlyMessage(for: error)
                showFailureAlert = true
            }
        }

        // The server found a pose, so the request itself succeeded — but the SDK
        // discarded it, and nothing in the scene moved. Two messages, in that order:
        // the toast reports what came back, the alert reports what was done with it.
        sdkDelegate.onLocalizationFalsePositive = { info in
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

    /// Explains the discard in the terms a tester needs: how far off the returned pose
    /// was, that the scene was deliberately left alone, and what to do next.
    private func falsePositiveText(for info: FalsePositiveInfo) -> String {
        // Suspected aliasing is a different problem and needs a different instruction.
        // The space genuinely looks the same from two places, so moving and asking again
        // returns the same wrong answer with more confidence behind it. Send the user
        // straight to the reset button instead of to another lap of the building.
        if info.rejection == .suspectedAliasing {
            return [
                "This part of the space looks the same as another part of the map, and the server keeps matching the wrong one.",
                String(
                    format: "%d viewpoints agreed on a pose %.1f m from where your device says the map is, but not strongly enough to overrule it.",
                    info.challengerSupport, info.jumpMeters
                ),
                "Localizing again will not help here. Tap the reset button at the top if the map looks misplaced, or move to a visibly different area first."
            ].joined(separator: "\n\n")
        }

        // Name the limit that was actually missed. Distance and heading are independent
        // checks with independent tolerances, so quoting the distance against the
        // distance limit alone contradicts itself whenever heading was the disqualifier
        // — "0.5 m ... (limit 3.7 m), so the response was discarded".
        let limitLine: String
        switch info.disagreement {
        case .distance:
            limitLine = String(
                format: "Its pose sits %.1f m from where your device's own motion says the map should be, past the %.1f m allowed — so it was discarded and the map was left where it is.",
                info.jumpMeters, info.thresholdMeters
            )
        case .heading:
            limitLine = String(
                format: "Its pose is turned %.0f degrees from where your device's own motion says the map should be, past the %.0f degrees allowed — so it was discarded and the map was left where it is. The %.1f m position was within tolerance.",
                info.yawDeltaDeg, info.thresholdDegrees, info.jumpMeters
            )
        case .both, .none:
            limitLine = String(
                format: "Its pose sits %.1f m and %.0f degrees from where your device's own motion says the map should be, past the %.1f m and %.0f degrees allowed — so it was discarded and the map was left where it is.",
                info.jumpMeters, info.yawDeltaDeg, info.thresholdMeters, info.thresholdDegrees
            )
        }

        var lines = [
            "The server matched your camera image to a different part of the space.",
            limitLine
        ]

        // Only quote the viewpoint tally when it was the disqualifier. On `.anchorHeldVote`
        // the challenger had every viewpoint it needed and still lost on a tie, so
        // "1 of the 1 viewpoints it would need" reads as the bar being met and the pose
        // refused anyway.
        switch info.cause {
        case .insufficientViewpoints:
            lines.append(String(
                format: "It had %d of the %d separate viewpoints it would need to move the map.",
                info.challengerSupport, info.requiredSupport
            ))
        case .anchorHeldVote:
            lines.append("Nothing else has agreed with it yet, so the anchor already in place kept the scene. One more fix from a few steps away would settle it either way.")
        case .inlierMargin, .none:
            break
        }

        if info.consecutiveCount > 1 {
            lines.append("Discarded \(info.consecutiveCount) responses in a row.")
        }

        lines.append("Move a few steps, point at a well-lit, distinctive area and localize again.")

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
