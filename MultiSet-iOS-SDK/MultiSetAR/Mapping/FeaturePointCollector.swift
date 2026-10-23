/*
Copyright (c) 2026 MultiSet AI. All rights reserved.
Licensed under the MultiSet License. You may not use this file except in compliance with the License. and you can't re-distribute this file without a prior notice
For license details, visit www.multiset.ai.
Redistribution in source or binary forms must retain this notice.
*/

import ARKit

/// Turns `rawFeaturePoints` into the posed-RGB scan's coverage cloud off the main thread.
///
/// The session delegate offers every frame; one in `stride` with normal tracking has its
/// points and identifiers copied out — never the `ARFrame` itself, which would starve
/// ARKit's frame pool. On a utility queue `FeaturePointFilter` keeps only features ARKit has
/// re-observed in place, and those go into a `PointCloudAccumulator`. Only what changed
/// reaches the main queue.
final class FeaturePointCollector: @unchecked Sendable {
    /// Feature points are read from one camera update in this many (≈ 10 Hz at 60 fps).
    static let stride = 6

    enum Update {
        case append([SIMD3<Float>])
        case replace([SIMD3<Float>])
    }

    private let queue = DispatchQueue(label: "ai.multiset.sdk.mapping.feature-points", qos: .utility)
    private let lock = NSLock()
    private var isCollecting = false
    private var frameCount = 0
    private var onUpdate: ((Update) -> Void)?
    private var accumulator = PointCloudAccumulator()
    private var filter = FeaturePointFilter()

    /// `onUpdate` runs on the main queue.
    func start(onUpdate: @escaping (Update) -> Void) {
        queue.async {
            self.accumulator = PointCloudAccumulator()
            self.filter = FeaturePointFilter()
        }
        lock.withLock {
            self.onUpdate = onUpdate
            frameCount = 0
            isCollecting = true
        }
    }

    func stop() {
        lock.withLock {
            isCollecting = false
            onUpdate = nil
        }
    }

    func offer(_ frame: ARFrame) {
        let callback: ((Update) -> Void)? = lock.withLock {
            guard isCollecting else { return nil }
            frameCount &+= 1
            return frameCount % Self.stride == 0 ? onUpdate : nil
        }
        // A limited frame's points come from a pose ARKit itself does not trust.
        guard let callback, case .normal = frame.camera.trackingState,
              let cloud = frame.rawFeaturePoints, !cloud.points.isEmpty else { return }
        let points = cloud.points, identifiers = cloud.identifiers
        let camera = frame.camera.transform.columns.3
        let position = SIMD3<Float>(camera.x, camera.y, camera.z)
        queue.async { [self] in
            let surfacePoints = filter.observe(identifiers: identifiers, points: points, camera: position)
            guard !surfacePoints.isEmpty else { return }
            let added = accumulator.insert(surfacePoints)
            if accumulator.didCoarsen {
                let all = accumulator.points
                DispatchQueue.main.async { callback(.replace(all)) }
            } else if !added.isEmpty {
                DispatchQueue.main.async { callback(.append(added)) }
            }
        }
    }

    /// Under memory pressure: halve the cloud's density at once.
    func coarsen() {
        let callback = lock.withLock { onUpdate }
        queue.async { [self] in
            guard accumulator.coarsen(), let callback else { return }
            let all = accumulator.points
            DispatchQueue.main.async { callback(.replace(all)) }
        }
    }
}
