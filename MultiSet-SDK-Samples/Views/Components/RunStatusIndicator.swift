/*
Copyright (c) 2026 MultiSet AI. All rights reserved.
Licensed under the MultiSet License. You may not use this file except in compliance with the License. and you can't re-distribute this file without a prior notice
For license details, visit www.multiset.ai.
Redistribution in source or binary forms must retain this notice.
*/

import Combine
import QuartzCore
import SwiftUI
import MultiSetSDK

/// The step a run's status card shows. Ported from the MultiSet iOS app's
/// `BackgroundIndicatorState`.
enum RunStatusState: Hashable {
    case hidden
    /// The run is open with nothing being taken or sent: waiting on the server, or between retries.
    case working
    /// Taking frames; `shots` counts those in, so each one can be shown as it is taken.
    case capturing(shots: Int)
    case uploading
    case succeeded
    case failed

    init(_ stage: LocalizationStage) {
        switch stage {
        case .idle: self = .hidden
        case .capturing(let captured, _): self = .capturing(shots: captured)
        case .uploading: self = .uploading
        case .awaitingResponse: self = .working
        @unknown default: self = .working
        }
    }

    var isInProgress: Bool {
        switch self {
        case .working, .capturing, .uploading: true
        case .hidden, .succeeded, .failed: false
        }
    }

    /// How long a result stays before it fades. Nil for the states that do not fade.
    var holdDuration: TimeInterval? {
        switch self {
        case .succeeded: 2
        case .failed: 3
        case .hidden, .working, .capturing, .uploading: nil
        }
    }

    var accessibilityText: String {
        switch self {
        case .hidden: ""
        case .working: "Checking position"
        case .capturing: "Capturing images"
        case .uploading: "Uploading images"
        case .succeeded: "Position confirmed"
        case .failed: "Position check failed"
        }
    }
}

/// Gives each step of a run long enough on screen to be read.
///
/// On a fast network a single-frame run captures, uploads and is answered inside half a second,
/// which drew as a flicker. A step is held for its minimum before the next shows; the steps queue
/// meanwhile, and an answer makes a queued loader redundant.
struct RunStatusPacer: Equatable {
    static let captureDwell: TimeInterval = 0.6
    /// The SDK times the upload step itself. Only a step that ended while queued behind the
    /// capture is held, this long, so it is seen at all.
    static let queuedUploadDwell: TimeInterval = 0.8
    static let workingDwell: TimeInterval = 0.5
    /// A result gives way this soon to the next run; only fading waits out its whole hold.
    static let resultDwell: TimeInterval = 1

    private(set) var shown: RunStatusState = .hidden
    private var shownAt: TimeInterval = 0
    private var queue: [RunStatusState] = []
    private var uploadEndedWhileQueued = false

    var latest: RunStatusState { queue.last ?? shown }

    var nextChange: TimeInterval? {
        queue.first.map { dwellEnd(before: $0) }
    }

    mutating func receive(_ state: RunStatusState, at now: TimeInterval) {
        advance(to: now)
        if !state.isInProgress {
            queue.removeAll { $0 == .working }
        }
        if state != .hidden, queue.last == .hidden {
            queue.removeLast()
        }
        if Self.sameStep(latest, state) {
            if queue.isEmpty { shown = state } else { queue[queue.count - 1] = state }
        } else {
            queue.append(state)
        }
        advance(to: now)
    }

    mutating func advance(to now: TimeInterval) {
        while let next = queue.first, now >= dwellEnd(before: next) {
            queue.removeFirst()
            shown = next
            shownAt = now
            uploadEndedWhileQueued = next == .uploading && !queue.isEmpty
        }
    }

    private func dwellEnd(before next: RunStatusState) -> TimeInterval {
        switch shown {
        case .hidden:
            shownAt
        case .working:
            shownAt + Self.workingDwell
        case .capturing:
            shownAt + Self.captureDwell
        case .uploading:
            uploadEndedWhileQueued ? shownAt + Self.queuedUploadDwell : shownAt
        case .succeeded, .failed:
            if next == .hidden, let hold = shown.holdDuration {
                shownAt + hold
            } else {
                shownAt + Self.resultDwell
            }
        }
    }

    /// A frame taken is a flash on the step already showing, not a step of its own.
    private static func sameStep(_ a: RunStatusState, _ b: RunStatusState) -> Bool {
        if case .capturing = a, case .capturing = b { return true }
        return a == b
    }
}

/// What the status card shows, paced so each step is seen. Fed from the SDK's stage callbacks and
/// its result callbacks; a result fades on its own.
@MainActor
final class RunStatusIndicator: ObservableObject {
    @Published private(set) var state: RunStatusState = .hidden

    private var pacer = RunStatusPacer()
    private var pendingAdvance: Task<Void, Never>?
    private var isShowingResult = false

    func receive(_ next: RunStatusState) {
        let now = CACurrentMediaTime()
        if next != .hidden { isShowingResult = next.holdDuration != nil }
        pacer.receive(next, at: now)
        // The SDK ends a run before it reports the result, so nothing else would fade the result.
        if next.holdDuration != nil { pacer.receive(.hidden, at: now) }
        publish()
    }

    /// A run the user is waiting on stays open between its silent retries, with no stage to show.
    func keepOpen() {
        guard pacer.latest == .hidden, !isShowingResult else { return }
        receive(.working)
    }

    private func publish() {
        let next = pacer.shown
        if next != state {
            if (state == .hidden) != (next == .hidden) {
                withAnimation(.easeOut(duration: 0.25)) { state = next }
            } else {
                state = next
            }
        }
        scheduleAdvance()
    }

    private func scheduleAdvance() {
        pendingAdvance?.cancel()
        guard let due = pacer.nextChange else { return }
        let delay = max(due - CACurrentMediaTime(), 0)
        pendingAdvance = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled, let self else { return }
            self.pacer.advance(to: max(CACurrentMediaTime(), due))
            self.publish()
        }
    }
}
