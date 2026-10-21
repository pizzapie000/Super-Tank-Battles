extends RefCounted

const Hints = preload("res://scripts/input/control_hints.gd")
const LESSONS := [
	{"title": "Welcome to your tank", "body": "Your crew is safe here. The practice tanks are switched off.\nTry each control, then continue when you are ready.", "seconds": 4.0},
	{"title": "Drive off the conveyor", "body": "Move in any direction. Your turret can aim separately from the body.\nTake a lap around the polishing station and get comfortable.", "seconds": 3.0},
	{"title": "Aim, fire, and watch the ricochets", "body": "Destroy two inactive practice tanks. They cannot shoot back.\nIn real fights, every shell can hurt teammates and its own shooter.", "seconds": 4.0},
	{"title": "Try a landmine", "body": "Place a mine, then drive clear. After training, its blast can hurt your crew.\nMines destroy crumbly walls. Shells bounce off those walls.", "seconds": 4.0},
	{"title": "Choose a powerup", "body": "Destroy the flashing practice tank, then equip the Loader upgrade it drops.\nMatching copies improve its level; a new type replaces it. Leave unwanted powerups for a teammate.", "seconds": 4.0},
	{"title": "Look after your crew", "body": "Hold {interact} beside a downed friend to revive them.\nAfter training, hold {repair} for 2 seconds to repair while parked. Cost: 2 supplies.", "seconds": 6.0},
]

static func lesson(index: int, assigned: Array) -> Dictionary:
	var result: Dictionary = LESSONS[index].duplicate()
	result.body = str(result.body).format({"interact": Hints.buttons("interact", assigned), "repair": Hints.buttons("repair", assigned)})
	var groups := {}
	for device in Hints.active_devices(assigned):
		var name := Hints.family(device)
		if not groups.has(name): groups[name] = []
		groups[name].append(device)
	var lines: Array[String] = []
	for name in groups:
		var devices: Array = groups[name]
		var value: String
		match index:
			0: value = Hints.buttons("continue", devices) + " — Continue"
			1: value = Hints.buttons("move", devices) + " — Move"
			2: value = "%s — Aim     %s — Fire" % [Hints.buttons("aim", devices), Hints.buttons("fire", devices)]
			3: value = Hints.buttons("mine", devices) + " — Place a mine"
			4: value = Hints.buttons("interact", devices) + " BESIDE A DROP — Equip or improve it"
			5: value = Hints.buttons("continue", devices) + " — Sound the alarm when ready"
		lines.append((str(name) + " · " if groups.size() > 1 else "") + value)
	if groups.is_empty(): result.body = "Reconnect your assigned control, or choose another setup from the main menu."
	result.controls = lines if not lines.is_empty() else ["Reconnect your assigned control to continue."]
	return result
