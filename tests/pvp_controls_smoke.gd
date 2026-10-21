extends SceneTree

const Session = preload("res://scripts/pvp/duel_session.gd")
var failures := 0

class TestLobby extends "res://scripts/pvp/duel_lobby.gd":
	var connected: Array[int] = []
	func connected_devices() -> Array[int]:
		return connected

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

func joy_button(device: int, code: int, pressed: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.device = device
	event.button_index = code
	event.pressed = pressed
	Input.parse_input_event(event)

func lobby_checks() -> void:
	Session.shared_keyboard()
	var lobby := TestLobby.new()
	root.add_child(lobby)
	await frames(2)
	check(not lobby.start_button.disabled and lobby.selected_pair() == [-2, -3], "The setup must preserve the original shared-keyboard option")
	lobby.choose_mode(1)
	check(lobby.start_button.disabled and lobby.descriptions[0].text.contains("Mouse"), "Mixed mode must explain mouse aiming and require a connected controller")
	lobby.choose_mode(2)
	check(lobby.start_button.disabled, "Two-controller mode must not begin with missing devices")
	lobby.connected.assign([7, 9])
	lobby.refresh()
	check(not lobby.start_button.disabled and lobby.selected_pair() == [7, 9], "Two controllers must receive distinct player slots")
	lobby.selectors[1].select(0)
	lobby.refresh_status()
	check(lobby.start_button.disabled and lobby.status.text.contains("different"), "Both players must never share the same controller")
	lobby.choose_mode(0)
	lobby.join_controller(7)
	check(lobby.mode == 1 and lobby.selected_pair() == [-1, 7], "The first joining controller must create keyboard-plus-controller play")
	lobby.join_controller(9)
	check(lobby.mode == 2 and lobby.selected_pair() == [7, 9], "A second joining controller must create two-controller play")
	lobby.connected.clear()
	lobby.connection_changed(7, false)
	check(lobby.start_button.disabled, "Unplugging controllers in setup must prevent an invalid match")
	lobby.queue_free()
	await frames(2)
	# Exercise the actual main-menu route, rather than just loading the lobby.
	var menu = load("res://scenes/game/MainMenu.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	PlayerSetup.loaded = true
	var previous_bindings := PlayerSetup.bindings.duplicate(true)
	PlayerSetup.bindings = [{"kind": "keyboard", "device": -2}, {"kind": "keyboard", "device": -3}, {"kind": "off"}, {"kind": "off"}]
	menu.start_duel()
	await frames(3)
	check(current_scene.scene_file_path.ends_with("DuelArena.tscn"), "Play Local Duel must use the shared main-menu controls and launch directly")
	PlayerSetup.bindings.assign(previous_bindings)
	PlayerSetup.loaded = false
	current_scene.queue_free()
	current_scene = null
	await frames(2)

func match_checks() -> void:
	Session.devices.assign([-1, 7])
	var game = load("res://scenes/game/DuelArena.tscn").instantiate()
	game.check_devices = false
	root.add_child(game)
	game.set_process(false)
	game.countdown = 0
	game.active = true
	game.set_controls(true)
	for wall in game.get_node("Walls").get_children(): wall.queue_free()
	game.wall_rects.clear()
	var keyboard: DuelTank = game.tanks[0]
	var pad: DuelTank = game.tanks[1]
	keyboard.position = Vector2(300, 400)
	pad.position = Vector2(850, 450)
	keyboard.rotation = PI / 2
	pad.rotation = 0
	await frames(3)
	check(keyboard.separate_turret and pad.separate_turret and keyboard.turn_speed == 6 and pad.turn_speed == 6, "Modern PvP players must use campaign steering and independent turrets")
	key(KEY_D, true)
	axis(7, JOY_AXIS_LEFT_Y, -1)
	axis(7, JOY_AXIS_RIGHT_X, -1)
	await frames(30)
	check(keyboard.velocity.x > 149 and absf(keyboard.velocity.y) < 0.1, "WASD must drive in world directions regardless of hull angle")
	check(pad.velocity.y < -149 and absf(pad.velocity.x) < 0.1, "The assigned controller must drive its own tank independently")
	check(pad.firing_direction().dot(Vector2.LEFT) > 0.999 and absf(pad.rotation + PI / 2) < 0.1, "Right-stick aiming must remain independent of hull movement")
	key(KEY_D, false)
	axis(7, JOY_AXIS_LEFT_Y, 0)
	axis(7, JOY_AXIS_RIGHT_X, 0)
	await frames(20)
	check(pad.velocity.is_zero_approx() and pad.firing_direction().dot(Vector2.LEFT) > 0.999, "Releasing the sticks must brake while retaining aim")
	key(KEY_SPACE, true)
	axis(7, JOY_AXIS_TRIGGER_RIGHT, 1)
	await frames(2)
	key(KEY_SPACE, false)
	axis(7, JOY_AXIS_TRIGGER_RIGHT, 0)
	check(keyboard.active_shells == 1 and pad.active_shells == 1, "Mouse/keyboard and controller trigger inputs must both launch shells")
	for shell in game.get_node("Shells").get_children(): shell.retire()
	await frames(2)
	joy_button(7, JOY_BUTTON_START, true)
	await frames(2)
	joy_button(7, JOY_BUTTON_START, false)
	var before := pad.position
	axis(7, JOY_AXIS_LEFT_X, 1)
	await frames(10)
	check(game.paused and game.controls_button.visible and pad.position == before, "Start must pause combat and expose the control-setup option")
	axis(7, JOY_AXIS_LEFT_X, 0)
	joy_button(7, JOY_BUTTON_START, true)
	await frames(2)
	joy_button(7, JOY_BUTTON_START, false)
	check(not game.paused, "Start must resume the same round")
	game.check_devices = true
	game.check_controller_connections()
	check(game.paused and game.missing_controller and not keyboard.controls_enabled, "A missing assigned controller must automatically pause both players")
	game.check_devices = false
	game.check_controller_connections()
	game.set_duel_paused(false)
	game.scores.assign([0, 6])
	keyboard.take_hit()
	await frames(2)
	joy_button(7, JOY_BUTTON_START, true)
	await frames(2)
	joy_button(7, JOY_BUTTON_START, false)
	check(game.scores == [0, 0] and not game.match_finished and game.tanks[1].device == 7, "A controller rematch must keep assignments and reset the score")
	game.queue_free()
	await frames(4)
	Session.devices.assign([7, 9])
	game = load("res://scenes/game/DuelArena.tscn").instantiate()
	game.check_devices = false
	root.add_child(game)
	game.set_process(false)
	game.active = true
	game.set_controls(true)
	for tank in game.tanks: tank.collision_mask = 0
	axis(7, JOY_AXIS_LEFT_X, 0.6)
	axis(9, JOY_AXIS_LEFT_Y, 1)
	await frames(30)
	check(game.tanks[0].velocity.x > 65 and game.tanks[0].velocity.x < 80 and game.tanks[1].velocity.y > 149, "Two controllers must remain independent and preserve analog movement speed")
	axis(7, JOY_AXIS_LEFT_X, 0)
	axis(9, JOY_AXIS_LEFT_Y, 0)
	game.queue_free()
	await frames(4)

func run() -> void:
	await lobby_checks()
	await match_checks()
	Session.shared_keyboard()
	print("PvP controls checks: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)
