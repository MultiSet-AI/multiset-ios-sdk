/*
Copyright (c) 2026 MultiSet AI. All rights reserved.
Licensed under the MultiSet License. You may not use this file except in compliance with the License. and you can't re-distribute this file without a prior notice
For license details, visit www.multiset.ai.
Redistribution in source or binary forms must retain this notice.
*/

import Combine
import Foundation
import MultiSetSDK

/// The scan screen's view of a scan the SDK is driving: it mirrors `MultiSet.shared.mapping`
/// and forwards the screen's taps. The capture rules themselves are inside the SDK.
@MainActor
final class ScanViewModel: ObservableObject {
    let source = ARMappingSource(kind: .lidar)

    @Published private(set) var scan = MultiSet.shared.mapping.scan
    /// Raised once as the scan enters its last minute; cleared when the scan stops.
    @Published var showsFinalMinuteWarning = false

    @Published var meshDisplay: ScanMeshDisplay {
        didSet {
            guard meshDisplay != oldValue else { return }
            source.meshRenderer?.display = meshDisplay
            UserDefaults.standard.set(meshDisplay.rawValue, forKey: Self.meshDisplayKey)
        }
    }

    private static let meshDisplayKey = "ai.multiset.sdk.scan.meshDisplay"

    private var observers: Set<AnyCancellable> = []
    private var mapping: MultiSetMapping { MultiSet.shared.mapping }

    init() {
        meshDisplay = UserDefaults.standard.string(forKey: Self.meshDisplayKey)
            .flatMap(ScanMeshDisplay.init(rawValue:)) ?? .surface
        source.meshRenderer?.display = meshDisplay

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
    var meshChunkCount: Int { scan.meshChunkCount }

    /// Stop is refused before the minimum, where nothing can build a map.
    var canFinish: Bool { phase == .mapping && elapsed >= MappingLimits.minimumScanDuration }

    var isBusy: Bool {
        scan.phase == .exporting || scan.phase == .zipping
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

    func stop() async {
        guard canFinish else { return }
        await mapping.stopScan()
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
        showsFinalMinuteWarning = Self.finalMinuteWarning(was: showsFinalMinuteWarning, old: old, new: new)
    }

    /// Up on crossing into the last minute, down once recording ends, so it never covers the save flow.
    static func finalMinuteWarning(was shown: Bool, old: MappingScanState, new: MappingScanState) -> Bool {
        guard new.phase == .mapping else { return false }
        return shown || (old.elapsed < MappingLimits.finalMinuteStart && new.elapsed >= MappingLimits.finalMinuteStart)
    }
}
