/*
Copyright (c) 2026 MultiSet AI. All rights reserved.
Licensed under the MultiSet License. You may not use this file except in compliance with the License. and you can't re-distribute this file without a prior notice
For license details, visit www.multiset.ai.
Redistribution in source or binary forms must retain this notice.
*/

import simd

/// The coverage cloud a posed-RGB scan draws: ARKit's feature points, one per voxel, in
/// world coordinates, so they stay on the surfaces they came from.
///
/// At `capacity` the grid doubles its voxel size and re-buckets rather than freezing, so
/// a part of the room reached late in a scan still shows up, at a coarser grain. Past
/// `maximumVoxelSize` new points are dropped.
struct PointCloudAccumulator: Sendable {
    private(set) var voxelSize: Float
    let capacity: Int
    let maximumVoxelSize: Float
    private(set) var points: [SIMD3<Float>] = []
    /// Whether the last mutating call re-bucketed: every point drawn so far is stale.
    private(set) var didCoarsen = false
    private var occupied: Set<SIMD3<Int32>> = []

    init(voxelSize: Float = 0.03, capacity: Int = 30_000, maximumVoxelSize: Float = 0.12) {
        self.voxelSize = voxelSize
        self.capacity = capacity
        self.maximumVoxelSize = maximumVoxelSize
    }

    var count: Int { points.count }

    /// Returns the points admitted by this call. When `didCoarsen` is set afterwards the
    /// caller should redraw from `points` instead.
    @discardableResult
    mutating func insert(_ candidates: [SIMD3<Float>]) -> [SIMD3<Float>] {
        didCoarsen = false
        var added: [SIMD3<Float>] = []
        for point in candidates where point.x.isFinite && point.y.isFinite && point.z.isFinite {
            var key = voxel(of: point)
            guard !occupied.contains(key) else { continue }
            if points.count >= capacity {
                guard rebucket() else { continue }
                didCoarsen = true
                key = voxel(of: point)
                guard !occupied.contains(key), points.count < capacity else { continue }
            }
            occupied.insert(key)
            points.append(point)
            added.append(point)
        }
        return added
    }

    /// Halves the density now, as under memory pressure. False when already coarsest.
    @discardableResult
    mutating func coarsen() -> Bool {
        didCoarsen = rebucket()
        return didCoarsen
    }

    private mutating func rebucket() -> Bool {
        let next = voxelSize * 2
        guard next <= maximumVoxelSize * 1.0001 else { return false }
        voxelSize = next
        let previous = points
        points.removeAll(keepingCapacity: true)
        occupied.removeAll(keepingCapacity: true)
        for point in previous where occupied.insert(voxel(of: point)).inserted {
            points.append(point)
        }
        return true
    }

    private func voxel(of point: SIMD3<Float>) -> SIMD3<Int32> {
        SIMD3<Int32>((point / voxelSize).rounded(.down))
    }
}
