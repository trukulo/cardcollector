// Brighter Silver Metallic Card Shader with Fewer and Bigger Diagonal Lines
shader_type canvas_item;
uniform float stripe_frequency : hint_range(0.5, 10.0) = 4.0; // Lower frequency for fewer lines
uniform float stripe_intensity : hint_range(0.0, 1.0) = 0.25; // Increased intensity
uniform float reflection_speed : hint_range(0.1, 5.0) = 1.8; // Faster reflections
uniform float desaturation_amount : hint_range(0.0, 1.0) = 0.25; // Reduced desaturation
uniform float metallic_texture_strength : hint_range(0.0, 1.0) = 0.5; // More texture
uniform float metallic_texture_scale : hint_range(1.0, 20.0) = 15.0; // More randomness
uniform float silver_intensity : hint_range(0.0, 1.0) = 0.8; // Brighter silver effect

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
    vec3 dark_silver_base = vec3(0.6, 0.62, 0.65); // Brighter base
    vec3 silver_highlight = vec3(0.95, 0.97, 1.0); // Brighter highlight

    float grain = fbm(UV * metallic_texture_scale + vec2(TIME * 0.02, TIME * 0.03));
    float combined_grain = (grain * 2.0 - 1.0) * 0.5;

    vec3 silver_result = mix(original.rgb, original.rgb * dark_silver_base, desaturation_amount * silver_intensity);
    silver_result = mix(silver_result, silver_result * (1.0 + combined_grain * 0.3), metallic_texture_strength);

    // Adjust diagonal lines for fewer and bigger lines
    float diagonal = (UV.x + UV.y) * stripe_frequency; // Lower frequency for fewer lines
    float diagonal_stripes = sin(diagonal * 6.28 - TIME * reflection_speed) * 0.5 + 0.5;
    diagonal_stripes = pow(diagonal_stripes, 1.5) * stripe_intensity; // Slightly softer edges

    float reflection = sin((UV.x + UV.y) * 8.0 + TIME * reflection_speed) * 0.5 + 0.5;
    reflection = pow(reflection, 5.0) * 0.4;

    silver_result += silver_highlight * reflection * 0.8;
    silver_result += silver_highlight * diagonal_stripes * 0.6;

    COLOR = vec4(silver_result, original.a);
}