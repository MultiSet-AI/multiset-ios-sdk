/*
Copyright (c) 2026 MultiSet AI. All rights reserved.
Licensed under the MultiSet License. You may not use this file except in compliance with the License. and you can't re-distribute this file without a prior notice
For license details, visit www.multiset.ai.
Redistribution in source or binary forms must retain this notice.
*/

import SwiftUI
import MapKit

/// `MKMapView` wrapper that draws the two tracks.
///
/// SwiftUI's `Map` content API would express this in a third of the lines, but it
/// requires iOS 17 and the demo app targets 16.0 — the sample ships as the SDK's
/// reference integration, so its floor stays where consumers are.
struct TrackMapView: UIViewControllerRepresentable {

    @ObservedObject var model: MapSessionModel
    let style: MapStyleMode

    /// Incremented by the zoom controls; the sign of the change selects the direction.
    /// A counter rather than a closure so SwiftUI drives it through `updateUIViewController`.
    let zoomRequest: Int

    /// Height of the map hidden below the fold. Used as bottom edge padding when
    /// recentring, so the tracked position lands in the middle of the visible band
    /// rather than the middle of the (mostly off-screen) map view.
    let obscuredBottom: CGFloat

    /// Height covered at the bottom of the visible band: the home indicator and the watermark.
    let bottomChrome: CGFloat

    func makeCoordinator() -> Coordinator {
        Coordinator(model: model)
    }

    func makeUIViewController(context: Context) -> MapHostController {
        let controller = MapHostController()
        let mapView = controller.mapView
        mapView.delegate = context.coordinator
        mapView.showsCompass = true
        mapView.showsScale = true
        // Locked north-up on purpose. An annotation image stays screen-aligned, so the
        // heading arrow's rotation is baked relative to north — rotating or pitching the
        // map would leave it pointing somewhere else entirely while looking authoritative.
        mapView.isRotateEnabled = false
        mapView.isPitchEnabled = false
        mapView.pointOfInterestFilter = .excludingAll
        apply(style: style, to: mapView)
        return controller
    }

    func updateUIViewController(_ controller: MapHostController, context: Context) {
        let mapView = controller.mapView
        controller.attributionClearance = obscuredBottom + bottomChrome + 4
        context.coordinator.model = model
        context.coordinator.obscuredBottom = obscuredBottom
        apply(style: style, to: mapView)
        context.coordinator.applyZoom(request: zoomRequest, mapView: mapView)
        context.coordinator.sync(mapView: mapView, model: model)
    }

    private func apply(style: MapStyleMode, to mapView: MKMapView) {
        let configuration: MKMapConfiguration = (style == .satellite)
            ? MKHybridMapConfiguration()
            : MKStandardMapConfiguration()

        // Reassigning an equivalent configuration forces a full redraw, so only set it
        // when the style actually changed.
        if type(of: mapView.preferredConfiguration) != type(of: configuration) {
            mapView.preferredConfiguration = configuration
        }

        if mapView.overrideUserInterfaceStyle != style.interfaceStyle {
            mapView.overrideUserInterfaceStyle = style.interfaceStyle
        }
    }

    // MARK: - Host

    // MapKit places its Apple logo and Legal link by the safe area; Apple requires both visible.
    final class MapHostController: UIViewController {
        let mapView = MKMapView()

        /// Distance up from the map's bottom edge that the attribution has to clear.
        var attributionClearance: CGFloat = 0 {
            didSet { updateAttributionInset() }
        }

        override func loadView() {
            view = mapView
        }

        override func viewSafeAreaInsetsDidChange() {
            super.viewSafeAreaInsetsDidChange()
            updateAttributionInset()
        }

        private func updateAttributionInset() {
            let inherited = view.safeAreaInsets.bottom - additionalSafeAreaInsets.bottom
            let needed = max(0, (attributionClearance - inherited).rounded())
            if additionalSafeAreaInsets.bottom != needed {
                additionalSafeAreaInsets.bottom = needed
            }
        }
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, MKMapViewDelegate {

        var model: MapSessionModel
        var obscuredBottom: CGFloat = 0

        /// Counts already drawn, so a redraw only happens when a track actually grew.
        private var drawnGpsCount = 0
        private var drawnVpsCount = 0
        private var drawnAccuracyKey: String?
        private var drawnGpsMarkerKey: String?

        private var gpsPolyline: MKPolyline?
        private var vpsPolyline: MKPolyline?
        private var accuracyCircle: MKCircle?

        /// Guards the follow-mode auto-disable against our own programmatic recentering.
        private var isProgrammaticRegionChange = false
        private var lastCenteredOn: CLLocationCoordinate2D?
        private var wasFollowing = true
        private var hasCenteredOnce = false

        private var lastZoomRequest = 0

        init(model: MapSessionModel) {
            self.model = model
        }

        // MARK: Zoom

        /// Applies a pending zoom step. `request` only ever moves by ±1, so its delta
        /// gives the direction; equal values mean nothing to do.
        func applyZoom(request: Int, mapView: MKMapView) {
            guard request != lastZoomRequest else { return }
            let zoomingIn = request > lastZoomRequest
            lastZoomRequest = request

            // The sheet can sit at zero height, where MKMapView reports a NaN span.
            // Feeding that back into setRegion throws "Invalid Region" and traps.
            guard mapView.bounds.width > 0, mapView.bounds.height > 0 else { return }
            let current = mapView.region
            guard current.span.latitudeDelta.isFinite,
                  current.span.longitudeDelta.isFinite,
                  current.center.latitude.isFinite,
                  current.center.longitude.isFinite else { return }

            let factor: Double = zoomingIn ? 0.5 : 2.0
            var region = current
            // MKCoordinateSpan tops out just under 180/360; clamp so zooming out far
            // enough cannot throw an invalid region.
            region.span = MKCoordinateSpan(
                latitudeDelta: min(max(region.span.latitudeDelta * factor, 0.000_2), 170),
                longitudeDelta: min(max(region.span.longitudeDelta * factor, 0.000_2), 350)
            )
            isProgrammaticRegionChange = true
            mapView.setRegion(region, animated: true)
        }

        // MARK: Sync

        func sync(mapView: MKMapView, model: MapSessionModel) {
            syncGpsTrack(mapView: mapView, model: model)
            syncVpsTrack(mapView: mapView, model: model)
            syncAccuracyCircle(mapView: mapView, model: model)
            syncAnnotations(mapView: mapView, model: model)
            followIfNeeded(mapView: mapView, model: model)
        }

        private func syncGpsTrack(mapView: MKMapView, model: MapSessionModel) {
            guard model.gpsTrack.count != drawnGpsCount else { return }
            drawnGpsCount = model.gpsTrack.count

            if let existing = gpsPolyline {
                mapView.removeOverlay(existing)
                gpsPolyline = nil
            }
            guard model.gpsTrack.count > 1 else { return }

            let line = MKPolyline(
                coordinates: model.gpsTrack.map(\.coordinate),
                count: model.gpsTrack.count
            )
            line.title = "gps"
            gpsPolyline = line
            mapView.addOverlay(line, level: .aboveRoads)
        }

        private func syncVpsTrack(mapView: MKMapView, model: MapSessionModel) {
            guard model.vpsTrack.count != drawnVpsCount else { return }
            drawnVpsCount = model.vpsTrack.count

            if let existing = vpsPolyline {
                mapView.removeOverlay(existing)
                vpsPolyline = nil
            }
            guard model.vpsTrack.count > 1 else { return }

            let line = MKPolyline(
                coordinates: model.vpsTrack.map(\.coordinate),
                count: model.vpsTrack.count
            )
            line.title = "vps"
            vpsPolyline = line
            mapView.addOverlay(line, level: .aboveRoads)
        }

        private func syncAccuracyCircle(mapView: MKMapView, model: MapSessionModel) {
            guard let latest = model.latestGps, latest.horizontalAccuracy > 0 else {
                if let existing = accuracyCircle {
                    mapView.removeOverlay(existing)
                    accuracyCircle = nil
                    drawnAccuracyKey = nil
                }
                return
            }

            let key = String(
                format: "%.6f,%.6f,%.1f",
                latest.latitude, latest.longitude, latest.horizontalAccuracy
            )
            guard key != drawnAccuracyKey else { return }
            drawnAccuracyKey = key

            if let existing = accuracyCircle {
                mapView.removeOverlay(existing)
            }
            let circle = MKCircle(center: latest.coordinate, radius: latest.horizontalAccuracy)
            accuracyCircle = circle
            mapView.addOverlay(circle, level: .aboveRoads)
        }

        private func syncAnnotations(mapView: MKMapView, model: MapSessionModel) {
            let existing = mapView.annotations.compactMap { $0 as? TrackAnnotation }
            let latestVpsId = model.latestVps?.id

            // VPS poses only ever append, so add the ones not yet on the map. The
            // previous latest is rebuilt as a plain dot when a newer pose arrives.
            let plotted = Set(existing.compactMap { annotation -> UUID? in
                if case .vps = annotation.kind { return annotation.pointId }
                return nil
            })

            for point in model.vpsTrack where !plotted.contains(point.id) {
                mapView.addAnnotation(TrackAnnotation(point: point, isLatest: point.id == latestVpsId))
            }

            // Demote any VPS annotation still flagged latest that no longer is.
            for annotation in existing {
                guard case .vps(_, _, let isLatest) = annotation.kind,
                      let pointId = annotation.pointId else { continue }
                if isLatest && pointId != latestVpsId {
                    mapView.removeAnnotation(annotation)
                    if let point = model.vpsTrack.first(where: { $0.id == pointId }) {
                        mapView.addAnnotation(TrackAnnotation(point: point, isLatest: false))
                    }
                }
            }

            // The GPS marker is a single moving annotation, replaced in place — but only
            // when it actually moved, otherwise every 0.1s update pass makes it blink.
            let gpsAnnotations = existing.filter { if case .gpsCurrent = $0.kind { return true } else { return false } }
            let gpsKey = model.latestGps.map { String(format: "%.7f,%.7f", $0.latitude, $0.longitude) }
            if gpsKey != drawnGpsMarkerKey {
                drawnGpsMarkerKey = gpsKey
                mapView.removeAnnotations(gpsAnnotations)
                if let latest = model.latestGps {
                    mapView.addAnnotation(TrackAnnotation(fix: latest))
                }
            }
        }

        // MARK: Follow

        private var lastRecenterToken = 0

        private func followIfNeeded(mapView: MKMapView, model: MapSessionModel) {
            // An explicit recentre request clears the "already centred here" guard, so
            // the map reframes even though the tracked position has not moved.
            if model.recenterToken != lastRecenterToken {
                lastRecenterToken = model.recenterToken
                lastCenteredOn = nil
            }

            // Re-enabling follow must recenter immediately, even though the target has
            // not moved since the user panned away — otherwise the button does nothing
            // until the next fix arrives.
            let reEnabled = model.followMode && !wasFollowing
            wasFollowing = model.followMode
            if reEnabled { lastCenteredOn = nil }

            guard model.followMode else { return }
            guard let target = model.latestVps?.coordinate ?? model.latestGps?.coordinate else { return }
            // Same guard as applyZoom: recentering a zero-sized map traps.
            guard mapView.bounds.width > 0, mapView.bounds.height > 0 else { return }
            guard CLLocationCoordinate2DIsValid(target) else { return }

            if let last = lastCenteredOn,
               abs(last.latitude - target.latitude) < 0.000_001,
               abs(last.longitude - target.longitude) < 0.000_001 {
                return
            }
            lastCenteredOn = target

            isProgrammaticRegionChange = true

            if !hasCenteredOnce {
                hasCenteredOnce = true
                // Establish the initial zoom once, without animation, so the offset
                // computed below reads the settled projection.
                mapView.setRegion(
                    MKCoordinateRegion(center: target, latitudinalMeters: 150, longitudinalMeters: 150),
                    animated: false
                )
            }

            mapView.setCenter(offsetCenter(for: target, in: mapView), animated: true)
        }

        /// The centre coordinate that puts `target` in the middle of the band of the map
        /// that is actually on screen.
        ///
        /// Deliberately not `setVisibleMapRect(_:edgePadding:)`: that fits the rect
        /// inside `viewport − padding`, so feeding it a rect built from the *current*
        /// span enlarges the span every call. Repeated expand/collapse compounded that
        /// until the map was fully zoomed out. `setCenter` never touches the span.
        private func offsetCenter(
            for target: CLLocationCoordinate2D,
            in mapView: MKMapView
        ) -> CLLocationCoordinate2D {
            let visibleHeight = max(40, mapView.bounds.height - obscuredBottom)
            guard visibleHeight < mapView.bounds.height else { return target }

            // Coordinate currently drawn at the point we want the target to occupy, and
            // the one at the view's true centre. Their difference is the shift to apply.
            let desiredPoint = CGPoint(x: mapView.bounds.midX, y: visibleHeight / 2)
            let atDesired = mapView.convert(desiredPoint, toCoordinateFrom: mapView)
            let atCentre = mapView.centerCoordinate

            guard atDesired.latitude.isFinite, atDesired.longitude.isFinite else { return target }

            return CLLocationCoordinate2D(
                latitude: target.latitude + (atCentre.latitude - atDesired.latitude),
                longitude: target.longitude + (atCentre.longitude - atDesired.longitude)
            )
        }

        // MARK: MKMapViewDelegate

        func mapView(_ mapView: MKMapView, regionWillChangeAnimated animated: Bool) {
            guard !isProgrammaticRegionChange else { return }
            // A pan or pinch means the user took over; stop fighting them for the camera.
            guard let recognizers = mapView.subviews.first?.gestureRecognizers else { return }
            let userDriven = recognizers.contains { $0.state == .began || $0.state == .changed }
            guard userDriven, model.followMode else { return }
            DispatchQueue.main.async { [weak self] in
                self?.model.followMode = false
            }
        }

        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            isProgrammaticRegionChange = false
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let circle = overlay as? MKCircle {
                let renderer = MKCircleRenderer(circle: circle)
                renderer.fillColor = GeoPoseMath.gpsUIColor.withAlphaComponent(0.15)
                renderer.strokeColor = GeoPoseMath.gpsUIColor.withAlphaComponent(0.5)
                renderer.lineWidth = 1
                return renderer
            }

            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                if polyline.title == "vps" {
                    renderer.strokeColor = GeoPoseMath.vpsUIColor
                    renderer.lineWidth = 4
                    renderer.lineDashPattern = [8, 6]
                } else {
                    renderer.strokeColor = GeoPoseMath.gpsUIColor
                    renderer.lineWidth = 5
                }
                return renderer
            }

            return MKOverlayRenderer(overlay: overlay)
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let track = annotation as? TrackAnnotation else { return nil }

            let identifier = track.reuseIdentifier
            let view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
                ?? MKAnnotationView(annotation: track, reuseIdentifier: identifier)

            view.annotation = track
            view.canShowCallout = true
            view.image = track.markerImage
            view.centerOffset = .zero
            return view
        }
    }
}

// MARK: - Annotation

/// A point on either track. One class for both so the delegate has a single cast.
final class TrackAnnotation: NSObject, MKAnnotation {

    enum Kind {
        case gpsCurrent
        case vps(color: UIColor, heading: Double?, isLatest: Bool)
    }

    let coordinate: CLLocationCoordinate2D
    let title: String?
    let subtitle: String?
    let kind: Kind
    /// Identity of the `VpsPoint` this was built from, so the latest marker can be
    /// demoted when a newer pose arrives.
    let pointId: UUID?

    init(fix: GpsFix) {
        coordinate = fix.coordinate
        kind = .gpsCurrent
        pointId = nil
        title = "Device GPS"
        subtitle = TrackAnnotation.gpsSubtitle(fix)
        super.init()
    }

    init(point: VpsPoint, isLatest: Bool) {
        coordinate = point.coordinate
        kind = .vps(
            color: GeoPoseMath.confidenceUIColor(point.confidence),
            heading: point.headingDegrees,
            isLatest: isLatest
        )
        pointId = point.id
        title = isLatest ? "VPS (latest)" : "VPS pose"
        subtitle = TrackAnnotation.vpsSubtitle(point)
        super.init()
    }

    var reuseIdentifier: String {
        switch kind {
        case .gpsCurrent: return "gps"
        case .vps(_, let heading, let isLatest):
            // The rotation is baked into the image, so each heading needs its own reuse bucket.
            if isLatest, let heading = heading {
                return "vps-arrow-\(Int(heading))"
            }
            return isLatest ? "vps-latest" : "vps-dot"
        }
    }

    var markerImage: UIImage? {
        switch kind {
        case .gpsCurrent:
            return TrackAnnotation.dot(color: GeoPoseMath.gpsUIColor, diameter: 16, ring: 3)
        case .vps(let color, let heading, let isLatest):
            if isLatest, let heading = heading {
                return TrackAnnotation.arrow(color: color, rotationDegrees: heading)
            }
            return TrackAnnotation.dot(color: color, diameter: isLatest ? 14 : 9, ring: 1.5)
        }
    }

    // MARK: Symbols

    private static func dot(color: UIColor, diameter: CGFloat, ring: CGFloat) -> UIImage {
        let size = CGSize(width: diameter + ring * 2, height: diameter + ring * 2)
        return UIGraphicsImageRenderer(size: size).image { context in
            let rect = CGRect(origin: .zero, size: size).insetBy(dx: ring / 2, dy: ring / 2)
            color.setFill()
            UIColor.white.setStroke()
            let path = UIBezierPath(ovalIn: rect)
            path.lineWidth = ring
            path.fill()
            path.stroke()
            _ = context
        }
    }

    private static func arrow(color: UIColor, rotationDegrees: Double) -> UIImage? {
        let configuration = UIImage.SymbolConfiguration(pointSize: 16, weight: .bold)
        guard let symbol = UIImage(systemName: "location.north.fill", withConfiguration: configuration)?
            .withTintColor(color, renderingMode: .alwaysOriginal) else { return nil }

        let canvas = CGSize(width: 34, height: 34)
        return UIGraphicsImageRenderer(size: canvas).image { context in
            let cgContext = context.cgContext

            UIColor.white.withAlphaComponent(0.9).setFill()
            UIBezierPath(ovalIn: CGRect(origin: .zero, size: canvas)).fill()

            cgContext.translateBy(x: canvas.width / 2, y: canvas.height / 2)
            cgContext.rotate(by: CGFloat(rotationDegrees) * .pi / 180)
            symbol.draw(in: CGRect(
                x: -symbol.size.width / 2,
                y: -symbol.size.height / 2,
                width: symbol.size.width,
                height: symbol.size.height
            ))
        }
    }

    // MARK: Callout text

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()

    private static func gpsSubtitle(_ fix: GpsFix) -> String {
        let accuracy = String(format: " · ±%.1fm", fix.horizontalAccuracy)
        return String(format: "%.6f, %.6f", fix.latitude, fix.longitude)
            + accuracy + " · " + timeFormatter.string(from: fix.timestamp)
    }

    private static func vpsSubtitle(_ point: VpsPoint) -> String {
        let confidence = point.confidence.map { String(format: " · conf %.2f", $0) } ?? ""
        let heading = point.headingDegrees.map { String(format: " · %.0f°", $0) } ?? ""
        return String(format: "%.6f, %.6f", point.latitude, point.longitude)
            + confidence + heading + " · " + timeFormatter.string(from: point.timestamp)
    }
}
