shader_type canvas_item;

uniform sampler2D noise_texture; // For random patterns
uniform vec4 base_color = vec4(0.0, 0.2, 0.5, 1.0); // Subtler base holographic color
uniform vec4 highlight_color = vec4(0.5, 0.3, 0.7, 1.0); // Subtler secondary holographic color
uniform float rainbow_saturation : hint_range(0.0, 2.0) = 2.2; // Reduced color intensity
uniform float rainbow_brightness : hint_range(0.0, 2.0) = 2.5; // Reduced brightness
uniform float speed : hint_range(0.0, 5.0) = 4; // Slower animation speed
uniform float noise_scale : hint_range(0.0, 10.0) = 2.0; // Reduced noise scale
uniform float refraction_strength : hint_range(0.0, 1.0) = 0.0; // Reduced refraction effect
uniform float shimmer_intensity : hint_range(0.0, 5.0) = 3.0; // Reduced shimmer
uniform float holographic_opacity : hint_range(0.0, 1.0) = 0.2; // Control overall effect strength
uniform float angle_sensitivity : hint_range(0.0, 10.0) = 2.0; // Reduced angle sensitivity

void fragment() {
    // Original texture
    vec4 original = texture(TEXTURE, UV);

    // Create angle effect (simulates viewing from different angles)
    vec2 view_angle = vec2(
        sin(TIME * speed * 0.3) * 0.5 + 0.5,
        cos(TIME * speed * 0.2) * 0.5 + 0.5
    );

    // Calculate normalized UV coordinates
    vec2 uv = UV;

    // Generate noise pattern for the holographic effect
    vec2 noise_uv = uv * noise_scale;
    noise_uv += TIME * speed * 0.02; // Slower noise animation
    float noise = texture(noise_texture, noise_uv).r;

    // Generate more subtle wave pattern
    float wave = sin((uv.y * 10.0) + TIME * speed) * 0.3 + 0.5;
    wave *= sin((uv.x * 8.0) - TIME * speed * 0.2) * 0.3 + 0.5;

    // More subtle rainbow effect
    float hue = uv.x * 0.7 + uv.y * 0.7 + TIME * speed * 0.1;
    hue += dot(view_angle, vec2(0.5, 0.3)) * angle_sensitivity;

    // Convert HSV to RGB for the rainbow effect
    vec3 rainbow;
    float h = mod(hue * 6.0, 6.0);
    float f = mod(h, 1.0);
    float s = rainbow_saturation;
    float v = rainbow_brightness;

    if (h < 1.0) rainbow = vec3(v, v * f, 0.0);
    else if (h < 2.0) rainbow = vec3(v * (1.0 - f), v, 0.0);
    else if (h < 3.0) rainbow = vec3(0.0, v, v * f);
    else if (h < 4.0) rainbow = vec3(0.0, v * (1.0 - f), v);
    else if (h < 5.0) rainbow = vec3(v * f, 0.0, v);
    else rainbow = vec3(v, 0.0, v * (1.0 - f));

    // More subtle shimmer effect
    float shimmer = pow(noise, 7.0) * shimmer_intensity; // Higher power for more isolated sparkles
    shimmer *= sin(TIME * speed * 1.0 + uv.x * 5.0 + uv.y * 7.0) * 0.3 + 0.3;

    // Mix base and highlight colors with rainbow effect
    vec3 holo_color = mix(base_color.rgb, highlight_color.rgb, wave);
    holo_color = mix(holo_color, rainbow, 0.4); // Reduced rainbow influence

    // Add shimmer highlights
    holo_color += vec3(shimmer);

    // Reduced refraction effect
    vec2 refraction_offset = (view_angle - 0.5) * refraction_strength * (noise * 2.0 - 1.0);
    vec4 refracted = texture(TEXTURE, UV + refraction_offset);

    // Apply the holographic effect with reduced opacity
    vec3 final_color = mix(original.rgb, holo_color, original.a * holographic_opacity);

    // Add original texture detail with reduced refraction
    final_color = mix(final_color, refracted.rgb, refraction_strength * 0.5 * original.a);

    // Final result
    COLOR = vec4(final_color, original.a);
}