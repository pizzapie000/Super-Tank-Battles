extends RefCounted

static func hazards(arena: Node2D, _tank: DuelTank) -> Array[Vector3]:
	var result: Array[Vector3] = []
	for mine in arena.get_node("Mines").get_children():
		if mine.released:
			continue
		# Begin detouring before arming, and stay outside the full blast radius.
		result.append(Vector3(mine.global_position.x, mine.global_position.y, mine.blast_radius + 24))
	return result

static func segment_clear(from: Vector2, to: Vector2, hazards: Array[Vector3]) -> bool:
	for hazard in hazards:
		var center := Vector2(hazard.x, hazard.y)
		var radius_squared := hazard.z * hazard.z
		var start_distance := from.distance_squared_to(center)
		if start_distance < radius_squared:
			# A newly placed mine may surround a tank: allow a straight escape outward.
			if to.distance_squared_to(center) < start_distance or (to - from).dot(from - center) < -0.01:
				return false
		else:
			var closest := Geometry2D.get_closest_point_to_segment(center, from, to)
			if closest.distance_squared_to(center) < radius_squared:
				return false
	return true

static func point_clear(point: Vector2, hazards: Array[Vector3]) -> bool:
	for hazard in hazards:
		if point.distance_squared_to(Vector2(hazard.x, hazard.y)) < hazard.z * hazard.z:
			return false
	return true
