/*
Copyright (c) 2026 MultiSet AI. All rights reserved.
Licensed under the MultiSet License. You may not use this file except in compliance with the License.
For license details, visit www.multiset.ai.
*/

#include <metal_stdlib>
#include <RealityKit/RealityKit.h>

using namespace metal;

// MARK: - Grid Calculation

// Projects world position onto a 2D grid based on the dominant surface normal.
// picks the best projection plane per face
// so flat floors only show XZ grid lines (not a solid fill).
float getGridFactor(float3 worldPos, float3 surfaceNormal, float gridSize, float lineWidth) {
    float3 absNormal = abs(surfaceNormal);
    float2 gridCoord;

    // Choose projection plane based on dominant normal axis
    if (absNormal.y > absNormal.x && absNormal.y > absNormal.z) {
        // Floor/ceiling → project onto XZ
        gridCoord = float2(worldPos.x, worldPos.z) / gridSize;
    } else if (absNormal.x > absNormal.z) {
        // Side wall → project onto YZ
        gridCoord = float2(worldPos.y, worldPos.z) / gridSize;
    } else {
        // Front/back wall → project onto XY
        gridCoord = float2(worldPos.x, worldPos.y) / gridSize;
    }

    float2 gridFract = fract(abs(gridCoord));
    float2 distToLine = min(gridFract, 1.0 - gridFract);
    float minDistToLine = min(distToLine.x, distToLine.y);
    float gridFactor = 1.0 - smoothstep(0.0, lineWidth, minDistToLine);

    return gridFactor;
}

// MARK: - Radial Reveal Surface Shader

[[visible]]
void radialRevealSurface(realitykit::surface_parameters params) {
    // Unpack custom parameters
    // xyz = center position in model space
    // w   = current reveal radius (progress * maxRadius)
    float4 customParam = params.uniforms().custom_parameter();
    float3 center = customParam.xyz;
    float currentRadius = customParam.w;

    // Get fragment position in model space (same coordinate system as center)
    float3 modelPos = params.geometry().model_position();

    // Calculate distance from fragment to reveal center
    float dist = distance(modelPos, center);

    // Clip fragments beyond the current reveal radius
    if (dist > currentRadius) {
        params.surface().set_opacity(0.0h);
        return;
    }

    // Base mesh color: #5B1D99 (darker purple), alpha 100/255 (~0.39)
    constexpr half3 baseColor = half3(0.357h, 0.114h, 0.6h);
    constexpr half baseAlpha = 0.39h;

    // --- Edge Glow ---
    constexpr half3 glowColor = half3(1.0h, 0.227h, 0.0h); // #FF3A00
    constexpr float glowWidthFactor = 0.10; // 10% of current radius
    constexpr half glowIntensity = 2.0h;

    float glowWidth = max(currentRadius * glowWidthFactor, 0.1);
    float distFromEdge = currentRadius - dist;

    // Glow is strongest at the edge (distFromEdge near 0) and fades inward
    float glowFactor = saturate(1.0 - saturate(distFromEdge / glowWidth));
    glowFactor = glowFactor * glowFactor; // Square for sharper falloff

    half3 glowContribution = glowColor * half(glowFactor) * glowIntensity;

    // --- Grid Overlay ---
    constexpr half3 gridColor = half3(1.0h, 1.0h, 0.0h); // #FFFF00
    constexpr float gridSize = 1.0;
    constexpr float gridLineWidth = 0.02;

    float3 worldPos = params.geometry().world_position();

    // Compute surface normal from screen-space derivatives of world position.
    // This gives us the face normal without needing vertex normals from the API.
    float3 dpdx_val = dfdx(worldPos);
    float3 dpdy_val = dfdy(worldPos);
    float3 surfaceNormal = normalize(cross(dpdx_val, dpdy_val));

    float gridFactor = getGridFactor(worldPos, surfaceNormal, gridSize, gridLineWidth);

    // --- Compose Final Color ---
    half3 finalColor = mix(baseColor, gridColor, half(gridFactor));
    half finalAlpha = max(baseAlpha, half(gridFactor) * 0.8h);

    // Add glow
    finalColor += glowContribution;
    finalAlpha = max(finalAlpha, half(glowFactor));

    // Output all color through emissive channel to bypass RealityKit's
    // color pipeline dimming. This ensures colors appear at true brightness.
    params.surface().set_base_color(half3(0.0h));
    params.surface().set_emissive_color(finalColor);
    params.surface().set_opacity(finalAlpha);
}
