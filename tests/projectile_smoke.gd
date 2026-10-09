extends SceneTree

const ShellScene = preload("res://scenes/projectiles/Shell.tscn")
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

func shot(owner_index: int, point: Vector2, direction: Vector2, speed: float = 300.0, missile: bool = false) -> DuelShell:
	var shell: DuelShell = ShellScene.instantiate()
	shell.shooter = game.tanks[owner_index]
	shell.position = point
	shell.direction = direction
	shell.speed = speed
	shell.is_missile = missile
	shell.shooter.register_shot()
	game.get_node("Shells").add_child(shell)
	return shell

func clean() -> void:
	for shell in game.get_node("Shells").get_children():
		shell.retire()

func run() -> void:
	game = load("res://scenes/game/DuelArena.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	await frames(2)
	for wall in game.get_node("Walls").get_children():
		game.get_node("Walls").remove_child(wall)
		wall.queue_free()
	game.wall_rects.clear()
	game.tanks[0].position = Vector2(200, 600)
	game.tanks[1].position = Vector2(900, 600)
	await frames(2)
	var first := shot(0, Vector2(360, 300), Vector2.RIGHT)
	var second := shot(1, Vector2(440, 300), Vector2.LEFT)
	await frames(12)
	check(not is_instance_valid(first) and not is_instance_valid(second), "Head-on bullets must destroy both shots")
	check(game.tanks[0].active_shells == 0 and game.tanks[1].active_shells == 0, "An interception must restore ammunition to both owners")
	first = shot(0, Vector2(360, 300), Vector2.RIGHT)
	second = shot(1, Vector2(440, 300), Vector2.LEFT, 510.0, true)
	await frames(12)
	check(not is_instance_valid(first) and not is_instance_valid(second), "A normal bullet must intercept a Green missile")
	first = shot(0, Vector2(360, 300), Vector2.RIGHT)
	second = shot(0, Vector2(440, 300), Vector2.LEFT)
	await frames(12)
	check(not is_instance_valid(first) and not is_instance_valid(second) and game.tanks[0].active_shells == 0, "Shots from the same tank must also destroy each other")
	# In one tick both shots cross (400, 400) and end beyond each other's old
	# position. Static sequential sweeps alone can miss this encounter.
	first = shot(0, Vector2(390, 400), Vector2.RIGHT, 1200.0)
	second = shot(1, Vector2(400, 390), Vector2.DOWN, 1200.0)
	await frames(2)
	check(not is_instance_valid(first) and not is_instance_valid(second), "Swept relative motion must catch fast perpendicular interceptions")
	# Their projected paths cross, but a wall stops the first shot earlier.
	game.add_wall(Rect2(390, 300, 3, 200))
	await frames(2)
	first = shot(0, Vector2(385, 400), Vector2.RIGHT, 1200.0)
	second = shot(1, Vector2(400, 380), Vector2.DOWN, 1200.0)
	await frames(2)
	check(is_instance_valid(first) and is_instance_valid(second), "Shots separated by an earlier wall collision must not intercept through the wall")
	check(first.bounce_count == 1, "The first solid collision must still be resolved as a wall bounce")
	clean()
	for wall in game.get_node("Walls").get_children():
		game.get_node("Walls").remove_child(wall)
		wall.queue_free()
	await frames(2)
	first = shot(0, Vector2(390, 300), Vector2.RIGHT, 1200.0)
	second = shot(1, Vector2(410, 300), Vector2.LEFT, 1200.0)
	first.flight_enabled = false
	second.flight_enabled = false
	await frames(3)
	check(is_instance_valid(first) and is_instance_valid(second), "Paused shots must not intercept until flight resumes")
	first.flight_enabled = true
	second.flight_enabled = true
	await frames(2)
	check(not is_instance_valid(first) and not is_instance_valid(second), "Resumed shots must intercept normally")
	first = shot(0, Vector2(400, 300), Vector2.RIGHT)
	second = shot(1, Vector2(400, 300), Vector2.LEFT)
	var survivor := shot(0, Vector2(400, 300), Vector2.DOWN)
	await frames(2)
	check(not is_instance_valid(first) and not is_instance_valid(second) and is_instance_valid(survivor), "A retired shot must not consume a third shot in the same frame")
	check(game.tanks[0].active_shells == 1 and game.tanks[1].active_shells == 0, "Each destroyed shot must release exactly one ammunition slot")
	clean()
	for child in game.get_children():
		if child is AudioStreamPlayer:
			child.stop()
	await frames(10)
	game.queue_free()
	await frames(10)
	print("PROJECTILE SMOKE: %s" % ("PASS" if failures == 0 else "%d FAILURE(S)" % failures))
	quit(0 if failures == 0 else 1)
