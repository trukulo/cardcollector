shader_type canvas_item;

// Parameters for customization
uniform sampler2D paper_texture; // Assign a paper texture in the inspector
uniform float roughness : hint_range(0.0, 1.0) = 0.5; // Controls how rugged the paper appears
uniform float displace_strength : hint_range(0.0, 0.1) = 0.015; // Controls displacement amount
uniform vec4 paper_color : source_color = vec4(0.9, 0.85, 0.8, 1.0); // Slight off-white tint
uniform float paper_blend : hint_range(0.0, 1.0) = 0.3; // How much the paper color affects the image
uniform float edge_darkening : hint_range(0.0, 0.5) = 0.1; // Darkens edges of the paper
uniform float edge_frequency : hint_range(1.0, 20.0) = 10.0; // Frequency of edge variation

// Noise function to create random variations
vec2 hash2(vec2 p) {
    p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
    return -1.0 + 2.0 * fract(sin(p) * 43758.5453123);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);

    vec2 u = f * f * (3.0 - 2.0 * f);

    float n = mix(
        mix(dot(hash2(i + vec2(0.0, 0.0)), f - vec2(0.0, 0.0)),
            dot(hash2(i + vec2(1.0, 0.0)), f - vec2(1.0, 0.0)), u.x),
        mix(dot(hash2(i + vec2(0.0, 1.0)), f - vec2(0.0, 1.0)),
            dot(hash2(i + vec2(1.0, 1.0)), f - vec2(1.0, 1.0)), u.x), u.y);

    return 0.5 + 0.5 * n;
}

// Function to create edge darkening effect
float edge_effect(vec2 uv) {
    float dist_from_center = length(uv - 0.5) * 2.0;
    float edge = smoothstep(0.8, 1.0, dist_from_center);

    // Add variation to the edges
    float variation = noise(uv * edge_frequency) * 0.3;
    edge = edge + variation * edge;

    return clamp(edge * edge_darkening, 0.0, 1.0);
}

void fragment() {
    // Sample the paper texture for displacement
    vec4 paper_sample = texture(paper_texture, UV);

    // Calculate displacement based on paper texture
    vec2 displacement = (paper_sample.rg - 0.5) * displace_strength * roughness;

    // Sample the screen texture with displacement
    vec4 screen_color = texture(TEXTURE, UV + displacement);

    // Calculate paper effect (texture + color tint + edge darkening)
    float paper_roughness = mix(1.0, paper_sample.r, roughness);
    float edge_dark = edge_effect(UV);

    // Mix the screen color with paper effects
    vec4 final_color = screen_color;
    final_color.rgb = mix(final_color.rgb, final_color.rgb * paper_roughness, 0.2 * roughness);
    final_color.rgb = mix(final_color.rgb, paper_color.rgb, paper_blend * paper_sample.r);
    final_color.rgb = final_color.rgb - edge_dark;

    COLOR = final_color;
}