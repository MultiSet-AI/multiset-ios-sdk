/*
Copyright (c) 2026 MultiSet AI. All rights reserved.
Licensed under the MultiSet License. You may not use this file except in compliance with the License.
For license details, visit www.multiset.ai.

Outline shader for object tracking meshes — a port of the Unity app's
`Custom/UniversalOutlineOnly` (Assets/Shader/OutlineOnly.shader) with the values of its
`OutlineMat` material. Two entities stand in for Unity's two passes: an occlusion mesh
for the depth-only "HideMesh" pass, and this shell, expanded along the normals and drawn
with its winding reversed so RealityKit's default back-face culling acts as Unity's
`Cull Front`.
*/

#include <metal_stdlib>
#include <RealityKit/RealityKit.h>

using namespace metal;

// OutlineMat.mat
constant half3 kOutlineColor = half3(0.31950867h, 0.1014151h, 0.5h);
constant half kOutlineAlpha = 0.5882353h;
constant float kGlowIntensity = 4.0;
constant float kSparkSpeed = 3.0;
constant float kSparkFrequency = 8.0;
constant float kSparkIntensity = 3.0;
constant float kRimPower = 2.0;
constant float kRimIntensity = 0.7;

float outlineHash(float2 p) {
    return fract(sin(dot(p, float2(127.1, 311.7))) * 43758.5453123);
}

float outlineNoise(float2 p) {
    float2 i = floor(p);
    float2 f = fract(p);
    float a = outlineHash(i);
    float b = outlineHash(i + float2(1.0, 0.0));
    float c = outlineHash(i + float2(0.0, 1.0));
    float d = outlineHash(i + float2(1.0, 1.0));
    float2 u = f * f * (3.0 - 2.0 * f);
    return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

// Unity's vertex pass: push every vertex out along its normal by the outline width.
// custom_parameter.x = outline width in model units.
[[visible]]
void outlineGeometry(realitykit::geometry_parameters params) {
    float width = params.uniforms().custom_parameter().x;
    params.geometry().set_model_position_offset(params.geometry().normal() * width);
}

// Unity's "SparkOutlineEdges" fragment pass.
[[visible]]
void outlineSurface(realitykit::surface_parameters params) {
    float3 normal = normalize(params.geometry().normal());
    float3 viewDir = normalize(params.geometry().view_direction());
    float3 modelPos = params.geometry().model_position();
    float time = params.uniforms().time() * kSparkSpeed;

    // The shell is drawn inside-out, so its normals point away from the viewer; the rim
    // Unity computes on the front-culled shell is the same quantity with the sign flipped.
    float facing = abs(dot(normal, viewDir));
    float rim = pow(saturate(1.0 - facing), kRimPower) * kRimIntensity;

    float2 sparkCoord1 = modelPos.xy * kSparkFrequency;
    float spark1 = pow(saturate(outlineNoise(sparkCoord1 + time * 0.5)), 2.0);
    float2 sparkCoord2 = modelPos.xz * kSparkFrequency * 1.7;
    float spark2 = pow(saturate(outlineNoise(sparkCoord2 - time * 0.3)), 3.0);
    float wave = pow(saturate(sin(modelPos.y * 10.0 - time * 3.0) * 0.5 + 0.5), 2.0);

    float sparkMask = step(0.6, outlineHash(floor(sparkCoord1)));
    float combinedSpark = max(mix(spark1, spark2, 0.5) * sparkMask, wave * 0.3);
    float pulse = sin(time * 2.0) * 0.3 + 0.7;
    float animation = (1.0 + combinedSpark * kSparkIntensity) * pulse;

    half3 color = kOutlineColor * half(kGlowIntensity * animation) * half(rim * 0.7 + 0.3);
    half alpha = half((rim * 0.6 + 0.4) * saturate(animation * 0.5)) * kOutlineAlpha;

    // Unlit: RealityKit takes the colour from base_color; emissive is set as well so
    // the glow survives a lighting model change.
    params.surface().set_base_color(color);
    params.surface().set_emissive_color(color);
    params.surface().set_opacity(alpha);
}
