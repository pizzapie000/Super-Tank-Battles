class_name EnemyProfiles
extends RefCounted

# Movement, bullet speed, turret speed, ricochets, live shots, mines, behavior.
const TYPES: Array[Dictionary] = [
	{"name": "Brown", "mission": 1, "color": "d98a36", "marker": "circle", "move": 0.0, "bullet": 300.0, "aim": 1.1, "ricochets": 1, "shots": 1, "mines": 0, "behavior": "Passive"},
	{"name": "Ash", "mission": 2, "color": "c4cfda", "marker": "square", "move": 85.0, "bullet": 300.0, "aim": 1.1, "ricochets": 1, "shots": 1, "mines": 0, "behavior": "Defensive"},
	{"name": "Marine", "mission": 5, "color": "00dfd0", "marker": "triangle", "move": 85.0, "bullet": 510.0, "aim": 1.1, "ricochets": 0, "shots": 1, "mines": 0, "behavior": "Defensive"},
	{"name": "Yellow", "mission": 8, "color": "ffe600", "marker": "bars", "move": 150.0, "bullet": 300.0, "aim": 1.1, "ricochets": 1, "shots": 1, "mines": 4, "behavior": "Incautious"},
	{"name": "Pink", "mission": 10, "color": "ff1493", "marker": "cross", "move": 85.0, "bullet": 300.0, "aim": 3.6, "ricochets": 1, "shots": 3, "mines": 0, "behavior": "Offensive"},
	{"name": "Green", "mission": 12, "color": "55ff21", "marker": "chevron", "move": 0.0, "bullet": 510.0, "aim": 3.6, "ricochets": 2, "shots": 2, "mines": 0, "behavior": "Active", "predictive": true, "bank_only": true, "missile": true},
	{"name": "Violet", "mission": 15, "color": "b84dff", "marker": "star", "move": 205.0, "bullet": 300.0, "aim": 3.6, "ricochets": 1, "shots": 5, "mines": 2, "behavior": "Offensive"},
	{"name": "White", "mission": 20, "color": "ffffff", "marker": "dots", "move": 85.0, "bullet": 300.0, "aim": 3.6, "ricochets": 1, "shots": 5, "mines": 2, "behavior": "Offensive", "invisible": true},
	{"name": "Black", "mission": 50, "color": "303846", "marker": "diamond", "move": 255.0, "bullet": 510.0, "aim": 3.6, "ricochets": 0, "shots": 3, "mines": 2, "behavior": "Dynamic"},
]

static func get_profile(type_name: String) -> Dictionary:
	for profile in TYPES:
		if profile.name == type_name:
			return profile.duplicate()
	return TYPES[0].duplicate()

static func mission_roster(mission: int) -> Array[String]:
	var eligible: Array[String] = []
	for profile in TYPES:
		if mission >= int(profile.mission):
			eligible.append(profile.name)
	var count := mini(7, 1 + mission / 6)
	var roster: Array[String] = [eligible.back()]
	var rng := RandomNumberGenerator.new()
	rng.seed = mission * 1337
	while roster.size() < count:
		roster.append(eligible[rng.randi_range(maxi(0, eligible.size() - 4), eligible.size() - 1)])
	return roster
