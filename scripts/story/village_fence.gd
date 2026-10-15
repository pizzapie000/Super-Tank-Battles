@tool
extends "res://scripts/mission_wall.gd"

@export var entrance_gate: bool = false:
	set(value):
		entrance_gate = value
		queue_redraw()

func refresh() -> void:
	super.refresh()
	color = Color("59432d")

func _draw() -> void:
	var rect := Rect2(Vector2(-7, -7), size)
	draw_rect(rect, Color("59432d"))
	for y in range(0, int(size.y), 19):
		draw_rect(Rect2(-5, y - 6, size.x - 4, 16), Color("b49360") if entrance_gate else Color("93764b"))
		draw_line(Vector2(-4, y - 4), Vector2(size.x - 10, y - 4), Color("d2b783"), 2)
		draw_circle(Vector2(2, y + 2), 1.5, Color("453724"))
	for x in [0, size.x - 14]:
		draw_line(Vector2(x, -7), Vector2(x, size.y - 7), Color("6c563b"), 4)
	if entrance_gate:
		for y in [size.y * 0.3, size.y * 0.7]:
			draw_rect(Rect2(-7, y, size.x, 6), Color("50615c"))
