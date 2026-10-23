/*
Copyright (c) 2026 MultiSet AI. All rights reserved.
Licensed under the MultiSet License. You may not use this file except in compliance with the License.
For license details, visit www.multiset.ai.

Shaders for what is drawn over the room while a map is scanned: the reconstruction's
surface, and the posed-RGB scan's feature points.
*/

#include <metal_stdlib>
#include <RealityKit/RealityKit.h>
using namespace metal;

// Faceted tone patches over the class colour, which the CPU sets per material.
[[visible]] void scanMeshSurface(realitykit::surface_parameters params) {
    float3 world = params.geometry().world_position();
    // Only the face normal's dominant axis matters: it picks the plane the pattern lies on.
    float3 axis = abs(cross(dfdx(world), dfdy(world)));
    float2 plane = axis.y >= axis.x && axis.y >= axis.z ? world.xz :
                   (axis.x >= axis.z ? world.zy : world.xy);

    float2 grid = plane / 0.175; // 17.5 cm patches, fixed to the world
    float2 cell = floor(grid);
    float2 local = fract(grid);
    float triangle = step(1.0, local.x + local.y);
    // Hash-without-sine (after Dave Hoskins): no per-fragment sine, no texture lookup.
    float3 hash = fract(float3(cell, triangle) * 0.1031);
    hash += dot(hash, hash.yzx + 33.33);
    float variation = fract((hash.x + hash.y) * hash.z);
    float band = floor(variation * 5.0) / 4.0;

    // ±14% brightness, faded where a patch is under a pixel so distance doesn't shimmer.
    float footprint = max(length(dfdx(grid)), length(dfdy(grid)));
    float contrast = 0.14 * (1.0 - smoothstep(0.15, 0.65, footprint));
    half3 color = half3(params.uniforms().custom_parameter().xyz);
    color *= half(1.0 + (band * 2.0 - 1.0) * contrast);

    params.surface().set_base_color(half3(0.0));
    params.surface().set_specular(0.0h);
    params.surface().set_metallic(0.0h);
    params.surface().set_roughness(1.0h);
    params.surface().set_emissive_color(color);
    params.surface().set_opacity(half(params.material_constants().opacity_scale()));
}

// The posed-RGB coverage points. Every corner of a point's quad is stored at the point
// itself, with uv0 naming the corner; the quad is opened here in the view's own plane, so
// it always faces the camera. custom_parameter is (glow colour, sprite radius in metres).
[[visible]] void scanFeaturePointGeometry(realitykit::geometry_parameters params) {
    float radius = params.uniforms().custom_parameter().w;
    float2 corner = params.geometry().uv0() * 2.0 - 1.0;
    float4x4 modelToView = params.uniforms().model_to_view();
    // The transpose of a rotation is its inverse: rows of model→view are the view's axes in model space.
    float3 right = float3(modelToView[0].x, modelToView[1].x, modelToView[2].x);
    float3 up = float3(modelToView[0].y, modelToView[1].y, modelToView[2].y);
    params.geometry().set_model_position_offset((right * corner.x + up * corner.y) * radius);
}

// A soft round glow: a near-white core fading through the colour to a transparent rim.
[[visible]] void scanFeaturePointSurface(realitykit::surface_parameters params) {
    float distance = length(params.geometry().uv0() * 2.0 - 1.0);
    if (distance > 1.0) {
        discard_fragment();
    }
    half core = half(1.0 - smoothstep(0.0, 0.4, distance));
    half halo = half(pow(saturate(1.0 - distance), 1.6));
    half3 glow = half3(params.uniforms().custom_parameter().xyz);
    half3 color = mix(glow, half3(1.0h, 1.0h, 0.85h), core * 0.7h);

    params.surface().set_base_color(half3(0.0));
    params.surface().set_specular(0.0h);
    params.surface().set_metallic(0.0h);
    params.surface().set_roughness(1.0h);
    params.surface().set_emissive_color(color);
    params.surface().set_opacity(saturate(core + halo));
}
