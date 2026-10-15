extends SceneTree

var failures := 0
var game: Node2D

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

func shoot_surface(rect: Rect2, message: String) -> void:
	for shell in game.get_node("Shells").get_children():
		shell.retire()
	await frames(2)
	var tank: DuelTank = game.tanks[0]
	tank.position = Vector2(rect.get_center().x, rect.position.y - 70)
	tank.rotation = PI / 2
	tank.cooldown = 0
	var contacts: Array[Vector2] = []
	game.fire_shell(tank)
	var shell: DuelShell = game.get_node("Shells").get_child(0)
	shell.bounced.connect(func(point: Vector2):
		contacts.append(point)
		# Clear the return path now that bank shots can kill their own shooter.
		tank.position.x += 120
	)
	await frames(30)
	check(not contacts.is_empty(), message)
	if not contacts.is_empty():
		check(absf(contacts[0].y - rect.position.y) < 6, "The bounce must occur on the visible cover's physical face")

func run() -> void:
	game = load("res://scenes/game/DuelArena.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.active = true
	game.countdown = 0
	game.set_controls(false)
	for wall in game.get_node("Walls").get_children():
		game.get_node("Walls").remove_child(wall)
		wall.queue_free()
	game.wall_rects.clear()
	game.tanks[0].team_id = 0
	game.tanks[1].position = Vector2(1100, 650)
	var tree = load("res://scenes/story/props/CoverTree.tscn").instantiate()
	tree.position = Vector2(600, 350)
	root.add_child(tree)
	game.add_wall(tree.wall_rect())
	var rubble = load("res://scenes/story/props/Rubble.tscn").instantiate()
	rubble.position = Vector2(900, 430)
	rubble.size = Vector2(120, 70)
	rubble.surface_type = "Wreckage"
	root.add_child(rubble)
	game.add_wall(rubble.wall_rect())
	await frames(2)
	var clear_ray := PhysicsRayQueryParameters2D.create(Vector2(500, 295), Vector2(700, 295), 1)
	var trunk_y: float = tree.wall_rect().get_center().y
	var trunk_ray := PhysicsRayQueryParameters2D.create(Vector2(500, trunk_y), Vector2(700, trunk_y), 1)
	check(game.get_world_2d().direct_space_state.intersect_ray(clear_ray).is_empty(), "Shots must travel underneath foliage without hitting an invisible canopy wall")
	check(not game.get_world_2d().direct_space_state.intersect_ray(trunk_ray).is_empty(), "The tree's visible trunk must be real solid cover")
	await shoot_surface(tree.wall_rect(), "A real shell must ricochet off the tree trunk")
	await shoot_surface(rubble.wall_rect(), "A real shell must ricochet off the rubble")
	var walls: Array[Rect2] = [rubble.wall_rect()]
	var shot := ShotPlanner.solve(Vector2(830, 340), Vector2(1100, 340), Vector2.ZERO, 300, walls, 1, [], 1)
	check(not shot.is_empty() and int(shot.bounces) == 1, "Rubble must support a calculated bank-shot angle, not just decorate the ground")
	for node in game.get_children():
		if node is AudioStreamPlayer:
			node.stop()
	game.queue_free()
	tree.queue_free()
	rubble.queue_free()
	await frames(12)
	print("SCENERY SMOKE: %s" % ("PASS" if failures == 0 else "%d FAILURE(S)" % failures))
	quit(0 if failures == 0 else 1)
