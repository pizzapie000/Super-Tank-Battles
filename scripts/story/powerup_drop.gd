extends "res://scripts/story/upgrade_pickup.gd"

const COLLECT_DELAY := 0.35
const EQUIP_RADIUS := 64.0
var age := 0.0
var prompt := ""

func _draw() -> void:
	draw_set_transform(Vector2(0, sin(age * 4) * 3))
	super._draw()
	if not prompt.is_empty():
		var font := ThemeDB.fallback_font
		var width := font.get_string_size(prompt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		draw_rect(Rect2(-width / 2 - 7, -49, width + 14, 23), Color("13222f"))
		draw_string(font, Vector2(-width / 2, -33), prompt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("ffd575"))
	draw_set_transform(Vector2.ZERO)
