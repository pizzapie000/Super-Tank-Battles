extends SceneTree

const Session = preload("res://scripts/pvp/duel_session.gd")
var game: Node2D
var failures := 0

func _initialize() -> void:
	run.call_deferred()
	create_timer(90).timeout.connect(func(): quit(1))

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func frames(count: int) -> void:
	for i in range(count):
		await physics_frame
		await process_frame

func clear_shells() -> void:
	for shell in game.get_node("Shells").get_children(): shell.retire()
	await frames(2)

func empty_arena() -> void:
	for wall in game.get_node("Walls").get_children(): wall.queue_free()
	game.wall_rects.clear()
	game.set_controls(false)
	game.tanks[0].position = Vector2(250, 350)
	game.tanks[0].rotation = 0
	game.tanks[1].position = Vector2(1000, 580)
	await frames(2)

func pickup_checks() -> void:
	game._process(4.0)
	check(game.pickups.is_empty() and is_equal_approx(game.round_elapsed, 2.6), "Pickups must wait for five seconds of combat, excluding READY")
	game._process(2.39)
	check(game.pickups.is_empty(), "No crate may appear before the first five combat seconds")
	game._process(0.02)
	check(game.pickups.size() == 2, "The first five seconds must unlock two weapon crates")
	var kinds: Array[String] = []
	for pickup in game.pickups:
		kinds.append(pickup.weapon_kind)
		for wall in game.wall_rects:
			check(not wall.grow(25).has_point(pickup.position), "Crates must spawn in reachable corridors clear of walls")
	check(kinds[0] != kinds[1], "The opening weapon crates must offer different weapons")
	var elapsed: float = game.round_elapsed
	var age: float = game.pickups[0].age
	game.set_duel_paused(true)
	game._process(10)
	check(game.round_elapsed == elapsed and game.pickups[0].age == age, "Pause must freeze pickup spawning and expiration")
	game.set_duel_paused(false)
	var pickup: Node2D = game.pickups[0]
	var kind: String = pickup.weapon_kind
	game.tanks[0].position = pickup.position
	game.update_pickups(0)
	check(game.tanks[0].weapon_kind == kind and game.pickups.size() == 1, "Driving over a crate must equip and remove it exactly once")
	game.update_pickups(7)
	check(game.pickups.size() == 2, "New crates must replenish during longer rounds")
	for i in range(8): game.update_pickups(7)
	check(game.pickups.size() <= game.MAX_PICKUPS, "Long rounds must bound the number of crates")
	game.start_round()
	await frames(2)
	check(game.pickups.is_empty() and game.round_elapsed == 0 and game.tanks[0].weapon_kind.is_empty(), "A new round must reset crates, weapons, and the five-second timer")
	game.countdown = 0
	game.active = true
	await empty_arena()

func shotgun_checks() -> void:
	var tank: DuelTank = game.tanks[0]
	tank.equip_weapon("shotgun")
	game.fire_shell(tank)
	check(tank.active_shells == 5 and tank.weapon_ammo == 4, "A shotgun trigger pull must launch five pellets and spend one blast")
	await frames(4)
	check(tank.active_shells == 5, "Shotgun pellets must fan out without destroying each other at the muzzle")
	var directions: Array[float] = []
	for shell in game.get_node("Shells").get_children(): directions.append(shell.direction.angle())
	check(directions.size() == 5 and directions[0] < -0.25 and directions[4] > 0.25, "The shotgun must produce a real spread on both sides of the aim direction")
	await clear_shells()
	for i in range(4):
		game.fire_shell(tank)
		await clear_shells()
	check(tank.weapon_kind.is_empty() and tank.max_shells == 5 and tank.shell_speed == 300, "Using all shotgun blasts must restore the normal weapon")
	tank.equip_weapon("shotgun")
	game.add_wall(Rect2(275, 250, 14, 200))
	await frames(2)
	game.fire_shell(tank)
	check(tank.active_shells == 0 and tank.weapon_ammo == 5, "Shotgun muzzles must not fire through a nearby wall or waste a blocked blast")
	await empty_arena()

func gatling_checks() -> void:
	var tank: DuelTank = game.tanks[0]
	tank.equip_weapon("gatling")
	tank.cooldown = 0
	tank.controls_enabled = true
	Input.action_press("p1_fire")
	await frames(48)
	Input.action_release("p1_fire")
	check(tank.weapon_ammo <= 29 and tank.active_shells >= 7, "Holding fire with a gatling must deliver rapid rounds")
	Input.action_press("p1_fire")
	await frames(90)
	Input.action_release("p1_fire")
	check(tank.active_shells == 16, "Rapid fire must still enforce its simultaneous-shell cap")
	tank.controls_enabled = false
	await clear_shells()
	tank.weapon_ammo = 1
	game.fire_shell(tank)
	check(tank.weapon_kind.is_empty() and tank.shot_cooldown == 0.32, "The gatling must return to normal shells after its final round")
	await clear_shells()
	tank.equip_weapon("gatling")
	tank.equip_weapon("homing")
	check(tank.weapon_kind == "homing" and tank.weapon_ammo == 3 and tank.max_shells == 5, "A new pickup must replace the previous weapon without stacking stats")

func homing_checks() -> void:
	var tank: DuelTank = game.tanks[0]
	var opponent: DuelTank = game.tanks[1]
	tank.position = Vector2(300, 300)
	opponent.position = Vector2(600, 420)
	tank.equip_weapon("homing")
	game.fire_shell(tank)
	var missile: DuelShell = game.get_node("Shells").get_child(0)
	check(missile.is_missile and missile.homing_turn_rate > 0 and tank.weapon_ammo == 2, "Heat seekers must launch real smoke-trailing guided missiles")
	await frames(25)
	check(is_instance_valid(missile) and missile.direction.y > 0.1 and missile.trail.size() > 15, "A heat seeker must turn toward the opponent while building its smoke trail")
	await frames(75)
	check(not opponent.alive and game.scores[0] == 1, "A guided missile must actually chase and hit an off-axis opponent")
	game.start_round()
	game.countdown = 0
	game.active = true
	await empty_arena()
	tank = game.tanks[0]
	opponent = game.tanks[1]
	tank.equip_weapon("homing")
	game.fire_shell(tank)
	missile = game.get_node("Shells").get_child(0)
	missile.age = 0.3
	missile.set_physics_process(false)
	missile.position = Vector2(500, 400)
	missile.direction = Vector2.RIGHT
	tank.position = Vector2(501, 390)
	opponent.position = Vector2(850, 250)
	var third := DuelTank.new()
	third.position = Vector2(550, 500)
	root.add_child(third)
	third.set_physics_process(false)
	missile.homing_targets.append(third)
	check(missile.guided_direction(0.1).y > 0, "Guidance must choose the closest other living player, excluding its own shooter")
	third.alive = false
	check(missile.guided_direction(0.1).y < 0, "Guidance must drop dead targets and choose the next living opponent")
	third.queue_free()
	# Shoot down a guided missile through the same interception path as bullets.
	tank.position = Vector2(250, 650)
	opponent.position = Vector2(1000, 650)
	missile.direction = Vector2.RIGHT
	missile.homing_turn_rate = 0.01
	missile.set_physics_process(true)
	var counter: DuelShell = game.ShellScene.instantiate()
	counter.shooter = opponent
	counter.position = Vector2(580, 400)
	counter.direction = Vector2.LEFT
	opponent.register_shot()
	game.get_node("Shells").add_child(counter)
	await frames(15)
	check(not is_instance_valid(missile) and not is_instance_valid(counter) and tank.active_shells == 0 and opponent.active_shells == 0, "Normal fire must be able to shoot down a homing missile and restore both magazines")

func run() -> void:
	Session.shared_keyboard()
	game = load("res://scenes/game/DuelArena.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	await frames(2)
	await pickup_checks()
	await shotgun_checks()
	await gatling_checks()
	await homing_checks()
	game.queue_free()
	await frames(5)
	print("PvP weapon checks: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)
