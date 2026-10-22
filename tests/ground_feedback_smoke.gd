extends SceneTree

const Feedback = preload("res://scripts/tank_ground_feedback.gd")
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

func drive(mode: int, pressed: bool, reverse: bool = false) -> void:
	if mode == 2:
		var event := InputEventKey.new()
		event.physical_keycode = KEY_A if reverse else KEY_D
		event.pressed = pressed
		Input.parse_input_event(event)
	else:
		var action := ("p1_back" if reverse else "p1_forward") if mode == 0 else ("solo_left" if reverse else "solo_right")
		if pressed:
			Input.action_press(action)
		else:
			Input.action_release(action)

func battle_mode(mode: int) -> void:
	var path: String = ["res://scenes/game/DuelArena.tscn", "res://scenes/game/CampaignArena.tscn", "res://scenes/story/Adventure.tscn"][mode]
	var game = load(path).instantiate()
	if mode > 0: game.save_progress = false
	if mode == 1: game.mission_override = 1
	if mode == 2: game.check_devices = false
	root.add_child(game)
	game.set_process(false)
	game.set_controls(false)
	game.active = true
	game.countdown = 0
	for other in game.tanks:
		other.set_physics_process(false)
		other.collision_layer = 0
		other.position += Vector2(5000, 5000)
	var tank: DuelTank = game.tanks[0]
	var origin: Vector2 = game.region().global_position if mode == 2 else Vector2.ZERO
	tank.position = origin + Vector2(450, 400)
	tank.rotation = 0
	tank.collision_mask = 0
	tank.controls_enabled = true
	tank.set_physics_process(true)
	if mode == 2:
		game.get_node("Camera").position = tank.position
		game.get_node("Camera").reset_smoothing()
	await frames(3)
	var layer = game.ground_feedback
	check(is_instance_valid(layer) and layer.get_index() == 0, "Mode %d must draw tracks behind tanks" % mode)
	drive(mode, true)
	await frames(45)
	check(tank.position.x > origin.x + 520 and layer.marks.size() >= 10, "Mode %d must leave a trail during actual weighted movement" % mode)
	check(layer.movement_audio.playing and layer.movement_audio.volume_db <= Feedback.MAX_VOLUME_DB, "Mode %d must play a quiet capped movement loop" % mode)
	game.paused = true
	tank.controls_enabled = false
	var age: float = layer.marks[0].age
	var count: int = layer.marks.size()
	await frames(12)
	check(layer.marks.size() == count and layer.marks[0].age == age and layer.movement_audio.stream_paused, "Mode %d pause must freeze marks and silence the engine" % mode)
	drive(mode, false)
	game.paused = false
	tank.controls_enabled = true
	await frames(30)
	count = layer.marks.size()
	await frames(15)
	check(layer.marks.size() == count and not layer.movement_audio.playing, "Mode %d stationary tanks must stop making tracks and rumbling" % mode)
	drive(mode, true, true)
	await frames(30)
	drive(mode, false, true)
	check(layer.marks.size() > count, "Mode %d reversing must leave tracks too" % mode)
	# Retry/checkpoint loads must free the marks and their audio together.
	if mode == 2:
		game.load_chapter(game.chapter)
	else:
		game.start_round()
	# Fresh encounters are active immediately; stop the replacement actors
	# before they can legitimately start a new trail or movement sound.
	game.set_controls(false)
	await frames(3)
	check(not is_instance_valid(layer) and game.ground_feedback.marks.is_empty() and not game.ground_feedback.movement_audio.playing, "Mode %d retry must clear marks and rumble" % mode)
	game.queue_free()
	await frames(3)

func sampling_checks() -> void:
	var layer := Feedback.new()
	root.add_child(layer)
	layer.set_physics_process(false)
	var tank := DuelTank.new()
	root.add_child(tank)
	tank.set_physics_process(false)
	tank.position = Vector2(640, 400)
	var roster: Array[DuelTank] = [tank]
	layer.step(roster, 1.0 / 60, true, false)
	# Uneven step lengths still produce evenly spaced marks on a straight path.
	for distance in [1.0, 4.0, 13.0, 2.0, 11.0, 7.0, 10.0]:
		tank.position.x += distance
		layer.step(roster, distance / 150, true, false)
	check(layer.marks.size() == 8, "Track spacing must depend on distance rather than frame rate")
	for i in range(1, layer.marks.size()):
		check(is_equal_approx(layer.marks[i].position.distance_to(layer.marks[i - 1].position), Feedback.MARK_SPACING), "Straight tread stamps must have even gaps")
	var count := layer.marks.size()
	tank.rotation += 0.8
	layer.step(roster, 0.15, true, false)
	check(layer.marks.size() > count, "Turning in place must leave short curved tread scuffs")
	count = layer.marks.size()
	tank.position += Vector2(2000, 0)
	layer.step(roster, 1.0 / 60, true, false)
	check(layer.marks.size() == count, "Teleports must never draw a long trail across the level")
	layer.step(roster, 0.5, true, false)
	check(not layer.movement_audio.playing, "Distant/stationary tanks must not keep the loop alive")
	tank.velocity = Vector2(150, 0)
	layer.step(roster, 0.1, true, false)
	check(layer.marks.size() == count and not layer.movement_audio.playing, "A blocked tank with velocity but no displacement must not paint tracks or rumble")
	tank.position = Vector2(640, 400)
	layer.step(roster, 0.01, false, false)
	tank.position.x += 12
	layer.step(roster, 0.1, false, false)
	check(layer.marks.size() == count, "Inactive intro tanks must not produce battle tracks")
	layer.step(roster, Feedback.MARK_LIFETIME + 0.1, false, false)
	check(layer.marks.is_empty(), "All tread marks must expire after five seconds")
	# A full wave still owns only one capped audio voice and bounded ground data.
	for i in range(35):
		var other := DuelTank.new()
		root.add_child(other)
		other.set_physics_process(false)
		other.position = Vector2(640 + i, 400)
		roster.append(other)
	layer.step(roster, 0.01, true, false)
	for frame in range(180):
		for other in roster: other.position.x += 2
		layer.step(roster, 1.0 / 60, true, false)
	check(layer.marks.size() <= Feedback.MAX_MARKS and layer.movement_audio.volume_db <= Feedback.MAX_VOLUME_DB and layer.get_child_count() == 1, "Large waves must have bounded marks and one quiet engine voice")
	for other in roster: other.queue_free()
	layer.queue_free()
	await frames(3)

func run() -> void:
	var devices := StorySession.devices.duplicate()
	var debug_checkpoint := StorySession.debug_checkpoint
	StorySession.devices.assign([-1])
	StorySession.debug_checkpoint = 3
	for mode in range(3):
		await battle_mode(mode)
	await sampling_checks()
	StorySession.devices.assign(devices)
	StorySession.debug_checkpoint = debug_checkpoint
	print("Ground feedback checks: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)
