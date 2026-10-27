extends SceneTree

const StoryTank = preload("res://scenes/story/StoryTank.tscn")
var failures := 0

class RepairField extends Node2D:
	func party_position_allowed(_tank: DuelTank, _at: Vector2, _before: Vector2) -> bool:
		return true
	func can_field_repair(_tank: DuelTank) -> bool:
		return true
	func field_repair(_tank: DuelTank) -> void:
		pass

class DrivenTank extends DuelTank:
	var order := Vector2.ZERO
	var ticks_left := 0
	func control_step(_delta: float) -> Vector2:
		return order
	func _physics_process(delta: float) -> void:
		super._physics_process(delta)
		ticks_left -= 1
		if ticks_left <= 0: set_physics_process(false)

func _initialize() -> void:
	run.call_deferred()
	create_timer(60).timeout.connect(func():
		push_error("Tank handling checks exceeded their time limit")
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

func key(code: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)

func axis(device: int, code: int, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.device = device
	event.axis = code
	event.axis_value = value
	Input.parse_input_event(event)

func classic_movement() -> void:
	# This exercise drives a keyboard tank even when the user's saved Player 1
	# is a real Wii Remote. Override only this test process, never preferences.
	PlayerSetup.load_preferences()
	var saved_bindings: Array = PlayerSetup.bindings.duplicate(true)
	PlayerSetup.bindings[0] = {"kind": "keyboard", "device": -1}
	var game = load("res://scenes/game/CampaignArena.tscn").instantiate()
	game.mission_override = 1
	game.save_progress = false
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.set_controls(false)
	for enemy in game.enemies:
		enemy.set_physics_process(false)
		enemy.position = Vector2(-1000, -1000)
	for wall in game.get_node("Walls").get_children():
		game.get_node("Walls").remove_child(wall)
		wall.queue_free()
	game.wall_rects.clear()
	game.active = true
	game.countdown = 0
	var classic: DuelTank = game.player
	var reference = StoryTank.instantiate()
	root.add_child(reference)
	# Let scene loading and the preceding physics-rate checks settle before
	# sampling the first acceleration ticks in real-time test runs.
	await frames(3)
	classic.position = Vector2(300, 300)
	reference.position = Vector2(300, 800)
	classic.rotation = PI / 2
	reference.rotation = PI / 2
	classic.controls_enabled = true
	reference.controls_enabled = true
	var offset: Vector2 = reference.position - classic.position
	# Compare actual movement, including direction changes and reversing, against
	# the True Campaign tank under the same physical keyboard inputs.
	for codes in [[KEY_D], [KEY_W], [KEY_S], [KEY_A], [KEY_W, KEY_D], []]:
		for code in codes: key(code, true)
		await frames(2)
		if codes == [KEY_D]:
			check(classic.velocity.x > 0 and classic.velocity.x < classic.forward_speed * 0.5 and absf(classic.velocity.y) < 0.01, "Classic D must accelerate to the right even while the hull faces down (velocity: %s)" % classic.velocity)
		await frames(27)
		check(classic.velocity.distance_to(reference.velocity) < 0.01 and absf(angle_difference(classic.rotation, reference.rotation)) < 0.001 and absf(classic.angular_velocity - reference.angular_velocity) < 0.001, "Classic movement, braking and hull steering must match True Campaign for input %s" % str(codes))
		check((reference.position - classic.position).distance_to(offset) < 0.05, "The two campaign tanks must follow the same weighted trajectory")
		check(classic.velocity.length() <= classic.forward_speed + 0.01, "Classic diagonal movement must not exceed normal top speed")
		for code in codes: key(code, false)
	check(classic.velocity.is_zero_approx(), "Classic releasing movement must brake to a complete stop")
	key(KEY_UP, true)
	await frames(28)
	check(classic.velocity.y < -classic.forward_speed * 0.98 and absf(classic.velocity.x) < 0.01, "Classic arrow keys must also move in world directions")
	key(KEY_UP, false)
	await frames(24)
	var toward_mouse := (classic.get_global_mouse_position() - classic.global_position).normalized()
	check(classic.firing_direction().dot(toward_mouse) > 0.999, "Classic mouse aiming must remain independent of directional driving")
	key(KEY_SPACE, true)
	await frames(2)
	key(KEY_SPACE, false)
	check(classic.active_shells == 1, "Classic firing input must still launch shells")
	key(KEY_E, true)
	await frames(2)
	key(KEY_E, false)
	check(classic.active_mines == 1, "Classic mine input must still deploy a mine")
	key(KEY_D, true)
	await frames(8)
	Input.action_press("pause_game")
	game._process(0)
	Input.action_release("pause_game")
	await frames(2)
	var paused_at := classic.position
	await frames(8)
	check(game.paused and classic.position == paused_at and classic.velocity.is_zero_approx() and classic.angular_velocity == 0, "Classic pause must stop both driving momentum and hull turning")
	key(KEY_D, false)
	for child in game.get_children():
		if child is AudioStreamPlayer: child.stop()
	game.queue_free()
	reference.queue_free()
	await frames(10)
	# The final mission and a retry must receive the same steering configuration.
	game = load("res://scenes/game/CampaignArena.tscn").instantiate()
	game.mission_override = 50
	game.save_progress = false
	root.add_child(game)
	game.set_process(false)
	game.start_round()
	check(game.player.campaign_controls and game.player.turn_speed == 6, "Later missions and retries must preserve True Campaign steering")
	game.queue_free()
	await frames(2)
	PlayerSetup.bindings.assign(saved_bindings)

func run() -> void:
	var keyboard = StoryTank.instantiate()
	var controller = StoryTank.instantiate()
	controller.device = 7
	controller.position = Vector2(0, 500)
	root.add_child(keyboard)
	root.add_child(controller)
	keyboard.controls_enabled = true
	await frames(2)
	key(KEY_D, true)
	await frames(1)
	check(keyboard.velocity.x > 0 and keyboard.velocity.x < keyboard.forward_speed * 0.3, "Pressing drive must build speed instead of jumping to full speed")
	await frames(24)
	check(keyboard.velocity.x > keyboard.forward_speed * 0.98, "The added weight must still let a held input reach full speed")
	key(KEY_D, false)
	key(KEY_W, true)
	await frames(1)
	check(keyboard.velocity.x > keyboard.forward_speed * 0.7 and keyboard.velocity.y < 0, "A right-angle turn must retain some forward momentum while changing direction")
	check(absf(keyboard.rotation) < 0.15 and absf(keyboard.angular_velocity) < keyboard.turn_speed, "The hull must begin turning gradually instead of snapping north")
	await frames(50)
	check(absf(angle_difference(keyboard.rotation, -PI / 2)) < 0.02 and keyboard.velocity.y < -keyboard.forward_speed * 0.98, "The hull and movement must settle into the requested direction")
	key(KEY_W, false)
	key(KEY_S, true)
	await frames(1)
	check(keyboard.velocity.y < 0, "Opposite input must brake existing momentum before reversing")
	await frames(45)
	check(keyboard.velocity.y > keyboard.forward_speed * 0.98, "Holding the opposite direction must complete the reversal")
	key(KEY_S, false)
	var released_at: Vector2 = keyboard.position
	await frames(1)
	check(keyboard.velocity.y > 0, "Releasing drive must allow a short coast")
	await frames(24)
	check(keyboard.velocity.is_zero_approx() and keyboard.position.distance_to(released_at) > 3 and keyboard.position.distance_to(released_at) < 25, "Track braking must stop the coast within a short, controlled distance")
	key(KEY_D, true)
	key(KEY_W, true)
	await frames(40)
	check(keyboard.velocity.length() <= keyboard.forward_speed + 0.01, "Diagonal input must not gain extra top speed")
	key(KEY_D, false)
	key(KEY_W, false)
	keyboard.controls_enabled = false
	await frames(1)
	check(keyboard.velocity.is_zero_approx() and keyboard.angular_velocity == 0, "Disabling controls must clear both movement and turn momentum")
	# Exercise the real controller input path and independent turret aiming.
	controller.controls_enabled = true
	axis(7, JOY_AXIS_LEFT_X, 1)
	await frames(25)
	axis(7, JOY_AXIS_LEFT_X, 0)
	axis(7, JOY_AXIS_LEFT_Y, -1)
	axis(7, JOY_AXIS_RIGHT_Y, 1)
	await frames(1)
	check(controller.velocity.x > controller.forward_speed * 0.7 and controller.velocity.y < 0, "Controllers must have the same weighted direction changes as the keyboard")
	check(absf(angle_difference(controller.turret_angle, PI / 2)) < 0.01, "Hull weight must not delay right-stick aiming")
	axis(7, JOY_AXIS_LEFT_Y, 0)
	axis(7, JOY_AXIS_LEFT_X, 0.6)
	await frames(45)
	check(controller.velocity.length() > 25 and controller.velocity.length() < controller.forward_speed * 0.65, "Analog stick strength must still control cruising speed")
	axis(7, JOY_AXIS_LEFT_X, 0)
	axis(7, JOY_AXIS_RIGHT_Y, 0)
	controller.controls_enabled = false
	# Field repairs must lock a tank immediately, even if it was driving and turning.
	var field := RepairField.new()
	root.add_child(field)
	keyboard.battlefield = field
	keyboard.controls_enabled = true
	keyboard.stop_motion()
	keyboard.position = Vector2.ZERO
	keyboard.rotation = 0
	key(KEY_D, true)
	await frames(25)
	key(KEY_D, false)
	key(KEY_W, true)
	await frames(3)
	key(KEY_R, true)
	var repair_at: Vector2 = keyboard.position
	await frames(1)
	check(keyboard.repairing and keyboard.velocity.is_zero_approx() and keyboard.angular_velocity == 0 and keyboard.position.distance_to(repair_at) < 0.1, "Starting a repair must immediately stop the rolling and turning tank")
	await frames(12)
	check(keyboard.position.distance_to(repair_at) < 0.1, "Repairing must not allow residual momentum to drift the tank")
	key(KEY_R, false)
	key(KEY_W, false)
	await frames(2)
	keyboard.velocity = Vector2(120, 0)
	keyboard.angular_velocity = 2
	keyboard.take_shell_hit(99)
	keyboard.revive(Vector2.ZERO)
	check(keyboard.velocity.is_zero_approx() and keyboard.angular_velocity == 0, "A revived crew member must not inherit momentum from being knocked out")
	keyboard.controls_enabled = false
	keyboard.battlefield = null
	field.queue_free()
	# Actual collision bodies must stop momentum at a wall rather than storing
	# up speed that bursts through it or launches the tank when direction changes.
	var wall := StaticBody2D.new()
	wall.collision_layer = 1
	wall.position = Vector2(510, 100)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(20, 200)
	shape.shape = rect
	wall.add_child(shape)
	root.add_child(wall)
	keyboard.position = Vector2(300, 100)
	keyboard.rotation = 0
	keyboard.controls_enabled = true
	key(KEY_D, true)
	await frames(120)
	check(keyboard.position.x <= 482.2 and keyboard.position.x > 475, "Momentum must still respect the actual tank-width wall collision")
	var contact_at: Vector2 = keyboard.position
	key(KEY_D, false)
	key(KEY_A, true)
	await frames(30)
	check(contact_at.x - keyboard.position.x > 30 and keyboard.velocity.x < 0, "A tank must be able to pull away from a wall after braking against it")
	key(KEY_A, false)
	keyboard.queue_free()
	controller.queue_free()
	wall.queue_free()
	await frames(3)
	# Run the real physics loop at different tick rates. Handling should depend
	# on elapsed time, including the short coast after letting go of the controls.
	var reference_position := Vector2.INF
	var reference_angle := INF
	for rate in [30, 60, 120]:
		Engine.physics_ticks_per_second = rate
		var tank := DrivenTank.new()
		tank.position = Vector2(0, -500)
		tank.controls_enabled = true
		tank.order = Vector2(1, 1)
		tank.ticks_left = rate / 2
		root.add_child(tank)
		while tank.is_physics_processing(): await process_frame
		tank.order = Vector2.ZERO
		tank.ticks_left = roundi(rate * 0.3)
		tank.set_physics_process(true)
		while tank.is_physics_processing(): await process_frame
		check(tank.velocity.is_zero_approx() and tank.angular_velocity == 0, "Weight must settle cleanly at %d physics ticks" % rate)
		if reference_position.is_finite():
			check(tank.position.distance_to(reference_position) < 4 and absf(angle_difference(tank.rotation, reference_angle)) < 0.06, "Handling must remain consistent across physics tick rates")
		else:
			reference_position = tank.position
			reference_angle = tank.rotation
		tank.queue_free()
		await frames(2)
	Engine.physics_ticks_per_second = 60
	await classic_movement()
	print("TANK WEIGHT SMOKE: %s" % ("PASS" if failures == 0 else "%d FAILURE(S)" % failures))
	quit(0 if failures == 0 else 1)
