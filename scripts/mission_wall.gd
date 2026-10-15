@tool
extends Polygon2D

## An axis-aligned wall. Its position is the top-left grid intersection;
## the seven-pixel overlap closes gaps where neighboring wall pieces meet.
@export var size: Vector2 = Vector2(14, 142):
	set(value):
		size = Vector2(maxf(6, value.x), maxf(6, value.y))
		refresh()

func _ready() -> void:
	refresh()

func refresh() -> void:
	polygon = PackedVector2Array([Vector2(-7, -7), Vector2(size.x - 7, -7), size - Vector2(7, 7), Vector2(-7, size.y - 7)])
	color = Color("52616b")
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(-4, -4, size.x - 6, size.y - 6), Color("384952"))
	draw_line(Vector2(-7, -6), Vector2(size.x - 7, -6), Color("8f9ba0"), 2)

func wall_rect() -> Rect2:
	# The arena uses the same rectangle for rendering, physics and bank-shot AI.
	var rect := Rect2(to_global(Vector2(-7, -7)), Vector2.ZERO)
	for corner in polygon:
		rect = rect.expand(to_global(corner))
	return rect

func _get_configuration_warnings() -> PackedStringArray:
	if not is_zero_approx(rotation) or not scale.is_equal_approx(Vector2.ONE):
		return ["Keep wall Rotation at 0 and Scale at (1, 1). Use Size to resize a wall, or use the HorizontalWall / VerticalWall scenes."]
	return []
