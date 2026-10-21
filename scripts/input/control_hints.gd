extends RefCounted
## Show controls only for assigned seats whose input device is available.

const Controls = preload("res://scripts/input/controller_input.gd")
const KEYBOARD := {"move": "WASD", "aim": "MOUSE", "fire": "CLICK / SPACE", "mine": "E", "interact": "F", "repair": "R"}
const ESDF := {"move": "ESDF", "aim": "S / F TO TURN", "fire": "Q", "mine": "G", "interact": "H", "repair": "T"}
const ARROWS := {"move": "ARROW KEYS", "aim": "LEFT / RIGHT TO TURN", "fire": "M", "mine": "/", "interact": ".", "repair": ","}
const PAD := {"move": "LEFT STICK", "aim": "RIGHT STICK", "fire": "RT / RB", "mine": "B", "interact": "A", "repair": "Y", "pause": "START", "continue": "A", "skip_intro": "A / START", "skip_tutorial": "Y", "browse": "LEFT STICK / D-PAD", "accept": "A", "back": "B"}
const WII := {"move": "NUNCHUK STICK", "aim": "POINT AT THE SCREEN", "fire": "B", "mine": "Z", "interact": "A", "repair": "C / MINUS", "pause": "PLUS", "continue": "A", "skip_intro": "A / PLUS", "skip_tutorial": "C / MINUS", "browse": "NUNCHUK STICK / D-PAD", "accept": "A", "back": "B / Z / 1"}
const KEYBOARD_MENUS := {"pause": "ESC", "continue": "ENTER", "skip_intro": "ENTER / SPACE", "skip_tutorial": "T", "browse": "ARROW KEYS", "accept": "ENTER", "back": "ESC"}

static func active_devices(assigned: Array) -> Array[int]:
	var result: Array[int] = []
	var connected := Controls.connected_devices()
	for device in assigned:
		if (device in [-1, -2, -3] or (device >= 0 and connected.has(device))) and not result.has(device):
			result.append(device)
	return result

static func family(device: int) -> String:
	return "KEYBOARD" if device < 0 else ("WII REMOTE" if Controls.is_wii(device) else "CONTROLLER")

static func for_device(action: String, device: int) -> String:
	if Controls.is_wii(device): return WII.get(action, "")
	if device >= 0: return PAD.get(action, "")
	var layout: Dictionary = KEYBOARD if device == -1 else (ESDF if device == -2 else ARROWS)
	return layout.get(action, KEYBOARD_MENUS.get(action, ""))

static func buttons(action: String, assigned: Array) -> String:
	var result: Array[String] = []
	for device in active_devices(assigned):
		var value := for_device(action, device)
		if not value.is_empty() and not result.has(value): result.append(value)
	return " / ".join(result)

static func menu_hint(assigned: Array) -> String:
	var devices := active_devices(assigned)
	if devices.is_empty(): return "Use the mouse to choose your player controls."
	return "%s to browse · %s to select · %s to go back" % [buttons("browse", devices), buttons("accept", devices), buttons("back", devices)]

static func mission_controls(device: int) -> String:
	if not active_devices([device]).has(device): return "Reconnect Player 1's assigned control to continue."
	return "%s drive · %s aim · %s fire · %s mine · %s pause" % [for_device("move", device), for_device("aim", device), for_device("fire", device), for_device("mine", device), for_device("pause", device)]
