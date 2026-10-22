extends SceneTree

var failures := 0

func _initialize() -> void:
	run.call_deferred()
	create_timer(90).timeout.connect(func(): push_error("Green self-hit checks timed out"); quit(1))

func check(condition: bool, message: String) -> void:
	if condition: return
	failures += 1
	push_error(message)

func frames(count: int = 2) -> void:
	for _frame in range(count):
		await physics_frame
		await process_frame

func reference_safe(at: Vector2, direction: Vector2, shooter: Vector2, walls: Array[Rect2], budget: int) -> bool:
	# An independent ray/circle quadratic checks the complete bounced flight.
	var boxes := ShotPlanner.prepare_walls(walls)
	for bounce in range(budget + 1):
		var wall := ShotPlanner.first_prepared_wall(at, direction, boxes, INF)
		var limit: float = wall.get("distance", INF)
		var offset := at - shooter
		var c := offset.length_squared() - 625.0
		if c <= 0: return false
		var b := 2 * offset.dot(direction)
		var disc := b * b - 4 * c
		if disc >= 0:
			var entry := (-b - sqrt(disc)) * 0.5
			if entry >= 0 and entry <= limit: return false
		if wall.is_empty() or bounce == budget: return true
		at = wall.point + wall.normal * 0.05
		direction = direction.bounce(wall.normal)
	return true

func geometry_checks() -> void:
	var origin := Vector2(300, 300)
	var front: Array[Rect2] = [Rect2(500, 0, 10, 800)]
	check(not ShotPlanner.avoids_shooter(origin + Vector2(31, 0), Vector2.RIGHT, origin, front, 2), "A head-on bank returning through the shooter must be unsafe")
	check(ShotPlanner.avoids_shooter(origin + Vector2(31, 0), Vector2.RIGHT, origin, front, 0), "A shell destroyed at its first wall must not count a nonexistent return bounce")
	var far_wall: Array[Rect2] = [Rect2(5000, 0, 10, 800)]
	check(not ShotPlanner.avoids_shooter(origin + Vector2(31, 0), Vector2.RIGHT, origin, far_wall, 2), "Unlimited-lifetime missiles must check return bounces beyond the targeting search distance")
	check(not ShotPlanner.solve(origin, Vector2(100, 300), Vector2.ZERO, 510, front, 2, [], 1).is_empty(), "The regression fixture must reproduce the previously accepted self-hit plan")
	check(ShotPlanner.solve(origin, Vector2(100, 300), Vector2.ZERO, 510, front, 2, [], 1, false, true).is_empty(), "Green must hold fire when the only available bank crosses its own hull")
	front.append(Rect2(-100, 0, 900, 10))
	var original := ShotPlanner.solve(origin, Vector2(100, 300), Vector2.ZERO, 510, front, 2, [], 1)
	check(is_zero_approx(original.angle), "The shortest legacy candidate must be the dangerous head-on bank")
	for simple in [false, true]:
		var safe := ShotPlanner.solve(origin, Vector2(100, 300), Vector2.ZERO, 510, front, 2, [], 1, simple, true)
		check(not safe.is_empty() and absf(safe.angle) > 0.5 and int(safe.bounces) >= 1, "Solo and co-op planning must find a longer safe alternative instead of repeatedly choosing the unsafe bank")
		if not safe.is_empty():
			var heading := Vector2.RIGHT.rotated(safe.angle)
			check(reference_safe(origin + heading * 31, heading, origin, front, 2), "The selected alternative must pass the independent full-flight safety check")
	var corner: Array[Rect2] = [Rect2(0, 100, 800, 20), Rect2(494.5, 100, 20, 700)]
	var diagonal := Vector2(1, -1).normalized()
	var past_target := ShotPlanner.trace(origin + diagonal * 31, diagonal, Vector2(400, 229.05), corner, 2, [], 1)
	check(not past_target.is_empty() and past_target.bounces == 2, "The double-bank fixture must reach its target before returning near its own hull")
	check(not ShotPlanner.avoids_shooter(origin + diagonal * 31, diagonal, origin, corner, 2), "The full-flight check must catch a self-hit after the predicted target position is missed")
	corner[1] = Rect2(520, 100, 20, 700)
	check(ShotPlanner.avoids_shooter(origin + diagonal * 31, diagonal, origin, corner, 2), "A nearby double-bank path that clears the hull must remain allowed")
	var top: Array[Rect2] = [Rect2(-100, -160, 800, 10)]
	var predictive := ShotPlanner.solve(Vector2.ZERO, Vector2(300, 0), Vector2(0, 90), 510, top, 2, [], 1, false, true)
	check(not predictive.is_empty() and predictive.bounces == 1 and predictive.target.y > 0, "Safe Green plans must still lead moving targets using a bank shot")
	var rng := RandomNumberGenerator.new()
	rng.seed = 771309
	var walls: Array[Rect2] = [Rect2(-10, -10, 820, 10), Rect2(-10, 600, 820, 10), Rect2(-10, 0, 10, 600), Rect2(800, 0, 10, 600), Rect2(190, 180, 70, 240), Rect2(520, 130, 60, 140)]
	var boxes := ShotPlanner.prepare_walls(walls)
	for sample in range(1000):
		var shooter := Vector2(rng.randf_range(40, 760), rng.randf_range(40, 560))
		var direction := Vector2.RIGHT.rotated(rng.randf_range(-PI, PI))
		var muzzle := shooter + direction * 31
		var budget := sample % 3
		check(ShotPlanner.avoids_shooter(muzzle, direction, shooter, walls, budget, boxes) == reference_safe(muzzle, direction, shooter, walls, budget), "Seeded ricochet checks must agree with independent ray/circle intersections")

func fixture(arena: Node2D, green: EnemyTank, walls: Array[Rect2], target: Vector2) -> void:
	for shell in arena.get_node("Shells").get_children(): shell.retire()
	for wall in arena.get_node("Walls").get_children():
		arena.get_node("Walls").remove_child(wall)
		wall.queue_free()
	arena.wall_rects.clear()
	for wall in walls: arena.add_wall(wall)
	for tank in arena.tanks:
		tank.controls_enabled = false
		tank.set_physics_process(false)
	for enemy in arena.enemies:
		if enemy != green: enemy.position = Vector2(40000, 900)
	green.position = Vector2(300, 300)
	green.cooldown = 0
	green.plan_timer = 10
	green.shot_plan.clear()
	arena.player.position = target
	arena.player.velocity = Vector2.ZERO
	green.aim_target = arena.player
	arena.paused = false
	arena.active = true

func live_checks(arena: Node2D) -> void:
	var green: EnemyTank = arena.enemies.filter(func(enemy): return enemy.enemy_name == "Green")[0]
	var wall: Array[Rect2] = [Rect2(500, 0, 10, 800)]
	fixture(arena, green, wall, Vector2(100, 300))
	await frames()
	green.plan_timer = 0
	green.control_step(1)
	check(green.shot_plan.is_empty(), "Both campaign and missions must request self-safe planning for Green tanks")
	green.turret_angle = 0
	green.shot_plan = {"angle": 0.0, "target": arena.player.position, "bounces": 1}
	check(green.aimed_path().is_empty(), "The actual muzzle must reject a cached plan that returns through the shooter")
	green.control_step(0.001)
	arena.fire_shell(green)
	check(not green.wants_fire() and green.active_shells == 0 and arena.get_node("Shells").get_child_count() == 0, "AI intent and the real arena firing entry point must both block unsafe Green shots")
	var alternatives: Array[Rect2] = [wall[0], Rect2(-100, 0, 900, 10)]
	fixture(arena, green, alternatives, Vector2(100, 300))
	await frames()
	green.plan_timer = 0
	green.control_step(1)
	check(not green.shot_plan.is_empty() and absf(green.shot_plan.get("angle", 0)) > 0.5, "Both arena modes must choose a safe alternative through their actual AI planner")
	fixture(arena, green, wall, Vector2(100, 347.55))
	await frames()
	# A safe cached aim can become unsafe while the turret is still within the
	# firing tolerance. The recheck must use the barrel, not the planned angle.
	green.shot_plan = {"angle": 0.08, "target": arena.player.position, "bounces": 1}
	var intended := Vector2.RIGHT.rotated(0.08)
	check(ShotPlanner.avoids_shooter(green.position + intended * 31, intended, green.position, wall, 2), "The turret-tolerance fixture's intended aim must be safe")
	green.turret_angle = 0.05
	check(not ShotPlanner.trace(green.position + green.firing_direction() * 31, green.firing_direction(), arena.player.position, wall, 2, [], 1).is_empty(), "The uncorrected barrel angle must still appear to reach the target")
	green.control_step(0.001)
	arena.fire_shell(green)
	check(not green.wants_fire() and green.active_shells == 0, "A slightly misaligned barrel must not fire a self-hit even if its stored aim is safe")
	# The same tank must still be able to fire a safe missile and survive if the
	# player dodges. No immunity or altered projectile damage is involved.
	green.turret_angle = 0.08
	check(not green.aimed_path().is_empty(), "Safe one-bank firing paths must remain available")
	arena.fire_shell(green)
	check(green.active_shells == 1, "A real safe Green missile must still launch")
	arena.player.position = Vector2(100, 800)
	await frames(100)
	check(green.alive, "The Green shooter must survive its safe ricochet when the player dodges")
	# A different two-wall return can reach the player's predicted position first
	# and only then clip its own hull. Withhold fire even though target trace hits.
	var corner: Array[Rect2] = [Rect2(0, 100, 800, 20), Rect2(494.5, 100, 20, 700)]
	fixture(arena, green, corner, Vector2(400, 229.05))
	await frames()
	green.turret_angle = -PI / 4
	green.shot_plan = {"angle": -PI / 4, "target": arena.player.position, "bounces": 2}
	check(green.aimed_path().is_empty(), "A real two-bank plan must be rejected if a miss would return into the shooter")
	arena.fire_shell(green)
	check(green.active_shells == 0, "The firing entry point must also block dangerous two-bank missiles")
	# Reproduce the original damage by deliberately bypassing AI validation. This
	# proves the fixture really hits the shooter and self-damage is still enabled.
	arena.player.position = Vector2(100, 800)
	var armor_before: int = green.get("armor") if green.get("armor") != null else 1
	arena.launch_shell(green, green.firing_direction())
	await frames(90)
	check(green.last_damage_source == green and (not green.alive or int(green.get("armor")) < armor_before), "The original double-bank shot must genuinely self-hit when forcibly launched without AI checks")
	arena.queue_free()
	await frames(3)

func run() -> void:
	geometry_checks()
	PlayerSetup.loaded = true
	PlayerSetup.bindings = [{"kind": "keyboard", "device": -1}, {"kind": "off"}, {"kind": "off"}, {"kind": "off"}]
	CampaignProgress.selected_mission = 12
	var mission = load("res://scenes/game/CampaignArena.tscn").instantiate()
	mission.save_progress = false
	mission.check_devices = false
	root.add_child(mission)
	mission.set_process(false)
	mission.countdown = 0
	await live_checks(mission)
	StorySession.devices = [-1]
	StorySession.debug_checkpoint = 11
	var story = load("res://scenes/story/Adventure.tscn").instantiate()
	story.save_progress = false
	story.check_devices = false
	root.add_child(story)
	story.set_process(false)
	await live_checks(story)
	print("Green self-hit checks: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)
