// Transparent-friendly version of bettercrt.glsl.
// Keeps the CRT warp/scanlines but preserves the input texture alpha so
// Ghostty's background-opacity can still show through.

float warp = 0.25; // simulate curvature of CRT monitor
float scan = 0.50; // simulate darkness between scanlines

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    // squared distance from center
    vec2 uv = fragCoord / iResolution.xy;
    vec2 dc = abs(0.5 - uv);
    dc *= dc;

    // warp the fragment coordinates
    uv.x -= 0.5; uv.x *= 1.0 + (dc.y * (0.3 * warp)); uv.x += 0.5;
    uv.y -= 0.5; uv.y *= 1.0 + (dc.x * (0.4 * warp)); uv.y += 0.5;

    // determine if we are drawing in a scanline
    float apply = abs(sin(fragCoord.y) * 0.25 * scan);

    // sample the texture
    vec4 color = texture(iChannel0, uv);

    // mix the sampled color with the scanline intensity while preserving alpha
    fragColor = vec4(mix(color.rgb, vec3(0.0), apply), color.a);
}
