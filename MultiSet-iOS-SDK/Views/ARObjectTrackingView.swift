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
    @State private var trackedObjectCode = ""
    @State private var autoTrackingTask: Task<Void, Never>?

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
                    // Object code badge (left)
                    if !trackedObjectCode.isEmpty {
                        Text(trackedObjectCode)
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color(hex: "#00BCD4").opacity(0.8))
                            .cornerRadius(16)
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
                    if hasTrackedObject {
                        Button(action: resetTracking) {
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

                    // Track Button (right)
                    if !isObjectTrackingActive {
                        Button(action: startTracking) {
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

            // Loading overlay when tracking API is in progress
            if isObjectTrackingActive {
                APILoadingOverlay(statusText: "Tracking object...")
            }
        }
        .preferredColorScheme(.dark)
        .toast(isPresented: $showToast, message: toastMessage, isSuccess: toastSuccess)
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
            hasTrackedObject = MultiSet.shared.hasTrackedObject
        }
    }

    // MARK: - Setup

    private func setupCallbacks() {
        sdkDelegate.onObjectTrackingSuccess = { objectCode, confidence in
            trackedObjectCode = objectCode
            hasTrackedObject = true
            if MultiSet.shared.config?.showAlerts == true {
                showToastMessage("Object tracked: \(objectCode)", success: true)
            }
        }

        sdkDelegate.onObjectTrackingFailure = { error in
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

        // Poll for AR tracking readiness (matches Unity's StartAutoTracking coroutine)
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

    private func cleanup() {
        autoTrackingTask?.cancel()
        autoTrackingTask = nil
        MultiSet.shared.stopObjectTracking()
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
