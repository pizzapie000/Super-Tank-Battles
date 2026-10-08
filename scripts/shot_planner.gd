class_name ShotPlanner
extends RefCounted

const RADIUS: float = 3.5
const HIT_RADIUS: float = 20.0

static func first_wall(origin: Vector2, direction: Vector2, walls: Array[Rect2]) -> Dictionary:
	var nearest: float = 4000.0
	var result: Dictionary = {}
	for wall in walls:
		var rect := wall.grow(RADIUS)
		var near_distance: float = -INF
		var far_distance: float = INF
		var normal := Vector2.ZERO
		var misses: bool = false
		for axis in range(2):
			if absf(direction[axis]) < 0.00001:
				if origin[axis] < rect.position[axis] or origin[axis] > rect.end[axis]:
					misses = true
					break
				continue
			var entry: float = (rect.position[axis] - origin[axis]) / direction[axis]
			var exit: float = (rect.end[axis] - origin[axis]) / direction[axis]
			if entry > exit:
				var swap := entry
				entry = exit
				exit = swap
			if entry > near_distance:
				near_distance = entry
				normal = Vector2.ZERO
				normal[axis] = -signf(direction[axis])
			far_distance = minf(far_distance, exit)
		if not misses and near_distance > 0.001 and near_distance <= far_distance and near_distance < nearest:
			nearest = near_distance
			result = {"point": origin + direction * nearest, "normal": normal, "distance": nearest}
	return result

static func trace(origin: Vector2, direction: Vector2, target: Vector2, walls: Array[Rect2], ricochets: int, allies: Array[Vector2] = []) -> Dictionary:
	var distance: float = 0.0
	var points: Array[Vector2] = [origin]
	for bounce in range(ricochets + 1):
		var hit := first_wall(origin, direction, walls)
		var wall_distance: float = float(hit.get("distance", 4000.0))
		var projection := (target - origin).dot(direction)
		var reaches := projection > 0.0 and projection <= wall_distance and (target - origin - direction * projection).length() <= HIT_RADIUS
		var travel := projection if reaches else wall_distance
		for ally in allies:
			var along := (ally - origin).dot(direction)
			if along > 0.0 and along < travel and (ally - origin - direction * along).length() < 25.0:
				return {}
		if reaches:
			points.append(origin + direction * projection)
			return {"distance": distance + projection, "bounces": bounce, "points": points}
		if hit.is_empty() or bounce == ricochets:
			return {}
		distance += wall_distance
		points.append(hit.point)
		origin = hit.point + hit.normal * 0.05
		direction = direction.bounce(hit.normal)
	return {}

static func mirror(point: Vector2, face: Vector2) -> Vector2:
	var result := point
	var axis := int(face.x)
	result[axis] = 2.0 * face.y - point[axis]
	return result

static func intercept_time(offset: Vector2, target_velocity: Vector2, speed: float) -> float:
	var a := target_velocity.length_squared() - speed * speed
	var b := 2.0 * offset.dot(target_velocity)
	var c := offset.length_squared()
	if absf(a) < 0.001:
		return maxf(0.0, -c / b) if absf(b) > 0.001 else 0.0
	var discriminant := b * b - 4.0 * a * c
	if discriminant < 0.0:
		return -1.0
	var first := (-b - sqrt(discriminant)) / (2.0 * a)
	var second := (-b + sqrt(discriminant)) / (2.0 * a)
	if first > 0.0 and second > 0.0:
		return minf(first, second)
	return maxf(first, second)

static func solve(origin: Vector2, target: Vector2, target_velocity: Vector2, speed: float, walls: Array[Rect2], ricochets: int, allies: Array[Vector2] = []) -> Dictionary:
	# Reflect the target (and its velocity) to unfold one- and two-wall paths.
	# Validate every candidate against the actual arena, including friendly tanks.
	var faces: Array[Vector2] = []
	for wall in walls:
		var rect := wall.grow(RADIUS)
		for face in [Vector2(0, rect.position.x), Vector2(0, rect.end.x), Vector2(1, rect.position.y), Vector2(1, rect.end.y)]:
			if not faces.has(face):
				faces.append(face)
	var midpoint := (origin + target) * 0.5
	faces.sort_custom(func(a: Vector2, b: Vector2): return absf(midpoint[int(a.x)] - a.y) < absf(midpoint[int(b.x)] - b.y))
	# Keep planning bounded even in dense missions; identical planes are deduplicated.
	if faces.size() > 24:
		faces.resize(24)
	var sequences: Array[Array] = [[]]
	if ricochets >= 1:
		for face in faces:
			sequences.append([face])
	if ricochets >= 2:
		for first in faces:
			for second in faces:
				if first != second:
					sequences.append([first, second])
	var best: Dictionary = {}
	var best_distance: float = INF
	for sequence in sequences:
		var image := target
		var image_velocity := target_velocity
		for i in range(sequence.size() - 1, -1, -1):
			var face: Vector2 = sequence[i]
			image = mirror(image, face)
			image_velocity[int(face.x)] *= -1.0
		var flight_time := intercept_time(image - origin, image_velocity, speed)
		if flight_time < 0.0 or flight_time > 8.0:
			continue
		var direction := (image + image_velocity * flight_time - origin).normalized()
		var future := target + target_velocity * flight_time
		var path := trace(origin, direction, future, walls, ricochets, allies)
		if not path.is_empty() and float(path.distance) < best_distance:
			best_distance = float(path.distance)
			best = {"angle": direction.angle(), "target": future, "bounces": path.bounces, "time": flight_time}
			if int(path.bounces) == 0:
				return best
	return best
