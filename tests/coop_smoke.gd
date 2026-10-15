extends SceneTree

const Tactics = preload("res://scripts/story/story_tactics.gd")
var game: Node2D
var failures := 0

func _initialize() -> void:
	run.call_deferred()
	create_timer(120).timeout.connect(func():
		push_error("Co-op checks exceeded their time limit")
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

func freeze_chapter(section: int) -> void:
	game.load_chapter(section)
	game.set_activity(false)
	game.active = true

func put_crew_at_trigger() -> void:
	var at: Vector2 = game.region().get_node("AmbushTrigger").global_position
	var points: Array = game.navigation.points.values()
	points.sort_custom(func(a: Vector2, b: Vector2): return a.distance_squared_to(at) < b.distance_squared_to(at))
	var placed: Array[Vector2] = []
	for crew in game.players:
		for candidate in points:
			var crowded := false
			for other in placed:
				if candidate.distance_to(other) < 65:
					crowded = true
			if not crowded and not game.navigation.path(crew.position, candidate).is_empty():
				crew.position = candidate
				placed.append(candidate)
				break

func run() -> void:
	StorySession.save_path = "user://coop_smoke.cfg"
	StorySession.resume_story = false
	StorySession.devices = [-1]
	game = load("res://scenes/story/Adventure.tscn").instantiate()
	game.save_progress = false
	game.check_devices = false
	root.add_child(game)
	game.set_process(false)
	await frames(2)
	# Validate actual loaded counts, spawn geometry and armor across the full route.
	for crew_size in range(1, 5):
		StorySession.devices.assign([-1, 7, 9, 12].slice(0, crew_size))
		for section in [1, 2, 3, 4, 5, 6, 7, 10, 11]:
			freeze_chapter(section)
			await frames(2)
			var base := 0
			var bosses := 0
			for marker in game.region().get_node("Enemies").get_children():
				if not marker.boss_title.is_empty():
					bosses += 1
				elif not marker.dormant:
					base += 1
			var expected := roundi(base * (1 + 0.4 * (crew_size - 1)))
			check(game.remaining_enemies() - bosses == expected, "Actual encounter budgets must follow 100/140/180/220 percent in section %d for %d players" % [section, crew_size])
			for i in range(game.region().get_node("Enemies").get_child_count()):
				var marker = game.region().get_node("Enemies").get_child(i)
				check(game.enemies[i].max_armor == marker.armor, "Adding players must not increase authored enemy or boss armor")
			for enemy in game.enemies:
				check(game.navigation.point_clear(enemy.position), "Scaled enemies must spawn clear of all solid scenery")
				check(not game.navigation.path(enemy.position, game.target_for_enemy(enemy).position).is_empty(), "Every scaled enemy must have a real route to its assigned player")
			if crew_size == 1:
				check(game.pending_attackers.is_empty() and game.enemies.size() == base + bosses, "Solo must retain the authored roster without co-op ambushes")
			if section == 2 and crew_size == 4:
				var names: Array[String] = []
				for enemy in game.enemies:
					names.append(enemy.enemy_name)
				for spec in game.pending_attackers:
					names.append(spec.type)
				check(names.has("Yellow") and names.has("Pink") and names.has("Marine"), "Large crews must meet mine, multi-shot and fast-shot specialists in the first wasteland section")
			if crew_size > 1 and section != 1:
				var budget: int = game.remaining_enemies()
				var initial: int = game.enemies.size()
				put_crew_at_trigger()
				game.update_ambush(0.1)
				game.set_activity(false)
				game.active = true
				check(game.pending_attackers.is_empty(), "Designed ambush entries must have space for every reserved enemy: section %d, crew %d, pending %s" % [section, crew_size, game.pending_attackers])
				check(game.remaining_enemies() == budget, "Rear and fortress waves must remain inside the scaled count budget")
				for enemy in game.enemies.slice(initial):
					check(game.navigation.point_clear(enemy.position), "Ambushes must spawn clear of rubble and their opened entrance gates")
					check(not game.navigation.path(enemy.position, game.target_for_enemy(enemy).position).is_empty(), "Ambush attackers must be able to reach the crew")
			if section == 7:
				var open_count := 0
				for entry in game.region().get_node("CoopEntries").get_children():
					if not entry.gate().visible:
						open_count += 1
				check(open_count == crew_size, "The fortress must use one entrance solo and two/three/four entrances for co-op")
			if crew_size == 4 and section == 3:
				var targets: Array[int] = []
				for enemy in game.enemies:
					if not targets.has(game.target_for_enemy(enemy).player_index):
						targets.append(game.target_for_enemy(enemy).player_index)
				check(targets.size() == 4, "The enemy squad must divide its attention among all four players")
	# Cover and flank decisions use real geometry and valid routes on a controlled board.
	StorySession.devices = [-1, 7, 9, 12]
	freeze_chapter(3)
	for child in game.get_node("Walls").get_children():
		game.get_node("Walls").remove_child(child)
		child.queue_free()
	game.wall_rects.clear()
	game.add_wall(Rect2(650, 300, 80, 140))
	game.navigation.build(game.wall_rects, Rect2(0, 0, 1600, 1100))
	for crew in game.players:
		crew.position = Vector2(300 + crew.player_index * 45, 400)
		crew.invulnerable = true
	for enemy in game.enemies:
		enemy.position = Vector2(1200, 850)
	var support = game.enemies[2]
	support.position = Vector2(850, 400)
	support.tactical_role = "Support"
	var target: DuelTank = game.players[0]
	var cover := Tactics.cover_goal(game, support, target)
	check(cover.is_finite() and game.navigation.point_clear(cover) and not game.navigation.segment_clear(cover, target.position, 0), "Support must select reachable cover that actually blocks direct fire")
	var flanker = game.enemies[1]
	flanker.tactical_role = "Flank"
	flanker.position = Vector2(850, 550)
	flanker.tactical_timer = 0
	var path: Array[Vector2] = game.navigation_path(flanker, false)
	check(not path.is_empty() and path.back().distance_to(game.target_for_enemy(flanker).position) > 150, "Flankers must use a distinct side approach instead of converging on the player center")
	var start: Vector2 = flanker.position
	flanker.controls_enabled = true
	flanker.max_shells = 0
	flanker.set_physics_process(true)
	await frames(55)
	check(flanker.position.distance_to(start) > 25, "A flanker must actually drive along its attack route")
	flanker.set_physics_process(false)
	for enemy in game.enemies:
		if enemy != support:
			enemy.position = Vector2(1400, 1000)
	support.position = Vector2(500, 400)
	support.ricochets = 1
	support.min_ricochets = 0
	target.position = Vector2(850, 400)
	var bank_walls: Array[Rect2] = [Rect2(100, 160, 1400, 30)]
	var plan: Dictionary = game.plan_enemy_shot(support, target, bank_walls)
	check(not plan.is_empty() and int(plan.bounces) == 1 and int(plan.min_bounces) == 1, "Co-op support must prefer a valid bank shot even when a direct shot is available")
	# Pickup ownership, one-slot tradeoffs, repair behavior and checkpoint persistence.
	freeze_chapter(2)
	var kinds := ["Loader", "Armor", "Bank Shot", "Engine"]
	for i in range(4):
		var pickup = game.region().get_node("Parts").get_child(i)
		var crew = game.players[i]
		crew.position = pickup.global_position + Vector2(20, 0)
		crew.interact_held = true
		game.update_part_pickups(0.5)
		crew.interact_held = false
		check(pickup.claimed and crew.equipped_part == kinds[i] and game.part_loadouts[i] == kinds[i], "Each crate must belong to the player who equips it")
	check(game.players[0].shot_cooldown < 0.32 and game.players[1].max_armor == 4 and game.players[1].forward_speed < 150, "Loader and armor kits must offer distinct reload and protection roles")
	check(game.players[2].shell_wall_hits == 3 and game.players[2].ricochet_bonus_damage == 1 and game.players[3].forward_speed > 150 and game.players[3].max_armor == 2, "Bank and engine kits must offer real ricochet and movement tradeoffs")
	game.supplies = 10
	game.repair_cooldown = 0
	for crew in game.players:
		crew.armor = 1
	game.field_repair()
	for crew in game.players:
		check(crew.armor == crew.max_armor, "Field repair must respect each player's equipped armor capacity")
	freeze_chapter(3)
	check(game.players[0].equipped_part == "Loader" and game.players[3].max_armor == 2, "Part roles must survive section transitions")
	game.players[0].equip_part("Engine")
	game.part_loadouts[0] = "Engine"
	game.retry_checkpoint()
	game.set_activity(false)
	check(game.players[0].equipped_part == "Loader", "Retry must restore the section's starting loadouts without stacking pickups")
	game.persist_story()
	var saved := StorySession.checkpoint()
	check(saved.parts == kinds, "Checkpoints must save each player's part slot")
	# Real bank-kit damage: a bounced shell deals two, a direct shell still deals one.
	freeze_chapter(1)
	await frames(2)
	for crew in game.players:
		crew.position = Vector2(2450 + crew.player_index * 55, 900)
	var shooter = game.players[2]
	shooter.position = Vector2(1780, 550)
	shooter.turret_angle = 0
	var victim = game.enemies[0]
	victim.position = Vector2(1730, 550)
	victim.armor = 4
	victim.max_armor = 4
	game.add_wall(Rect2(1920, 520, 12, 70))
	await frames(2)
	game.fire_shell(shooter)
	var shell = game.get_node("Shells").get_child(0)
	shell.bounced.connect(func(_point: Vector2): shooter.position.y += 100)
	await frames(75)
	check(victim.armor == 2, "A real shell from the bank kit must deal two damage after ricocheting")
	shooter.position = Vector2(1780, 550)
	victim.position = Vector2(1850, 550)
	game.fire_shell(shooter)
	await frames(25)
	check(victim.armor == 1, "The bank kit must not double direct-shot damage")
	for node in game.get_children():
		if node is AudioStreamPlayer:
			node.stop()
	game.queue_free()
	await frames(15)
	StorySession.resume_story = true
	game = load("res://scenes/story/Adventure.tscn").instantiate()
	game.save_progress = false
	game.check_devices = false
	root.add_child(game)
	game.set_process(false)
	game.set_activity(false)
	check(game.chapter == 3 and game.players[1].equipped_part == "Armor" and game.players[3].max_armor == 2, "Continuing the adventure must restore player roles from disk")
	game.queue_free()
	await frames(15)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(StorySession.save_path))
	StorySession.save_path = "user://adventure.cfg"
	StorySession.devices = [-1]
	StorySession.resume_story = false
	print("CO-OP SMOKE: %s" % ("PASS" if failures == 0 else "%d FAILURE(S)" % failures))
	quit(0 if failures == 0 else 1)
