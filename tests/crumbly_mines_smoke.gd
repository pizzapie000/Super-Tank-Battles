extends SceneTree

const Crumbly = preload("res://scenes/levels/pieces/CrumblyWall.tscn")
const Awareness = preload("res://scripts/enemy_mine_awareness.gd")
var failures := 0
var game: Node2D

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

func clear_arena() -> void:
	game.set_process(false)
	game.active = true
	game.paused = false
	game.countdown = 0
	game.set_controls(false)
	for node in ["Walls", "Shells", "Mines", "Effects"]:
		for child in game.get_node(node).get_children():
			game.get_node(node).remove_child(child)
			child.queue_free()
	game.wall_rects.clear()
	game.mine_walls.clear()
	game.navigation.build(game.wall_rects)
	for i in range(game.tanks.size()):
		game.tanks[i].position = Vector2(1100, 600 - i * 50)
		game.tanks[i].active_mines = 0
		game.tanks[i].active_shells = 0
		game.tanks[i].max_shells = 0
		game.tanks[i].stop_motion()

func add_wall(at: Vector2, size: Vector2) -> Node2D:
	var wall = Crumbly.instantiate()
	wall.position = at
	wall.size = size
	game.get_node("Walls").add_child(wall)
	wall.activate()
	game.mine_walls.append(wall)
	game.wall_rects.append(wall.wall_rect())
	game.rebuild_navigation()
	return wall

func stop_audio() -> void:
	for child in game.get_children():
		if child is AudioStreamPlayer: child.stop()

func run() -> void:
	CampaignProgress.debug_mission = 0
	game = load("res://scenes/game/CampaignArena.tscn").instantiate()
	game.mission_override = 20
	game.save_progress = false
	root.add_child(game)
	game.set_process(false)
	for number in [7, 8, 12, 20, 25, 30, 35, 40, 45, 50]:
		game.mission = number
		game.start_round()
		check(game.mine_walls.size() == 2 and game.mine_walls.all(func(wall): return wall.runtime_body.collision_layer == 1), "Authored classic crumbly pieces must create their own real colliders")
	game.mission = 20
	game.start_round()
	clear_arena()
	var wall = add_wall(Vector2(600, 350), Vector2(28, 128))
	var old_rect: Rect2 = wall.wall_rect()
	var player: DuelTank = game.player
	player.max_shells = 5
	player.position = Vector2(450, 400)
	player.rotation = 0
	player.turret_angle = 0
	check(not game.navigation.segment_clear(Vector2(450, 400), Vector2(750, 400)), "Intact crumbly walls must block navigation and shot planning")
	game.fire_shell(player)
	await frames(30)
	var shell = game.get_node("Shells").get_child(0)
	check(shell.direction.x < 0 and shell.bounce_count == 1 and not wall.broken, "An actual shell must ricochet from crumbly masonry without damaging it")
	shell.retire()
	await frames(2)
	player.position = Vector2(540, 400)
	player.controls_enabled = true
	Input.action_press("solo_right")
	await frames(35)
	Input.action_release("solo_right")
	player.controls_enabled = false
	check(player.position.x <= old_rect.position.x - 17.8 and not wall.broken, "A driven tank must collide with crumbly walls without breaking them")
	game.drop_mine(player)
	var mine: TankMine = game.get_node("Mines").get_child(0)
	player.position = Vector2(450, 400)
	mine.fuse = 0.1
	await frames(10)
	check(wall.broken and not wall.visible and wall.runtime_body.collision_layer == 0, "A real nearby mine blast must remove a crumbly wall's art and collider")
	check(not game.wall_rects.has(old_rect) and game.navigation.segment_clear(Vector2(450, 400), Vector2(750, 400)), "A mine breach must update both the wall list and AI navigation")
	player.cooldown = 0
	player.turret_angle = 0
	game.fire_shell(player)
	await frames(40)
	shell = game.get_node("Shells").get_child(0)
	check(shell.position.x > old_rect.end.x and shell.direction.x > 0 and shell.bounce_count == 0, "Shots must fly through the actual breach without hitting an invisible replacement wall")
	shell.retire()
	game.start_round()
	check(game.mine_walls.all(func(piece): return not piece.broken and piece.runtime_body.collision_layer == 1), "Retry must restore the authored mine-only walls")
	# Use the real slowest and fastest mine layers. Their deployment must produce
	# an immediate physical retreat instead of continuing to chase over the mine.
	for kind in ["Yellow", "Violet", "White", "Black"]:
		game.mission = int(EnemyProfiles.get_profile(kind).mission)
		game.start_round()
		clear_arena()
		var enemy: EnemyTank = game.enemies[0]
		enemy.position = Vector2(450, 400)
		enemy.rotation = 0
		enemy.mine_timer = 0
		enemy.controls_enabled = true
		game.player.position = Vector2(750, 400)
		if kind != "Yellow": game.player.position = Vector2(690, 400)
		enemy.mine_intent = true
		check(enemy.wants_mine(), "%s must recognize an open, safe mine escape lane" % kind)
		game.drop_mine(enemy)
		mine = game.get_node("Mines").get_child(0)
		var placed_at := mine.position
		await frames(105)
		check(enemy.alive and enemy.position.distance_to(placed_at) > mine.blast_radius and enemy.active_mines <= enemy.max_mines, "%s must physically escape its own mine before it arms" % kind)
		check(is_instance_valid(mine) and not mine.released, "%s must avoid retriggering the mine during its retreat" % kind)
		enemy.controls_enabled = false
	# An enemy boxed into a tiny bay must refuse to plant a suicide mine.
	game.start_round()
	clear_arena()
	var trapped: EnemyTank = game.enemies[0]
	trapped.position = Vector2(500, 400)
	trapped.rotation = 0
	trapped.mine_timer = 0
	trapped.mine_intent = true
	game.add_wall(Rect2(525, 300, 20, 200))
	game.add_wall(Rect2(455, 300, 20, 200))
	game.rebuild_navigation()
	check(not trapped.wants_mine(), "A mine layer must wait if no safe escape lane exists")
	stop_audio()
	game.queue_free()
	await frames(8)
	var layout = load("res://scenes/levels/missions/Mission20.tscn").instantiate()
	root.add_child(layout)
	current_scene = layout
	await frames(4)
	game = current_scene
	game.set_process(false)
	game.set_controls(false)
	check(game.external_layout == layout and not game.save_progress and game.mine_walls.size() == 2, "Running an authored crumbly mission directly must use the normal safe preview")
	var source_wall = layout.get_node("Walls").get_child(0)
	check(not is_instance_valid(source_wall.runtime_body), "The hidden editor-source wall must not leave a second collider under the playable preview")
	var preview_wall = game.mine_walls[0]
	var breach_at: Vector2 = preview_wall.wall_rect().get_center()
	game.break_mine_walls(breach_at, 78)
	await frames(2)
	var ray := PhysicsRayQueryParameters2D.create(breach_at - Vector2(0, 40), breach_at + Vector2(0, 40), 1)
	check(preview_wall.broken and game.get_world_2d().direct_space_state.intersect_ray(ray).is_empty(), "A preview breach must remove all actual collision at the authored wall")
	game.queue_free()
	await frames(3)
	StorySession.devices = [-1, 7]
	StorySession.debug_checkpoint = 3
	game = load("res://scenes/story/Adventure.tscn").instantiate()
	game.save_progress = false
	game.check_devices = false
	root.add_child(game)
	game.set_process(false)
	for section in [1, 3, 4, 5, 6, 7, 8, 10, 11, 12, 14, 16, 19]:
		game.load_chapter(section)
		game.set_activity(false)
		var local_walls: Array = game.mine_walls.filter(func(piece): return game.region().is_ancestor_of(piece))
		check(local_walls.size() == 2, "Every selected story area must load its editable crumbly cover")
	game.load_chapter(3)
	game.set_activity(false)
	game.stage_ready_time = 0
	game.active = true
	var origin: Vector2 = game.region().global_position
	var crew = game.players[0]
	var friend = game.players[1]
	crew.invulnerable = false
	friend.invulnerable = false
	crew.armor = 3
	friend.armor = 3
	crew.position = origin + Vector2(150, 550)
	friend.position = crew.position + Vector2(50, 0)
	var enemy = game.enemies[0]
	var ally = game.enemies[1]
	var enemy_armor: int = enemy.armor
	var ally_armor: int = ally.armor
	enemy.position = origin + Vector2(700, 900)
	ally.position = enemy.position + Vector2(50, 0)
	game.drop_mine(crew)
	mine = game.get_node("Mines").get_child(0)
	mine.detonate()
	check(crew.armor == 2 and friend.armor == 2, "A crew mine must injure its owner and nearby teammates")
	enemy.max_mines = 1
	enemy.mine_timer = 0
	game.drop_mine(enemy)
	mine = game.get_node("Mines").get_child(1)
	check(not Awareness.hazards(game, enemy).is_empty(), "Enemy mines must remain hazards to their own team")
	mine.detonate()
	check(enemy.armor == enemy_armor - 1 and ally.armor == ally_armor - 1, "Enemy mines must also damage their owner and allied enemies, including armored carriers")
	var authored = game.region().get_node("Rubble").get_child(0)
	var point: Vector2 = authored.wall_rect().get_center()
	var blast := TankMine.new()
	blast.position = point
	blast.arena = game
	game.get_node("Mines").add_child(blast)
	blast.detonate()
	check(authored.broken and not game.navigation.walls.has(authored.wall_rect()), "Story mine blasts must open authored wall geometry and rebuild local navigation")
	game.load_chapter(3)
	check(not authored.broken and authored.runtime_body.collision_layer == 1, "Retrying a story checkpoint must restore its crumbly walls")
	stop_audio()
	game.queue_free()
	await frames(10)
	StorySession.devices = [-1]
	StorySession.debug_checkpoint = -1
	print("CRUMBLY WALL / MINES SMOKE: %s" % ("PASS" if failures == 0 else "%d FAILURE(S)" % failures))
	quit(0 if failures == 0 else 1)
