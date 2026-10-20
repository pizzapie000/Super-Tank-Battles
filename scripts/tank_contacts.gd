extends RefCounted

# All tank bodies have an 18-pixel radius. Allow for the physics safe margin,
# then require a small gap before another bump can count as a new contact.
const TOUCH_DISTANCE := 36.5
const RELEASE_DISTANCE := 42.0
const COOLDOWN := 3.0

var pairs: Dictionary = {}

func update(tanks: Array[DuelTank], delta: float) -> Array[Vector2]:
	var hearts: Array[Vector2] = []
	var living: Array[DuelTank] = []
	for tank in tanks:
		if is_instance_valid(tank) and tank.is_inside_tree() and tank.alive:
			living.append(tank)
	var seen: Dictionary = {}
	for i in range(living.size()):
		for j in range(i + 1, living.size()):
			var first := living[i]
			var second := living[j]
			var a := first.get_instance_id()
			var b := second.get_instance_id()
			var key := "%d:%d" % [mini(a, b), maxi(a, b)]
			var distance := first.global_position.distance_to(second.global_position)
			if not pairs.has(key):
				if distance > TOUCH_DISTANCE:
					continue
				pairs[key] = {"touching": false, "cooldown": 0.0}
			seen[key] = true
			var state: Dictionary = pairs[key]
			state.cooldown = maxf(0, state.cooldown - delta)
			if distance > RELEASE_DISTANCE:
				state.touching = false
			elif distance <= TOUCH_DISTANCE and not state.touching:
				state.touching = true
				if state.cooldown <= 0:
					state.cooldown = COOLDOWN
					hearts.append((first.global_position + second.global_position) * 0.5)
	# Stages replace their tanks; don't retain IDs from an old encounter.
	for key in pairs.keys():
		if not seen.has(key):
			pairs.erase(key)
	return hearts
