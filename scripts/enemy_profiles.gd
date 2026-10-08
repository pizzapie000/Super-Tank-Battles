class_name EnemyProfiles
extends RefCounted

# Movement, bullet speed, turret speed, ricochets, live shots, mines, behavior.
const TYPES: Array[Dictionary] = [
	{"name": "Brown", "mission": 1, "color": "a77a52", "move": 0.0, "bullet": 300.0, "aim": 1.1, "ricochets": 1, "shots": 1, "mines": 0, "behavior": "Passive"},
	{"name": "Ash", "mission": 2, "color": "a8b4bf", "move": 85.0, "bullet": 300.0, "aim": 1.1, "ricochets": 1, "shots": 1, "mines": 0, "behavior": "Defensive"},
	{"name": "Marine", "mission": 5, "color": "41aaa2", "move": 85.0, "bullet": 510.0, "aim": 1.1, "ricochets": 0, "shots": 1, "mines": 0, "behavior": "Defensive"},
	{"name": "Yellow", "mission": 8, "color": "efcf4b", "move": 150.0, "bullet": 300.0, "aim": 1.1, "ricochets": 1, "shots": 1, "mines": 4, "behavior": "Incautious"},
	{"name": "Pink", "mission": 10, "color": "ef8db6", "move": 85.0, "bullet": 300.0, "aim": 3.6, "ricochets": 1, "shots": 3, "mines": 0, "behavior": "Offensive"},
	{"name": "Green", "mission": 12, "color": "76c958", "move": 0.0, "bullet": 510.0, "aim": 3.6, "ricochets": 2, "shots": 2, "mines": 0, "behavior": "Active", "predictive": true},
	{"name": "Violet", "mission": 15, "color": "b482ea", "move": 205.0, "bullet": 300.0, "aim": 3.6, "ricochets": 1, "shots": 5, "mines": 2, "behavior": "Offensive"},
	{"name": "White", "mission": 20, "color": "edf3ee", "move": 85.0, "bullet": 300.0, "aim": 3.6, "ricochets": 1, "shots": 5, "mines": 2, "behavior": "Offensive", "invisible": true},
	{"name": "Black", "mission": 50, "color": "657080", "move": 255.0, "bullet": 510.0, "aim": 3.6, "ricochets": 0, "shots": 3, "mines": 2, "behavior": "Dynamic"},
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
