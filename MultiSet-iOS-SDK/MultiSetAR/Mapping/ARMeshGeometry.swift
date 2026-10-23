/*
Copyright (c) 2026 MultiSet AI. All rights reserved.
Licensed under the MultiSet License. You may not use this file except in compliance with the License. and you can't re-distribute this file without a prior notice
For license details, visit www.multiset.ai.
Redistribution in source or binary forms must retain this notice.
*/

import ARKit
import MultiSetSDK

/// Reads ARKit's reconstruction buffers. Everything is handed over raw: the SDK applies the
/// anchor transform and the axis conversion itself.
enum ARMeshGeometry {

    static func chunk(from anchor: ARMeshAnchor) -> MappingMeshChunk? {
        let geometry = anchor.geometry
        guard geometry.vertices.count > 0, geometry.faces.primitiveType == .triangle else { return nil }
        return MappingMeshChunk(
            name: "Mesh \(anchor.identifier.uuidString)",
            transform: anchor.transform,
            positions: float3s(from: geometry.vertices),
            normals: float3s(from: geometry.normals),
            indices: indices(from: geometry.faces))
    }

    // ARGeometrySource packs three floats per vertex (stride 12); never read through
    // SIMD3<Float>, which is 16 bytes and would walk off the end of the buffer.
    static func float3s(from source: ARGeometrySource) -> [SIMD3<Float>] {
        let base = source.buffer.contents().advanced(by: source.offset)
        return (0..<source.count).map { index in
            let floats = base.advanced(by: index * source.stride).assumingMemoryBound(to: Float.self)
            return SIMD3(floats[0], floats[1], floats[2])
        }
    }

    static func indices(from faces: ARGeometryElement) -> [UInt32] {
        let count = faces.count * faces.indexCountPerPrimitive
        let source = faces.buffer.contents()
        if faces.bytesPerIndex == 4 {
            return Array(UnsafeBufferPointer(start: source.assumingMemoryBound(to: UInt32.self), count: count))
        }
        let shorts = UnsafeBufferPointer(start: source.assumingMemoryBound(to: UInt16.self), count: count)
        return shorts.map { UInt32($0) }
    }
}
