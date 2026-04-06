/*
Copyright (c) 2026 MultiSet AI. All rights reserved.
Licensed under the MultiSet License. You may not use this file except in compliance with the License. and you can't re-distribute this file without a prior notice
For license details, visit www.multiset.ai.
Redistribution in source or binary forms must retain this notice.
*/

import SwiftUI
import MultiSetSDK

/// Landing page — authentication, localization mode selection, and object tracking
struct LandingView: View {
    @StateObject private var sdkDelegate = MultiSetSDKDelegate()
    @State private var navigateToAR = false
    @State private var navigateToObjectTracking = false
    @State private var showConfigAlert = false
    @State private var showMapMissingAlert = false
    @State private var showObjectCodeMissingAlert = false
    @State private var showToast = false
    @State private var toastMessage = ""
    @State private var toastSuccess = true

    // Localization mode selection
    @State private var selectedMode: LocalizationMode = .multiFrame

    var body: some View {
        NavigationStack {
            ZStack {
                Color(UIColor.systemBackground)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {

                        // ── Header ──
                        VStack(spacing: 8) {
                            Image("sdk_logo")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 100, height: 66)

                            Text("MultiSet VPS Samples")
                                .font(.system(size: 26, weight: .bold))
                                .foregroundColor(Color(hex: "#7B2CBF"))
                        }
                        .padding(.top, 24)

                        // ── Auth Button ──
                        Button(action: initializeSDK) {
                            HStack(spacing: 10) {
                                Image(systemName: sdkDelegate.isAuthenticated ? "checkmark.shield.fill" : "lock.fill")
                                    .font(.system(size: 16))
                                Text(sdkDelegate.isAuthenticated ? "Authenticated" : sdkDelegate.isAuthenticating ? "Authenticating..." : "Authenticate")
                                    .font(.system(size: 17, weight: .semibold))
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(sdkDelegate.isAuthenticated ? Color(hex: "#4CAF50") : Color(hex: "#7B2CBF"))
                            .foregroundColor(.white)
                            .cornerRadius(26)
                        }
                        .disabled(sdkDelegate.isAuthenticated || sdkDelegate.isAuthenticating)
                        .padding(.horizontal, 20)

                        // ── Localization Card ──
                        VStack(spacing: 16) {
                            Text("Localization")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(Color(hex: "#7B2CBF"))
                                .frame(maxWidth: .infinity, alignment: .leading)

                            // Map code display
                            if SDKConfig.hasMapConfiguration() {
                                HStack(spacing: 6) {
                                    Image(systemName: "map.fill")
                                        .font(.system(size: 11))
                                        .foregroundColor(Color(hex: "#7B2CBF").opacity(0.7))
                                    Text(!SDKConfig.mapSetCode.isEmpty ? SDKConfig.mapSetCode : SDKConfig.mapCode)
                                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                                        .foregroundColor(.secondary)
                                    Spacer()
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color(hex: "#7B2CBF").opacity(0.08))
                                .cornerRadius(8)
                            } else {
                                Text("No map configured. Set mapCode or mapSetCode in SDKConfig.")
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }

                            // Mode picker
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Mode")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.secondary)

                                Picker("Mode", selection: $selectedMode) {
                                    ForEach(LocalizationMode.allCases) { mode in
                                        Text(mode.rawValue).tag(mode)
                                    }
                                }
                                .pickerStyle(SegmentedPickerStyle())
                            }

                            // Localize button
                            Button(action: openARView) {
                                Text("Start Localization")
                                    .font(.system(size: 16, weight: .semibold))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 48)
                                    .background(sdkDelegate.isAuthenticated ? Color(hex: "#7B2CBF") : Color.gray.opacity(0.4))
                                    .foregroundColor(.white)
                                    .cornerRadius(24)
                            }
                            .disabled(!sdkDelegate.isAuthenticated)
                        }
                        .padding(20)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.gray.opacity(0.25), lineWidth: 1)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(Color(UIColor.secondarySystemBackground))
                                )
                        )
                        .padding(.horizontal, 20)

                        // ── Object Tracking Card ──
                        VStack(spacing: 16) {
                            HStack {
                                Text("Object Tracking")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(Color(hex: "#00BCD4"))

                                Spacer()

                                if !SDKConfig.objectCodes.isEmpty {
                                    Text("\(SDKConfig.objectCodes.count) object\(SDKConfig.objectCodes.count == 1 ? "" : "s")")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.secondary)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 4)
                                        .background(Color.gray.opacity(0.15))
                                        .cornerRadius(10)
                                }
                            }

                            if SDKConfig.objectCodes.isEmpty {
                                Text("No object codes configured. Add codes in SDKConfig to enable tracking.")
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            } else {
                                // Object codes list
                                VStack(spacing: 6) {
                                    ForEach(SDKConfig.objectCodes, id: \.self) { code in
                                        HStack(spacing: 6) {
                                            Image(systemName: "cube.fill")
                                                .font(.system(size: 11))
                                                .foregroundColor(Color(hex: "#00BCD4").opacity(0.7))
                                            Text(code)
                                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                                .foregroundColor(.secondary)
                                            Spacer()
                                        }
                                    }
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color(hex: "#00BCD4").opacity(0.08))
                                .cornerRadius(8)
                            }

                            Button(action: openObjectTracking) {
                                Text("Start Object Tracking")
                                    .font(.system(size: 16, weight: .semibold))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 48)
                                    .background(sdkDelegate.isAuthenticated ? Color(hex: "#00BCD4") : Color.gray.opacity(0.4))
                                    .foregroundColor(.white)
                                    .cornerRadius(24)
                            }
                            .disabled(!sdkDelegate.isAuthenticated)
                        }
                        .padding(20)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.gray.opacity(0.25), lineWidth: 1)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(Color(UIColor.secondarySystemBackground))
                                )
                        )
                        .padding(.horizontal, 20)

                        Spacer(minLength: 20)

                        // ── Footer ──
                        Button(action: openCredentialsURL) {
                            Text("To get credentials visit developer.multiset.ai/credentials")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .underline()
                        }
                        .padding(.bottom, 24)
                    }
                }
            }
            .navigationDestination(isPresented: $navigateToAR) {
                ARLocalizationView(
                    sdkDelegate: sdkDelegate,
                    localizationMode: selectedMode
                )
                .navigationBarBackButtonHidden(true)
            }
            .navigationDestination(isPresented: $navigateToObjectTracking) {
                ARObjectTrackingView(
                    sdkDelegate: sdkDelegate
                )
                .navigationBarBackButtonHidden(true)
            }
            .toast(isPresented: $showToast, message: toastMessage, isSuccess: toastSuccess)
            .alert("Configuration Required", isPresented: $showConfigAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("No map codes or object codes are configured. Please update SDKConfig.")
            }
            .alert("Map Code Required", isPresented: $showMapMissingAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Please configure a mapCode or mapSetCode in SDKConfig to start localization.")
            }
            .alert("Object Codes Required", isPresented: $showObjectCodeMissingAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Please add at least one object code in SDKConfig to start object tracking.")
            }
            .onAppear {
                checkConfiguration()
                checkAndAutoInitialize()
            }
        }
    }

    // MARK: - Computed Properties

    private var mapCodeDisplayText: String {
        if SDKConfig.mapCode.isEmpty && SDKConfig.mapSetCode.isEmpty {
            return "No Map Configured"
        } else if !SDKConfig.mapCode.isEmpty {
            return "Map Code: \(SDKConfig.mapCode)"
        } else {
            return "Map Set Code: \(SDKConfig.mapSetCode)"
        }
    }

    // MARK: - Actions

    private func checkConfiguration() {
        if !SDKConfig.hasMapConfiguration() && !SDKConfig.hasObjectTrackingConfiguration() {
            showConfigAlert = true
        }
    }

    private func checkAndAutoInitialize() {
        if SDKConfig.hasCredentials() && !sdkDelegate.isAuthenticated && !MultiSet.shared.isInitialized {
            initializeSDK()
        }
    }

    private func initializeSDK() {
        guard SDKConfig.hasCredentials() else {
            showToast(message: "Please enter ClientId and ClientSecret in SDKConfig file", success: false)
            return
        }

        sdkDelegate.isAuthenticating = true
        sdkDelegate.statusText = "Authenticating..."

        var config = SDKConfig.buildConfig()
        config.localizationMode = selectedMode

        MultiSet.shared.initialize(config: config, callback: sdkDelegate)
    }

    private func openARView() {
        guard SDKConfig.hasMapConfiguration() else {
            showMapMissingAlert = true
            return
        }

        MultiSet.shared.setLocalizationMode(selectedMode)
        navigateToAR = true
    }

    private func openObjectTracking() {
        guard SDKConfig.hasObjectTrackingConfiguration() else {
            showObjectCodeMissingAlert = true
            return
        }

        if !MultiSet.shared.isInitialized {
            initializeSDK()
        }

        navigateToObjectTracking = true
    }

    private func openCredentialsURL() {
        if let url = URL(string: "https://developer.multiset.ai/credentials") {
            UIApplication.shared.open(url)
        }
    }

    private func showToast(message: String, success: Bool) {
        toastMessage = message
        toastSuccess = success
        showToast = true
    }
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

#if DEBUG
struct LandingView_Previews: PreviewProvider {
    static var previews: some View {
        LandingView()
    }
}
#endif
