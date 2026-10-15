@tool
extends Polygon2D

const Art = preload("res://scripts/story/factory_art.gd")
@export var belt_size: Vector2 = Vector2(300, 230):
	set(value):
		belt_size = Vector2(maxf(100, value.x), maxf(90, value.y))
		refresh()
var clock: float = 0

func _ready() -> void:
	z_as_relative = false
	z_index = -8
	refresh()

func refresh() -> void:
	polygon = PackedVector2Array([Vector2.ZERO, Vector2(belt_size.x, 0), belt_size, Vector2(0, belt_size.y)])
	color = Color("14232c")
	queue_redraw()

func _process(delta: float) -> void:
	clock += delta
	queue_redraw()

func _draw() -> void:
	Art.conveyor(self, Rect2(Vector2.ZERO, belt_size), clock)
