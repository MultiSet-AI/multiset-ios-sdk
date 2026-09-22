/*
Copyright (c) 2026 MultiSet AI. All rights reserved.
Licensed under the MultiSet License. You may not use this file except in compliance with the License.
For license details, visit www.multiset.ai.
*/

import Foundation
import RealityKit
import ARKit
import QuartzCore
import simd

/// Drives the radial reveal animation on mesh entities using CustomMaterial.
internal class MeshRevealAnimator {

    // MARK: - Configuration

    /// Whether the animation should loop
    var loop: Bool = true

    /// Delay between loops in seconds
    var delayBetweenLoops: Float = 20.0

    /// Extra padding added to the calculated radius
    var radiusPadding: Float = 5.0

    // Duration scaling reference points (power-curve interpolation)
    private let smallRadius: Float = 20.0
    private let smallRadiusDuration: Float = 5.0
    private let largeRadius: Float = 200.0
    private let largeRadiusDuration: Float = 20.0

    // MARK: - State

    private var displayLink: CADisplayLink?
    private var startTime: CFTimeInterval = 0
    private var animationDuration: Float = 5.0
    private var maxRadius: Float = 10.0
    private var centerModelSpace: SIMD3<Float> = .zero
    private var containerEntity: Entity?
    private var meshEntities: [ModelEntity] = []
    private var isAnimating = false
    private var isPaused = false
    private var pauseEndTime: CFTimeInterval = 0

    /// Weak reference to ARSession for fetching current camera position on loop restarts.
    private weak var arSession: ARSession?

    // MARK: - Public Methods

    /// Start the radial reveal animation from the camera's position.
    /// - Parameters:
    ///   - containerEntity: The parent entity containing ModelEntity children with CustomMaterial
    ///   - cameraWorldPosition: Camera position in world space at the time of localization
    ///   - arSession: AR session reference for updating center on loop restarts
    func startRevealAnimation(containerEntity: Entity, cameraWorldPosition: SIMD3<Float>, arSession: ARSession?) {
        self.containerEntity = containerEntity
        self.arSession = arSession

        // Collect all ModelEntity children
        meshEntities = collectModelEntities(from: containerEntity)
        guard !meshEntities.isEmpty else {
            print("MultiSetSDK >> MeshRevealAnimator: No ModelEntity children found")
            return
        }

        // Set center from initial camera position
        updateCenter(fromWorldPosition: cameraWorldPosition)

        // Calculate max radius from entity bounds
        maxRadius = calculateMaxRadius(entities: meshEntities, center: centerModelSpace)

        // Calculate animation duration from radius
        animationDuration = calculateDuration(fromRadius: maxRadius)

        // Initialize all materials to progress = 0
        updateMaterials(currentRadius: 0)

        // Start display link
        startTime = CACurrentMediaTime()
        isAnimating = true
        isPaused = false

        displayLink = CADisplayLink(target: self, selector: #selector(updateAnimation))
        displayLink?.add(to: .main, forMode: .common)

        print("MultiSetSDK >> MeshRevealAnimator: Started reveal (radius: \(maxRadius), duration: \(animationDuration)s)")
    }

    /// Stop the animation and clean up.
    func stopAnimation() {
        displayLink?.invalidate()
        displayLink = nil
        isAnimating = false
        isPaused = false
        meshEntities.removeAll()
        containerEntity = nil
        arSession = nil
    }

    /// Restart the animation from the beginning with a new camera position.
    func restartAnimation(cameraWorldPosition: SIMD3<Float>) {
        guard let container = containerEntity else { return }
        let session = arSession
        stopAnimation()
        startRevealAnimation(containerEntity: container, cameraWorldPosition: cameraWorldPosition, arSession: session)
    }

    // MARK: - Center Update

    /// Convert a world position to the container entity's model space and set as center.
    private func updateCenter(fromWorldPosition worldPos: SIMD3<Float>) {
        guard let container = containerEntity else { return }

        let containerWorldTransform = container.transformMatrix(relativeTo: nil)
        let invContainerWorld = containerWorldTransform.inverse
        let posInModelSpace = invContainerWorld * SIMD4<Float>(worldPos.x, worldPos.y, worldPos.z, 1.0)
        centerModelSpace = SIMD3<Float>(posInModelSpace.x, posInModelSpace.y, posInModelSpace.z)
    }

    /// Fetch current camera world position from ARSession and update center.
    private func updateCenterFromCamera() {
        guard let frame = arSession?.currentFrame else { return }

        let cameraTransform = frame.camera.transform
        let cameraWorldPos = SIMD3<Float>(cameraTransform.columns.3.x,
                                          cameraTransform.columns.3.y,
                                          cameraTransform.columns.3.z)
        updateCenter(fromWorldPosition: cameraWorldPos)

        // Recalculate max radius from new center
        maxRadius = calculateMaxRadius(entities: meshEntities, center: centerModelSpace)
        animationDuration = calculateDuration(fromRadius: maxRadius)
    }

    // MARK: - Animation Loop

    @objc private func updateAnimation() {
        let now = CACurrentMediaTime()

        if isPaused {
            // Keep mesh fully visible during pause
            updateMaterials(currentRadius: maxRadius)

            if now >= pauseEndTime {
                // Update center to current camera position before restarting
                updateCenterFromCamera()
                isPaused = false
                startTime = now
                updateMaterials(currentRadius: 0)
            }
            return
        }

        let elapsed = Float(now - startTime)
        let progress = min(elapsed / animationDuration, 1.0)
        let currentRadius = progress * maxRadius

        updateMaterials(currentRadius: currentRadius)

        if progress >= 1.0 {
            if loop {
                if delayBetweenLoops > 0 {
                    isPaused = true
                    pauseEndTime = now + Double(delayBetweenLoops)
                } else {
                    // Update center to current camera position before restarting
                    updateCenterFromCamera()
                    startTime = now
                    updateMaterials(currentRadius: 0)
                }
            } else {
                // Animation complete, keep mesh fully visible
                displayLink?.invalidate()
                displayLink = nil
                isAnimating = false
            }
        }
    }

    // MARK: - Material Updates

    private func updateMaterials(currentRadius: Float) {
        let customValue = SIMD4<Float>(centerModelSpace.x, centerModelSpace.y, centerModelSpace.z, currentRadius)

        for entity in meshEntities {
            guard var model = entity.model else { continue }
            var updatedMaterials: [any Material] = []

            for material in model.materials {
                if var customMaterial = material as? CustomMaterial {
                    customMaterial.custom.value = customValue
                    updatedMaterials.append(customMaterial)
                } else {
                    updatedMaterials.append(material)
                }
            }

            model.materials = updatedMaterials
            entity.model = model
        }
    }

    // MARK: - Helpers

    private func collectModelEntities(from entity: Entity) -> [ModelEntity] {
        var result: [ModelEntity] = []
        for child in entity.children {
            if let modelEntity = child as? ModelEntity {
                result.append(modelEntity)
            }
            result.append(contentsOf: collectModelEntities(from: child))
        }
        return result
    }

    private func calculateMaxRadius(entities: [ModelEntity], center: SIMD3<Float>) -> Float {
        var maxDist: Float = 0

        for entity in entities {
            // Get bounding box in model's local space
            let bounds = entity.visualBounds(relativeTo: entity)
            let bMin = bounds.min
            let bMax = bounds.max

            // Check distance from center to all 8 corners of the bounding box
            let corners: [SIMD3<Float>] = [
                SIMD3<Float>(bMin.x, bMin.y, bMin.z),
                SIMD3<Float>(bMax.x, bMin.y, bMin.z),
                SIMD3<Float>(bMin.x, bMax.y, bMin.z),
                SIMD3<Float>(bMax.x, bMax.y, bMin.z),
                SIMD3<Float>(bMin.x, bMin.y, bMax.z),
                SIMD3<Float>(bMax.x, bMin.y, bMax.z),
                SIMD3<Float>(bMin.x, bMax.y, bMax.z),
                SIMD3<Float>(bMax.x, bMax.y, bMax.z)
            ]

            for corner in corners {
                let dist = simd_distance(corner, center)
                maxDist = max(maxDist, dist)
            }
        }

        return maxDist + radiusPadding
    }

    /// Power-curve interpolation for animation duration based on radius.
    private func calculateDuration(fromRadius radius: Float) -> Float {
        let r = max(radius, 1.0)

        // exponent = log(d2/d1) / log(r2/r1)
        let exponent = log(largeRadiusDuration / smallRadiusDuration) / log(largeRadius / smallRadius)

        // coefficient = d1 / (r1^exponent)
        let coefficient = smallRadiusDuration / pow(smallRadius, exponent)

        // duration = coefficient * radius^exponent
        return coefficient * pow(r, exponent)
    }
}
