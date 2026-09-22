/*
Copyright (c) 2026 MultiSet AI. All rights reserved.
Licensed under the MultiSet License. You may not use this file except in compliance with the License. and you can't re-distribute this file without a prior notice
For license details, visit www.multiset.ai.
Redistribution in source or binary forms must retain this notice.
*/

import Foundation
import RealityKit
import simd

/// A parsed glTF node. Built off the main thread; renderers turn it into entities on it.
/// `Primitive` is whatever the renderer's `prepare` step produced for each primitive.
internal struct GLBNode<Primitive: Sendable>: Sendable {
    let transform: Transform
    let primitives: [Primitive]
    let children: [GLBNode<Primitive>]
}

/// A primitive ready to draw
internal struct GLBPrimitive: Sendable {
    let positions: [SIMD3<Float>]
    let normals: [SIMD3<Float>]
    let indices: [UInt32]
}

/// A primitive's buffers exactly as the file stores them
internal struct GLBRawPrimitive {
    let positions: [SIMD3<Float>]
    /// Empty when the primitive has no NORMAL attribute
    let normals: [SIMD3<Float>]
    /// Nil when the primitive has no index accessor
    let indices: [UInt32]?

    var sequentialIndices: [UInt32] {
        (0..<UInt32(positions.count)).map { $0 }
    }
}

/// Binary glTF parser shared by the map and object mesh renderers. It does no RealityKit
/// work, so it runs off the main thread.
// Reads are unaligned: some exporters leave bufferViews unpadded, so floats land on 2-byte offsets.
internal enum GLBParser {

    /// - Parameter prepare: Turns a primitive into what the renderer draws, or nil to skip it
    static func parse<Primitive: Sendable>(_ data: Data, preparing prepare: (GLBRawPrimitive) -> Primitive?) throws -> [GLBNode<Primitive>] {
        guard data.count >= 12 else {
            throw GLBError.invalidHeader
        }

        let magic = data.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: 0, as: UInt32.self) }
        guard magic == 0x46546C67 else {
            throw GLBError.invalidMagic
        }

        var offset = 12
        var jsonData: Data?
        var binaryData: Data?

        while offset < data.count {
            guard offset + 8 <= data.count else { break }

            let chunkLength = data.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: offset, as: UInt32.self) }
            let chunkType = data.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: offset + 4, as: UInt32.self) }

            offset += 8

            guard offset + Int(chunkLength) <= data.count else { break }

            let chunkData = data.subdata(in: offset..<(offset + Int(chunkLength)))

            if chunkType == 0x4E4F534A {
                jsonData = chunkData
            } else if chunkType == 0x004E4942 {
                binaryData = chunkData
            }

            offset += Int(chunkLength)
        }

        guard let json = jsonData, let binary = binaryData else {
            throw GLBError.missingChunks
        }

        let gltf = try JSONDecoder().decode(GLTFRoot.self, from: json)
        return try buildNodesFromGLTF(gltf: gltf, binaryData: binary, prepare: prepare)
    }

    private static func buildNodesFromGLTF<Primitive: Sendable>(gltf: GLTFRoot, binaryData: Data,
                                                                prepare: (GLBRawPrimitive) -> Primitive?) throws -> [GLBNode<Primitive>] {
        guard let meshes = gltf.meshes, !meshes.isEmpty else {
            throw GLBError.noMeshes
        }

        // Walk the scene graph via nodes to respect transforms
        if let nodes = gltf.nodes, let scenes = gltf.scenes, let sceneIndex = gltf.scene,
           sceneIndex < scenes.count, let rootNodeIndices = scenes[sceneIndex].nodes {
            return try rootNodeIndices.map { nodeIndex in
                try buildNode(nodeIndex: nodeIndex, nodes: nodes, meshes: meshes,
                              gltf: gltf, binaryData: binaryData, prepare: prepare)
            }
        }

        // Fallback: no scene graph, iterate meshes directly (original behavior)
        return try meshes.map { mesh in
            try buildMeshNode(mesh: mesh, gltf: gltf, binaryData: binaryData, prepare: prepare)
        }
    }

    private static func buildNode<Primitive: Sendable>(nodeIndex: Int, nodes: [GLTFNode], meshes: [GLTFMesh],
                                                       gltf: GLTFRoot, binaryData: Data,
                                                       prepare: (GLBRawPrimitive) -> Primitive?) throws -> GLBNode<Primitive> {
        let node = nodes[nodeIndex]
        var transform = Transform.identity

        // Apply node transform
        if let matrix = node.matrix, matrix.count == 16 {
            // Column-major 4x4 matrix
            let col0 = SIMD4<Float>(matrix[0], matrix[1], matrix[2], matrix[3])
            let col1 = SIMD4<Float>(matrix[4], matrix[5], matrix[6], matrix[7])
            let col2 = SIMD4<Float>(matrix[8], matrix[9], matrix[10], matrix[11])
            let col3 = SIMD4<Float>(matrix[12], matrix[13], matrix[14], matrix[15])
            transform = Transform(matrix: float4x4(col0, col1, col2, col3))
        } else {
            if let t = node.translation, t.count == 3 {
                transform.translation = SIMD3<Float>(t[0], t[1], t[2])
            }
            if let r = node.rotation, r.count == 4 {
                // glTF quaternion order: [x, y, z, w]
                transform.rotation = simd_quatf(ix: r[0], iy: r[1], iz: r[2], r: r[3])
            }
            if let s = node.scale, s.count == 3 {
                transform.scale = SIMD3<Float>(s[0], s[1], s[2])
            }
        }

        var children: [GLBNode<Primitive>] = []

        // If this node references a mesh, build it
        if let meshIndex = node.mesh, meshIndex < meshes.count {
            children.append(try buildMeshNode(mesh: meshes[meshIndex], gltf: gltf,
                                              binaryData: binaryData, prepare: prepare))
        }

        // Recurse into children
        if let childIndices = node.children {
            for childIndex in childIndices where childIndex < nodes.count {
                children.append(try buildNode(
                    nodeIndex: childIndex, nodes: nodes, meshes: meshes,
                    gltf: gltf, binaryData: binaryData, prepare: prepare
                ))
            }
        }

        return GLBNode(transform: transform, primitives: [], children: children)
    }

    private static func buildMeshNode<Primitive: Sendable>(mesh: GLTFMesh, gltf: GLTFRoot, binaryData: Data,
                                                           prepare: (GLBRawPrimitive) -> Primitive?) throws -> GLBNode<Primitive> {
        var primitives: [Primitive] = []

        for primitive in mesh.primitives {
            guard let positionAccessorIndex = primitive.attributes["POSITION"],
                  let accessors = gltf.accessors,
                  positionAccessorIndex < accessors.count else {
                continue
            }

            let positionAccessor = accessors[positionAccessorIndex]

            let positions = try extractVec3Data(
                accessor: positionAccessor,
                bufferViews: gltf.bufferViews ?? [],
                binaryData: binaryData
            )

            var normals: [SIMD3<Float>] = []
            if let normalAccessorIndex = primitive.attributes["NORMAL"],
               normalAccessorIndex < accessors.count {
                let normalAccessor = accessors[normalAccessorIndex]
                normals = try extractVec3Data(
                    accessor: normalAccessor,
                    bufferViews: gltf.bufferViews ?? [],
                    binaryData: binaryData
                )
            }

            var indices: [UInt32]?
            if let indicesAccessorIndex = primitive.indices,
               indicesAccessorIndex < accessors.count {
                let indicesAccessor = accessors[indicesAccessorIndex]
                indices = try extractIndices(
                    accessor: indicesAccessor,
                    bufferViews: gltf.bufferViews ?? [],
                    binaryData: binaryData
                )
            }

            let raw = GLBRawPrimitive(positions: positions, normals: normals, indices: indices)
            if let prepared = prepare(raw) {
                primitives.append(prepared)
            }
        }

        return GLBNode(transform: .identity, primitives: primitives, children: [])
    }

    private static func extractVec3Data(accessor: GLTFAccessor, bufferViews: [GLTFBufferView], binaryData: Data) throws -> [SIMD3<Float>] {
        guard let bufferViewIndex = accessor.bufferView,
              bufferViewIndex < bufferViews.count else {
            throw GLBError.invalidBufferView
        }

        let bufferView = bufferViews[bufferViewIndex]
        let byteOffset = (bufferView.byteOffset ?? 0) + (accessor.byteOffset ?? 0)
        let byteStride = bufferView.byteStride ?? 12

        var result: [SIMD3<Float>] = []
        result.reserveCapacity(accessor.count)

        binaryData.withUnsafeBytes { ptr in
            for i in 0..<accessor.count {
                let offset = byteOffset + (i * byteStride)
                let x = ptr.loadUnaligned(fromByteOffset: offset, as: Float.self)
                let y = ptr.loadUnaligned(fromByteOffset: offset + 4, as: Float.self)
                let z = ptr.loadUnaligned(fromByteOffset: offset + 8, as: Float.self)
                result.append(SIMD3<Float>(x, y, z))
            }
        }

        return result
    }

    private static func extractIndices(accessor: GLTFAccessor, bufferViews: [GLTFBufferView], binaryData: Data) throws -> [UInt32] {
        guard let bufferViewIndex = accessor.bufferView,
              bufferViewIndex < bufferViews.count else {
            throw GLBError.invalidBufferView
        }

        let bufferView = bufferViews[bufferViewIndex]
        let byteOffset = (bufferView.byteOffset ?? 0) + (accessor.byteOffset ?? 0)

        var result: [UInt32] = []
        result.reserveCapacity(accessor.count)

        binaryData.withUnsafeBytes { ptr in
            for i in 0..<accessor.count {
                let index: UInt32
                switch accessor.componentType {
                case 5121:
                    let offset = byteOffset + i
                    index = UInt32(ptr.load(fromByteOffset: offset, as: UInt8.self))
                case 5123:
                    let offset = byteOffset + (i * 2)
                    index = UInt32(ptr.loadUnaligned(fromByteOffset: offset, as: UInt16.self))
                case 5125:
                    let offset = byteOffset + (i * 4)
                    index = ptr.loadUnaligned(fromByteOffset: offset, as: UInt32.self)
                default:
                    index = 0
                }
                result.append(index)
            }
        }

        return result
    }
}

// MARK: - GLB/GLTF Data Structures

internal enum GLBError: Error {
    case invalidHeader
    case invalidMagic
    case missingChunks
    case noMeshes
    case invalidBufferView
    case invalidAccessor
}

internal struct GLTFRoot: Codable {
    let asset: GLTFAsset?
    let scene: Int?
    let scenes: [GLTFScene]?
    let nodes: [GLTFNode]?
    let meshes: [GLTFMesh]?
    let accessors: [GLTFAccessor]?
    let bufferViews: [GLTFBufferView]?
    let buffers: [GLTFBuffer]?
    let materials: [GLTFMaterial]?
}

internal struct GLTFAsset: Codable {
    let version: String
    let generator: String?
}

internal struct GLTFScene: Codable {
    let name: String?
    let nodes: [Int]?
}

internal struct GLTFNode: Codable {
    let name: String?
    let mesh: Int?
    let children: [Int]?
    let translation: [Float]?
    let rotation: [Float]?
    let scale: [Float]?
    let matrix: [Float]?
}

internal struct GLTFMesh: Codable {
    let name: String?
    let primitives: [GLTFPrimitive]
}

internal struct GLTFPrimitive: Codable {
    let attributes: [String: Int]
    let indices: Int?
    let material: Int?
    let mode: Int?
}

internal struct GLTFAccessor: Codable {
    let bufferView: Int?
    let byteOffset: Int?
    let componentType: Int
    let count: Int
    let type: String
    let max: [Float]?
    let min: [Float]?
}

internal struct GLTFBufferView: Codable {
    let buffer: Int
    let byteOffset: Int?
    let byteLength: Int
    let byteStride: Int?
    let target: Int?
}

internal struct GLTFBuffer: Codable {
    let byteLength: Int
    let uri: String?
}

internal struct GLTFMaterial: Codable {
    let name: String?
    let pbrMetallicRoughness: GLTFPBRMetallicRoughness?
    let doubleSided: Bool?
}

internal struct GLTFPBRMetallicRoughness: Codable {
    let baseColorFactor: [Float]?
    let metallicFactor: Float?
    let roughnessFactor: Float?
}
