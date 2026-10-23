/*
Copyright (c) 2026 MultiSet AI. All rights reserved.
Licensed under the MultiSet License. You may not use this file except in compliance with the License. and you can't re-distribute this file without a prior notice
For license details, visit www.multiset.ai.
Redistribution in source or binary forms must retain this notice.
*/

import simd

/// Admits an ARKit raw feature point to the coverage cloud only once ARKit has re-observed
/// the same feature, by identifier, in `confirmations` samples that agree within
/// `tolerance`, seen from viewpoints `minimumParallaxDegrees` apart, at a range where its
/// depth can be trusted.
///
/// Raw feature points are ARKit's working hypotheses: many are triangulated with little
/// parallax and land tens of centimetres off any surface. Agreement alone is not enough —
/// a guess repeated from the same viewpoint agrees with itself — so the camera must have
/// moved enough for the sightings to have actually measured depth. Display only: nothing
/// here reaches the map.
struct FeaturePointFilter: Sendable {
    /// Samples of one feature, agreeing within `tolerance`, before it is drawn.
    static let confirmations = 3
    static let tolerance: Float = 0.03
    /// A raw point's depth is unreliable very close and, with little parallax, far away.
    static let minimumRange: Float = 0.25
    static let maximumRange: Float = 5.0
    /// Samples (≈ 1 s) after which a feature's earlier sightings no longer count.
    static let staleSamples = 10
    /// Parallax a feature's sightings must span, at the point, before it is drawn: about
    /// 10 cm of sideways movement at 2 m. Turning on the spot gives none.
    static let minimumParallaxDegrees: Float = 3
    /// Identifiers remembered as drawn; past it the set is cleared, and a re-confirmed
    /// feature lands in a voxel the cloud already holds.
    static let confirmedMemory = 50_000

    private struct Track: Sendable {
        var mean: SIMD3<Float>
        var count: Int
        var lastSeen: Int
        var firstCamera: SIMD3<Float>
    }

    private var tracks: [UInt64: Track] = [:]
    private var confirmed: Set<UInt64> = []
    private var sample = 0

    private let minimumParallaxCosine = cos(Self.minimumParallaxDegrees * .pi / 180)

    var confirmedCount: Int { confirmed.count }

    /// Returns the points confirmed by this sample, each at its averaged position.
    mutating func observe(
        identifiers: [UInt64], points: [SIMD3<Float>], camera: SIMD3<Float>
    ) -> [SIMD3<Float>] {
        sample += 1
        var newlyConfirmed: [SIMD3<Float>] = []
        for (id, point) in zip(identifiers, points) where !confirmed.contains(id) {
            let range = simd_distance(point, camera)
            guard point.x.isFinite, point.y.isFinite, point.z.isFinite,
                  range >= Self.minimumRange,
                  range <= Self.maximumRange else { continue }

            guard var track = tracks[id],
                  sample - track.lastSeen <= Self.staleSamples,
                  simd_distance(track.mean, point) <= Self.tolerance else {
                tracks[id] = Track(mean: point, count: 1, lastSeen: sample, firstCamera: camera)
                continue
            }
            track.count += 1
            track.mean += (point - track.mean) / Float(track.count)
            track.lastSeen = sample
            if track.count >= Self.confirmations, hasParallax(track, point: point, camera: camera) {
                if confirmed.count >= Self.confirmedMemory { confirmed.removeAll(keepingCapacity: true) }
                confirmed.insert(id)
                tracks[id] = nil
                newlyConfirmed.append(point)
            } else {
                tracks[id] = track
            }
        }
        if sample % Self.staleSamples == 0 {
            tracks = tracks.filter { sample - $0.value.lastSeen <= Self.staleSamples }
        }
        return newlyConfirmed
    }

    private func hasParallax(_ track: Track, point: SIMD3<Float>, camera: SIMD3<Float>) -> Bool {
        let first = track.firstCamera - point, now = camera - point
        guard simd_length(first) > 0, simd_length(now) > 0 else { return false }
        return simd_dot(simd_normalize(first), simd_normalize(now)) <= minimumParallaxCosine
    }
}
