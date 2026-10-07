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

func clear_shells() -> void:
	for shell in game.get_node("Shells").get_children():
		shell.retire()

func run() -> void:
	game = load("res://scenes/game/DuelArena.tscn").instantiate()
	root.add_child(game)
	await frames(2)
	check(game.tanks.size() == 2, "Two tanks must spawn")
	for iteration in range(60):
		game.start_round()
		var reached: Dictionary = {Vector2i.ZERO: true}
		var frontier: Array[Vector2i] = [Vector2i.ZERO]
		while not frontier.is_empty():
			var cell: Vector2i = frontier.pop_back()
			for direction in game.DIRECTIONS:
				var next: Vector2i = cell + direction
				if game.valid_cell(next) and not reached.has(next) and game.passages.has(game.edge_key(cell, next)):
					reached[next] = true
					frontier.append(next)
		check(reached.size() == 36, "Every maze cell must be reachable")
	await frames(2)
	game.countdown = 0.0
	game.active = true
	game.set_controls(true)
	var tank: DuelTank = game.tanks[0]
	var start := tank.position
	Input.action_press("p1_forward")
	await frames(12)
	Input.action_release("p1_forward")
	check(tank.position.distance_to(start) > 20, "Tank must drive forward")
	var angle := tank.rotation
	Input.action_press("p1_right")
	await frames(8)
	Input.action_release("p1_right")
	check(tank.rotation > angle + 0.1, "Tank must turn")
	# Use an empty arena for deterministic collision and input checks.
	for body in game.get_node("Walls").get_children():
		game.get_node("Walls").remove_child(body)
		body.queue_free()
	game.wall_rects.clear()
	game.add_wall(Rect2(100, 150, 10, 400))
	game.add_wall(Rect2(650, 150, 10, 400))
	tank.position = Vector2(300, 300)
	tank.rotation = 0
	game.tanks[1].position = Vector2(550, 450)
	await frames(2)
	Input.action_press("p1_fire")
	await frames(2)
	Input.action_release("p1_fire")
	check(tank.active_shells == 1, "Fire input must create a shell")
	clear_shells()
	await frames(2)
	# Max shot count is enforced by the input path, including when fire is held.
	for i in range(5):
		tank.cooldown = 0.0
		game.fire_shell(tank)
	check(tank.active_shells == 5, "Five shots must fit in the magazine")
	Input.action_press("p1_fire")
	tank.cooldown = 0.0
	await frames(2)
	Input.action_release("p1_fire")
	check(tank.active_shells == 5, "Holding fire must respect the shot cap")
	for live_shell in game.get_node("Shells").get_children():
		live_shell.lifetime = 0.1
	await frames(14)
	check(tank.active_shells == 0, "Retiring shells must restore ammunition")
	# A real physics bounce should send the shell back toward its owner.
	game.fire_shell(tank)
	var shell: DuelShell = game.get_node("Shells").get_child(0)
	await frames(60)
	check(shell.direction.x < 0, "Shell must reflect from the wall")
	await frames(62)
	check(not tank.alive, "Returning shell must kill its shooter")
	check(game.scores[1] == 1, "Survivor must receive a point after a self-hit")
	# Close-range enemy hit must count even during muzzle grace.
	game.start_round()
	await frames(2)
	game.countdown = 0.0
	game.active = true
	for body in game.get_node("Walls").get_children():
		game.get_node("Walls").remove_child(body)
		body.queue_free()
	game.tanks[0].position = Vector2(300, 300)
	game.tanks[0].rotation = 0
	game.tanks[1].position = Vector2(350, 300)
	await frames(2)
	game.fire_shell(game.tanks[0])
	await frames(8)
	check(not game.tanks[1].alive, "Opponent must be vulnerable to a close-range shell")
	check(game.scores[0] == 1, "Enemy hit must award one point")
	game.start_round()
	await frames(2)
	game.tanks[0].take_hit()
	game.tanks[1].take_hit()
	await frames(2)
	check(game.banner == "DOUBLE KNOCKOUT", "Simultaneous deaths must draw")
	check(game.scores == [1, 1], "Draw must not award points")
	game.start_round()
	await frames(2)
	game.scores.assign([6, 1])
	game.tanks[1].take_hit()
	await frames(2)
	check(game.match_finished and game.scores[0] == 7, "Seven points must end the match")
	Input.action_press("rematch")
	await frames(2)
	Input.action_release("rematch")
	check(game.scores == [0, 0] and not game.match_finished, "Rematch must reset the score")
	# Pause must stop movement and prevent fire.
	game.countdown = 0.0
	game.active = true
	game.set_controls(true)
	Input.action_press("pause_game")
	await frames(2)
	Input.action_release("pause_game")
	start = game.tanks[0].position
	Input.action_press("p1_forward")
	Input.action_press("p1_fire")
	await frames(10)
	Input.action_release("p1_forward")
	Input.action_release("p1_fire")
	check(game.tanks[0].position == start, "Paused tank must stay still")
	check(game.get_node("Shells").get_child_count() == 0, "Paused tank must not fire")
	print("DUEL SMOKE: %s" % ("PASS" if failures == 0 else "%d FAILURE(S)" % failures))
	for child in game.get_children():
		if child is AudioStreamPlayer:
			child.stop()
	await frames(10)
	game.queue_free()
	await frames(10)
	quit(0 if failures == 0 else 1)
