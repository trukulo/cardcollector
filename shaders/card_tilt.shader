// Basic 3D tilt/perspective shader for cards sin efectos especiales
shader_type canvas_item;
uniform float tilt_x : hint_range(-1.0, 1.0) = 0.0;
uniform float tilt_y : hint_range(-1.0, 1.0) = 0.0;

void fragment() {
    vec2 center = vec2(0.5, 0.5);
    vec2 tilt = vec2(tilt_x, tilt_y) * 0.15; // Ajusta la fuerza del efecto
    vec2 uv_tilted = UV + (UV - center) * tilt;
    vec4 original = texture(TEXTURE, uv_tilted);
    COLOR = original;
}
