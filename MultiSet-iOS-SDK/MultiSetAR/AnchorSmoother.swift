/*
Copyright (c) 2026 MultiSet AI. All rights reserved.
Licensed under the MultiSet License. You may not use this file except in compliance with the License. and you can't re-distribute this file without a prior notice
For license details, visit www.multiset.ai.
Redistribution in source or binary forms must retain this notice.
*/

import Foundation
import simd

// Pure simd, so the GeoAlignment host check can run it.
struct AnchorSmoother {

    typealias Pose = (position: SIMD3<Float>, rotation: simd_quatf)

    var duration: TimeInterval

    private var start: Pose?
    private(set) var target: Pose?
    private var startTime: TimeInterval = 0

    init(duration: TimeInterval) {
        self.duration = duration
    }

    // Starting from the shown pose keeps a target that lands mid-glide from jumping.
    mutating func setTarget(position: SIMD3<Float>, rotation: simd_quatf, at time: TimeInterval, snap: Bool) {
        let next = (position, rotation)
        start = snap ? next : (pose(at: time) ?? next)
        target = next
        startTime = time
    }

    func pose(at time: TimeInterval) -> Pose? {
        guard let start, let target else { return nil }
        let progress = duration > 0 ? Float(min(max((time - startTime) / duration, 0), 1)) : 1
        return (simd_mix(start.position, target.position, SIMD3<Float>(repeating: progress)),
                simd_slerp(start.rotation, target.rotation, progress))
    }

    mutating func clear() {
        start = nil
        target = nil
    }
}
