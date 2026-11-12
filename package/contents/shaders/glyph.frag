#version 440

// The glyphs.
// The field arrives interpolated from the cell corners. Each pixel first
// extrapolates it to the centre of its own character cell (exact, because the
// interpolation is linear and the centre lies on the diagonal shared by the
// cell's two triangles), so every pixel of a cell agrees on one colour and
// one density. It then draws the matching glyph from the atlas, cross-fading
// neighbouring glyphs of the ramp so density changes morph instead of popping.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 1) in vec4 fieldValue;
layout(location = 0) out vec4 fragColor;

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

layout(binding = 1) uniform sampler2D atlas;

float glyph(float index, vec2 f)
{
    // keep half a texel away from the neighbouring glyph in the atlas
    float x = clamp(f.x, 0.5 / cell.x, 1.0 - 0.5 / cell.x);
    return texture(atlas, vec2((index + x) / glyphCount, f.y)).a;
}

void main()
{
    vec2 px = qt_TexCoord0 * resolution;
    vec2 id = floor(px / cell);
    vec2 f = fract(px / cell);

    vec2 toCentre = (id + 0.5) * cell - px;
    vec4 fld = fieldValue
             + dFdx(fieldValue) * (toCentre.x / dFdx(px.x))
             + dFdy(fieldValue) * (toCentre.y / dFdy(px.y));
    fld = clamp(fld, 0.0, 1.0);

    float v = fld.a * fade;
    float g = v * (glyphCount - 1.0);
    float i0 = floor(g);
    float i1 = min(i0 + 1.0, glyphCount - 1.0);
    float cov = mix(glyph(i0, f), glyph(i1, f), smoothstep(0.0, 1.0, g - i0));

    vec3 ink = fld.rgb * (0.55 + 0.45 * v);
    vec3 base = background.rgb + fld.rgb * (v * glow);
    vec3 col = mix(base, ink, cov);

    fragColor = vec4(col, 1.0) * qt_Opacity;
}
