extends SceneTree

const Awareness = preload("res://scripts/enemy_mine_awareness.gd")
var game: Node2D
var failures := 0

func _initialize() -> void:
	run.call_deferred()
	create_timer(120).timeout.connect(func():
		push_error("Repair and mine checks exceeded their time limit")
		quit(1)
	)

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func frames(count: int) -> void:
	for i in range(count):
		await physics_frame
		await process_frame

func key(code: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)

func pad(device: int, pressed: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.device = device
	event.button_index = JOY_BUTTON_Y
	event.pressed = pressed
	Input.parse_input_event(event)

func clear_arena() -> void:
	game.set_activity(false)
	game.active = true
	game.clear_container("Walls")
	game.clear_container("Shells")
	game.clear_container("Mines")
	game.wall_rects.clear()
	game.navigation.build(game.wall_rects, Rect2(game.region().global_position, Vector2(1600, 1100)))
	for enemy in game.enemies:
		enemy.max_shells = 0
		enemy.max_mines = 0
		enemy.position = game.region().global_position + Vector2(1500, 1000)
	for crew in game.players:
		crew.active_mines = 0

func make_mine(at: Vector2, owner: DuelTank, fuse: float = 30) -> TankMine:
	var mine := TankMine.new()
	mine.position = at
	mine.owner_tank = owner
	mine.arena = game
	mine.fuse = fuse
	mine.age = 0.8
	game.get_node("Mines").add_child(mine)
	return mine

func run() -> void:
	StorySession.save_path = "user://repair_mines_smoke.cfg"
	StorySession.devices = [-1, 7]
	StorySession.resume_story = false
	game = load("res://scenes/story/Adventure.tscn").instantiate()
	game.save_progress = false
	game.stage_ready_duration = 0
	game.check_devices = false
	root.add_child(game)
	game.set_process(false)
	game.load_chapter(2)
	clear_arena()
	var origin: Vector2 = game.region().global_position
	var first = game.players[0]
	var friend = game.players[1]
	first.position = origin + Vector2(300, 550)
	friend.position = origin + Vector2(300, 800)
	for crew in game.players:
		crew.armor = 1
		crew.controls_enabled = true
		crew.set_physics_process(true)
	game.supplies = 10
	var start: Vector2 = first.position
	# Holding real repair and drive/fire inputs must lock this tank until completion.
	key(KEY_R, true)
	key(KEY_D, true)
	key(KEY_SPACE, true)
	key(KEY_E, true)
	await frames(50)
	check(first.repair_progress > 0.5 and first.armor == 1 and game.supplies == 10, "A partial repair hold must not heal or spend supplies")
	check(first.position.distance_to(start) < 0.1 and first.velocity.is_zero_approx(), "Repairing must keep the tank still even when drive input is held")
	check(game.get_node("Shells").get_child_count() == 0 and game.get_node("Mines").get_child_count() == 0, "A tank must not fire or deploy mines while working on its repair")
	key(KEY_R, false)
	key(KEY_D, false)
	key(KEY_SPACE, false)
	key(KEY_E, false)
	await frames(2)
	check(first.repair_progress == 0 and game.supplies == 10, "Releasing repair early must cancel the hold without charging supplies")
	key(KEY_R, true)
	await frames(125)
	check(first.armor == first.max_armor and friend.armor == 1 and game.supplies == 8, "A complete two-second hold must spend two supplies and repair only its owner")
	check(first.position.distance_to(start) < 0.1, "The tank must remain stationary for the complete repair")
	first.armor = 1
	await frames(25)
	check(first.armor == 1 and first.repair_progress == 0 and game.supplies == 8, "A completed repair must require a fresh button hold before another repair")
	key(KEY_R, false)
	await frames(2)
	pad(9, true)
	await frames(3)
	check(first.repair_progress == 0 and friend.repair_progress == 0, "Unassigned controllers must not repair another player's tank")
	pad(9, false)
	pad(7, true)
	await frames(125)
	pad(7, false)
	await frames(2)
	check(friend.armor == friend.max_armor and first.armor == 1 and game.supplies == 6, "Controller Y must repair its own assigned tank")
	key(KEY_R, true)
	await frames(30)
	game.pause_story()
	check(first.repair_progress == 0, "Pausing or disconnecting must cancel a partially completed repair")
	await frames(5)
	key(KEY_R, false)
	await frames(1)
	game.resume_game()
	for enemy in game.enemies:
		enemy.controls_enabled = false
		enemy.set_physics_process(false)
	await frames(2)
	check(first.armor == 1 and game.supplies == 6, "Canceled repairs must not complete while paused")
	game.supplies = 1
	key(KEY_R, true)
	await frames(3)
	check(not first.repairing and first.repair_progress == 0, "Insufficient supplies must not immobilize a tank or start a repair")
	key(KEY_R, false)
	game.supplies = 6
	game.stage_ready_time = 3
	key(KEY_R, true)
	await frames(3)
	check(first.repair_progress == 0, "Arrival protection must not allow repair channeling before the stage starts")
	key(KEY_R, false)
	await frames(2)
	game.stage_ready_time = 0
	game.supplies = 2
	first.armor = 1
	friend.armor = 1
	key(KEY_R, true)
	pad(7, true)
	await frames(125)
	key(KEY_R, false)
	pad(7, false)
	await frames(2)
	var healed := int(first.armor == first.max_armor) + int(friend.armor == friend.max_armor)
	check(game.supplies == 0 and healed == 1, "Simultaneous repairs must not overspend shared supplies or heal a second tank for free")
	# Real enemies must steer around a live mine, including Incautious and fast tanks.
	for kind in ["Yellow", "Black"]:
		game.load_chapter(2)
		clear_arena()
		origin = game.region().global_position
		first = game.players[0]
		first.position = origin + Vector2(1200, 550)
		game.players[1].position = origin + Vector2(1200, 900)
		for crew in game.players:
			crew.invulnerable = true
		var enemy = game.spawn_enemy(kind, origin + Vector2(400, 550), 3)
		enemy.pursuer = true
		enemy.tactical_slot = 0
		enemy.aim_target = first
		enemy.plan_timer = 999
		enemy.max_shells = 0
		enemy.max_mines = 0
		enemy.rotation = 0
		enemy.path.assign([first.position])
		enemy.path_timer = 0.4
		var mine_at := origin + Vector2(750, 550)
		var mine := make_mine(mine_at, first)
		var hazard := Awareness.hazards(game, enemy)
		var route: Array[Vector2] = game.navigation_path(enemy, false)
		var anchor: Vector2 = enemy.position
		check(not route.is_empty(), "Enemy navigation must find a route around a player mine")
		for point in route:
			check(Awareness.segment_clear(anchor, point, hazard), "Every planned segment must stay clear of the mine blast area")
			anchor = point
		enemy.controls_enabled = true
		enemy.set_physics_process(true)
		var closest := INF
		for i in range(420):
			await frames(1)
			closest = minf(closest, enemy.position.distance_to(mine_at))
			if not is_instance_valid(mine) or not enemy.alive:
				break
		check(enemy.alive and enemy.position.x > mine_at.x + 120, "%s must actually drive past a mine instead of charging into it or stopping forever" % kind)
		check(closest > 88 and is_instance_valid(mine), "%s must keep outside the mine's blast area throughout its detour" % kind)
		if is_instance_valid(mine):
			mine.owner_tank = enemy
			check(Awareness.hazards(game, enemy).is_empty(), "Enemy-owned mines that cannot damage allies must not create false hazards")
	# A fully blocked lane is safer to wait out than to cross through an armed mine.
	game.load_chapter(2)
	clear_arena()
	origin = game.region().global_position
	first = game.players[0]
	first.position = origin + Vector2(1200, 550)
	game.players[1].position = origin + Vector2(1200, 900)
	game.add_wall(Rect2(origin, Vector2(1600, 450)))
	game.add_wall(Rect2(origin + Vector2(0, 650), Vector2(1600, 450)))
	game.navigation.build(game.wall_rects, Rect2(origin, Vector2(1600, 1100)))
	var waiting = game.spawn_enemy("Yellow", origin + Vector2(400, 550), 3)
	waiting.pursuer = true
	waiting.tactical_slot = 0
	waiting.aim_target = first
	waiting.plan_timer = 999
	waiting.max_shells = 0
	waiting.max_mines = 0
	waiting.rotation = 0
	make_mine(origin + Vector2(750, 550), first, 2.4)
	waiting.controls_enabled = true
	waiting.set_physics_process(true)
	await frames(65)
	check(waiting.position.x < origin.x + 480, "An enemy must wait when a mine blocks the only safe passage")
	await frames(180)
	check(waiting.alive and waiting.position.x > origin.x + 550, "Navigation must recover when the blocking mine disappears")
	# White tanks must enter in view, then visibly transition into their cloak.
	game.stage_ready_duration = 5
	for section in [13, 14]:
		game.load_chapter(section)
		game.set_activity(false)
		game.active = true
		game.get_node("Camera").position = game.region().get_node("Start").global_position
		game.get_node("Camera").zoom = Vector2.ONE
		game.update_camera(1)
		for enemy in game.enemies:
			if not enemy.invisible_tank:
				continue
			var point: Vector2 = enemy.position - game.get_node("Camera").position + Vector2(640, 400)
			check(point.x > 70 and point.x < 1210 and point.y > 160 and point.y < 700, "White tanks must start inside the crew's entrance view")
			check(game.navigation.point_clear(enemy.position) and game.navigation.segment_clear(game.players[0].position, enemy.position, 0), "White tank introductions must be clear of scenery and visible from the entrance")
			check(enemy.body_opacity == 1 and enemy.cloak_time == 0, "White tanks must remain visible through the protected arrival")
			game.stage_ready_time = 0
			enemy.control_step(0.4)
			check(enemy.body_opacity > 0.1 and enemy.body_opacity < 0.9, "The cloak must have a visible intermediate fade")
			enemy.control_step(0.4)
			check(enemy.body_opacity == 0, "White tanks must still become fully invisible after their introduction")
	for child in game.get_children():
		if child is AudioStreamPlayer:
			child.stop()
	game.queue_free()
	await frames(8)
	StorySession.save_path = "user://adventure.cfg"
	StorySession.devices = [-1]
	print("REPAIR / MINES SMOKE: %s" % ("PASS" if failures == 0 else "%d FAILURE(S)" % failures))
	quit(0 if failures == 0 else 1)
