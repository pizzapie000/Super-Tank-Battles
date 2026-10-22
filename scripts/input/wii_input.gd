extends Node

signal connection_changed(device: int, connected: bool)
signal state_changed
const FIRST_DEVICE: int = 1000
const TIMEOUT: float = 0.75
var socket := PacketPeerUDP.new()
var listen_port: int = 0
var token: String = ""
var last_sequence: int = -1
var last_packet: float = -100
var states: Dictionary = {}
var calibration: Dictionary = {}
var settings_path: String = "user://wii_controllers.cfg"
var bridge_pid: int = -1
var bridge_starting := false
var launch_requested_at: float = -100
var next_process_check: float = -100
var status: String = "Wii bridge is stopped."
var cursor_layer: CanvasLayer
var cursor_canvas: Node2D

func _ready() -> void:
	token = Crypto.new().generate_random_bytes(16).hex_encode()
	for port in range(42430, 42450):
		if socket.bind(port, "127.0.0.1") == OK:
			listen_port = port
			break
	load_calibration()
	process_priority = -100
	cursor_layer = CanvasLayer.new()
	cursor_layer.layer = 45
	add_child(cursor_layer)
	cursor_canvas = Node2D.new()
	cursor_layer.add_child(cursor_canvas)
	cursor_canvas.draw.connect(draw_cursors)
	if listen_port == 0: status = "Could not open the local Wii input connection."

func _process(_delta: float) -> void:
	var budget := 128
	while socket.get_available_packet_count() > 0 and budget > 0:
		budget -= 1
		var bytes := socket.get_packet()
		if bytes.size() > 8192 or socket.get_packet_ip() != "127.0.0.1": continue
		var packet = JSON.parse_string(bytes.get_string_from_utf8())
		if packet is Dictionary: accept_snapshot(packet, seconds())
	if seconds() - last_packet > TIMEOUT:
		disconnect_all()
		if bridge_pid > 0 and seconds() >= next_process_check:
			next_process_check = seconds() + 1
			if bridge_is_running():
				status = "Waiting for the Wii bridge. Open it or reconnect the remotes."
			else:
				bridge_pid = -1
				bridge_starting = false
				status = "Wii bridge closed. Choose Start Wii Bridge to try again."
		elif bridge_starting and seconds() - launch_requested_at > 20:
			bridge_starting = false
			status = "The Wii bridge did not respond. Check its window, then choose Start Wii Bridge to retry."
	cursor_canvas.queue_redraw()

func seconds() -> float:
	return Time.get_ticks_msec() / 1000.0

func valid_pair(value: Variant, minimum: float, maximum: float) -> bool:
	if not value is Array or value.size() != 2: return false
	for number in value:
		if not (number is float or number is int) or not is_finite(float(number)) or float(number) < minimum or float(number) > maximum: return false
	return true

func accept_snapshot(packet: Dictionary, now: float) -> bool:
	if packet.get("version") != 1 or packet.get("token") != token: return false
	var sequence = packet.get("seq")
	if not (sequence is float or sequence is int) or not is_finite(float(sequence)) or float(sequence) != floorf(float(sequence)) or sequence <= last_sequence: return false
	var devices = packet.get("devices")
	if not devices is Array or devices.size() > 4: return false
	var next: Dictionary = {}
	var ids: Dictionary = {}
	for entry in devices:
		if not entry is Dictionary: return false
		var slot = entry.get("slot", -1)
		if not (slot is float or slot is int) or not is_finite(float(slot)) or slot < 0 or slot > 3 or slot != int(slot): return false
		var device := FIRST_DEVICE + int(slot)
		var identity = entry.get("id")
		if not identity is String or identity.is_empty() or identity.length() > 64 or ids.has(identity) or next.has(device): return false
		if not valid_pair(entry.get("stick"), -1, 1): return false
		if entry.get("ir") != null and not valid_pair(entry.ir, 0, 1): return false
		for flag in ["connected", "nunchuk", "c", "z"]:
			if not entry.get(flag) is bool: return false
		var buttons = entry.get("buttons")
		if not (buttons is float or buttons is int) or not is_finite(float(buttons)) or buttons < 0 or buttons > 65535 or buttons != int(buttons): return false
		var state: Dictionary = entry.duplicate(true)
		state["color"] = states.get(device, {}).get("color", StorySession.COLORS[int(slot)])
		ids[identity] = true
		next[device] = state
	last_sequence = int(sequence)
	last_packet = now
	# Confirm startup with an authenticated heartbeat from the app macOS launched.
	var process_id = packet.get("pid")
	if bridge_starting and (process_id is int or process_id is float) and process_id == bridge_pid:
		bridge_starting = false
	var before := states
	states = next
	for device in range(FIRST_DEVICE, FIRST_DEVICE + 4):
		var was := eligible(before.get(device, {}))
		var live := eligible(states.get(device, {}))
		if was != live: connection_changed.emit(device, live)
		publish_controls(device, before.get(device, {}), states.get(device, {}))
	status = "Bridge connected. Pair or wake your Wii Remotes." if states.is_empty() else "Bridge connected. Calibrate each remote before playing."
	if packet.get("status") is String: status = packet.status.left(300)
	state_changed.emit()
	return true

func eligible(state: Dictionary) -> bool:
	return bool(state.get("connected", false))

func connected_devices() -> Array[int]:
	var result: Array[int] = []
	for device in states:
		if eligible(states[device]): result.append(device)
	result.sort()
	return result

func device_name(device: int) -> String:
	return "Wii Remote %d%s" % [device - FIRST_DEVICE + 1, " + Nunchuk" if states.get(device, {}).get("nunchuk", false) else ""]

func axis(device: int, code: int, source: Dictionary = {}) -> float:
	if source.is_empty(): source = states
	var state: Dictionary = source.get(device, {})
	if not eligible(state): return 0
	if code == JOY_AXIS_TRIGGER_RIGHT: return 1.0 if (int(state.buttons) & 4) != 0 else 0.0
	if code not in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y]: return 0
	if not state.nunchuk: return 0
	var center: Vector2 = calibration.get(state.id, {}).get("stick_center", Vector2.ZERO)
	return clampf(float(state.stick[code]) - center[code], -1, 1)

func button(device: int, code: int, source: Dictionary = {}) -> bool:
	if source.is_empty(): source = states
	var state: Dictionary = source.get(device, {})
	if not eligible(state): return false
	match code:
		JOY_BUTTON_A: return (int(state.buttons) & 8) != 0
		JOY_BUTTON_B: return (state.nunchuk and state.z) or (int(state.buttons) & 2) != 0
		JOY_BUTTON_Y: return (state.nunchuk and state.c) or (int(state.buttons) & 16) != 0
		JOY_BUTTON_START: return (int(state.buttons) & 4096) != 0
		JOY_BUTTON_RIGHT_SHOULDER: return (int(state.buttons) & 4) != 0
		JOY_BUTTON_DPAD_UP: return (int(state.buttons) & 0x0800) != 0
		JOY_BUTTON_DPAD_DOWN: return (int(state.buttons) & 0x0400) != 0
		JOY_BUTTON_DPAD_LEFT: return (int(state.buttons) & 0x0100) != 0
		JOY_BUTTON_DPAD_RIGHT: return (int(state.buttons) & 0x0200) != 0
	return false

func publish_controls(device: int, before: Dictionary, after: Dictionary) -> void:
	var previous := {device: before}
	var current := {device: after}
	for code in [JOY_BUTTON_A, JOY_BUTTON_B, JOY_BUTTON_Y, JOY_BUTTON_START, JOY_BUTTON_RIGHT_SHOULDER, JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT]:
		var pressed := button(device, code, current)
		if pressed != button(device, code, previous):
			var event := InputEventJoypadButton.new()
			event.device = device
			event.button_index = code
			event.pressed = pressed
			get_viewport().push_input(event)
	for code in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y]:
		var value := axis(device, code, current)
		if absf(value - axis(device, code, previous)) > 0.015:
			var event := InputEventJoypadMotion.new()
			event.device = device
			event.axis = code
			event.axis_value = value
			get_viewport().push_input(event)

func disconnect_all() -> void:
	if states.is_empty(): return
	var before := states
	states = {}
	for device in before:
		if eligible(before[device]): connection_changed.emit(device, false)
		publish_controls(device, before[device], {})
	state_changed.emit()

func pointer(device: int) -> Variant:
	var state: Dictionary = states.get(device, {})
	if not eligible(state) or state.get("ir") == null: return null
	var raw := Vector2(state.ir[0], state.ir[1])
	var setting: Dictionary = calibration.get(state.id, {})
	var point := Vector2(1 - raw.x, raw.y)
	if setting.has("top_left") and setting.has("bottom_right"):
		var a: Vector2 = setting.top_left
		var b: Vector2 = setting.bottom_right
		point = (raw - a) / (b - a) * 0.7 + Vector2.ONE * 0.15
	return point.clamp(Vector2.ZERO, Vector2.ONE)

func world_aim(device: int, tank: Node2D) -> Variant:
	var point = pointer(device)
	if point == null: return null
	states[device].color = tank.tint
	return tank.get_canvas_transform().affine_inverse() * (point * tank.get_viewport_rect().size)

func save_corners(device: int, top_left: Vector2, bottom_right: Vector2) -> bool:
	if not states.has(device) or absf(bottom_right.x - top_left.x) < 0.04 or absf(bottom_right.y - top_left.y) < 0.04: return false
	var key: String = states[device].id
	var setting: Dictionary = calibration.get(key, {})
	setting.top_left = top_left
	setting.bottom_right = bottom_right
	calibration[key] = setting
	return save_calibration()

func center_stick(device: int) -> void:
	if not states.has(device): return
	var key: String = states[device].id
	var setting: Dictionary = calibration.get(key, {})
	setting.stick_center = Vector2(states[device].stick[0], states[device].stick[1])
	calibration[key] = setting
	save_calibration()

func load_calibration() -> void:
	calibration = {}
	var file := ConfigFile.new()
	if file.load(settings_path) != OK: return
	var saved = file.get_value("wii", "remotes", {})
	if saved is Dictionary: calibration = saved

func save_calibration() -> bool:
	var file := ConfigFile.new()
	file.set_value("wii", "remotes", calibration)
	return file.save(settings_path) == OK

func launch_bridge(window_test: bool = false) -> Error:
	if OS.get_name() != "macOS": status = "This Wii bridge currently supports macOS."; return ERR_UNAVAILABLE
	if listen_port == 0: return ERR_CANT_CREATE
	if bridge_starting or bridge_is_running(): return OK
	disconnect_all()
	token = Crypto.new().generate_random_bytes(16).hex_encode()
	last_sequence = -1
	last_packet = -100
	bridge_pid = -1
	var bundle := ProjectSettings.globalize_path("res://tools/wii/Wii Remote Bridge.app")
	if not FileAccess.file_exists(bundle.path_join("Contents/MacOS/WiiRemoteBridge")): status = "Build the Wii bridge using tools/wii/build.command first."; return ERR_FILE_NOT_FOUND
	# Launch the app bundle through macOS so Bluetooth permission belongs to the bridge.
	# Executing its binary as a Godot child attributes the request to Godot and aborts it.
	var arguments := PackedStringArray(["--port", str(listen_port), "--token", token, "--owner-pid", str(OS.get_process_id())])
	if window_test: arguments.append("--window-test")
	# Godot uses NSWorkspace for .app paths and returns the launched app's actual PID.
	bridge_pid = OS.create_process(bundle, arguments)
	bridge_starting = bridge_pid > 0
	launch_requested_at = seconds()
	next_process_check = seconds() + 1
	status = "Starting the Wii bridge. Allow Bluetooth if macOS asks…" if bridge_starting else "Could not start the Wii bridge."
	return OK if bridge_starting else ERR_CANT_CREATE

func bridge_is_running() -> bool:
	if bridge_pid <= 0: return false
	# A Launch Services app is not a Unix child. Godot's waitpid-based check logs
	# errors after it exits, so probe existence without changing or signalling it.
	var output: Array = []
	return OS.execute("/bin/kill", ["-0", str(bridge_pid)], output, true) == 0

func draw_cursors() -> void:
	for device in connected_devices():
		var point = pointer(device)
		if point == null: continue
		var at: Vector2 = point * get_viewport().get_visible_rect().size
		var color: Color = states[device].color
		cursor_canvas.draw_arc(at, 10, 0, TAU, 28, Color.BLACK, 4, true)
		cursor_canvas.draw_arc(at, 10, 0, TAU, 28, color.lightened(0.25), 2, true)
		for side in [-1, 1]:
			cursor_canvas.draw_line(at + Vector2(side * 5, 0), at + Vector2(side * 15, 0), color, 2)
			cursor_canvas.draw_line(at + Vector2(0, side * 5), at + Vector2(0, side * 15), color, 2)
		cursor_canvas.draw_string(ThemeDB.fallback_font, at + Vector2(15, -12), "W%d" % (device - FIRST_DEVICE + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, color.lightened(0.3))

func _exit_tree() -> void:
	disconnect_all()
	socket.close()
	if bridge_is_running(): OS.kill(bridge_pid)
