extends Node2D

var tint: Color = Color.WHITE
var age: float = 0.0
var duration: float = 0.6
var large: bool = true
var vectors: Array[Vector2] = []

func _ready() -> void:
	for i in range(18 if large else 5):
		vectors.append(Vector2.RIGHT.rotated(randf() * TAU) * randf_range(30, 120 if large else 55))

func _process(delta: float) -> void:
	age += delta
	if age >= duration:
		queue_free()
	else:
		queue_redraw()

func _draw() -> void:
	var fade := 1.0 - age / duration
	if large:
		draw_arc(Vector2.ZERO, 12 + age * 90, 0, TAU, 48, Color(tint, fade * 0.65), 2, true)
	for vector in vectors:
		var point := vector * age
		draw_line(point, point - vector.normalized() * (3 + fade * 8), Color(tint, fade), 2, true)
