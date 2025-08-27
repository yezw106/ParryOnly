shader_type canvas_item;
render_mode unshaded, blend_add; // 叠加发光

uniform float speed = 2.5;
uniform float alpha = 0.7;
uniform vec4 tint : source_color = vec4(0.6, 0.8, 1.0, 1.0);

void fragment(){
    vec4 tex = texture(TEXTURE, UV);
    float pulse = 0.85 + 0.15 * sin(TIME * speed);
    COLOR = vec4(tint.rgb, alpha) * vec4(tex.rgb, tex.a * pulse);
}
