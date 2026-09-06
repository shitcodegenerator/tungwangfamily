shader_type canvas_item;

// 低強度舷窗水光。套用在舷窗 Sprite2D 或獨立透明 overlay，
// 不要套在角色、角色陰影、碰撞節點或主要移動物件上。

uniform vec4 water_tint : source_color = vec4(0.35, 0.72, 0.88, 1.0);
uniform float strength : hint_range(0.0, 0.35) = 0.08;
uniform float speed : hint_range(0.0, 2.0) = 0.35;
uniform float wave_amount : hint_range(0.0, 0.04) = 0.008;
uniform float event_pulse : hint_range(0.0, 1.0) = 0.0;

void fragment() {
    vec2 uv = UV;
    float wave_a = sin((uv.y * 18.0) + (TIME * speed * 2.0));
    float wave_b = sin((uv.x * 11.0) - (TIME * speed * 1.35));
    uv.x += wave_a * wave_amount;
    uv.y += wave_b * wave_amount * 0.35;

    vec4 base = texture(TEXTURE, uv);
    float band = 0.5 + (0.5 * sin((uv.y * 14.0) + (TIME * speed)));
    float pulse = 1.0 + (event_pulse * 0.45);
    vec3 lit = base.rgb + (water_tint.rgb * band * strength * pulse * base.a);
    COLOR = vec4(lit, base.a);
}
