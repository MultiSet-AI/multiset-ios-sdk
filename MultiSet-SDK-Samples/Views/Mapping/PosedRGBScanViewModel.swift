/*
Copyright (c) 2026 MultiSet AI. All rights reserved.
Licensed under the MultiSet License. You may not use this file except in compliance with the License. and you can't re-distribute this file without a prior notice
For license details, visit www.multiset.ai.
Redistribution in source or binary forms must retain this notice.
*/

import Combine
import Foundation
import MultiSetSDK

/// The posed-RGB scan screen's view of a scan the SDK is driving. Besides mirroring
/// `MultiSet.shared.mapping.scan` it turns two of its changes into one-off messages: new
/// tracking advice becomes a toast, and a scan the SDK stopped by itself becomes a notice.
@MainActor
final class PosedRGBScanViewModel: ObservableObject {
    struct Notice: Identifiable, Equatable {
        let title: String
        let message: String
        var id: String { title + message }
    }

    let source = ARMappingSource(kind: .posedRGB)

    @Published private(set) var scan = MultiSet.shared.mapping.scan
    /// Cleared by the banner that shows it.
    @Published var toast: MSToast?
    /// Why the scan stopped on its own, for an alert; nil once read.
    @Published var notice: Notice?
    /// Raised once as the scan enters its last minute; cleared when the scan stops.
    @Published var showsFinalMinuteWarning = false

    private var observers: Set<AnyCancellable> = []
    private var mapping: MultiSetMapping { MultiSet.shared.mapping }

    init() {
        NotificationCenter.default.publisher(for: .multiSetMappingScanDidChange)
            .sink { [weak self] _ in self?.update(MultiSet.shared.mapping.scan) }
            .store(in: &observers)
    }

    var phase: MappingPhase { scan.phase }
    var elapsed: TimeInterval { scan.elapsed }
    var zipProgress: Double { scan.packagingProgress }
    var showsMotionWarning: Bool { scan.showsMotionWarning }
    var savedFrames: Int { scan.savedFrames }
    var blurredFrames: Int { scan.blurredFrames }
    var discardedFrames: Int { scan.discardedFrames }
    var tracking: MappingTrackingStatus? { scan.tracking }
    var walkedArea: Double? { scan.walkedArea }
    var isCapturingSlowly: Bool { scan.isCapturingSlowly }

    /// Finish is refused before the minimum, where nothing can build a map.
    var canFinish: Bool { phase == .mapping && elapsed >= MappingLimits.minimumScanDuration }

    var isInFinalMinute: Bool {
        phase == .mapping && elapsed >= MappingLimits.finalMinuteStart
    }

    // MARK: - Screen lifecycle

    func appear() {
        mapping.setSource(source)
        update(mapping.scan)
        Task { await mapping.beginPreview() }
    }

    /// Detaching lets the ARView, its session and the location manager go with the screen.
    func disappear() {
        mapping.endPreview()
        mapping.setSource(nil)
    }

    // MARK: - Scan

    func start() async {
        await mapping.startScan()
    }

    func finish() async {
        guard canFinish else { return }
        await mapping.stopScan()
    }

    func cancelPackaging() {
        mapping.cancelPackaging()
    }

    func resumePackaging() async {
        await mapping.resumePackaging()
    }

    func discard() async {
        await mapping.discardScan()
    }

    func acknowledgeFailure() {
        mapping.acknowledgeFailure()
    }

    private func update(_ new: MappingScanState) {
        let old = scan
        scan = new
        showsFinalMinuteWarning = ScanViewModel.finalMinuteWarning(was: showsFinalMinuteWarning, old: old, new: new)
        if new.phase == .preparing, old.phase != .preparing {
            toast = nil
        }
        if let advice = new.trackingAdvice, advice != old.trackingAdvice {
            toast = advice.kind.toast
        }
        if old.autoStopReason == nil, let reason = new.autoStopReason, let why = Self.why(reason) {
            notice = Notice(
                title: "Scan stopped",
                message: "\(why), so the scan stopped. What was captured has been kept.")
        }
    }

    /// The time limit has its own warning a minute ahead, so it needs no notice.
    private static func why(_ reason: MappingAutoStopReason) -> String? {
        switch reason {
        case .interrupted: "The scan was interrupted"
        case .lowStorage: "The device is almost out of storage"
        case .timeLimit: nil
        @unknown default: nil
        }
    }
}
