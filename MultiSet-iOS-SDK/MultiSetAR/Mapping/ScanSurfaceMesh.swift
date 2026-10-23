/*
Copyright (c) 2026 MultiSet AI. All rights reserved.
Licensed under the MultiSet License. You may not use this file except in compliance with the License. and you can't re-distribute this file without a prior notice
For license details, visit www.multiset.ai.
Redistribution in source or binary forms must retain this notice.
*/

import Foundation
import simd

/// What ARKit labelled a reconstructed face, by `ARMeshClassification` raw value, so the
/// on-screen palette can be chosen and checked on the host without importing ARKit.
///
/// Display only: the GLB a scan writes carries geometry and no labels.
enum ScanSurfaceClass: UInt8, CaseIterable, Sendable {
    case unknown = 0, wall, floor, ceiling, table, seat, window, door

    /// sRGB `0xRRGGBB`. Unknown is the pale lavender a face shows until ARKit labels it.
    var hex: UInt32 {
        switch self {
        case .unknown: 0x9978ED
        case .wall: 0x835BEA
        case .floor: 0xBBA5F3
        case .ceiling: 0x4417B5
        case .table: 0x9978ED
        case .seat: 0x6634E5
        case .window: 0xAA8EF0
        case .door: 0x774AE8
        }
    }

    var linearRGB: SIMD3<Float> {
        func linear(_ shift: UInt32) -> Float {
            let value = Float((hex >> shift) & 0xFF) / 255
            return value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        return SIMD3(linear(16), linear(8), linear(0))
    }
}

/// One ARKit mesh chunk's triangles, ready to draw with a material per surface class.
///
/// A face is dropped when it is degenerate or names a vertex that is missing or not
/// finite, and its label goes with it, so every surviving face keeps its own label.
struct ScanSurfaceMesh: Equatable, Sendable {
    let indices: [UInt32]
    let faceClasses: [ScanSurfaceClass]

    init(positions: [SIMD3<Float>], indices source: [UInt32], classes: [UInt8]?) {
        var indices: [UInt32] = []
        var faceClasses: [ScanSurfaceClass] = []
        let faceCount = source.count / 3
        indices.reserveCapacity(faceCount * 3)
        faceClasses.reserveCapacity(faceCount)
        for face in 0..<faceCount {
            let corners = source[(face * 3)..<(face * 3 + 3)]
            guard corners.allSatisfy({ Int($0) < positions.count }) else { continue }
            let a = positions[Int(corners[corners.startIndex])]
            let b = positions[Int(corners[corners.startIndex + 1])]
            let c = positions[Int(corners[corners.startIndex + 2])]
            let areaSquared = simd_length_squared(simd_cross(b - a, c - a))
            guard areaSquared > 1e-12, areaSquared.isFinite else { continue }
            indices.append(contentsOf: corners)
            let label = classes.flatMap { face < $0.count ? $0[face] : nil }
            faceClasses.append(label.flatMap(ScanSurfaceClass.init(rawValue:)) ?? .unknown)
        }
        self.indices = indices
        self.faceClasses = faceClasses
    }

    var isEmpty: Bool { indices.isEmpty }

    /// Per-face material slots: one material per `ScanSurfaceClass`, in `allCases` order.
    var materialIndices: [UInt32] { faceClasses.map { UInt32($0.rawValue) } }
}
