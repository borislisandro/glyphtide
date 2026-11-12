#version 440

// Pass 1 — the field.
// Rendered at ONE PIXEL PER CHARACTER CELL (cols x rows), so all the noise
// work happens a few thousand times per frame instead of millions.
// Output: rgb = glyph colour, a = glyph density (0 = blank, 1 = densest glyph).

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;
    float zoom;
    float seed;
    vec2 grid;   // cols, rows
    vec2 cell;   // cell size in px
    vec4 colorA; // primary  (crimson)
    vec4 colorB; // warm     (orange)
    vec4 colorC; // accent   (magenta)
    vec4 colorD; // deep     (dark red)
};

vec3 hash3(vec3 p)
{
    p = vec3(dot(p, vec3(127.1, 311.7, 74.7)),
             dot(p, vec3(269.5, 183.3, 246.1)),
             dot(p, vec3(113.5, 271.9, 124.6)));
    return -1.0 + 2.0 * fract(sin(p) * 43758.5453123);
}

// 3D gradient noise, quintic interpolation, roughly [-0.7, 0.7]
float noise(vec3 p)
{
    vec3 i = floor(p);
    vec3 f = fract(p);
    vec3 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);

    return mix(mix(mix(dot(hash3(i + vec3(0, 0, 0)), f - vec3(0, 0, 0)),
                       dot(hash3(i + vec3(1, 0, 0)), f - vec3(1, 0, 0)), u.x),
                   mix(dot(hash3(i + vec3(0, 1, 0)), f - vec3(0, 1, 0)),
                       dot(hash3(i + vec3(1, 1, 0)), f - vec3(1, 1, 0)), u.x), u.y),
               mix(mix(dot(hash3(i + vec3(0, 0, 1)), f - vec3(0, 0, 1)),
                       dot(hash3(i + vec3(1, 0, 1)), f - vec3(1, 0, 1)), u.x),
                   mix(dot(hash3(i + vec3(0, 1, 1)), f - vec3(0, 1, 1)),
                       dot(hash3(i + vec3(1, 1, 1)), f - vec3(1, 1, 1)), u.x), u.y), u.z);
}

// One translucent "sheet": domain-warped noise, so the outline is a soft
// organic lobe that slowly changes shape instead of just sliding.
float sheet(vec2 p, float t, float k)
{
    vec3 q = vec3(p * 0.6, t * 0.6);
    vec2 w = vec2(noise(q + vec3(k, 0.0, 1.7)),
                  noise(q + vec3(5.2, k, 8.3)));
    return noise(vec3(p + 1.1 * w, t + k * 3.1));
}

// Composite a sheet over what is already there.
// d is the distance to the sheet's outline in screen pixels (negative outside),
// estimated from the noise gradient so the rim has a constant width on screen.
// The rim is the densest part; inside, the sheet thins out to a light stipple
// crossed by fading echo lines of the outline, like contour lines on a map.
void blend(inout vec3 col, inout float v, float n, float th, vec3 cIn, vec3 cRim, float alpha)
{
    float e = n - th;
    vec2 grad = vec2(dFdx(n) / cell.x, dFdy(n) / cell.y);
    float d = e / max(length(grad), 1e-5);

    float m = smoothstep(-4.0, 6.0, d);
    float depth = smoothstep(4.0, 54.0, d);

    float r = (fract(d / 110.0) - 0.5) * 5.0;
    float ring = exp(-r * r) * depth * exp(-max(d, 0.0) / 420.0);
    float inten = mix(1.0, 0.13, depth) + 0.50 * ring;
    vec3 c = mix(cRim, cIn, depth * (1.0 - 0.7 * ring));

    // faint halo just outside the rim
    float h = exp(min(d, 0.0) / 16.0) * smoothstep(-0.07, 0.0, e) * (1.0 - m) * 0.16;
    col = mix(col, cRim, h / max(h + v, 1e-4));
    v = v + h * (1.0 - v);

    float a = m * alpha;
    col = mix(col, c, a);
    v = mix(v, inten, a);
}

void main()
{
    vec2 px = qt_TexCoord0 * grid * cell;
    vec2 p = px / (680.0 * zoom) + vec2(seed * 3.7, seed * 1.9);
    float t = time * 0.035;

    vec3 col = vec3(0.0);
    float v = 0.0;

    vec3 A = colorA.rgb, B = colorB.rgb, C = colorC.rgb, D = colorD.rgb;

    // back to front
    blend(col, v, sheet(p * 0.50 + vec2(t * 0.20, 0.0), t * 0.8, 1.0), 0.16, D * 0.75, mix(D, A, 0.6), 0.90);
    blend(col, v, sheet(p * 0.66 - vec2(0.0, t * 0.25), t * 1.0, 2.0), 0.20, mix(D, A, 0.55), A, 0.88);
    blend(col, v, sheet(p * 0.85 + vec2(-t * 0.30, t * 0.15), t * 1.2, 3.0), 0.25, mix(A, B, 0.45), B, 0.86);
    blend(col, v, sheet(p * 1.05 + vec2(t * 0.25, t * 0.30), t * 1.4, 4.0), 0.31, mix(C, D, 0.45), C, 0.84);

    fragColor = vec4(col, clamp(v, 0.0, 1.0));
}
