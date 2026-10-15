@tool
extends Node2D

const BOARD := Rect2(64, 152, 1152, 512)
const FLOOR = preload("res://assets/Floor Tiles/Clay brick floor tile.jpg")
const NavigationScript = preload("res://scripts/mission_navigation.gd")
@export_range(1, 50) var mission_number: int = 1:
	set(value):
		mission_number = value
		queue_redraw()
var last_editor_state: String = ""
var validation_timer: float = 0.0
var layout_warnings: PackedStringArray = []

func _ready() -> void:
	if Engine.is_editor_hint():
		queue_redraw()
		return
	# Run Current Scene launches this mission without unlocking campaign saves.
	# The same scene is only inspected (never added to the tree) by normal play.
	var arena = load("res://scenes/game/CampaignArena.tscn").instantiate()
	arena.mission_override = mission_number
	arena.external_layout = self
	arena.save_progress = false
	hide()
	launch_preview.call_deferred(arena)

func launch_preview(arena: Node2D) -> void:
	# Make the arena the current scene so Backspace/scene changes clean up the
	# preview normally. Keep this source layout alive as a hidden child.
	var tree := get_tree()
	get_parent().remove_child(self)
	arena.add_child(self)
	tree.root.add_child(arena)
	tree.current_scene = arena

func _process(delta: float) -> void:
	if not Engine.is_editor_hint():
		return
	validation_timer -= delta
	if validation_timer > 0:
		return
	validation_timer = 0.5
	var state: Array = []
	for node in find_children("*", "", true, false):
		if node.has_method("wall_rect"):
			state.append([node.wall_rect(), node.global_rotation, node.global_scale])
		elif node.get("tank_type") != null:
			state.append([node.tank_type, node.global_position])
	var fingerprint := str(state)
	if fingerprint != last_editor_state:
		last_editor_state = fingerprint
		layout_warnings = validate_layout()
		update_configuration_warnings()

func _get_configuration_warnings() -> PackedStringArray:
	return layout_warnings

func validate_layout() -> PackedStringArray:
	var messages: PackedStringArray = []
	if not has_node("PlayerSpawn"):
		messages.append("Keep the PlayerSpawn marker: every mission needs a player starting position.")
		return messages
	var rectangles := wall_rectangles()
	for node in find_children("*", "", true, false):
		if node.has_method("wall_rect") and (not is_zero_approx(node.global_rotation) or not node.global_scale.is_equal_approx(Vector2.ONE)):
			messages.append("%s: keep wall Rotation at 0 and Scale at (1, 1). Resize using Size instead." % node.name)
	for rect in rectangles:
		if not BOARD.grow(7).encloses(rect):
			messages.append("An interior wall extends outside the arena. Move it inside the boundary.")
			break
	var markers: Array[Node] = [$PlayerSpawn]
	markers.append_array(enemy_spawns())
	for i in range(markers.size()):
		var point: Vector2 = markers[i].global_position
		if not BOARD.grow(-20).has_point(point):
			messages.append("%s starts too close to or outside the boundary." % markers[i].name)
		for rect in rectangles:
			if rect.grow(20).has_point(point):
				messages.append("%s starts inside or too close to a wall. Move its spawn marker." % markers[i].name)
				break
		for j in range(i):
			if point.distance_to(markers[j].global_position) < 40:
				messages.append("%s and %s overlap. Separate their spawn markers." % [markers[i].name, markers[j].name])
	var nav = NavigationScript.new()
	nav.build(rectangles + boundary_rectangles())
	for marker in enemy_spawns():
		if float(EnemyProfiles.get_profile(marker.tank_type).move) > 0 and nav.path(marker.global_position, $PlayerSpawn.global_position).is_empty():
			messages.append("%s has no tank-width route to the player. Leave an opening between their areas." % marker.name)
	return messages

func wall_rectangles() -> Array[Rect2]:
	var result: Array[Rect2] = []
	for wall in find_children("*", "", true, false):
		if wall.has_method("wall_rect"):
			result.append(wall.wall_rect())
	return result

func enemy_spawns() -> Array[Node]:
	var result: Array[Node] = []
	for marker in find_children("*", "", true, false):
		if marker.get("tank_type") != null and marker.tank_type != "Player":
			result.append(marker)
	return result

func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	draw_rect(Rect2(0, 0, 1280, 800), Color("101923"))
	draw_rect(BOARD.grow(20), Color("090f16"))
	draw_rect(BOARD, Color("21303a"))
	draw_texture_rect(FLOOR, BOARD, false, Color(0.65, 0.75, 0.85, 0.16))
	for x in range(10):
		draw_line(BOARD.position + Vector2(x * 128, 0), BOARD.position + Vector2(x * 128, BOARD.size.y), Color(0.8, 0.9, 1, 0.13))
	for y in range(5):
		draw_line(BOARD.position + Vector2(0, y * 128), BOARD.position + Vector2(BOARD.size.x, y * 128), Color(0.8, 0.9, 1, 0.13))
	for rect in boundary_rectangles():
		draw_rect(rect, Color("52616b"))
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(64, 80), "MISSION %02d  /  EDITABLE LAYOUT" % mission_number, HORIZONTAL_ALIGNMENT_LEFT, -1, 27, Color.WHITE)
	draw_string(font, Vector2(64, 115), "Walls: drag, duplicate, or delete.  Spawns: drag to move.  Run Current Scene to test.", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("bdcbd1"))
	draw_string(font, Vector2(64, 721), "Add walls from scenes/levels/pieces. Grid snap: step (128, 128), offset (64, 152).", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("bdcbd1"))

static func boundary_rectangles() -> Array[Rect2]:
	return [Rect2(50, 138, 1180, 14), Rect2(50, 664, 1180, 14), Rect2(50, 152, 14, 512), Rect2(1216, 152, 14, 512)]
