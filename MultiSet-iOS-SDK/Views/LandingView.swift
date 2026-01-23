/*
Copyright (c) 2026 MultiSet AI. All rights reserved.
Licensed under the MultiSet License. You may not use this file except in compliance with the License. and you can't re-distribute this file without a prior notice
For license details, visit www.multiset.ai.
Redistribution in source or binary forms must retain this notice.
*/

import SwiftUI
import MultiSetSDK

/// Landing page view matching Android's MainActivity
/// Displays app info, map code, authentication controls, and navigation to AR view
struct LandingView: View {
    @StateObject private var sdkDelegate = MultiSetSDKDelegate()
    @State private var navigateToAR = false
    @State private var showConfigAlert = false
    @State private var showToast = false
    @State private var toastMessage = ""
    @State private var toastSuccess = true

    // Localization mode selection
    @State private var selectedMode: LocalizationMode = .multiFrame

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color(UIColor.systemBackground)
                    .ignoresSafeArea()

                VStack(spacing: 16) {
                    Spacer()
                        .frame(height: 20)

                    // Logo
                    Image("sdk_logo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 120, height: 80)

                    // Title
                    Text("MultiSet VPS Demo")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(Color(hex: "#7B2CBF"))

                    // Map Code Display
                    Text(mapCodeDisplayText)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)

                    // Status Text
                    Text(sdkDelegate.statusText)
                        .font(.system(size: 16))
                        .foregroundColor(Color(hex: "#7B2CBF"))
                        .padding(.vertical, 12)

                    // Localization Mode Picker
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Localization Mode")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)

                        Picker("Mode", selection: $selectedMode) {
                            ForEach(LocalizationMode.allCases) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }
                    .padding(.horizontal, 16)

                    Spacer()
                        .frame(height: 20)

                    // Auth Button
                    Button(action: initializeSDK) {
                        Text(sdkDelegate.isAuthenticated ? "Authenticated" : "Auth")
                            .font(.system(size: 18, weight: .medium))
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(sdkDelegate.isAuthenticated ? Color.gray : Color(hex: "#7B2CBF"))
                            .foregroundColor(.white)
                            .cornerRadius(28)
                    }
                    .disabled(sdkDelegate.isAuthenticated || sdkDelegate.isAuthenticating)
                    .padding(.horizontal, 16)

                    // Localize Button
                    Button(action: openARView) {
                        Text("Localize")
                            .font(.system(size: 18, weight: .medium))
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(sdkDelegate.isAuthenticated ? Color(hex: "#7B2CBF") : Color.gray)
                            .foregroundColor(.white)
                            .cornerRadius(28)
                    }
                    .disabled(!sdkDelegate.isAuthenticated)
                    .padding(.horizontal, 16)

                    Spacer()

                    // Instructions Text
                    Button(action: openCredentialsURL) {
                        Text("To get credentials visit developer.multiset.ai/credentials")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .underline()
                    }
                    .padding(.bottom, 32)
                }
                .padding()
            }
            .navigationDestination(isPresented: $navigateToAR) {
                ARLocalizationView(
                    sdkDelegate: sdkDelegate,
                    localizationMode: selectedMode
                )
                .navigationBarBackButtonHidden(true)
            }
            .toast(isPresented: $showToast, message: toastMessage, isSuccess: toastSuccess)
            .alert("Configuration Required", isPresented: $showConfigAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Both MAP_CODE and MAP_SET_CODE are empty. Please configure at least one in the SDKConfig file.")
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
        if !SDKConfig.hasMapConfiguration() {
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

        // Build config from SDKConfig (contains all user-customizable settings)
        var config = SDKConfig.buildConfig()
        config.localizationMode = selectedMode  // Override with UI selection

        // Initialize SDK
        MultiSet.shared.initialize(config: config, callback: sdkDelegate)
    }

    private func openARView() {
        // Validate map configuration
        switch SDKConfig.getActiveMapType() {
        case .map:
            guard !SDKConfig.mapCode.isEmpty else {
                showToast(message: "Please enter mapCode in SDKConfig file", success: false)
                return
            }
        case .mapSet:
            guard !SDKConfig.mapSetCode.isEmpty else {
                showToast(message: "Please enter mapSetCode in SDKConfig file", success: false)
                return
            }
        }

        // Update localization mode before navigating
        MultiSet.shared.setLocalizationMode(selectedMode)

        navigateToAR = true
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
