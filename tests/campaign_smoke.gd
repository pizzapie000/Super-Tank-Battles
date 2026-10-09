extends SceneTree

var game: Node2D
var failures: int = 0

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

func open_arena() -> void:
	for wall in game.get_node("Walls").get_children():
		game.get_node("Walls").remove_child(wall)
		wall.queue_free()
	game.wall_rects.clear()
	game.countdown = 0.0
	game.active = true
	game.set_controls(false)

func run() -> void:
	# Test real path geometry: an obstacle rules out both direct and single-bank shots.
	var room: Array[Rect2] = [Rect2(-10, -10, 420, 10), Rect2(-10, 400, 420, 10), Rect2(-10, 0, 10, 400), Rect2(400, 0, 10, 400), Rect2(130, 130, 140, 140)]
	var single := ShotPlanner.solve(Vector2(300, 100), Vector2(100, 300), Vector2.ZERO, 510.0, room, 1)
	var double := ShotPlanner.solve(Vector2(300, 100), Vector2(100, 300), Vector2.ZERO, 510.0, room, 2)
	check(single.is_empty(), "The covered target must be unreachable with one ricochet")
	check(not double.is_empty() and int(double.get("bounces", 0)) == 2, "Green must find a real two-ricochet path around cover")
	var bank_only := ShotPlanner.solve(Vector2(300, 100), Vector2(100, 300), Vector2.ZERO, 510.0, room, 2, [], 1)
	check(not bank_only.is_empty() and int(bank_only.get("bounces", 0)) == 2, "Green's bank-only constraint must still allow two-bounce paths")
	var empty_walls: Array[Rect2] = []
	var lead := ShotPlanner.solve(Vector2.ZERO, Vector2(300, 0), Vector2(0, 90), 300.0, empty_walls, 0)
	check(not lead.is_empty() and float(lead.angle) > 0.2 and lead.target.y > 80.0, "Predictive aiming must lead a moving player")
	check(ShotPlanner.solve(Vector2.ZERO, Vector2(300, 0), Vector2.ZERO, 510.0, empty_walls, 2, [], 1).is_empty(), "Bank-only aiming must reject direct shots when no wall angle exists")
	var bank_wall: Array[Rect2] = [Rect2(-100, -160, 800, 10)]
	var visible_bank := ShotPlanner.solve(Vector2.ZERO, Vector2(300, 0), Vector2(0, 90), 510.0, bank_wall, 2, [], 1)
	check(not visible_bank.is_empty() and int(visible_bank.get("bounces", 0)) == 1 and visible_bank.target.y > 0.0, "Green must choose a predictive bank angle even with direct line of sight")
	var friendly: Array[Vector2] = [Vector2(150, 0)]
	check(ShotPlanner.solve(Vector2.ZERO, Vector2(300, 0), Vector2.ZERO, 300.0, empty_walls, 0, friendly).is_empty(), "AI must avoid firing through allies")
	CampaignProgress.selected_mission = 1
	game = load("res://scenes/game/CampaignArena.tscn").instantiate()
	game.save_progress = false
	root.add_child(game)
	game.set_process(false)
	await frames(2)
	var debuts := {1: "Brown", 2: "Ash", 5: "Marine", 8: "Yellow", 10: "Pink", 12: "Green", 15: "Violet", 20: "White", 50: "Black"}
	for mission in range(1, 51):
		game.mission = mission
		game.start_round()
		await frames(2)
		check(game.tanks.size() == game.enemies.size() + 1, "Each mission needs a player and its full roster")
		if debuts.has(mission):
			check(game.enemies[0].enemy_name == debuts[mission], "Mission %d must introduce %s" % [mission, debuts[mission]])
		var visited: Dictionary = {Vector2i.ZERO: true}
		var frontier: Array[Vector2i] = [Vector2i.ZERO]
		while not frontier.is_empty():
			var cell: Vector2i = frontier.pop_front()
			for next in game.neighbors(cell):
				if not visited.has(next):
					visited[next] = true
					frontier.append(next)
		check(visited.size() == 36, "Every campaign arena must be connected")
		for enemy in game.enemies:
			check(int(enemy.profile.mission) <= mission, "Enemy types must never appear before their debut")
			for rect in game.wall_rects:
				check(not rect.grow(18.0).has_point(enemy.position), "Enemy spawns must be clear of walls")
			if enemy.forward_speed > 0.0:
				check(not game.navigation_path(enemy, false).is_empty(), "Moving enemies must be able to navigate to the player")
	# Brown must actually fire and hit a player while staying still.
	game.mission = 1
	game.start_round()
	await frames(2)
	open_arena()
	game.player.position = Vector2(300, 300)
	var brown: EnemyTank = game.enemies[0]
	brown.position = Vector2(600, 300)
	brown.turret_angle = PI
	brown.controls_enabled = true
	await frames(95)
	check(brown.position == Vector2(600, 300), "Brown must remain stationary")
	check(not game.player.alive and game.lives == 2 and game.outcome == "defeat", "Enemy AI fire must kill the player and consume a life")
	# Ash must really navigate, rather than merely storing a path.
	game.mission = 2
	game.start_round()
	await frames(2)
	game.active = true
	game.countdown = 0.0
	var ash: EnemyTank = game.enemies[0]
	var start := ash.position
	ash.cooldown = 100.0
	ash.controls_enabled = true
	await frames(180)
	check(ash.position.distance_to(start) > 85.0, "Ash must cross cell boundaries instead of circling its starting center")
	# All enemy projectile caps and bounce budgets must reach the live shell scene.
	for type_name in ["Marine", "Green", "Pink", "Violet", "Black"]:
		game.mission = int(EnemyProfiles.get_profile(type_name).mission)
		game.start_round()
		await frames(2)
		open_arena()
		var enemy: EnemyTank = game.enemies[0]
		enemy.position = Vector2(500, 300)
		enemy.turret_angle = 0.0
		if type_name == "Green":
			enemy.position = Vector2(300, 300)
			game.player.position = Vector2(500, 300)
			for other in game.enemies:
				if other != enemy:
					other.position = Vector2(900, 450)
			game.add_wall(Rect2(100, 150, 700, 10))
			await frames(2)
			enemy.plan_timer = 0.0
			enemy.control_step(0.0)
			check(not enemy.shot_plan.is_empty(), "Green must find a bank angle for its firing-cap check")
			enemy.turret_angle = float(enemy.shot_plan.get("angle", 0.0))
		for i in range(enemy.max_shells + 2):
			game.fire_shell(enemy)
		check(enemy.active_shells == enemy.max_shells, "AI must respect its simultaneous shot cap")
		var shell: DuelShell = game.get_node("Shells").get_child(0)
		check(shell.speed == enemy.shell_speed and shell.max_bounces == enemy.ricochets + 1, "Enemy bullets must use the profile speed and ricochet budget")
		check(shell.is_missile == (type_name == "Green"), "Only Green must fire the new missile projectile")
	# Green must withhold fire without a bank angle, including the actual firing entry point.
	game.mission = 12
	game.start_round()
	await frames(2)
	open_arena()
	var green: EnemyTank = game.enemies[0]
	green.position = Vector2(300, 300)
	game.player.position = Vector2(500, 300)
	for other in game.enemies:
		if other != green:
			other.position = Vector2(900, 450)
	green.plan_timer = 0.0
	green.control_step(1.0)
	game.fire_shell(green)
	check(not green.wants_fire() and green.active_shells == 0, "Green must never fire a direct shot without a valid bank angle")
	game.add_wall(Rect2(100, 150, 700, 10))
	await frames(2)
	green.plan_timer = 0.0
	green.control_step(1.0)
	check(green.wants_fire() and not green.aimed_path().is_empty(), "Green must fire when its barrel aligns with a valid bank path")
	game.fire_shell(green)
	var missile: DuelShell = game.get_node("Shells").get_child(0)
	# Observe the trail at the actual bounce, while the missile is alive.
	# Multiple physics steps can run between process frames under rendering load.
	var observed_bounce: Array[bool] = [false]
	missile.bounced.connect(func(_point: Vector2):
		observed_bounce[0] = true
		check(missile.is_missile and missile.trail.size() > 8, "Green missiles must build a longer exhaust trail than normal bullets")
	)
	await frames(50)
	check(observed_bounce[0], "Green's real missile must execute its planned bank shot")
	check(not game.player.alive, "Green's real bank-shot missile must bounce and hit the player")
	# White becomes invisible but leaves visible ground tracks.
	game.mission = 20
	game.start_round()
	await frames(2)
	open_arena()
	var white: EnemyTank = game.enemies[0]
	white.control_step(1.0)
	check(white.body_opacity == 0.0, "White must become invisible when the mission starts")
	white.velocity = Vector2(85, 0)
	game.stamp_tracks()
	check(not game.track_marks.is_empty() and game.track_marks.back().white, "Invisible White tanks must leave tracks")
	# Yellow's rapid deployment and four-mine cap.
	game.mission = 8
	game.start_round()
	await frames(2)
	open_arena()
	var yellow: EnemyTank = game.enemies[0]
	check(yellow.mine_cooldown < 3.5 and yellow.max_mines == 4, "Yellow must deploy mines faster and hold four")
	for i in range(5):
		yellow.position = Vector2(300 + i * 40, 300)
		yellow.mine_timer = 0.0
		game.drop_mine(yellow)
	check(yellow.active_mines == 4 and game.get_node("Mines").get_child_count() == 4, "Mine deployment must respect the active cap")
	# Chain blasts, shell impact, proximity arming, and pause use actual physics bodies.
	game.mission = 1
	game.start_round()
	await frames(2)
	open_arena()
	game.player.position = Vector2(300, 300)
	game.enemies[0].position = Vector2(900, 450)
	game.drop_mine(game.player)
	game.player.position = Vector2(365, 300)
	game.player.mine_timer = 0.0
	game.drop_mine(game.player)
	game.player.position = Vector2(700, 450)
	await frames(2)
	game.get_node("Mines").get_child(0).detonate()
	await frames(2)
	check(game.get_node("Mines").get_child_count() == 0 and game.player.active_mines == 0, "Mine chains must release both ammunition slots")
	game.player.position = Vector2(300, 300)
	game.player.mine_timer = 0.0
	game.drop_mine(game.player)
	var mine: TankMine = game.get_node("Mines").get_child(0)
	game.freeze_ordnance(true)
	var age := mine.age
	await frames(10)
	check(mine.age == age, "Pause must freeze mine fuses and arming")
	game.freeze_ordnance(false)
	await frames(48)
	check(not game.player.alive, "Armed mines must be lethal to their owner")
	# A shell must detonate a mine on contact, even before proximity arming.
	game.start_round()
	await frames(2)
	open_arena()
	game.player.position = Vector2(360, 300)
	game.drop_mine(game.player)
	game.player.position = Vector2(300, 300)
	game.player.turret_angle = 0.0
	game.enemies[0].position = Vector2(900, 450)
	await frames(2)
	game.fire_shell(game.player)
	await frames(10)
	check(game.get_node("Mines").get_child_count() == 0 and not game.player.alive, "A bullet hitting a mine must detonate its blast")
	# Clearing a mission must advance only on Enter; death must retry the same mission.
	game.lives = 3
	game.mission = 12
	game.start_round()
	await frames(2)
	for enemy in game.enemies:
		enemy.take_hit()
	await frames(2)
	check(game.outcome == "clear" and not game.active and game.lives == 3, "Clearing enemies must win and stop the mission")
	Input.action_press("rematch")
	game._process(0.0)
	Input.action_release("rematch")
	check(game.mission == 13 and game.outcome.is_empty(), "Enter must advance after clearing a mission")
	await frames(2)
	game.player.take_hit()
	await frames(2)
	Input.action_press("rematch")
	game._process(0.0)
	Input.action_release("rematch")
	check(game.mission == 13 and game.lives == 2 and game.player.alive, "Retry must preserve mission number and consume a life")
	await frames(2)
	# A simultaneous player/enemy trade is a defeat, not a free mission unlock.
	game.player.take_hit()
	for enemy in game.enemies:
		enemy.take_hit()
	await frames(2)
	check(game.outcome == "defeat", "A player death must take priority over mission clear")
	game.mission = 50
	game.start_round()
	await frames(2)
	for enemy in game.enemies:
		enemy.take_hit()
	await frames(2)
	check(game.outcome == "complete", "Mission 50 must end the campaign")
	for child in game.get_children():
		if child is AudioStreamPlayer:
			child.stop()
	await frames(10)
	game.queue_free()
	await frames(10)
	# Main menu must expose both playable modes without changing save progress.
	var menu: Control = load("res://scenes/game/MainMenu.tscn").instantiate()
	root.add_child(menu)
	await frames(2)
	check(menu.mission_select.item_count >= 1, "Main menu must offer the campaign mission selector")
	menu.show_guide()
	await frames(2)
	check(is_instance_valid(menu.guide), "Enemy field guide must open")
	menu.queue_free()
	await frames(2)
	print("CAMPAIGN SMOKE: %s" % ("PASS" if failures == 0 else "%d FAILURE(S)" % failures))
	quit(0 if failures == 0 else 1)
