// Brighter and More Golden Metallic Card Shader with Fewer and Bigger Diagonal Lines
shader_type canvas_item;
uniform float stripe_frequency : hint_range(0.5, 10.0) = 4.0; // Lower frequency for fewer lines
uniform float stripe_intensity : hint_range(0.0, 1.0) = 0.3; // Increased intensity
uniform float reflection_speed : hint_range(0.1, 5.0) = 1.5; // Faster reflections
uniform float gold_intensity : hint_range(0.3, 1.0) = 0.7; // Stronger golden effect
uniform float metallic_texture_strength : hint_range(0.0, 1.0) = 0.5; // More texture
uniform float metallic_texture_scale : hint_range(1.0, 20.0) = 14.0; // More randomness

float rand(vec2 co) {
    return fract(sin(dot(co.xy, vec2(12.9898, 78.233))) * 43758.5453);
}

float noise(vec2 uv) {
    vec2 i = floor(uv);
    vec2 f = fract(uv);
    float a = rand(i);
    float b = rand(i + vec2(1.0, 0.0));
    float c = rand(i + vec2(0.0, 1.0));
    float d = rand(i + vec2(1.0, 1.0));
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

float fbm(vec2 uv) {
    float value = 0.0;
    float amplitude = 0.5;
    float frequency = 1.0;
    for (int i = 0; i < 5; i++) {
        value += amplitude * noise(uv * frequency);
        frequency *= 2.0;
        amplitude *= 0.5;
    }
    return value;
}

void fragment() {
    vec4 original = texture(TEXTURE, UV);
    vec3 dark_gold_base = vec3(0.9, 0.7, 0.2); // More yellow for a stronger golden tint
    vec3 gold_highlight = vec3(1.0, 0.85, 0.3); // Brighter and more golden highlight

    float grain = fbm(UV * metallic_texture_scale + vec2(TIME * 0.02, TIME * 0.03));
    float combined_grain = (grain * 2.0 - 1.0) * 0.5;

    vec3 gold_result = mix(original.rgb, original.rgb * dark_gold_base, gold_intensity);
    gold_result = mix(gold_result, gold_result * (1.0 + combined_grain * 0.3), metallic_texture_strength);

    // Adjust diagonal lines for fewer and bigger lines
    float diagonal = (UV.x + UV.y) * stripe_frequency; // Lower frequency for fewer lines
    float diagonal_stripes = sin(diagonal * 6.28 - TIME * reflection_speed) * 0.5 + 0.5;
    diagonal_stripes = pow(diagonal_stripes, 1.5) * stripe_intensity; // Slightly softer edges

    float reflection = sin((UV.x + UV.y) * 8.0 + TIME * reflection_speed) * 0.5 + 0.5;
    reflection = pow(reflection, 5.0) * 0.5; // Slightly stronger reflection

    gold_result += gold_highlight * reflection * 0.8;
    gold_result += gold_highlight * diagonal_stripes * 0.6;

    COLOR = vec4(gold_result, original.a);
}