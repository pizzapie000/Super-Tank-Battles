extends RefCounted

const MULTIPLIERS := [1.0, 1.4, 1.8, 2.2]

static func scaled_count(base_count: int, crew_size: int) -> int:
	return roundi(base_count * MULTIPLIERS[clampi(crew_size, 1, 4) - 1])

static func specialist(section: int, crew_size: int, ordinal: int, fallback: String) -> String:
	# Specialists occupy extra slots in the count budget; they never add free health.
	if crew_size < 2 or section < 2:
		return fallback
	var pool: Array[String] = ["Ash", "Yellow"]
	if crew_size >= 3 or section >= 3:
		pool.append("Pink")
	if crew_size >= 4 or section >= 4:
		pool.append("Marine")
	if section >= 5:
		pool.append("Green")
	return pool[ordinal % pool.size()]
