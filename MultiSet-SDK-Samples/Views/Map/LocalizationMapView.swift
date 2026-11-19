/*
Copyright (c) 2026 MultiSet AI. All rights reserved.
Licensed under the MultiSet License. You may not use this file except in compliance with the License. and you can't re-distribute this file without a prior notice
For license details, visit www.multiset.ai.
Redistribution in source or binary forms must retain this notice.
*/

import SwiftUI
import Combine
import ARKit
import MultiSetSDK

/// GeoPose Map View: a live AR view under a draggable Apple map that plots each fix's GeoPose
/// against the device GPS. Needs a geo-referenced map or MapSet.
struct LocalizationMapView: View {

    @ObservedObject var sdkDelegate: MultiSetSDKDelegate

    @Environment(\.dismiss) private var dismiss

    @StateObject private var model = MapSessionModel()
    @StateObject private var tracker = LocationTracker()

    @State private var showCloseConfirmation = false
    @State private var isTrackingNormal = false
    @State private var showFalsePositiveAlert = false
    @State private var falsePositiveMessage = ""

    /// Map sheet positions. A native `.sheet` with detents would block touches to the
    /// AR view behind it — `presentationBackgroundInteraction` is iOS 16.4 and the app
    /// targets 16.0 — so the sheet is built here instead.
    private enum SheetDetent: CaseIterable {
        case hidden, collapsed, half, expanded, full

        func height(in total: CGFloat) -> CGFloat {
            switch self {
            case .hidden: return 0
            case .collapsed: return 110
            case .half: return total * 0.5
            case .expanded: return total * 0.92
            case .full: return total
            }
        }

        /// Positions a drag can settle on. `.full` is reachable only through the
        /// full-screen button, so a drag can never accidentally bury the AR view.
        static var draggable: [SheetDetent] { [.hidden, .collapsed, .half, .expanded] }
    }

    @State private var detent: SheetDetent = .half
    /// Restored when the user leaves full screen.
    @State private var detentBeforeFullScreen: SheetDetent = .half
    @State private var mapStyle: MapStyleMode = .street
    /// Live drag offset. Deliberately `@State` and not `@GestureState`: the latter
    /// auto-resets to zero the moment the gesture ends, racing the snap animation, so
    /// the sheet visibly jumped back to its old height for a frame before animating.
    /// Clearing it inside the same `withAnimation` as the detent change removes the jump.
    @State private var dragTranslation: CGFloat = 0

    private var isFullScreen: Bool { detent == .full }

    // SDK state, polled the same way ARLocalizationView does it.
    @State private var isLocalizing = false
    @State private var isCapturingFrames = false
    @State private var watermarkClearance: CGFloat = 0
    private let stateTimer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

    var body: some View {
        GeometryReader { geometry in
            let total = geometry.size.height
            // How much of the sheet is on screen right now, drag included. The sheet
            // itself is always `total` tall; only this changes.
            let visible = min(max(detent.height(in: total) - dragTranslation, 0), total)

            ZStack(alignment: .bottom) {
                MultiSetARView()
                    .ignoresSafeArea()

                // Everything below stays in the hierarchy at all times and is hidden by
                // opacity or by a zero height. Adding and removing these branches
                // structurally — as an `if` would — tears down the MKMapView through
                // its representable in the middle of a running spring animation, which
                // both loses all map state and is a crash risk.
                VStack(spacing: 0) {
                    topBar
                    Spacer()
                    localizeButton
                        .padding(.bottom, max(visible, bottomSafeInset) + 16)
                }
                .opacity(isFullScreen ? 0 : 1)
                .allowsHitTesting(!isFullScreen)

                showMapButton
                    .opacity(detent == .hidden ? 1 : 0)
                    .allowsHitTesting(detent == .hidden)

                mapSheet(totalHeight: total, visible: visible)
                    .allowsHitTesting(visible > 0)
            }
        }
        .ignoresSafeArea(edges: .bottom)
        .preferredColorScheme(.dark)
        .alert("Close GeoPose Map View", isPresented: $showCloseConfirmation) {
            Button("Yes", role: .destructive) {
                cleanup()
                dismiss()
            }
            Button("No", role: .cancel) {}
        } message: {
            Text("Would you like to close the GeoPose Map View?")
        }
        .alert("False Positive Detected", isPresented: $showFalsePositiveAlert) {
            Button("Localize Again") { localizeNow() }
            Button("Dismiss", role: .cancel) {}
        } message: {
            Text(falsePositiveMessage)
        }
        .onAppear {
            // No mesh toggle here, so undo a hide left over from another AR screen.
            MultiSet.shared.setMeshVisible(true)
            configureForMapFlow()
            setupCallbacks()
            tracker.start()
            startAutoLocalizationIfNeeded()
        }
        .onDisappear {
            cleanup()
        }
        .onReceive(stateTimer) { _ in
            isLocalizing = MultiSet.shared.isLocalizing
            isCapturingFrames = MultiSet.shared.isCapturingFrames
            watermarkClearance = MultiSet.shared.watermarkClearance
        }
        .onChange(of: tracker.authorizationDenied) { denied in
            if denied { model.setLocationDenied() }
        }
    }

    // MARK: - AR overlays

    private var topBar: some View {
        HStack(alignment: .top) {
            Text(statusText)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Capsule().fill(model.vpsStatus.color.opacity(0.9)))

            Spacer()

            Button(action: { showCloseConfirmation = true }) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(Color(hex: "#7B2CBF"))
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }

    private var localizeButton: some View {
        HStack {
            Spacer()
            if !isLocalizing {
                Button(action: localizeNow) {
                    Image("capture_button")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 64, height: 64)
                }
                .disabled(!isTrackingNormal)
                .opacity(isTrackingNormal ? 1.0 : 0.5)
                .padding(.trailing, 24)
            }
        }
    }

    // MARK: - Map sheet

    /// The sheet is always full height and is moved with `offset`, never resized.
    ///
    /// Animating `frame(height:)` on a view backed by a `CAMetalLayer` — which MKMapView
    /// is — forces a new drawable on every animation frame. When one is destroyed while
    /// a command buffer still references it, Metal traps with
    /// "object is being destroyed while still required to be alive by the command
    /// buffer". Translating the layer costs nothing and cannot churn drawables, which is
    /// also why Apple Maps slides its sheet over a stationary map.
    private func mapSheet(totalHeight: CGFloat, visible: CGFloat) -> some View {
        VStack(spacing: 0) {
            sheetHeader(totalHeight: totalHeight)
            SessionMapView(
                model: model,
                // The part of the map hidden below the fold, so the map can keep the
                // tracked position centred in the band that is actually on screen.
                obscuredBottom: totalHeight - visible,
                bottomChrome: bottomChromeHeight,
                isFullScreen: isFullScreen,
                onToggleFullScreen: toggleFullScreen,
                style: $mapStyle
            )
        }
        .frame(height: totalHeight)
        .background(Color(UIColor.systemBackground))
        .clipShape(RoundedCorners(radius: isFullScreen ? 0 : 16, corners: [.topLeft, .topRight]))
        .shadow(radius: 8)
        .offset(y: totalHeight - visible)
    }

    /// The grab area. The drag gesture lives **here only** — attaching it to the whole
    /// sheet made it compete with the MKMapView's own pan and pinch recognizers, so a
    /// drag on the map body would arbitrarily pan the map or move the sheet.
    private func sheetHeader(totalHeight: CGFloat) -> some View {
        ZStack {
            // The capsule owns the tap. Putting `onTapGesture` on the whole header
            // alongside the drag made the two arbitrate against each other, and against
            // the chevron button inside it.
            Button(action: cycleDetent) {
                Capsule()
                    .fill(Color.secondary.opacity(0.5))
                    .frame(width: 40, height: 5)
                    .padding(12)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Resize map")

            HStack {
                TrackLegend()

                Spacer()

                Button {
                    setDetent(.hidden)
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.secondary)
                        .frame(width: 36, height: 36)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Hide map")
            }
            .padding(.leading, 14)
            .padding(.trailing, 8)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 36)
        .padding(.vertical, 4)
        .background(Color(UIColor.systemBackground))
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 8)
                .onChanged { value in
                    dragTranslation = value.translation.height
                }
                .onEnded { value in
                    snap(from: detent.height(in: totalHeight) - value.translation.height,
                         totalHeight: totalHeight)
                }
        )
        // A drag that is cancelled rather than ended never reaches `onEnded`, which
        // would leave a stale offset wedging the sheet at a height nothing resets.
        // `@GestureState` cleared itself for free; `@State` has to be told.
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onEnded { _ in
                    if dragTranslation != 0 {
                        snap(from: detent.height(in: totalHeight) - dragTranslation,
                             totalHeight: totalHeight)
                    }
                }
        )
    }

    // This screen lays out from the screen's bottom edge, so its geometry reports no bottom inset.
    private var bottomSafeInset: CGFloat {
        (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.keyWindow?.safeAreaInsets.bottom ?? 0
    }

    /// The bottom safe-area inset, plus the MultiSet watermark when the plan shows one.
    private var bottomChromeHeight: CGFloat {
        bottomSafeInset + watermarkClearance
    }

    /// Brings the map back once it has been hidden; leading, because the localize button is trailing.
    private var showMapButton: some View {
        HStack {
            Button {
                setDetent(.half)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "map.fill")
                    Text("Map")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 11)
                .background(Capsule().fill(Color(hex: "#7B2CBF")))
                .shadow(radius: 4)
            }
            .padding(.leading, 20)
            .padding(.bottom, bottomChromeHeight + 16)

            Spacer()
        }
    }

    /// Settle on whichever draggable detent the release height is closest to.
    private func snap(from height: CGFloat, totalHeight: CGFloat) {
        let nearest = SheetDetent.draggable.min {
            abs($0.height(in: totalHeight) - height) < abs($1.height(in: totalHeight) - height)
        }
        setDetent(nearest ?? .half)
    }

    private func cycleDetent() {
        switch detent {
        case .hidden: setDetent(.half)
        case .collapsed: setDetent(.half)
        case .half: setDetent(.expanded)
        case .expanded: setDetent(.collapsed)
        case .full: break
        }
    }

    private func toggleFullScreen() {
        if isFullScreen {
            setDetent(detentBeforeFullScreen)
        } else {
            detentBeforeFullScreen = detent
            setDetent(.full)
        }
    }

    /// Clears any live drag offset in the same transaction as the detent change, so the
    /// sheet animates straight from where the finger left it to the new resting height.
    private func setDetent(_ new: SheetDetent) {
        withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
            dragTranslation = 0
            detent = new
        }
        // Once the sheet settles, a different band of the map is on screen, so ask it
        // to reframe. Deferred rather than immediate so it does not fire on every frame
        // of the spring.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            model.requestRecenter()
        }
    }

    private var statusText: String {
        if isCapturingFrames { return "Capturing frames…" }
        if isLocalizing { return "VPS: Localizing…" }
        return model.vpsStatus.label
    }

    // MARK: - Setup

    /// The screen is meaningless without a GeoPose in the response, so force that one
    /// flag on while leaving every other Settings value as the user set it.
    private func configureForMapFlow() {
        guard MultiSet.shared.isInitialized else { return }
        var config = SDKConfig.buildConfig()
        if let currentMode = MultiSet.shared.config?.localizationMode {
            config.localizationMode = currentMode
        }
        config.geoCoordinatesInResponse = true
        MultiSet.shared.updateConfig(config)
    }

    private func setupCallbacks() {
        tracker.onFix = { fix in
            model.onGpsFix(fix)
        }

        sdkDelegate.onLocalizationSuccess = { result in
            model.onLocalizationSuccess(result)
        }

        sdkDelegate.onLocalizationFailure = { _ in
            model.onLocalizationFailure()
        }

        // A pose came back but was discarded, so it is kept off the VPS track and
        // called out explicitly — on this screen an unflagged bad fix would just look
        // like a sudden jump in drift.
        sdkDelegate.onLocalizationFalsePositive = { info in
            model.onFalsePositive()
            guard MultiSet.shared.config?.showAlerts == true else { return }
            var message = String(
                format: "The server matched your camera image to a different part of the space — its pose sits %.1f m from where your device's own motion says the map should be (limit %.0f m).\n\nThe response was discarded and nothing was plotted. Move a few steps, point at a well-lit, distinctive area and localize again.",
                info.jumpMeters, info.thresholdMeters
            )
            if info.consecutiveCount >= 3 {
                message += "\n\nDiscarded \(info.consecutiveCount) in a row. If the first fix of this session was the wrong one, close and reopen the scene to start over."
            }
            falsePositiveMessage = message
            showFalsePositiveAlert = true
        }

        sdkDelegate.onTrackingChanged = { state in
            isTrackingNormal = (state == .tracking)
        }

        if MultiSet.shared.config?.passGeoPose == true {
            MultiSet.shared.startGpsUpdates()
        }
    }

    private func startAutoLocalizationIfNeeded() {
        guard MultiSet.shared.config?.autoLocalize == true else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            guard !MultiSet.shared.isLocalizing else { return }
            localizeNow()
        }
    }

    private func localizeNow() {
        // Both tracks start accumulating together so the comparison is fair.
        model.startGpsLogging()
        model.setStatus(.localizing)
        MultiSet.shared.localize()
    }

    private func cleanup() {
        tracker.stop()
        MultiSet.shared.stopLocalization()
        MultiSet.shared.stopGpsUpdates()
    }
}

/// Rounds only the given corners. `RoundedRectangle` rounds all four, which would clip
/// the bottom of the map sheet against the screen edge.
private struct RoundedCorners: Shape {
    let radius: CGFloat
    let corners: UIRectCorner

    func path(in rect: CGRect) -> Path {
        Path(UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        ).cgPath)
    }
}
