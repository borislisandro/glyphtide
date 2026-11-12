#version 440

// The field, evaluated in the VERTEX shader.
// The mesh has one vertex per character-cell corner (cols+1 x rows+1), so all
// the noise work runs a few thousand times per frame instead of millions, and
// nothing is rendered to an intermediate texture.
// Output: rgb = glyph colour, a = glyph density (0 = blank, 1 = densest glyph).

layout(location = 0) in vec4 qt_Vertex;
layout(location = 1) in vec2 qt_MultiTexCoord0;

layout(location = 0) out vec2 qt_TexCoord0;
layout(location = 1) out vec4 fieldValue;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;
    float zoom;
    float seed;
    float glyphCount;
    float glow;
    float fade;
    float patternA;   // pattern being shown
    float patternB;   // pattern being morphed to
    float patternMix; // 0 = all A, 1 = all B
    vec2 resolution; // size of the glyph grid in px (cols * cell.x, rows * cell.y)
    vec2 cell;       // cell size in px
    vec4 background;
    vec4 colorA;     // primary  (crimson)
    vec4 colorB;     // warm     (orange)
    vec4 colorC;     // accent   (magenta)
    vec4 colorD;     // deep     (dark red)
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

// Signed distance (in screen pixels, negative outside) from this cell to the
// outline of a sheet. Uses a finite-difference gradient of the noise, so the
// rim keeps a constant on-screen width and the distance varies smoothly in
// both space and time. x = distance, y = raw noise minus threshold.
vec2 outline(vec2 q, float t, float k, float th, float pxPerUnit)
{
    const float h = 0.03;
    float n = sheet(q, t, k);
    vec2 g = vec2(sheet(q + vec2(h, 0.0), t, k) - n,
                  sheet(q + vec2(0.0, h), t, k) - n) / h;
    float e = n - th;
    return vec2(e / max(length(g), 0.04) * pxPerUnit, e);
}

// Composite a sheet over what is already there.
// The rim is the densest part; inside, the sheet thins out to a light stipple
// crossed by fading echo lines of the outline, like contour lines on a map.
void blend(inout vec3 col, inout float v, vec2 o, vec3 cIn, vec3 cRim, float alpha)
{
    float d = o.x;
    float edge = 0.8 * cell.y; // soft enough that a moving rim fades cells in, never pops them

    float m = smoothstep(-0.5 * edge, 0.5 * edge, d);
    float depth = smoothstep(0.3 * edge, 0.3 * edge + 56.0, d);

    float r = (fract(d / 110.0) - 0.5) * 5.0;
    float ring = exp(-r * r) * depth * exp(-max(d, 0.0) / 420.0);
    float inten = mix(1.0, 0.13, depth) + 0.50 * ring;
    vec3 c = mix(cRim, cIn, depth * (1.0 - 0.7 * ring));

    // faint halo just outside the rim
    float h = exp(min(d, 0.0) / 16.0) * smoothstep(-0.07, 0.0, o.y) * (1.0 - m) * 0.16;
    col = mix(col, cRim, h / max(h + v, 1e-4));
    v = v + h * (1.0 - v);

    float a = m * alpha;
    col = mix(col, c, a);
    v = mix(v, inten, a);
}

// ---- pattern 0: Drift — translucent sheets sliding over each other ----------
vec4 fieldDrift(vec2 px)
{
    float unit = 680.0 * zoom; // screen pixels per noise unit
    vec2 p = px / unit + vec2(seed * 3.7, seed * 1.9);
    float t = time * 0.035;

    vec3 col = vec3(0.0);
    float v = 0.0;
    vec3 A = colorA.rgb, B = colorB.rgb, C = colorC.rgb, D = colorD.rgb;

    // back to front
    blend(col, v, outline(p * 0.50 + vec2(t * 0.20, 0.0), t * 0.8, 1.0, 0.16, unit / 0.50), D * 0.75, mix(D, A, 0.6), 0.90);
    blend(col, v, outline(p * 0.66 - vec2(0.0, t * 0.25), t * 1.0, 2.0, 0.20, unit / 0.66), mix(D, A, 0.55), A, 0.88);
    blend(col, v, outline(p * 0.85 + vec2(-t * 0.30, t * 0.15), t * 1.2, 3.0, 0.25, unit / 0.85), mix(A, B, 0.45), B, 0.86);
    blend(col, v, outline(p * 1.05 + vec2(t * 0.25, t * 0.30), t * 1.4, 4.0, 0.31, unit / 1.05), mix(C, D, 0.45), C, 0.84);

    return vec4(col, v);
}

// ---- pattern 1: Dunes — layered ridgelines rolling sideways ------------------
float ridge(float x, float k, float t)
{
    float ph = x * (0.9 + 0.15 * k) + k * 1.7;
    return sin(ph * 1.3 + t * (0.6 + 0.1 * k)) * 0.55
         + noise(vec3(ph * 0.8, k * 3.0, t * 0.5)) * 1.5;
}

vec4 fieldDunes(vec2 px)
{
    float unit = 680.0 * zoom;
    float x = px.x / unit + seed * 2.3;
    float t = time * 0.06;

    vec3 col = vec3(0.0);
    float v = 0.0;
    vec3 A = colorA.rgb, B = colorB.rgb, C = colorC.rgb, D = colorD.rgb;

    for (int i = 0; i < 5; ++i) {
        float k = float(i);
        float amp = (120.0 + 22.0 * k) * zoom;
        float y0 = resolution.y * (0.34 + 0.15 * k);
        float r0 = ridge(x, k, t);
        float slope = (ridge(x + 0.02, k, t) - r0) * amp / (0.02 * unit);
        float d = (px.y - (y0 + amp * r0)) / sqrt(1.0 + slope * slope);

        float f = k / 4.0;
        vec3 rim = mix(mix(D, A, 0.55), mix(A, B, 0.85), f);
        rim = mix(rim, C, 0.35 * step(0.5, mod(k, 2.0)));
        blend(col, v, vec2(d, 1.0), mix(D * 0.6, rim, 0.35), rim, 0.94);
    }
    return vec4(col, v);
}

// ---- pattern 2: Ripples — rings spreading from three wandering sources -------
vec4 fieldRipples(vec2 px)
{
    float t = time * 0.05;
    vec3 A = colorA.rgb, B = colorB.rgb, C = colorC.rgb, D = colorD.rgb;

    vec3 col = vec3(0.0);
    float v = 0.0;
    for (int i = 0; i < 3; ++i) {
        float k = float(i);
        vec2 c = resolution * (0.5 + 0.42 * vec2(sin(t * 0.31 * (k + 1.0) + k * 2.1 + seed * 3.0),
                                                 cos(t * 0.23 * (k + 1.0) + k * 1.3 + seed * 5.0)));
        float r = length(px - c);
        float spacing = (190.0 + 30.0 * k) * zoom;                 // px between rings
        float ph = fract(r / spacing - time * (0.060 - 0.008 * k)); // rings travel outwards
        float dist = abs(ph - 0.5) * spacing;                      // px to the nearest ring
        float line = 1.0 - smoothstep(0.35 * cell.y, 1.5 * cell.y, dist);
        float wake = (1.0 - smoothstep(0.0, 0.45 * spacing, dist)) * 0.16;
        float reach = exp(-r / (780.0 * zoom));
        float inten = (line + wake) * reach;

        vec3 c3 = i == 0 ? A : (i == 1 ? C : mix(A, B, 0.7));
        c3 = mix(mix(D, c3, 0.6), c3, line);
        col = mix(col, c3, inten / max(inten + v, 1e-4));
        v = v + inten * (1.0 - v);
    }
    return vec4(col, v);
}

// ---- pattern 3: Aurora — hanging curtains of light that sway -----------------
vec4 fieldAurora(vec2 px)
{
    float unit = 680.0 * zoom;
    vec2 p = px / unit + vec2(seed * 1.3, seed * 0.7);
    float t = time * 0.04;
    float y01 = px.y / resolution.y;
    vec3 A = colorA.rgb, B = colorB.rgb, C = colorC.rgb, D = colorD.rgb;

    vec3 col = vec3(0.0);
    float v = 0.0;
    for (int i = 0; i < 3; ++i) {
        float k = float(i);
        float sway = noise(vec3(p.y * 0.45 + k * 4.0, t * 1.2, k)) * 1.0
                   + noise(vec3(p.y * 1.6, t * 2.0, k + 7.0)) * 0.22;
        float freq = 0.55 + 0.22 * k;
        float xq = (p.x + sway) * freq;
        float n = noise(vec3(xq, k * 9.0, t * 0.9));
        // distance in px to the curtain (the zero crossing of n)
        float dn = (noise(vec3(xq + 0.02, k * 9.0, t * 0.9)) - n) / 0.02;
        float dist = abs(n) / max(abs(dn), 0.08) * unit / freq;

        float line = 1.0 - smoothstep(0.5 * cell.x, 2.2 * cell.x, dist);
        float veil = exp(-dist / (70.0 * zoom)) * 0.22;
        // each curtain hangs from the top and frays out at its own height
        float len = 0.55 + 0.30 * noise(vec3(p.x * 0.5 + k * 3.0, 2.0, t * 1.5)) + 0.08 * k;
        float hang = 1.0 - smoothstep(len - 0.35, len + 0.15, y01);
        float inten = clamp((line + veil) * hang, 0.0, 1.0);

        vec3 c = i == 0 ? mix(D, A, 0.75) : (i == 1 ? A : C);
        c = mix(c, B, line * (1.0 - smoothstep(0.0, len, y01)) * 0.85);
        col = mix(col, c, inten / max(inten + v, 1e-4));
        v = v + inten * (1.0 - v);
    }
    return vec4(col, v);
}

vec4 field(float id, vec2 px)
{
    if (id < 0.5) return fieldDrift(px);
    if (id < 1.5) return fieldDunes(px);
    if (id < 2.5) return fieldRipples(px);
    return fieldAurora(px);
}

void main()
{
    qt_TexCoord0 = qt_MultiTexCoord0;
    gl_Position = qt_Matrix * qt_Vertex;

    vec2 px = qt_MultiTexCoord0 * resolution;
    vec4 f = field(patternA, px);
    if (patternMix > 0.001)
        f = mix(f, field(patternB, px), patternMix);

    fieldValue = vec4(f.rgb, clamp(f.a, 0.0, 1.0));
}
