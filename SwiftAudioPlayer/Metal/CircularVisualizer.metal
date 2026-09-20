//
//  CircularVisualizer.metal
//  SwiftAudioPlayer
//
//  Renders the circular FFT visualizer on the GPU.
//  Each bar is a simple rectangular quad (2 triangles = 6 vertices).
//  No fragment-shader clipping — zero artefacts, maximum performance.
//
//  Uniform buffer(2) — float[6]:
//    [0] bandCount
//    [1] innerRadius   (NDC)
//    [2] maxBarLength  (NDC)
//    [3] barHalfWidth  (NDC)
//    [4] rotation      (radians)
//    [5] minBarLength  (NDC)
//

#include <metal_stdlib>
using namespace metal;

struct VertexOut {
    float4 position [[position]];
    float4 color    [[flat]];
};

vertex VertexOut visualizer_vertex(
    uint              vid    [[vertex_id]],
    constant float*   bands  [[buffer(0)]],
    constant float4*  colors [[buffer(1)]],
    constant float*   u      [[buffer(2)]]
) {
    int   bandCount    = int(u[0]);
    float innerRadius  = u[1];
    float maxBarLength = u[2];
    float barHalfWidth = u[3];
    float rotation     = u[4];
    float minBarLength = u[5];

    int barIndex  = int(vid) / 6;
    int localVert = int(vid) % 6;
    int  bandIndex = barIndex % bandCount;
    bool isLeft    = barIndex >= bandCount;

    float amplitude = clamp(bands[bandIndex], 0.0f, 1.0f);
    float barLength = amplitude * maxBarLength + minBarLength;

    // angleStep = π / (bandCount-1), matching CPUCircularVisualizerView exactly
    float angleStep = M_PI_F / float(max(bandCount - 1, 1));
    float baseAngle = angleStep * float(bandIndex);
    float angle     = (isLeft ? -baseAngle : baseAngle) - M_PI_F / 2.0f + rotation;

    float cosA =  cos(angle);
    float sinA =  sin(angle);
    float tanX = -sinA;
    float tanY =  cosA;

    float2 baseCenter = float2(cosA * innerRadius,               sinA * innerRadius);
    float2 tipCenter  = float2(cosA * (innerRadius + barLength), sinA * (innerRadius + barLength));

    // Four corners of the rectangular bar
    float2 near0 = baseCenter + float2(tanX, tanY) * barHalfWidth;
    float2 near1 = baseCenter - float2(tanX, tanY) * barHalfWidth;
    float2 far0  = tipCenter  + float2(tanX, tanY) * barHalfWidth;
    float2 far1  = tipCenter  - float2(tanX, tanY) * barHalfWidth;

    // Triangle A: near0, far0, near1 — Triangle B: far0, far1, near1
    float2 corners[4]  = {near0, far0, near1, far1};
    int    cornerIdx[6] = {0, 1, 2, 1, 3, 2};

    VertexOut out;
    out.position = float4(corners[cornerIdx[localVert]], 0.0f, 1.0f);
    out.color    = colors[bandIndex];
    return out;
}

fragment float4 visualizer_fragment(VertexOut in [[stage_in]]) {
    return in.color;
}
