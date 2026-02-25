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
    @State private var isTrackingNormal = false
    @State private var hasLocalized = false

    // SDK State (polled)
    @State private var isLocalizing = false
    @State private var isShowingOverlay = false
    @State private var isCapturingFrames = false

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

                    // Close Button (right)
                    Button(action: { showCloseConfirmation = true }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 40, height: 40)
                            .background(Color(hex: "#7B2CBF"))
                            .clipShape(Circle())
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
                    // Reset Button (left)
                    if hasLocalized {
                        Button(action: resetWorldOrigin) {
                            Text("Reset")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(Color.orange)
                                .cornerRadius(24)
                        }
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
                .padding(.bottom, 24)
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
        .toast(isPresented: $showToast, message: toastMessage, isSuccess: toastSuccess)
        .alert("Close Localization", isPresented: $showCloseConfirmation) {
            Button("Yes", role: .destructive) {
                cleanup()
                dismiss()
            }
            Button("No", role: .cancel) {}
        } message: {
            Text("Would you like to close the Localization scene?")
        }
        .onAppear {
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
                showToastMessage(error, success: false)
            }
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
        MultiSet.shared.stopLocalization()
        MultiSet.shared.clearMesh()
        hasLocalized = false
        showToastMessage("World origin reset", success: true)

        // Restart auto-localization if enabled
        startAutoLocalizationIfNeeded()
    }

    private func cleanup() {
        MultiSet.shared.stopLocalization()
        MultiSet.shared.stopGpsUpdates()
    }

    private func showToastMessage(_ message: String, success: Bool) {
        toastMessage = message
        toastSuccess = success
        showToast = true
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
