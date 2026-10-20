extends Node2D

const DURATION := 1.0
var age: float = 0.0
var arena: Node2D
var outline := PackedVector2Array()

func _ready() -> void:
	z_as_relative = false
	z_index = 25
	for i in range(49):
		var t := TAU * i / 48.0
		outline.append(Vector2(8 * pow(sin(t), 3), -(13 * cos(t) - 5 * cos(2 * t) - 2 * cos(3 * t) - cos(4 * t)) * 0.5))
	queue_redraw()

func _process(delta: float) -> void:
	if is_instance_valid(arena) and arena.paused:
		return
	age += delta
	if age >= DURATION:
		queue_free()
	else:
		queue_redraw()

func _draw() -> void:
	var alpha := 1.0 - smoothstep(0.65, DURATION, age)
	var size := lerpf(0.4, 1.0, minf(age / 0.12, 1.0))
	draw_set_transform(Vector2(sin(age * 5) * 3, -12 - age * 44), 0, Vector2.ONE * size)
	draw_colored_polygon(outline, Color(1, 0.16, 0.5, alpha))
	draw_polyline(outline, Color(1, 0.88, 0.94, alpha), 1.5, true)
	draw_arc(Vector2(-3.4, -3.7), 1.7, PI, PI * 1.65, 8, Color(1, 1, 1, alpha * 0.85), 1.3, true)
