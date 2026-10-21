extends RefCounted

const ControllerInput = preload("res://scripts/input/controller_input.gd")

const KEYBOARD: int = -1
const SHARED_LEFT: int = -2
const SHARED_RIGHT: int = -3
static var devices: Array[int] = [SHARED_LEFT, SHARED_RIGHT]

static func shared_keyboard() -> void:
	devices.assign([SHARED_LEFT, SHARED_RIGHT])

static func controller_name(device: int) -> String:
	var label := ControllerInput.device_name(device)
	return label if not label.is_empty() else "Controller %d" % (device + 1)

static func valid_pair(pair: Array[int], connected: Array[int]) -> bool:
	if pair.size() != 2 or pair[0] == pair[1]:
		return false
	for device in pair:
		if device < SHARED_RIGHT or (device >= 0 and not connected.has(device)):
			return false
	if pair.has(KEYBOARD) and (pair.has(SHARED_LEFT) or pair.has(SHARED_RIGHT)): return false
	return true
