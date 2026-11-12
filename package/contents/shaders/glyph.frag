#version 440

// Pass 2 — the glyphs.
// For every screen pixel: find its character cell, look up that cell's
// colour/density in the field texture, and draw the matching glyph from
// the atlas. Neighbouring glyphs in the ramp are cross-faded over a short
// window so density changes morph instead of popping.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 resolution; // item size in px
    vec2 grid;       // cols, rows
    vec2 cell;       // cell size in px
    float glyphCount;
    float glow;
    float fade;
    vec4 background;
};

layout(binding = 1) uniform sampler2D field;
layout(binding = 2) uniform sampler2D atlas;

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

    vec4 fld = texture(field, (id + 0.5) / grid);
    float v = clamp(fld.a, 0.0, 1.0) * fade;

    float g = v * (glyphCount - 1.0);
    float i0 = floor(g);
    float i1 = min(i0 + 1.0, glyphCount - 1.0);
    float cov = mix(glyph(i0, f), glyph(i1, f), smoothstep(0.3, 0.7, g - i0));

    vec3 ink = fld.rgb * (0.55 + 0.45 * v);
    vec3 base = background.rgb + fld.rgb * (v * glow);
    vec3 col = mix(base, ink, cov);

    fragColor = vec4(col, 1.0) * qt_Opacity;
}
