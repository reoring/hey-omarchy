#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 screenSize;
    vec4 drawRect;
    vec4 drop;
    vec4 flow;
    vec2 appearance;
};
layout(binding = 1) uniform sampler2D wallpaper;

float pathX(float y) {
    return flow.x + 3.0 * sin(y * 0.026 + flow.y)
        + 1.2 * sin(y * 0.071 + flow.y * 1.7);
}

void main() {
    vec2 pixel = drawRect.xy + qt_TexCoord0 * drawRect.zw;
    float radius = max(drop.z, 0.1);
    float slide = clamp(drop.w - 1.0, 0.0, 2.5);
    float impact = clamp(appearance.x, 0.0, 1.0);

    // A drop keeps its own silhouette for its lifetime; motion never re-rolls it.
    vec4 shape = fract(flow.y * vec4(0.1031, 0.11369, 0.13787, 0.09987));
    shape += dot(shape, shape.wzxy + 33.33);
    shape = fract((shape.xxyz + shape.yzzw) * shape.zywx);
    float aspect = sqrt(mix(0.72, 1.32, shape.x));
    float lean = mix(-0.26, 0.26, shape.y) / (1.0 + 0.60 * slide);
    float upperWidth = mix(0.45, 1.0, shape.z);
    float lowerWidth = mix(0.94, 1.06, shape.y);
    float shoulderEnd = mix(0.10, 0.70, shape.w);
    float ripple = mix(0.04, 0.14, shape.w);
    float rippleFrequency = mix(2.6, 5.0, shape.z);

    // Impact spreads the cap; sliding stretches it without erasing its character.
    float radiusX = radius * aspect * (1.0 + 0.55 * impact) / sqrt(1.0 + 0.24 * slide);
    float radiusY = radius / aspect * (1.0 + 0.50 * slide) * (1.0 - 0.35 * impact);
    float path = pathX(pixel.y);
    float headPath = drop.x + path - pathX(drop.y) + (pixel.y - drop.y) * lean;
    float y = (pixel.y - drop.y) / radiusY;
    float shoulder = smoothstep(-1.0, shoulderEnd, y);
    float profile = mix(upperWidth, lowerWidth, shoulder);
    float irregularity = 1.0 + ripple * sin(flow.y * 2.3 + y * rippleFrequency);
    float width = profile * irregularity;
    vec2 q = vec2((pixel.x - headPath) / (radiusX * width), y);
    float distanceToHead = length(q);
    float headAA = max(fwidth(distanceToHead), 0.001);
    float headCoverage = 1.0 - smoothstep(1.0 - headAA, 1.0 + headAA, distanceToHead);
    float headAlpha = headCoverage * 0.86;

    // The trail records actual travel only. It is a thin wet film, not another
    // elongated bead; its upstream end fades and the simulator dries it out.
    float trailLength = max(drop.y - flow.z, 0.0);
    float along = clamp((pixel.y - flow.z) / max(trailLength, 0.001), 0.0, 1.0);
    float trailWidth = 0.35 + min(1.8, radius * 0.18) * pow(along, 1.4);
    float trailDistance = abs(pixel.x - path) - trailWidth;
    float trailAA = max(fwidth(trailDistance), 0.5);
    float trailCoverage = 1.0 - smoothstep(-trailAA, trailAA, trailDistance);
    trailCoverage *= smoothstep(flow.z, flow.z + min(8.0, max(trailLength * 0.25, 0.01)), pixel.y);
    trailCoverage *= 1.0 - smoothstep(drop.y, drop.y + 1.0, pixel.y);
    trailCoverage *= smoothstep(0.5, 3.0, trailLength);
    float trailAlpha = trailCoverage * clamp(flow.w, 0.0, 1.0)
        * (0.10 + 0.30 * along) * sqrt(along);

    float alpha = headAlpha + trailAlpha * (1.0 - headAlpha);
    if (alpha < 0.001) {
        fragColor = vec4(0.0);
        return;
    }

    // A rounded cap bends the wallpaper by only a few logical pixels. The
    // gradient includes the shoulder taper, so the highlight is not an oval rim.
    float shoulderRange = 1.0 + shoulderEnd;
    float shoulderT = clamp((y + 1.0) / shoulderRange, 0.0, 1.0);
    float widthSlope = (lowerWidth - upperWidth)
        * 6.0 * shoulderT * (1.0 - shoulderT) / shoulderRange;
    widthSlope = widthSlope * irregularity
        + profile * ripple * rippleFrequency * cos(flow.y * 2.3 + y * rippleFrequency);
    float pathSlope = 0.078 * cos(pixel.y * 0.026 + flow.y)
        + 0.0852 * cos(pixel.y * 0.071 + flow.y * 1.7);
    vec2 gradient = vec2(q.x / width,
        (q.y - q.x * q.x * widthSlope / width) * radiusX / radiusY
        - q.x * (pathSlope + lean) / width);
    float capHeight = mix(0.65, 1.20, shape.w);
    vec3 normal = normalize(vec3(gradient,
        0.18 + capHeight * sqrt(max(0.0, 1.0 - dot(q, q)))));
    vec2 headBend = -normal.xy * min(8.0, radius * 0.60);
    float trailNormal = clamp((pixel.x - path) / max(trailWidth, 0.1), -1.0, 1.0);
    vec2 trailBend = vec2(-trailNormal, trailNormal * pathSlope) * 0.65;
    float headWeight = headAlpha / max(alpha, 0.001);
    vec2 bend = mix(trailBend, headBend, headWeight);

    // The shared source already matches the screen's PreserveAspectCrop image.
    vec2 size = max(screenSize, vec2(1.0));
    vec2 halfTexel = 0.5 / size;
    vec2 uv = clamp((pixel + bend) / size, halfTexel, vec2(1.0) - halfTexel);
    vec3 color = texture(wallpaper, uv).rgb;

    float crescent = pow(max(dot(normal.xy, vec2(-0.60, -0.80)), 0.0), 5.0);
    crescent *= smoothstep(0.30, 0.72, distanceToHead)
        * (1.0 - smoothstep(0.86, 1.04, distanceToHead));
    float glint = pow(max(dot(normal, normalize(vec3(-0.45, -0.60, 0.66))), 0.0), 32.0);
    float shadow = pow(max(dot(normal.xy, vec2(0.60, 0.80)), 0.0), 3.0)
        * smoothstep(0.45, 0.90, distanceToHead);
    color *= 1.0 - 0.16 * shadow * headWeight;
    color += vec3(0.88, 0.94, 1.0) * (0.50 * crescent + 0.28 * glint) * headWeight;
    color += vec3(0.018) * max(-trailNormal, 0.0) * (1.0 - headWeight);

    alpha *= clamp(appearance.y, 0.0, 1.0) * qt_Opacity;
    fragColor = vec4(color * alpha, alpha);
}
