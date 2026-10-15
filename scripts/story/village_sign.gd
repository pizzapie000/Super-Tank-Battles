@tool
extends Node2D

@export_multiline var message: String = "PLEASE\nLEAVE US IN PEACE":
	set(value):
		message = value
		queue_redraw()

func _ready() -> void:
	z_index = 1
	queue_redraw()

func _draw() -> void:
	draw_line(Vector2(-58, 28), Vector2(-58, 54), Color("4b3828"), 7)
	draw_line(Vector2(58, 28), Vector2(58, 54), Color("4b3828"), 7)
	draw_rect(Rect2(-96, -39, 192, 78), Color("473425"))
	draw_rect(Rect2(-92, -35, 184, 70), Color("a08456"))
	for y in [-12, 13]:
		draw_line(Vector2(-91, y), Vector2(91, y), Color("79613f"), 2)
	for x in [-85, 85]:
		for y in [-28, 28]:
			draw_circle(Vector2(x, y), 2, Color("473425"))
	var lines := message.split("\n")
	for i in range(lines.size()):
		var size := 16
		var font := ThemeDB.fallback_font
		var width := font.get_string_size(lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		draw_string(font, Vector2(-width / 2, -9 + i * 23), lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color("fff4ca"))
