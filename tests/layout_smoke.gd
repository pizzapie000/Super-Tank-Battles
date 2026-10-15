extends SceneTree

var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func frames(count: int) -> void:
	for i in range(count):
		await physics_frame
		await process_frame

func run() -> void:
	var game = load("res://scenes/game/CampaignArena.tscn").instantiate()
	game.save_progress = false
	root.add_child(game)
	game.set_process(false)
	# Compare the running arena to its saved scene, so intentional editor changes
	# are validated without requiring the original generated spawn positions.
	for mission in range(1, 51):
		game.mission = mission
		game.start_round()
		var saved_layout = load("res://scenes/levels/missions/Mission%02d.tscn" % mission).instantiate()
		var expected_walls: Array[Rect2] = saved_layout.boundary_rectangles()
		expected_walls.append_array(saved_layout.wall_rectangles())
		check(game.wall_rects == expected_walls, "Mission %d must load every authored wall" % mission)
		check(game.player.position == saved_layout.get_node("PlayerSpawn").position, "Mission %d must preserve its authored player position" % mission)
		var markers: Array[Node] = saved_layout.enemy_spawns()
		check(game.enemies.size() == markers.size(), "Mission %d must load its authored enemy roster" % mission)
		for i in range(markers.size()):
			check(game.enemies[i].enemy_name == markers[i].tank_type and game.enemies[i].position == markers[i].global_position, "Mission %d must preserve its authored enemies and spawns" % mission)
		saved_layout.free()
	await frames(2)
	var layout = load("res://scenes/levels/missions/Mission01.tscn").instantiate()
	var marker = layout.get_node("Enemies").get_child(0)
	marker.tank_type = "Pink"
	marker.position = Vector2(300, 400)
	layout.get_node("PlayerSpawn").position = Vector2(900, 400)
	var wall = load("res://scenes/levels/pieces/VerticalWall.tscn").instantiate()
	wall.position = Vector2(640, 152)
	wall.size = Vector2(14, 526)
	# Dragging a piece onto the root also works; it needn't be under Walls.
	layout.add_child(wall)
	wall.owner = layout
	game.external_layout = layout
	game.mission = 1
	game.start_round()
	await frames(2)
	check(game.wall_rects.size() == 5 and game.wall_rects.back() == Rect2(633, 145, 14, 526), "An added scene wall must become actual arena geometry")
	check(game.navigation.path(Vector2(300, 400), Vector2(900, 400)).is_empty(), "AI must not route through an added full-height barrier")
	check(not layout.validate_layout().is_empty(), "The editor must warn about blocked mobile enemy spawns")
	var ray := PhysicsRayQueryParameters2D.create(Vector2(300, 400), Vector2(900, 400), 1)
	check(not game.get_world_2d().direct_space_state.intersect_ray(ray).is_empty(), "Saved scene walls must block actual physics rays")
	wall.position = Vector2(640, 250)
	wall.size = Vector2(14, 270)
	# Save/reload the edited scene, as Godot's editor does.
	var packed := PackedScene.new()
	check(packed.pack(layout) == OK, "An edited mission must pack successfully")
	var path := "user://layout_smoke_scene.tscn"
	check(ResourceSaver.save(packed, path) == OK, "An edited mission must save successfully")
	var reloaded = load(path).instantiate()
	game.external_layout = reloaded
	game.start_round()
	await frames(2)
	check(game.wall_rects.back() == Rect2(633, 243, 14, 270), "Moving/resizing a wall must survive scene save and reload")
	check(reloaded.validate_layout().is_empty(), "An open route and safe spawns must have no layout warnings")
	var route: Array[Vector2] = game.navigation.path(Vector2(300, 400), Vector2(900, 400))
	check(not route.is_empty(), "AI must find a route around the edited wall's end")
	check(not game.navigation.path(Vector2(615, 400), Vector2(900, 400)).is_empty(), "A tank touching a wall must reconnect to its route rather than stall")
	var point := Vector2(300, 400)
	for next in route:
		check(game.navigation.segment_clear(point, next), "Every edited-level route segment must clear the whole tank")
		point = next
	game.active = true
	game.countdown = 0
	game.enemies[0].cooldown = 100
	game.enemies[0].controls_enabled = true
	await frames(540)
	check(game.enemies[0].position.x > 660, "A live enemy must move around an off-grid resized wall, not get stuck on it")
	var edited_wall: Node = reloaded.find_children("*", "Polygon2D", true, false).filter(func(node): return node.has_method("wall_rect"))[0]
	edited_wall.get_parent().remove_child(edited_wall)
	edited_wall.free()
	game.start_round()
	await frames(2)
	check(game.wall_rects.size() == 4 and game.navigation.segment_clear(Vector2(300, 400), Vector2(900, 400)), "Deleting a wall must remove its rendering, collision and navigation barrier")
	check(game.get_world_2d().direct_space_state.intersect_ray(ray).is_empty(), "A deleted wall must no longer block physics rays")
	game.queue_free()
	await frames(2)
	layout.free()
	reloaded.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	# Running a mission scene directly must preview its own number, avoid save
	# changes, and be cleaned up when returning to the main menu.
	var preview_layout = load("res://scenes/levels/missions/Mission17.tscn").instantiate()
	root.add_child(preview_layout)
	await frames(3)
	var preview = current_scene
	check(preview != null and preview.get_script().resource_path == "res://scripts/campaign_arena.gd", "Run Current Scene must launch a playable arena")
	check(preview.mission == 17 and not preview.save_progress and preview.external_layout == preview_layout, "Scene preview must use its mission without changing campaign saves")
	check(preview_layout.get_parent() == preview, "The arena must own its source layout during preview")
	preview.set_process(false)
	Input.action_press("return_menu")
	preview._process(0)
	Input.action_release("return_menu")
	await frames(3)
	check(not is_instance_valid(preview) and not is_instance_valid(preview_layout), "Returning to the menu must free the entire mission preview")
	check(current_scene != null and current_scene.name == "MainMenu", "Preview Backspace must return to the menu")
	print("LAYOUT SMOKE: %s" % ("PASS" if failures == 0 else "%d FAILURE(S)" % failures))
	quit(0 if failures == 0 else 1)
