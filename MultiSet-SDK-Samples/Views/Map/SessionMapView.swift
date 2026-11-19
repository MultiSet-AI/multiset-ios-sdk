/*
Copyright (c) 2026 MultiSet AI. All rights reserved.
Licensed under the MultiSet License. You may not use this file except in compliance with the License. and you can't re-distribute this file without a prior notice
For license details, visit www.multiset.ai.
Redistribution in source or binary forms must retain this notice.
*/

import SwiftUI

/// The map half of the GeoPose Map View: the GPS and VPS tracks, a status chip and the controls.
struct SessionMapView: View {

    @ObservedObject var model: MapSessionModel

    /// Height of the map below the fold. The map view stays full height, because resizing it
    /// churns Metal drawables, so this is how the renderer learns which band is on screen.
    let obscuredBottom: CGFloat

    /// Height covered at the bottom of the visible band: the home indicator and the watermark.
    let bottomChrome: CGFloat

    let isFullScreen: Bool
    let onToggleFullScreen: () -> Void

    @Binding var style: MapStyleMode

    @State private var zoomRequest = 0

    var body: some View {
        ZStack(alignment: .top) {
            TrackMapView(
                model: model,
                style: style,
                zoomRequest: zoomRequest,
                obscuredBottom: obscuredBottom,
                bottomChrome: bottomChrome
            )
            .ignoresSafeArea(edges: .bottom)

            // Anchored to the top: below the fold, a bottom-aligned control would be off-screen.
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 6) {
                    statusChip
                    if let notice = notice {
                        Text(notice)
                            .font(.system(size: 12))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 12).fill(Color.black.opacity(0.65))
                            )
                    }
                }

                Spacer(minLength: 0)

                controlColumn
                    .layoutPriority(1)
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
        }
    }

    private var statusChip: some View {
        HStack(spacing: 5) {
            Image(systemName: model.vpsStatus.symbol)
                .font(.system(size: 11, weight: .bold))
            Text(model.vpsStatus.label)
                .font(.system(size: 12, weight: .semibold))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Capsule().fill(model.vpsStatus.color))
        .shadow(radius: 2)
    }

    private var controlColumn: some View {
        VStack(spacing: 8) {
            Button(action: onToggleFullScreen) {
                controlIcon(
                    isFullScreen
                        ? "arrow.down.right.and.arrow.up.left"
                        : "arrow.up.left.and.arrow.down.right",
                    active: isFullScreen
                )
            }

            VStack(spacing: 0) {
                Button { zoomRequest += 1 } label: { zoomIcon("plus") }
                Divider().frame(width: 22)
                Button { zoomRequest -= 1 } label: { zoomIcon("minus") }
            }
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color(UIColor.systemBackground).opacity(0.9))
            )
            .shadow(radius: 2)

            Button { model.followMode.toggle() } label: {
                controlIcon(model.followMode ? "location.fill" : "location", active: model.followMode)
            }

            Menu {
                Picker("Map Style", selection: $style) {
                    ForEach(MapStyleMode.allCases) { mode in
                        Label(mode.label, systemImage: mode.symbol).tag(mode)
                    }
                }
            } label: {
                controlIcon("square.3.layers.3d", active: false)
            }
            .accessibilityLabel("Map style")
        }
    }

    private func zoomIcon(_ systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(.primary)
            .frame(width: 36, height: 36)
    }

    private func controlIcon(_ systemName: String, active: Bool) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(active ? .white : .primary)
            .frame(width: 36, height: 36)
            .background(
                Circle().fill(active ? Color(hex: "#7B2CBF") : Color(UIColor.systemBackground).opacity(0.9))
            )
            .shadow(radius: 2)
    }

    private var notice: String? {
        if model.vpsStatus == .notGeoReferenced {
            return "Localized, but this map or MapSet is not geo-referenced, so there is no GeoPose to plot."
        }
        if !model.locationAvailable {
            return "Location unavailable — the GPS track will not plot. The VPS track is unaffected."
        }
        if model.coarseOnly {
            return "Reduced location accuracy granted — the GPS track is coarse."
        }
        if model.vpsTrack.isEmpty {
            return "Waiting for the first VPS GeoPose…"
        }
        return nil
    }
}

/// Track key, in the sheet header beside the grab handle.
struct TrackLegend: View {
    private let gpsColor = Color(hex: "#1E88E5")
    private let vpsColor = Color(hex: "#43A047")

    var body: some View {
        HStack(spacing: 12) {
            item(color: gpsColor, label: "GPS", dashed: false)
            item(color: vpsColor, label: "VPS", dashed: true)
        }
    }

    private func item(color: Color, label: String, dashed: Bool) -> some View {
        HStack(spacing: 5) {
            if dashed {
                HStack(spacing: 3) {
                    Capsule().fill(color).frame(width: 6, height: 3)
                    Capsule().fill(color).frame(width: 6, height: 3)
                }
            } else {
                Capsule().fill(color).frame(width: 15, height: 3)
            }
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
        }
    }
}
