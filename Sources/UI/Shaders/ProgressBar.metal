// The progress bar's fill: Figma's halftone dots over the gradient, drawn per pixel
// on the GPU. It's static — redrawn only when the progress changes; the passing
// light is a Core Animation layer on top (ProgressLight).
#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

/// - position: the pixel, in points within the fill
/// - color: the fill's gradient at this pixel (from SwiftUI)
/// - size: the fill's size in points
/// - dotStart, dotEnd: the dots' gradient, left to right
[[stitchable]] half4 progressFill(float2 position, half4 color, float2 size,
                                  half4 dotStart, half4 dotEnd) {
    float x = position.x / max(size.x, 1.0);

    // How far inside the capsule this pixel is, in points: 0 on its outline.
    float r = size.y * 0.5;
    float2 axis = float2(clamp(position.x, r, max(size.x - r, r)), r);
    float inside = r - distance(position, axis);

    // Dots on a staggered 3 pt grid, slightly larger toward the leading edge, and
    // shrinking toward the outline so the texture wraps the capsule's curve.
    const float cell = 3.0;
    float row = floor(position.y / cell);
    float2 p = float2(position.x + fmod(row, 2.0) * cell * 0.5, position.y);
    float2 center = (floor(p / cell) + 0.5) * cell;
    float radius = cell * mix(0.26, 0.38, x) * smoothstep(0.0, 4.0, inside);
    float dot = 1.0 - smoothstep(radius - 0.4, radius + 0.4, distance(p, center));

    half4 dots = mix(dotStart, dotEnd, half(x));
    half4 result = mix(color, dots, half(dot) * dots.a);

    return result;
}
