@tool
extends "res://scripts/mission_wall.gd"

@export_enum("Concrete", "Wreckage", "Bricks") var surface_type: String = "Concrete":
	set(value):
		surface_type = value
		refresh()
@export var variation: int = 1:
	set(value):
		variation = value
		queue_redraw()

func refresh() -> void:
	super.refresh()
	color = Color("746f61") if surface_type == "Concrete" else (Color("555f59") if surface_type == "Wreckage" else Color("8b6853"))

func _draw() -> void:
	var rect := Rect2(Vector2(-7, -7), size)
	draw_rect(Rect2(rect.position + Vector2(4, 6), size), Color(0, 0, 0, 0.3))
	draw_rect(rect, color)
	draw_rect(rect.grow(-5), color.darkened(0.18))
	draw_line(rect.position + Vector2(2, 2), rect.position + Vector2(size.x - 2, 2), color.lightened(0.4), 3)
	draw_line(rect.position + Vector2(2, 2), rect.position + Vector2(2, size.y - 2), color.lightened(0.17), 2)
	draw_line(rect.end - Vector2(1, 2), rect.end - Vector2(size.x - 2, 2), color.darkened(0.5), 3)
	var rng := RandomNumberGenerator.new()
	rng.seed = variation * 257
	if surface_type == "Wreckage":
		for y in range(8, int(size.y) - 7, 10):
			draw_line(Vector2(3, y), Vector2(size.x - 17, y), Color("303e40"), 3)
		for x in [4.0, size.x - 18]:
			for y in [4.0, size.y - 18]:
				draw_circle(Vector2(x, y), 2.2, Color("acb7ae"))
		draw_rect(Rect2(size.x * 0.32 - 7, 6, size.x * 0.24, size.y - 25), Color("b58c46"), false, 2)
	elif surface_type == "Bricks":
		for y in range(9, int(size.y) - 6, 15):
			draw_line(Vector2(-4, y), Vector2(size.x - 10, y), color.darkened(0.5), 2)
			for x in range(9 + (y % 2) * 12, int(size.x) - 6, 25):
				draw_line(Vector2(x, y - 14), Vector2(x, y), color.darkened(0.5), 2)
	else:
		var middle := size * 0.5 - Vector2(7, 7)
		draw_polyline(PackedVector2Array([Vector2(size.x * 0.22, -6), middle + Vector2(-8, -9), middle + Vector2(10, 5), Vector2(size.x * 0.6, size.y - 8)]), Color("393b36"), 2, true)
		for i in range(7):
			var at := Vector2(rng.randf_range(2, size.x - 14), rng.randf_range(2, size.y - 14))
			draw_colored_polygon(PackedVector2Array([at, at + Vector2(6, 2), at + Vector2(2, 6)]), color.lightened(0.2))
