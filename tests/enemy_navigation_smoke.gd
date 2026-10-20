extends SceneTree

const Navigation = preload("res://scripts/mission_navigation.gd")
var game: Node2D
var failures := 0

func _initialize() -> void:
	run.call_deferred()
	create_timer(90).timeout.connect(func():
		push_error("Enemy corner navigation checks exceeded their time limit")
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

func commander(at: Vector2, target: Vector2, stale_route: bool = false) -> EnemyTank:
	game.load_chapter(14)
	game.set_activity(false)
	game.active = true
	var home: Vector2 = game.region().global_position
	var boss: EnemyTank
	for enemy in game.enemies:
		if enemy.boss:
			boss = enemy
		else:
			enemy.alive = false
			enemy.collision_layer = 0
			enemy.collision_mask = 0
	for i in range(game.players.size()):
		game.players[i].position = home + (target if i == 0 else Vector2(140, 200 + i * 170))
		game.players[i].invulnerable = true
	boss.position = home + at
	boss.rotation = PI
	boss.max_shells = 0
	boss.max_mines = 0
	boss.tactical_slot = 0
	boss.tactical_role = "Assault"
	boss.aim_target = game.players[0]
	boss.plan_timer = 99999
	boss.shot_plan.clear()
	if stale_route:
		# Simulate a previously clear route now blocked by a wall. The recovery
		# must use real reverse movement and replace this stale route.
		boss.pursuer = true
		boss.path.assign([game.players[0].position])
		boss.path_timer = 99999
	boss.controls_enabled = true
	boss.set_physics_process(true)
	return boss

func run() -> void:
	var navigation := Navigation.new()
	var walls: Array[Rect2] = [Rect2(100, 100, 100, 100)]
	navigation.build(walls, Rect2(0, 0, 400, 400))
	check(navigation.point_clear(Vector2(85, 85)), "A round tank must fit diagonally outside a wall corner")
	check(not navigation.point_clear(Vector2(90, 90)), "Rounded clearance must still block corners inside the tank radius")
	check(navigation.segment_clear(Vector2(70, 100), Vector2(100, 70)), "A full-width route must pass outside a rounded wall corner")
	check(not navigation.segment_clear(Vector2(80, 100), Vector2(100, 80)), "A route must not clip the actual rounded corner")
	check(not navigation.segment_clear(Vector2(50, 150), Vector2(250, 150)), "The rounded-corner fix must not permit travel through a wall's center")
	check(navigation.segment_clear(Vector2(85, 85), Vector2(85, 85)), "Zero-length clearance checks must agree with the circular tank body")
	check(not navigation.segment_clear(Vector2(150, 150), Vector2(150, 150)), "A zero-length check inside a wall must remain blocked")
	check(not navigation.path(Vector2(87.2, 87.2), Vector2(50, 50)).is_empty(), "A tank touching a corner must reconnect to the navigation graph")
	StorySession.save_path = "user://enemy_navigation_smoke.cfg"
	StorySession.resume_story = false
	StorySession.debug_checkpoint = 14
	for crew_size in [1, 4]:
		StorySession.devices = [-1]
		for i in range(1, crew_size): StorySession.devices.append(i + 6)
		game = load("res://scenes/story/Adventure.tscn").instantiate()
		game.save_progress = false
		game.check_devices = false
		game.intro_music = null
		game.stage_ready_duration = 0
		root.add_child(game)
		game.set_process(false)
		game.region().boss_reinforcements = false
		await frames(2)
		# This is an actual legal physics position beside the command district's
		# ruined building. Previously the boss stayed here forever with no path.
		var boss := commander(Vector2(376.7109, 827.6014), Vector2(900, 500))
		if crew_size == 4:
			boss.armor = boss.max_armor / 2 + 1
			boss.take_shell_hit(1)
			check(boss.phase_two, "The corner regression must also exercise the faster second boss phase")
		var start: Vector2 = boss.position
		check(not game.navigation_path(boss, false).is_empty(), "The Commander needs a route from the previously trapped wall corner")
		await frames(600)
		check(boss.position.distance_to(start) > 140 and boss.position.distance_to(game.players[0].position) < 400, "The real stage 15 boss must escape the corner and re-engage for %d players" % crew_size)
		boss = commander(Vector2(578.08, 490), Vector2(380, 490), true)
		var reversed := false
		var closest := INF
		var previous: Vector2 = boss.position
		var previous_frame := Engine.get_physics_frames()
		for i in range(600):
			await frames(1)
			var moved := boss.position - previous
			var physics_steps := maxi(1, Engine.get_physics_frames() - previous_frame)
			check(moved.length() < maxf(boss.forward_speed, boss.reverse_speed) * physics_steps / 60.0 + 0.5, "Corner recovery must move normally rather than teleporting")
			if i < 150 and moved.dot(Vector2.RIGHT.rotated(boss.rotation)) < -0.1:
				reversed = true
			closest = minf(closest, boss.position.distance_to(game.players[0].position))
			previous = boss.position
			previous_frame = Engine.get_physics_frames()
		check(reversed, "A stalled Commander must visibly back away from the wall")
		check(closest < 70, "After backing out the Commander must find a fresh route around the barrier")
		# Recovery must not select the empty-looking space behind it if a player
		# mine makes that escape unsafe.
		boss = commander(Vector2(578.08, 490), Vector2(380, 490), true)
		var mine := TankMine.new()
		mine.owner_tank = game.players[0]
		mine.arena = game
		mine.position = game.region().global_position + Vector2(710, 490)
		mine.fuse = 30
		game.get_node("Mines").add_child(mine)
		var nearest := INF
		for i in range(300):
			await frames(1)
			nearest = minf(nearest, boss.position.distance_to(mine.position))
		check(boss.alive and nearest > mine.blast_radius + 20, "The back-out maneuver must stay outside a nearby player's mine blast area")
		for child in game.get_children():
			if child is AudioStreamPlayer: child.stop()
		game.queue_free()
		await frames(8)
	StorySession.save_path = "user://adventure.cfg"
	StorySession.debug_checkpoint = -1
	StorySession.devices = [-1]
	print("ENEMY NAVIGATION SMOKE: %s" % ("PASS" if failures == 0 else "%d FAILURE(S)" % failures))
	quit(0 if failures == 0 else 1)
