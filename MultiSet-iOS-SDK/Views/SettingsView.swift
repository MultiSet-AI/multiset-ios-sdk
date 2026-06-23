/*
Copyright (c) 2026 MultiSet AI. All rights reserved.
Licensed under the MultiSet License. You may not use this file except in compliance with the License. and you can't re-distribute this file without a prior notice
For license details, visit www.multiset.ai.
Redistribution in source or binary forms must retain this notice.
*/

import SwiftUI
import MultiSetSDK

/// Full-screen "Configuration" sheet, launched from the landing page.
///
/// Lets the user adjust the behavioral parameters of `ConfigStore` (the demo
/// app's localization & object-tracking settings) then Save (persisted to
/// `UserDefaults`) or Reset to defaults. `SDKConfig.buildConfig()` reads these
/// values when localization / tracking starts, so saved values take effect on
/// the next run.
///
/// Edits are made on an isolated draft copy and only committed to the shared
/// store on Save, so closing with the X discards changes — mirroring the
/// Android sample app's settings window.
struct SettingsView: View {

    /// Whether the current localization mode is multi-frame. The "Number of
    /// Frames" row only applies to multi-frame localization.
    let isMultiFrame: Bool

    /// Called after a successful Save (the parent shows a confirmation toast).
    var onSaved: (String) -> Void

    @Environment(\.dismiss) private var dismiss

    /// Independent draft seeded from the shared store; committed on Save.
    @StateObject private var draft = ConfigStore.shared.makeDraft()

    @State private var showResetToast = false

    private let accent = Color(hex: "#7B2CBF")

    var body: some View {
        NavigationStack {
            Form {
                mapLocalizationSection
                objectTrackingSection
            }
            .navigationTitle("Configuration")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                    }
                    .accessibilityLabel("Close")
                }
            }
            .safeAreaInset(edge: .bottom) { footer }
            .toast(isPresented: $showResetToast, message: "Reset to defaults", isSuccess: true)
        }
        .tint(accent)
    }

    // MARK: - Sections

    private var mapLocalizationSection: some View {
        Section("Map Localization") {
            Toggle("Auto Localize", isOn: $draft.autoLocalize)
            Toggle("Background Localization", isOn: $draft.backgroundLocalization)
            sliderRow(
                "Background Interval",
                value: $draft.bgLocalizationIntervalSeconds,
                range: 15...180, step: 1,
                display: "\(Int(draft.bgLocalizationIntervalSeconds)) s"
            )
            Toggle("Relocalization (on tracking loss)", isOn: $draft.relocalization)
            Toggle("First Localization Until Success", isOn: $draft.firstLocalizationUntilSuccess)

            if isMultiFrame {
                sliderRow(
                    "Number of Frames",
                    value: intBinding($draft.numberOfFrames),
                    range: 4...6, step: 1,
                    display: "\(draft.numberOfFrames)"
                )
            }

            Toggle("Confidence Check", isOn: $draft.confidenceCheck)
            sliderRow(
                "Confidence Threshold",
                value: $draft.confidenceThreshold,
                range: 0.2...0.8, step: 0.05,
                display: String(format: "%.2f", draft.confidenceThreshold)
            )

            Toggle("Enable Geo Hint (GPS)", isOn: $draft.enableGeoHint)
            Toggle("Include Geo Coordinates In Response", isOn: $draft.includeGeoCoordinatesInResponse)
            sliderRow(
                "Hint Radius",
                value: intBinding($draft.hintRadius),
                range: 1...100, step: 1,
                display: "\(draft.hintRadius) m"
            )
            Toggle("Use 2D Filtering", isOn: $draft.use2DFiltering)

            textRow("Hint Map Codes (comma separated)", placeholder: "MAP_A, MAP_B", text: $draft.hintMapCodes)
            textRow("Hint Position (x,y,z)", placeholder: "12.5,0.0,-3.2", text: $draft.hintPosition)
            textRow("Hint Floor Height (floor,ceiling)", placeholder: "0,5", text: $draft.hintFloorHeight)
        }
    }

    private var objectTrackingSection: some View {
        Section("Object Tracking") {
            Toggle("Auto Tracking", isOn: $draft.autoTracking)
            Toggle("Background Tracking", isOn: $draft.backgroundTracking)
            sliderRow(
                "Background Duration",
                value: $draft.bgTrackingDurationSeconds,
                range: 5...30, step: 1,
                display: "\(Int(draft.bgTrackingDurationSeconds)) s"
            )
            Toggle("Restart Tracking (on tracking loss)", isOn: $draft.restartTracking)
            Toggle("First Tracking Until Success", isOn: $draft.firstTrackingUntilSuccess)
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 12) {
            Button(action: onReset) {
                Text("Reset")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .foregroundColor(accent)
                    .background(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(accent, lineWidth: 1.5)
                    )
            }

            Button(action: onSave) {
                Text("Save")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .foregroundColor(.white)
                    .background(RoundedRectangle(cornerRadius: 24).fill(accent))
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(.bar)
    }

    // MARK: - Actions

    private func onSave() {
        draft.validate()
        ConfigStore.shared.apply(from: draft)
        ConfigStore.shared.save()

        // Push the updated settings into the already-initialized SDK so they
        // take effect on the next localization / tracking run (without this,
        // changes would only apply after an app relaunch). Preserve the SDK's
        // current localization mode, which the Settings screen doesn't edit.
        if MultiSet.shared.isInitialized {
            var newConfig = SDKConfig.buildConfig()
            if let currentMode = MultiSet.shared.config?.localizationMode {
                newConfig.localizationMode = currentMode
            }
            MultiSet.shared.updateConfig(newConfig)
        }

        dismiss()
        onSaved("Settings saved")
    }

    private func onReset() {
        draft.resetToDefaults()
        ConfigStore.shared.resetToDefaults()
        ConfigStore.shared.clearPersisted()

        // Apply the restored defaults to the running SDK immediately, mirroring
        // onSave(), so a reset also takes effect on the next run.
        if MultiSet.shared.isInitialized {
            var newConfig = SDKConfig.buildConfig()
            if let currentMode = MultiSet.shared.config?.localizationMode {
                newConfig.localizationMode = currentMode
            }
            MultiSet.shared.updateConfig(newConfig)
        }

        showResetToast = true
    }

    // MARK: - Row builders

    /// A labelled slider whose current value is shown to the right of the label.
    /// The slider physically constrains input to `range` in `step` increments, so
    /// out-of-range values are impossible.
    private func sliderRow(
        _ label: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double,
        display: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label)
                Spacer()
                Text(display)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(accent)
            }
            Slider(value: value, in: range, step: step)
        }
        .padding(.vertical, 2)
    }

    private func textRow(_ label: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
            TextField(placeholder, text: text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .font(.system(size: 15, design: .monospaced))
        }
        .padding(.vertical, 2)
    }

    /// Bridges an `Int` binding to the `Double` a `Slider` requires.
    private func intBinding(_ source: Binding<Int>) -> Binding<Double> {
        Binding<Double>(
            get: { Double(source.wrappedValue) },
            set: { source.wrappedValue = Int($0.rounded()) }
        )
    }
}

#if DEBUG
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            SettingsView(isMultiFrame: true, onSaved: { _ in })
            SettingsView(isMultiFrame: false, onSaved: { _ in })
                .preferredColorScheme(.dark)
        }
    }
}
#endif
