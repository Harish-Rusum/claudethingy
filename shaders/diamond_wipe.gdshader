shader_type canvas_item;

// 0 = clear, 1 = fully covered
uniform float progress : hint_range(0.0, 1.0) = 0.0;
// sweep the other way (used when revealing so it reads as one continuous wipe)
uniform bool flip = false;
uniform vec2 cells = vec2(40.0, 22.5);
uniform vec4 color : source_color = vec4(0.105882354, 0.05882353, 0.11764706, 1.0);

void fragment() {
	vec2 cell = fract(UV * cells) - 0.5;
	float d = abs(cell.x) + abs(cell.y);
	float x = flip ? 1.0 - UV.x : UV.x;
	float r = progress * 2.0 - x;
	if (d > r) {
		discard;
	}
	COLOR = color;
}
