@tool
extends "res://scripts/mission_wall.gd"

@export_enum("Classic", "Factory", "Wasteland", "Forest", "Fortress", "Village", "Capital") var environment: String = "Classic":
	set(value):
		environment = value
		queue_redraw()
@export var variation: int = 1
var broken: bool = false
var runtime_body: StaticBody2D

func refresh() -> void:
	super.refresh()
	color = Color.TRANSPARENT
	if is_instance_valid(runtime_body):
		runtime_body.position = size / 2 - Vector2(7, 7)
		runtime_body.get_node("CollisionShape2D").shape.size = size

func activate() -> void:
	# Authored pieces have no physics until their arena activates them. This
	# avoids a second, invisible collider in direct mission-scene previews.
	if not is_instance_valid(runtime_body):
		runtime_body = StaticBody2D.new()
		runtime_body.collision_mask = 0
		var collider := CollisionShape2D.new()
		collider.name = "CollisionShape2D"
		collider.shape = RectangleShape2D.new()
		runtime_body.add_child(collider)
		add_child(runtime_body)
	runtime_body.collision_layer = 0 if broken else 1
	refresh()

func restore_mine_wall() -> void:
	broken = false
	show()
	if is_instance_valid(runtime_body): runtime_body.collision_layer = 1

func break_from_mine(point: Vector2, radius: float) -> bool:
	if broken or not is_visible_in_tree():
		return false
	var rect := wall_rect()
	if point.distance_to(point.clamp(rect.position, rect.end)) > radius:
		return false
	broken = true
	if is_instance_valid(runtime_body): runtime_body.collision_layer = 0
	hide()
	return true

func _draw() -> void:
	var stone := Color("c5ad80")
	if environment == "Forest": stone = Color("a6ad7e")
	elif environment in ["Fortress", "Capital"]: stone = Color("acb4a2")
	elif environment == "Factory": stone = Color("bbaa8b")
	var rect := Rect2(Vector2(-7, -7), size)
	draw_rect(rect.grow(2), Color("302c26"))
	draw_rect(rect, stone.darkened(0.35))
	var rng := RandomNumberGenerator.new()
	rng.seed = variation * 371 + int(size.x * 13 + size.y * 29)
	var row_height := minf(18, size.y)
	for row in range(int(ceil(size.y / row_height))):
		var y := -7 + row * row_height
		var x := -7.0
		while x < rect.end.x:
			var width := minf(rng.randf_range(18, 37), rect.end.x - x)
			var height := minf(row_height, rect.end.y - y)
			var brick := Rect2(x + 1, y + 1, maxf(1, width - 2), maxf(1, height - 2))
			draw_rect(brick, stone.darkened(rng.randf_range(0, 0.22)))
			draw_line(brick.position, Vector2(brick.end.x, brick.position.y), stone.lightened(0.22), 1)
			x += width
	# Deep, branching fractures and loose chips distinguish mine-only masonry.
	for i in range(maxi(2, int(maxf(size.x, size.y) / 44))):
		var at := Vector2(rng.randf_range(-5, size.x - 9), rng.randf_range(-5, size.y - 9))
		var end := (at + Vector2(rng.randf_range(-14, 14), rng.randf_range(9, 22))).clamp(rect.position, rect.end)
		var bend := at.lerp(end, 0.5) + Vector2(4, -2)
		draw_polyline(PackedVector2Array([at, bend, end]), Color("423c30"), 2, true)
		draw_line(bend, (bend + Vector2(-7, 3)).clamp(rect.position, rect.end), Color("423c30"), 1.5, true)
	for i in range(maxi(4, int((size.x + size.y) / 22))):
		var at := Vector2(rng.randf_range(-7, size.x - 7), size.y - rng.randf_range(7, 11))
		draw_colored_polygon(PackedVector2Array([at, at + Vector2(5, 1), at + Vector2(2, 5)]), stone.darkened(0.15))
	for edge in [-7.0, size.x - 7]:
		for i in range(maxi(1, int(size.y / 28))):
			var y := rng.randf_range(-6, size.y - 8)
			var inward := 1.0 if edge < 0 else -1.0
			draw_colored_polygon(PackedVector2Array([Vector2(edge, y), Vector2(edge + inward * 6, y + 3), Vector2(edge, y + 7)]), Color("423c30"))
