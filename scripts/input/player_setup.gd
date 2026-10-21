class_name PlayerSetup
extends RefCounted
## Shared seats. Saved Wii identities survive a different bridge slot next time.

const Controls = preload("res://scripts/input/controller_input.gd")
const OFF := -10
static var settings_path := "user://player_controls.cfg"
static var loaded := false
static var bindings: Array[Dictionary] = [{"kind": "keyboard", "device": -1}, {"kind": "off"}, {"kind": "off"}, {"kind": "off"}]

static func load_preferences() -> void:
	if loaded: return
	loaded = true
	var file := ConfigFile.new()
	if file.load(settings_path) != OK: return
	var saved = file.get_value("players", "bindings", [])
	if not saved is Array or saved.size() != 4: return
	for slot in range(4):
		if saved[slot] is Dictionary and saved[slot].get("kind") in ["off", "keyboard", "wii", "pad"]:
			bindings[slot] = saved[slot].duplicate()

static func save_preferences() -> void:
	var file := ConfigFile.new()
	file.set_value("players", "bindings", bindings)
	file.save(settings_path)

static func device(slot: int) -> int:
	load_preferences()
	var binding := bindings[slot]
	match binding.get("kind", "off"):
		"off": return OFF
		"keyboard": return int(binding.get("device", -1))
		"wii":
			var wii := Controls.bridge()
			for candidate in wii.connected_devices():
				if wii.states[candidate].id == binding.get("id"): return candidate
		"pad":
			var pads := Input.get_connected_joypads()
			var ordinal := 0
			for candidate in pads:
				if Input.get_joy_guid(candidate) == binding.get("guid"):
					if ordinal == int(binding.get("ordinal", 0)): return candidate
					ordinal += 1
	return -100 - slot # An assigned but disconnected seat, distinct from Off.

static func assign(slot: int, selected: int) -> String:
	if selected != OFF:
		for other in range(4):
			if other != slot and device(other) == selected: return "That control is already assigned to Player %d." % (other + 1)
	if slot == 0 and selected == OFF: return "Player 1 needs a control."
	if selected == OFF: bindings[slot] = {"kind": "off"}
	elif selected in [-1, -2, -3]: bindings[slot] = {"kind": "keyboard", "device": selected}
	elif Controls.is_wii(selected):
		var state: Dictionary = Controls.bridge().states.get(selected, {})
		if not Controls.bridge().eligible(state): return "Reconnect that Wii Remote first."
		bindings[slot] = {"kind": "wii", "id": state.id, "name": Controls.device_name(selected)}
	elif Input.get_connected_joypads().has(selected):
		var guid := Input.get_joy_guid(selected)
		var ordinal := 0
		for candidate in Input.get_connected_joypads():
			if candidate == selected: break
			if Input.get_joy_guid(candidate) == guid: ordinal += 1
		bindings[slot] = {"kind": "pad", "guid": guid, "ordinal": ordinal, "name": Controls.device_name(selected)}
	else: return "That controller is disconnected."
	save_preferences()
	return ""

static func selected(count: int = 4) -> Array[int]:
	var result: Array[int] = []
	for slot in range(count):
		var selected_device := device(slot)
		if selected_device != OFF: result.append(selected_device)
	return result

static func problem(mode: String) -> String:
	var count := 1 if mode == "missions" else (2 if mode == "duel" else 4)
	var used: Array[int] = []
	var gap := false
	for slot in range(count):
		var selected_device := device(slot)
		if selected_device == OFF:
			gap = true
			if slot == 0 or mode == "duel": return "Assign Player %d in Player Setup to play %s." % [slot + 1, mode]
			continue
		if gap: return "Fill the player seats in order, or set unused seats to Off."
		if selected_device < -10: return "Reconnect Player %d's controller, or choose another control." % (slot + 1)
		if used.has(selected_device): return "Each player needs a different control."
		used.append(selected_device)
	if used.has(-1) and (used.has(-2) or used.has(-3)): return "For solo WASD, set the other keyboard seats to Off. For two keyboard players, choose ESDF + arrows."
	return ""

static func control_name(selected_device: int) -> String:
	match selected_device:
		OFF: return "Off"
		-1: return "Keyboard + mouse / trackpad"
		-2: return "Keyboard: ESDF + Q"
		-3: return "Keyboard: arrows + M"
	return Controls.device_name(selected_device) if selected_device >= 0 else "Disconnected controller"
