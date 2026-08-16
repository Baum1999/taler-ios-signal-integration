//
//  Shaders.metal
//

#include <metal_stdlib>
using namespace metal;

// https://stackoverflow.com/questions/12964279/whats-the-origin-of-this-glsl-rand-one-liner
float hashVal(float2 p) {
    return fract(sin(dot(p, float2(12.9898, 78.233))) * 43758.5453);
}

float noiseFrom(float2 p) {
    float2 intVal = floor(p);
    float2 fraction = fract(p);
    fraction = fraction * fraction * (3.0 - 2.0 * fraction);
    float a = hashVal(intVal);
    float b = hashVal(intVal + float2(1.0, 0.0));
    float c = hashVal(intVal + float2(0.0, 1.0));
    float d = hashVal(intVal + float2(1.0, 1.0));
    return mix(mix(a, b, fraction.x), mix(c, d, fraction.x), fraction.y);
}

// MARK: -
/// The first two parameters are required by SwiftUI: it will automatically pass the position of the view, and its current color.
/// The remaining parameters are created by us, and need to be passed by the caller.
[[ stitchable ]] half4 liquidBack(float2 position, half4 color, float2 size, float time) {
    /// we don't use the original color
    float t = time * 0.3;
    float2 uv2 = (position * 2.0 - size) * 2.0 / min(size.x, size.y);
    float noisA = noiseFrom(uv2 + float2(t, t * 0.6));
    float noisB = noiseFrom(uv2 + noisA * 1.5 + float2(-t * 0.4, t * 0.3));
    float noise = noiseFrom(uv2 * 1.5 + noisB * 1.2 + float2(t * 0.2, -t * 0.5));

    float3 silver = float3(0.2, 0.2, 0.25);
    float3 highlight = float3(0.5, 0.5, 0.6);
    float3 shadow = float3(0.02, 0.01, 0.05);
    float3 tint = float3(0.706, 0.773, 1.0);       // Taler dark:(0.0, 0.259, 0.702) is too blue, but light (0.706, 0.773, 1.0) is fine

    float chrome = pow(noise * 0.5 + 0.5, 0.6);
    float3 color3 = mix(shadow, silver, chrome);
    color3 = mix(color3, highlight, smoothstep(0.8, 0.98, chrome));
    color3 += tint * smoothstep(0.3, 0.6, noisA) * 0.15;

    // Add some highlights
    float spec = pow(max(chrome, 0.0), 12.0);
    color3 += float3(0.6, 0.6, 0.8) * spec * 0.3;

    return half4(half3(color3), 1.0);
}
