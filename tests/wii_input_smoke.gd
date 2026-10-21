extends SceneTree

const Controls = preload("res://scripts/input/controller_input.gd")
const Session = preload("res://scripts/pvp/duel_session.gd")
var wii: Node
var failures := 0
var sequence := 1
var sender := PacketPeerUDP.new()
var fixtures: Array[Dictionary] = []

func _initialize() -> void:
	run.call_deferred()
	create_timer(90).timeout.connect(func(): quit(1))

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func frames(count: int, feed: bool = true) -> void:
	for i in range(count):
		if feed:
			sender.put_packet(JSON.stringify({"version": 1, "token": wii.token, "seq": sequence, "devices": fixtures}).to_utf8_buffer())
			sequence += 1
		await physics_frame
		await process_frame

func calibration_checks() -> void:
	var setup = load("res://scenes/game/WiiSetup.tscn").instantiate()
	root.add_child(setup)
	await frames(3)
	check(setup.remote_select.item_count == 2 and not setup.calibrate_button.disabled, "Live Wii remotes must appear in setup")
	setup.begin_calibration()
	fixtures[0].ir = [0.7, 0.2]
	fixtures[0].buttons = 8
	await frames(2)
	check(setup.phase == 1, "A real Wii A-button event must capture the first calibration target")
	fixtures[0].buttons = 0
	await frames(2)
	fixtures[0].ir = [0.3, 0.8]
	fixtures[0].buttons = 8
	await frames(2)
	check(setup.phase == -1, "A second Wii A press must save the opposite target")
	fixtures[0].buttons = 0
	fixtures[0].ir = [0.5, 0.5]
	await frames(2)
	var pointer = wii.pointer(1000)
	check(pointer != null and pointer.distance_to(Vector2(0.5, 0.5)) < 0.001, "Per-remote calibration must handle reversed camera X and map the center correctly")
	check(not wii.save_corners(1000, Vector2.ONE * 0.5, Vector2.ONE * 0.51), "Degenerate calibration must be rejected")
	var saved: Dictionary = wii.calibration.duplicate(true)
	wii.calibration.clear()
	wii.load_calibration()
	check(wii.calibration == saved, "Pointer calibration must survive a settings reload and stay keyed to remote identity")
	fixtures[0].stick = [0.03, -0.02]
	await frames(2)
	wii.center_stick(1000)
	check(absf(Controls.axis(1000, JOY_AXIS_LEFT_X)) < 0.001 and absf(Controls.axis(1000, JOY_AXIS_LEFT_Y)) < 0.001, "Stick centering must remove resting drift")
	wii.calibration[fixtures[0].id].stick_center = Vector2.ZERO
	setup.queue_free()
	await frames(2)

func lobby_checks() -> void:
	Session.shared_keyboard()
	var lobby = load("res://scenes/game/DuelLobby.tscn").instantiate()
	root.add_child(lobby)
	await frames(2)
	fixtures[0].buttons = 8
	await frames(2)
	check(lobby.selected_pair() == [-1, 1000], "Wii A must join PvP as a separate controller")
	fixtures[0].buttons = 0
	fixtures[1].buttons = 8
	await frames(2)
	check(lobby.selected_pair() == [1000, 1001] and lobby.descriptions[0].text.contains("Nunchuk"), "Two Wii Remotes must get independent PvP slots and Wii instructions")
	fixtures[1].buttons = 0
	lobby.queue_free()
	await frames(2)
	lobby = load("res://scenes/story/Lobby.tscn").instantiate()
	root.add_child(lobby)
	await frames(2)
	fixtures[0].buttons = 8
	await frames(2)
	fixtures[0].buttons = 0
	fixtures[1].buttons = 8
	await frames(2)
	check(StorySession.devices == [-1, 1000, 1001], "Wii A must join campaign co-op alongside a keyboard player")
	fixtures[1].buttons = 0
	lobby.queue_free()
	await frames(2)

func pvp_checks() -> void:
	Session.devices.assign([1000, 1001])
	var game = load("res://scenes/game/DuelArena.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.countdown = 0
	game.active = true
	game.set_controls(true)
	for wall in game.get_node("Walls").get_children(): wall.queue_free()
	game.wall_rects.clear()
	game.tanks[0].position = Vector2(250, 400)
	game.tanks[1].position = Vector2(1000, 300)
	for tank in game.tanks: tank.max_shells = 0
	fixtures[0].stick = [1.0, 0.0]
	fixtures[0].ir = [0.45, 0.3]
	fixtures[1].stick = [0.0, 1.0]
	fixtures[1].ir = [0.2, 0.8]
	await frames(35)
	check(game.tanks[0].velocity.x > 149 and game.tanks[1].velocity.y > 149, "Independent Nunchuks must actually move both PvP tanks in different directions")
	for tank in game.tanks:
		var aim = Controls.aim(tank.device, tank)
		check(aim != null and tank.firing_direction().dot((aim - tank.global_position).normalized()) > 0.98, "Each Wii pointer must aim its own turret independently")
		check(wii.states[tank.device].color == tank.tint, "Wii aim cursors must match their player colors")
		tank.max_shells = 5
	fixtures[0].stick = [0.0, 0.0]
	fixtures[1].stick = [0.0, 0.0]
	fixtures[0].buttons = 4
	fixtures[1].buttons = 4
	await frames(3)
	check(game.tanks[0].active_shells > 0 and game.tanks[1].active_shells > 0, "Both Wii B triggers must launch actual PvP shells")
	fixtures[0].buttons = 0x1000
	fixtures[1].buttons = 0
	await frames(2)
	check(game.paused, "Wii Plus must pause PvP")
	fixtures[0].buttons = 0
	await frames(2)
	fixtures[0].buttons = 0x1000
	await frames(2)
	check(not game.paused, "A second Plus press must resume PvP")
	fixtures[0].buttons = 0
	await frames(2)
	var aim_before: float = game.tanks[0].turret_angle
	fixtures[0].ir = null
	await frames(3)
	check(is_equal_approx(game.tanks[0].turret_angle, aim_before), "Losing sight of the sensor bar must retain the last aim instead of snapping away")
	await frames(5, false)
	wii.last_packet = wii.seconds() - wii.TIMEOUT - 0.1
	await frames(2, false)
	check(game.paused and Controls.connected_devices().filter(func(device: int): return device >= 1000).is_empty() and not Controls.button(1000, JOY_BUTTON_RIGHT_SHOULDER), "A stale bridge must release inputs and pause the match")
	game.queue_free()
	await frames(3)

func story_checks() -> void:
	StorySession.devices.assign([1000, 1001])
	StorySession.debug_checkpoint = 2
	for entry in fixtures:
		entry.buttons = 0
		entry.ir = [0.5, 0.4]
		entry.stick = [0, 0]
	await frames(3)
	var game = load("res://scenes/story/Adventure.tscn").instantiate()
	game.save_progress = false
	game.check_devices = true
	game.stage_ready_duration = 0
	root.add_child(game)
	game.set_process(false)
	game.set_activity(true)
	for enemy in game.enemies:
		enemy.set_physics_process(false)
		enemy.controls_enabled = false
	for tank in game.players:
		tank.collision_mask = 0
		tank.invulnerable = true
		tank.max_shells = 0
	var crew: DuelTank = game.players[0]
	var before := crew.position
	fixtures[0].stick = [1, 0]
	await frames(30)
	check(crew.position.x > before.x + 30, "Wii Nunchuk movement must work in the true campaign too")
	fixtures[0].stick = [0, 0]
	fixtures[0].z = true
	await frames(2)
	check(crew.active_mines == 1, "Nunchuk Z must deploy a campaign mine")
	fixtures[0].z = false
	await frames(3)
	for mine in game.get_node("Mines").get_children(): mine.queue_free()
	crew.armor = crew.max_armor - 1
	game.supplies = 2
	fixtures[0].stick = [1, 0]
	fixtures[0].c = true
	await frames(5)
	before = crew.position
	await frames(105)
	check(crew.position == before and crew.repair_progress > 1.5, "Holding Nunchuk C must lock the tank during the repair")
	await frames(25)
	check(crew.armor == crew.max_armor and game.supplies == 0, "A two-second Nunchuk C hold must complete the campaign repair")
	fixtures[0].c = false
	fixtures[0].stick = [0, 0]
	await frames(2)
	fixtures[0].nunchuk = false
	await frames(2)
	check(game.paused and game.missing_device and not crew.controls_enabled, "Unplugging a Nunchuk must pause co-op rather than leave stale controls")
	fixtures[0].nunchuk = true
	await frames(2)
	check(not game.paused and not game.missing_device, "Reconnecting the same Nunchuk must restore the original co-op player")
	game.queue_free()
	await frames(5)
	StorySession.debug_checkpoint = -1

func run() -> void:
	wii = Controls.bridge()
	if wii.listen_port == 0:
		push_error("Wii integration checks require permission to bind a local UDP socket.")
		quit(1)
		return
	var settings: String = wii.settings_path
	wii.settings_path = "user://wii_input_smoke.cfg"
	wii.calibration.clear()
	var binary := ProjectSettings.globalize_path("res://tools/wii/Wii Remote Bridge.app/Contents/MacOS/WiiRemoteBridge")
	var output: Array = []
	check(OS.execute(binary, ["--fixture-json"], output) == 0, "Native Wii report decoder must run")
	var fixture = JSON.parse_string("".join(output))
	if not fixture is Dictionary: push_error("Missing native report fixture"); quit(1); return
	output.clear()
	check(OS.execute(binary, ["--hid-fixture-json"], output) == 0, "Native HID report decoder must run")
	check(JSON.parse_string("".join(output)) == fixture, "macOS HID reports must produce the same Nunchuk, buttons and pointer as the Bluetooth report format")
	fixtures.assign([fixture.duplicate(true), fixture.duplicate(true)])
	fixtures[0].id = "wii-test-one"
	fixtures[1].id = "wii-test-two"
	fixtures[1].slot = 1
	for entry in fixtures: entry.buttons = 0
	sender.set_dest_address("127.0.0.1", wii.listen_port)
	await frames(3)
	check(wii.connected_devices() == [1000, 1001], "Native decoded reports must reach the game through the loopback UDP connection")
	var invalid := {"version": 1, "token": "wrong", "seq": 9999, "devices": fixtures}
	check(not wii.accept_snapshot(invalid, wii.seconds()), "Packets from the wrong bridge session must be ignored")
	invalid.token = wii.token
	invalid.seq = 0
	check(not wii.accept_snapshot(invalid, wii.seconds()), "Out-of-order packets must not resurrect old button states")
	invalid.seq = 9999
	invalid.devices = [fixtures[0], fixtures[0]]
	check(not wii.accept_snapshot(invalid, wii.seconds()), "Duplicate remote identities/slots must be rejected")
	await calibration_checks()
	await lobby_checks()
	await pvp_checks()
	await story_checks()
	wii.disconnect_all()
	sender.close()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(wii.settings_path))
	wii.settings_path = settings
	wii.load_calibration()
	Session.shared_keyboard()
	StorySession.devices.assign([-1])
	await frames(5, false)
	print("Wii input checks: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)
