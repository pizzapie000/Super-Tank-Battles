extends SceneTree

const Spacing = preload("res://scripts/enemy_spacing.gd")
const Navigation = preload("res://scripts/mission_navigation.gd")
const Awareness = preload("res://scripts/enemy_mine_awareness.gd")
var failures := 0

func _initialize() -> void:
	run.call_deferred()
	create_timer(120).timeout.connect(func(): quit(1))

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func frames(count: int) -> void:
	for i in range(count):
		await physics_frame
		await process_frame

func validate_route(navigation, route: Array[Vector2], from: Vector2, hazards: Array[Vector3]) -> bool:
	for point in route:
		if not navigation.segment_clear(from, point, 17.9) or not Awareness.segment_clear(from, point, hazards):
			return false
		from = point
	return true

func encounter(story: bool, crew_size: int) -> void:
	var game
	if story:
		StorySession.debug_checkpoint = 3
		StorySession.devices.assign([-1, 7, 9, 12].slice(0, crew_size))
		game = load("res://scenes/story/Adventure.tscn").instantiate()
		game.check_devices = false
	else:
		CampaignProgress.debug_mission = 0
		game = load("res://scenes/game/CampaignArena.tscn").instantiate()
		game.mission_override = 50
	game.save_progress = false
	root.add_child(game)
	game.set_process(false)
	game.active = true
	game.countdown = 0
	game.set_controls(false)
	for piece in game.mine_walls:
		piece.runtime_body.collision_layer = 0
	for child in game.get_node("Walls").get_children():
		game.get_node("Walls").remove_child(child)
		child.queue_free()
	game.wall_rects.clear()
	var origin: Vector2 = game.region().global_position if story else Vector2.ZERO
	var obstacle := Rect2(origin + Vector2(550, 320), Vector2(140, 260))
	game.add_wall(obstacle)
	game.navigation.build(game.wall_rects, Rect2(origin + Vector2(64, 152), Vector2(1152, 512)))
	var target: DuelTank = game.players[0] if story else game.player
	target.position = origin + Vector2(1100, 450)
	if story:
		for crew in game.players.slice(1): crew.position = origin + Vector2(-500, 1000)
	for enemy in game.enemies:
		enemy.alive = false
		enemy.collision_layer = 0
		enemy.controls_enabled = false
	var squad: Array = game.enemies.slice(0, 3 if story else 7)
	var starts := [Vector2(310, 420), Vector2(270, 420), Vector2(270, 460), Vector2(230, 420), Vector2(230, 460), Vector2(230, 500), Vector2(270, 500)]
	for i in range(squad.size()):
		var enemy = squad[i]
		enemy.configure("Yellow", game)
		enemy.alive = true
		enemy.collision_layer = 2
		enemy.position = origin + starts[i]
		enemy.rotation = 0
		enemy.max_shells = 0
		enemy.max_mines = 0
		enemy.aim_target = target
		enemy.plan_timer = 9999
		if story:
			enemy.pursuer = true
			enemy.tactical_slot = 0
			enemy.tactical_timer = 0
	check(Spacing.neighbors(game, squad[0]).size() >= 2, "Three or more nearby live tanks must activate crowd awareness")
	for enemy in squad.slice(2): enemy.alive = false
	check(Spacing.traffic(game, squad[1]).is_empty(), "A pair alone must retain its normal route rather than activating crowd detours")
	for enemy in squad.slice(2): enemy.alive = true
	var top := false
	var bottom := false
	for enemy in squad:
		enemy.path = game.navigation_path(enemy, false)
		enemy.path_timer = 0.45
		check(not enemy.path.is_empty() and validate_route(game.navigation, enemy.path, enemy.position, []), "Crowd routes must remain connected and clear of the actual walls")
		for point in enemy.path:
			top = top or point.y < obstacle.position.y - 19
			bottom = bottom or point.y > obstacle.end.y + 19
	check(top and bottom, "A crowded squad must choose both routes around the obstacle instead of the same lane")
	for enemy in squad:
		enemy.controls_enabled = true
		enemy.set_physics_process(true)
	var crossed_top := false
	var crossed_bottom := false
	for i in range(900):
		await frames(1)
		for enemy in squad:
			if enemy.position.x > obstacle.position.x and enemy.position.x < obstacle.end.x:
				crossed_top = crossed_top or enemy.position.y < obstacle.position.y - 17.8
				crossed_bottom = crossed_bottom or enemy.position.y > obstacle.end.y + 17.8
	check(crossed_top and crossed_bottom, "The actual moving squad must use both passages in %s with %d players" % ["story" if story else "classic", crew_size])
	for enemy in squad:
		check(enemy.position.x > origin.x + 800 and enemy.alive, "Every tank must progress beyond the obstacle without getting stuck or teleporting")
	for child in game.get_children():
		if child is AudioStreamPlayer: child.stop()
	game.queue_free()
	await frames(8)

func run() -> void:
	var navigation := Navigation.new()
	var walls: Array[Rect2] = [Rect2(64, 152, 1152, 200), Rect2(64, 450, 1152, 214)]
	navigation.build(walls)
	var traffic: Array[Vector3] = [Vector3(640, 400, 100)]
	var narrow := navigation.path(Vector2(200, 400), Vector2(1100, 400), [], traffic)
	check(not narrow.is_empty() and validate_route(navigation, narrow, Vector2(200, 400), []), "Soft crowd costs must never block the only narrow corridor")
	var mines: Array[Vector3] = [Vector3(640, 400, 102)]
	check(navigation.path(Vector2(200, 400), Vector2(1100, 400), mines, traffic).is_empty(), "Avoiding a crowd must never override a mine that blocks the sole corridor")
	navigation.build([])
	var safe := navigation.path(Vector2(200, 400), Vector2(1100, 400), mines, traffic)
	check(not safe.is_empty() and validate_route(navigation, safe, Vector2(200, 400), mines), "Alternate routes must respect mine blast clearance throughout simplification")
	await encounter(false, 1)
	await encounter(true, 1)
	await encounter(true, 4)
	StorySession.debug_checkpoint = -1
	StorySession.devices = [-1]
	print("ENEMY SPACING SMOKE: %s" % ("PASS" if failures == 0 else "%d FAILURE(S)" % failures))
	quit(0 if failures == 0 else 1)
