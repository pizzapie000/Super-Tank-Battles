extends Node2D

const Tank = preload("res://scripts/pvp/pvp_tank.gd")
const LIFETIME: float = 22.0
var weapon_kind: String = "gatling"
var age: float = 0

func _draw() -> void:
	var color: Color = Tank.WEAPONS[weapon_kind].color
	var bob := sin(age * 3.5) * 2
	var fade := clampf((LIFETIME - age) / 2, 0, 1)
	modulate.a = fade
	draw_circle(Vector2.ZERO, 26 + sin(age * 4) * 2, Color(color, 0.12))
	draw_circle(Vector2(2, 4), 21, Color(0, 0, 0, 0.3))
	draw_set_transform(Vector2(0, bob))
	draw_rect(Rect2(-18, -18, 36, 36), Color("13242e"))
	draw_rect(Rect2(-18, -18, 36, 36), color, false, 2)
	match weapon_kind:
		"gatling":
			for x in [-7, 0, 7]:
				draw_line(Vector2(x, 9), Vector2(x, -10), color, 3)
			draw_rect(Rect2(-12, 2, 24, 5), color)
		"shotgun":
			for angle in [-0.6, 0.0, 0.6]:
				var point := Vector2.UP.rotated(angle) * 12
				draw_line(Vector2(0, 11), point, color, 2)
				draw_circle(point, 2.5, Color.WHITE)
		"homing":
			draw_arc(Vector2.ZERO, 11, 0, TAU, 24, Color(color, 0.6), 1.5, true)
			draw_colored_polygon(PackedVector2Array([Vector2(0, -13), Vector2(5, 7), Vector2(0, 4), Vector2(-5, 7)]), color)
			draw_line(Vector2(0, 7), Vector2(0, 14), Color("ffbd60"), 3)
	var font := ThemeDB.fallback_font
	var title: String = Tank.WEAPONS[weapon_kind].title
	var width := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
	draw_rect(Rect2(-width / 2 - 4, 23, width + 8, 17), Color("101e28"))
	draw_string(font, Vector2(-width / 2, 36), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, color)
	draw_set_transform(Vector2.ZERO)
