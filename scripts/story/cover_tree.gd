@tool
extends Polygon2D

const Atlas = preload("res://scripts/story/scenery_atlas.gd")

@export_range(55, 140) var crown_radius: float = 94:
	set(value):
		crown_radius = value
		refresh()
@export var variation: int = 1:
	set(value):
		variation = value
		refresh()
@export var scorched: bool = false:
	set(value):
		scorched = value
		refresh()

func _ready() -> void:
	# Absolute layers keep foliage above tanks, shells and their trails, while
	# the shadow/trunk remain on the ground. The HUD lives on its own CanvasLayer.
	z_as_relative = false
	z_index = 20
	$Shadow.z_as_relative = false
	$Shadow.z_index = -5
	$Trunk.z_as_relative = false
	$Trunk.z_index = -4
	if not $Shadow.draw.is_connected(draw_shadow):
		$Shadow.draw.connect(draw_shadow)
	if not $Trunk.draw.is_connected(draw_trunk):
		$Trunk.draw.connect(draw_trunk)
	refresh()

func refresh() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = variation * 503 + 19
	var points := PackedVector2Array()
	for i in range(40):
		var angle := i * TAU / 40
		var radius := crown_radius * rng.randf_range(0.84, 1.04)
		points.append(Vector2(cos(angle), sin(angle) * 0.72) * radius + Vector2(0, -45))
	polygon = points
	color = Color("26392e") if scorched else Color("153e32")
	if not Atlas.lookup(self, Atlas.tree_key("crown", crown_radius, variation, scorched)).is_empty(): color = Color.TRANSPARENT
	queue_redraw()
	if has_node("Shadow"):
		$Shadow.queue_redraw()
		$Trunk.queue_redraw()

func _draw() -> void:
	if Atlas.draw(self, Atlas.tree_key("crown", crown_radius, variation, scorched)): return
	var rng := RandomNumberGenerator.new()
	rng.seed = variation * 503 + 19
	for i in range(15):
		var angle := rng.randf_range(0, TAU)
		var offset := Vector2(cos(angle), sin(angle) * 0.78) * crown_radius * rng.randf_range(0.12, 0.56)
		var radius := crown_radius * rng.randf_range(0.22, 0.36)
		var tint := Color("425442") if scorched else Color("2b6044")
		tint = tint.lightened(rng.randf_range(-0.08, 0.09))
		draw_circle(offset + Vector2(0, -45), radius, tint)
		draw_arc(offset + Vector2(0, -45), radius * 0.85, PI, TAU, 12, Color(tint.lightened(0.13), 0.5), 2, true)
	for i in range(6):
		var angle := i * TAU / 6 + variation
		var start := Vector2(0, -20)
		var end := start + Vector2.RIGHT.rotated(angle) * crown_radius * 0.65
		draw_line(start, end, Color("2c3229"), 5 if scorched else 3)
		if scorched:
			draw_line(end, end + Vector2.RIGHT.rotated(angle + 0.6) * 15, Color("776e4e"), 2)

func draw_shadow() -> void:
	if Atlas.draw($Shadow, Atlas.tree_key("shadow", crown_radius, variation, scorched)): return
	$Shadow.draw_set_transform(Vector2(12, -12), 0, Vector2(1, 0.76))
	$Shadow.draw_circle(Vector2.ZERO, crown_radius + 8, Color(0.01, 0.03, 0.02, 0.38))

func draw_trunk() -> void:
	if Atlas.draw($Trunk, Atlas.tree_key("trunk", crown_radius, variation, scorched)): return
	# The trunk base emerges below the crown, making the solid face readable.
	$Trunk.draw_line(Vector2(0, -15), Vector2(0, 42), Color("473e30"), 14)
	$Trunk.draw_rect(Rect2(-12, 22, 24, 26), Color("473e30"))
	$Trunk.draw_line(Vector2(-10, 24), Vector2(8, 24), Color("a68c61"), 2)
	$Trunk.draw_line(Vector2(-3, 25), Vector2(-2, 47), Color("251f1c"), 3)
	for angle in [0.4, 2.6, 4.3]:
		$Trunk.draw_line(Vector2(0, 35), Vector2(0, 35) + Vector2.RIGHT.rotated(angle) * 27, Color("5c513a"), 5)

func wall_rect() -> Rect2:
	# Leaves provide visual concealment; only the visible trunk is solid.
	return Rect2(global_position + Vector2(-12, 22), Vector2(24, 26))

func _get_configuration_warnings() -> PackedStringArray:
	if not is_zero_approx(global_rotation) or not global_scale.is_equal_approx(Vector2.ONE):
		return ["Keep tree Rotation at 0 and Scale at (1, 1). Change Crown Radius to resize the foliage."]
	return []
