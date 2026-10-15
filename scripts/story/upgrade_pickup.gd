@tool
extends Node2D

const Parts = preload("res://scripts/story/upgrade_parts.gd")
@export_enum("Loader", "Armor", "Bank Shot", "Engine") var part_type: String = "Loader":
	set(value):
		part_type = value
		queue_redraw()
var claimed: bool = false
var progress: float = 0
var claimant: Node2D

func _ready() -> void:
	z_as_relative = false
	z_index = 3
	queue_redraw()

func reset_pickup() -> void:
	claimed = false
	progress = 0
	claimant = null
	show()
	queue_redraw()

func _draw() -> void:
	var tint: Color = Parts.COLORS[part_type]
	draw_circle(Vector2.ZERO, 31, Color(tint, 0.13))
	draw_rect(Rect2(-21, -21, 42, 42), Color("192c37"))
	draw_rect(Rect2(-21, -21, 42, 42), tint, false, 2)
	for x in [-17, 17]:
		for y in [-17, 17]:
			draw_circle(Vector2(x, y), 2, Color("cfdbd8"))
	match part_type:
		"Loader":
			for x in [-9, 0, 9]:
				draw_line(Vector2(x, 10), Vector2(x, -9), tint, 5)
				draw_colored_polygon(PackedVector2Array([Vector2(x - 3, -9), Vector2(x + 3, -9), Vector2(x, -14)]), tint)
		"Armor":
			draw_colored_polygon(PackedVector2Array([Vector2(-12, -12), Vector2(12, -12), Vector2(10, 5), Vector2(0, 15), Vector2(-10, 5)]), tint)
			draw_line(Vector2(0, -8), Vector2(0, 8), Color("192c37"), 3)
		"Bank Shot":
			draw_polyline(PackedVector2Array([Vector2(-13, 12), Vector2(10, -12), Vector2(10, 12)]), tint, 4)
			draw_line(Vector2(-2, -15), Vector2(16, -15), Color.WHITE, 3)
		"Engine":
			draw_rect(Rect2(-12, -10, 24, 20), tint)
			for y in [-5, 1, 7]:
				draw_line(Vector2(-8, y), Vector2(8, y), Color("192c37"), 2)
			draw_line(Vector2(12, 5), Vector2(16, 5), tint, 4)
	var font := ThemeDB.fallback_font
	var label := part_type.to_upper()
	var width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	draw_rect(Rect2(-width / 2 - 5, 24, width + 10, 20), Color("13222f"))
	draw_string(font, Vector2(-width / 2, 39), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
	if progress > 0:
		draw_arc(Vector2.ZERO, 28, -PI / 2, -PI / 2 + TAU * progress / 0.45, 24, Color.WHITE, 3)
