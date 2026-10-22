class_name ShotPlanner
extends RefCounted

const RADIUS: float = 3.5
const HIT_RADIUS: float = 20.0
const SHOOTER_CLEARANCE: float = 25.0

static func prepare_walls(walls: Array[Rect2]) -> Array[AABB]:
	var boxes: Array[AABB] = []
	for wall in walls:
		var padded := wall.grow(RADIUS)
		boxes.append(AABB(Vector3(padded.position.x, padded.position.y, -1), Vector3(padded.size.x, padded.size.y, 2)))
	return boxes

static func first_wall(origin: Vector2, direction: Vector2, walls: Array[Rect2]) -> Dictionary:
	return first_prepared_wall(origin, direction, prepare_walls(walls))

static func first_prepared_wall(origin: Vector2, direction: Vector2, boxes: Array[AABB], max_distance: float = 4000.0) -> Dictionary:
	var nearest := max_distance
	var normal := Vector2.ZERO
	var found := false
	var parallel_x := absf(direction.x) < 0.00001
	var parallel_y := absf(direction.y) < 0.00001
	var inverse_x := 0.0 if parallel_x else 1.0 / direction.x
	var inverse_y := 0.0 if parallel_y else 1.0 / direction.y
	var ray_origin := Vector3(origin.x, origin.y, 0)
	var ray_direction := Vector3(0 if parallel_x else direction.x, 0 if parallel_y else direction.y, 0)
	# Godot's native slab test rejects misses. Padded 2D walls become thin 3D
	# boxes with the ray at z=0; calculate the same 2D entry distance and normal.
	for box in boxes:
		if box.intersects_ray(ray_origin, ray_direction) == null: continue
		var near_x := -INF
		var near_y := -INF
		if not parallel_x: near_x = ((box.position.x if direction.x > 0 else box.end.x) - origin.x) * inverse_x
		if not parallel_y: near_y = ((box.position.y if direction.y > 0 else box.end.y) - origin.y) * inverse_y
		var entry := maxf(near_x, near_y)
		if entry > 0.001 and entry < nearest:
			nearest = entry
			normal = Vector2(0, -signf(direction.y)) if near_y > near_x else Vector2(-signf(direction.x), 0)
			found = true
	return {"point": origin + direction * nearest, "normal": normal, "distance": nearest} if found else {}

static func trace(origin: Vector2, direction: Vector2, target: Vector2, walls: Array[Rect2], ricochets: int, allies: Array[Vector2] = [], min_ricochets: int = 0, prepared: Array[AABB] = []) -> Dictionary:
	var boxes := prepare_walls(walls) if prepared.is_empty() else prepared
	var distance: float = 0.0
	var points: Array[Vector2] = [origin]
	for bounce in range(ricochets + 1):
		var hit := first_prepared_wall(origin, direction, boxes)
		var wall_distance: float = float(hit.get("distance", 4000.0))
		var projection := (target - origin).dot(direction)
		var reaches := projection > 0.0 and projection <= wall_distance and (target - origin - direction * projection).length_squared() <= HIT_RADIUS * HIT_RADIUS
		var travel := projection if reaches else wall_distance
		for ally in allies:
			var along := (ally - origin).dot(direction)
			if along > 0.0 and along < travel and (ally - origin - direction * along).length_squared() < 625.0:
				return {}
		if reaches:
			# Reject an early hit: continuing through the target to count a later
			# bounce would claim a bank shot that actually hits the tank directly.
			if bounce < min_ricochets:
				return {}
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

static func avoids_shooter(muzzle: Vector2, direction: Vector2, shooter: Vector2, walls: Array[Rect2], ricochets: int, prepared: Array[AABB] = []) -> bool:
	var boxes := prepare_walls(walls) if prepared.is_empty() else prepared
	for bounce in range(ricochets + 1):
		var hit := first_prepared_wall(muzzle, direction, boxes, INF)
		var travel: float = float(hit.get("distance", INF))
		var along := clampf((shooter - muzzle).dot(direction), 0.0, travel)
		if shooter.distance_squared_to(muzzle + direction * along) <= SHOOTER_CLEARANCE * SHOOTER_CLEARANCE:
			return false
		# Include the full flight even beyond the intended target: it may dodge.
		# The final wall destroys the shell instead of reflecting it again.
		if hit.is_empty() or bounce == ricochets:
			return true
		muzzle = hit.point + hit.normal * 0.05
		direction = direction.bounce(hit.normal)
	return true

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

static func solve(origin: Vector2, target: Vector2, target_velocity: Vector2, speed: float, walls: Array[Rect2], ricochets: int, allies: Array[Vector2] = [], min_ricochets: int = 0, prefer_simple: bool = false, avoid_self: bool = false, safety_walls: Array[Rect2] = []) -> Dictionary:
	var boxes := prepare_walls(walls)
	var safety_boxes := prepare_walls(safety_walls) if avoid_self and not safety_walls.is_empty() else boxes
	# Most patrol shots are direct. Validate that path before allocating hundreds
	# of reflected candidates; the muzzle still rechecks the actual shot at firing.
	if min_ricochets == 0:
		var direct_time := intercept_time(target - origin, target_velocity, speed)
		if direct_time >= 0 and direct_time <= 8:
			var future := target + target_velocity * direct_time
			var direct := (future - origin).normalized()
			if not trace(origin, direct, future, walls, 0, allies, 0, boxes).is_empty() and (not avoid_self or avoids_shooter(origin + direct * 31.0, direct, origin, walls, ricochets, safety_boxes)):
				return {"angle": direct.angle(), "target": future, "bounces": 0, "time": direct_time}
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
		# Co-op supports choose a validated single bank when available and search
		# double banks when needed. Solo retains the full shortest-path search.
		if prefer_simple and sequence.size() > 1 and not best.is_empty():
			return best
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
		var path := trace(origin, direction, future, walls, ricochets, allies, min_ricochets, boxes)
		if not path.is_empty() and float(path.distance) < best_distance:
			if avoid_self and not avoids_shooter(origin + direction * 31.0, direction, origin, walls, ricochets, safety_boxes):
				continue
			best_distance = float(path.distance)
			best = {"angle": direction.angle(), "target": future, "bounces": path.bounces, "time": flight_time}
			if int(path.bounces) == 0:
				return best
	return best
