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
    @State private var showMapMissingAlert = false
    @State private var showObjectCodeMissingAlert = false
    @State private var showToast = false
    @State private var toastMessage = ""
    @State private var toastSuccess = true
    @State private var showSettings = false
    @State private var showMapping = false
    @State private var navigateToDrafts = false
    @State private var showMappingUnsupported = false
    @State private var draftCount = 0
    @State private var captureKind = MappingSupport.captureKinds.first ?? .lidar

    @State private var selectedMode: LocalizationMode = .singleFrame

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

                        // ── Mapping Card ──
                        VStack(spacing: 16) {
                            HStack {
                                Text("Mapping")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(Color(hex: "#D97706"))

                                Spacer()

                                if draftCount > 0 {
                                    Text("\(draftCount) draft\(draftCount == 1 ? "" : "s")")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.secondary)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 4)
                                        .background(Color.gray.opacity(0.15))
                                        .cornerRadius(10)
                                }
                            }

                            Text("Scan a space to build a new VPS map. Uploading needs the SDK to be authenticated.")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            // Only a device with LiDAR has a choice; without it the scan is Posed RGB.
                            if MappingSupport.captureKinds.count > 1 {
                                Picker("Scan with", selection: $captureKind) {
                                    ForEach(MappingSupport.captureKinds, id: \.self) { kind in
                                        Text(kind.title).tag(kind)
                                    }
                                }
                                .pickerStyle(.segmented)
                            }

                            if !MappingSupport.captureKinds.isEmpty {
                                Text("\(captureKind.title): \(captureKind.summary)")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }

                            Button(action: openMapping) {
                                Text("Create Map")
                                    .font(.system(size: 16, weight: .semibold))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 48)
                                    .background(MappingSupport.supports(captureKind) ? Color(hex: "#D97706") : Color.gray.opacity(0.4))
                                    .foregroundColor(.white)
                                    .cornerRadius(24)
                            }

                            Button {
                                navigateToDrafts = true
                            } label: {
                                Text("Draft Maps")
                                    .font(.system(size: 16, weight: .semibold))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 48)
                                    .foregroundColor(Color(hex: "#D97706"))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 24)
                                            .stroke(Color(hex: "#D97706"), lineWidth: 1.5)
                                    )
                            }
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
                        // Its own cover, not chained beside Settings': two presentations on one view clash.
                        .fullScreenCover(isPresented: $showMapping, onDismiss: refreshDraftCount) {
                            MappingFlowView(kind: captureKind) { showMapping = false }
                        }

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
            .navigationDestination(isPresented: $navigateToDrafts) {
                DraftMapsView()
            }
            .navigationDestination(isPresented: $navigateToObjectTracking) {
                ARObjectTrackingView(
                    sdkDelegate: sdkDelegate
                )
                .navigationBarBackButtonHidden(true)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.primary)
                    }
                    .accessibilityLabel("Configuration")
                }
            }
            .fullScreenCover(isPresented: $showSettings) {
                SettingsView(isMultiFrame: selectedMode == .multiFrame) { message in
                    showToast(message: message, success: true)
                }
            }
            .toast(isPresented: $showToast, message: toastMessage, isSuccess: toastSuccess)
            .alert(MappingSupport.unsupportedTitle, isPresented: $showMappingUnsupported) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(MappingSupport.unsupportedMessage)
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
                checkAndAutoInitialize()
                refreshDraftCount()
            }
            .onReceive(NotificationCenter.default.publisher(for: .multiSetMappingDraftsDidChange)) { _ in
                refreshDraftCount()
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

    private func openMapping() {
        guard MappingSupport.supports(captureKind) else {
            showMappingUnsupported = true
            return
        }
        showMapping = true
    }

    private func refreshDraftCount() {
        draftCount = MultiSet.shared.mapping.drafts().count
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

#if DEBUG
struct LandingView_Previews: PreviewProvider {
    static var previews: some View {
        LandingView()
    }
}
#endif
