extends RefCounted
## One input interface for ordinary gamepads and the local Wii bridge.

static func connected_devices() -> Array[int]:
	var result := Input.get_connected_joypads()
	result.append_array(bridge().connected_devices())
	return result

static func is_wii(device: int) -> bool:
	return device >= 1000 and device < 1000 + 4

static func device_name(device: int) -> String:
	return bridge().device_name(device) if is_wii(device) else Input.get_joy_name(device)

static func axis(device: int, code: int) -> float:
	return bridge().axis(device, code) if is_wii(device) else Input.get_joy_axis(device, code)

static func button(device: int, code: int) -> bool:
	return bridge().button(device, code) if is_wii(device) else Input.is_joy_button_pressed(device, code)

static func connect_changes(receiver: Callable) -> void:
	if not Input.joy_connection_changed.is_connected(receiver):
		Input.joy_connection_changed.connect(receiver)
	if not bridge().connection_changed.is_connected(receiver):
		bridge().connection_changed.connect(receiver)

static func rumble(device: int, weak: float, strong: float, duration: float) -> void:
	if not is_wii(device): Input.start_joy_vibration(device, weak, strong, duration)

static func aim(device: int, tank: Node2D) -> Variant:
	if is_wii(device):
		return bridge().world_aim(device, tank)
	var stick := StorySession.stick(Vector2(axis(device, JOY_AXIS_RIGHT_X), axis(device, JOY_AXIS_RIGHT_Y)))
	return null if stick.is_zero_approx() else tank.global_position + stick * 300

static func bridge() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node("WiiInput")
