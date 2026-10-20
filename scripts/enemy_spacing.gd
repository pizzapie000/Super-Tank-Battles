extends RefCounted

const MineAwareness = preload("res://scripts/enemy_mine_awareness.gd")
const GROUP_RADIUS := 150.0
const PERSONAL_SPACE := 68.0
const COMMIT_TIME := 1.8
const APPROACH_ANGLES := [PI / 2, -PI / 2, PI * 0.75, -PI * 0.75, PI, PI / 3, -PI / 3]

static func neighbors(arena: Node2D, enemy: DuelTank) -> Array[DuelTank]:
	var result: Array[DuelTank] = []
	for other in arena.enemies:
		if other == enemy or not other.alive or other.get("dormant") == true:
			continue
		if enemy.global_position.distance_to(other.global_position) < GROUP_RADIUS and arena.navigation.segment_clear(enemy.global_position, other.global_position, 0):
			result.append(other)
	return result

static func traffic(arena: Node2D, enemy) -> Array[Vector3]:
	var nearby := neighbors(arena, enemy)
	if nearby.size() < 2 and (enemy.crowd_time <= 0 or nearby.is_empty()):
		if enemy.crowd_time > 0:
			return enemy.crowd_traffic
		return []
	var leader: DuelTank = enemy
	for other in nearby:
		if other.forward_speed > 0 and other.get_instance_id() < leader.get_instance_id():
			leader = other
	var zones: Array[Vector3] = []
	nearby.sort_custom(func(a: DuelTank, b: DuelTank): return enemy.global_position.distance_squared_to(a.global_position) < enemy.global_position.distance_squared_to(b.global_position))
	# Bound the route-cost work even in a large reinforcement wave.
	for other in nearby.slice(0, 6):
		# Let one moving tank keep its route; followers choose other lanes.
		# Stationary sentries remain obstacles even for the lead tank.
		if leader == enemy and other.forward_speed > 0:
			continue
		zones.append(Vector3(other.global_position.x, other.global_position.y, 72))
		if other.get_instance_id() > enemy.get_instance_id():
			continue
		var anchor: Vector2 = other.global_position
		var budget := 240.0
		for waypoint in other.path:
			var length: float = minf(budget, anchor.distance_to(waypoint))
			for step in range(1, int(length / 60) + 1):
				var at: Vector2 = anchor.move_toward(waypoint, step * 60)
				zones.append(Vector3(at.x, at.y, 60))
			budget -= length
			if budget <= 0: break
			anchor = waypoint
	enemy.crowd_traffic = zones
	enemy.crowd_time = COMMIT_TIME if not zones.is_empty() else 0
	return zones

static func path(arena: Node2D, enemy, goal: Vector2, hazards: Array[Vector3]) -> Array[Vector2]:
	var zones := traffic(arena, enemy)
	if zones.is_empty():
		enemy.crowd_lane = Vector2.ZERO
		return arena.navigation.path(enemy.global_position, goal, hazards)
	var target = enemy.current_target()
	var destination := goal
	if is_instance_valid(target) and goal.distance_to(target.global_position) < 50:
		# Give followers their own firing approach rather than converging on the
		# player's exact center. Preserve existing flanking and cover destinations.
		if enemy.crowd_lane.is_zero_approx():
			var slot := maxi(0, arena.enemies.find(enemy) - 1)
			var radius := 150.0 + 70 * int(slot / APPROACH_ANGLES.size())
			enemy.crowd_lane = (goal - enemy.global_position).normalized().rotated(APPROACH_ANGLES[slot % APPROACH_ANGLES.size()]) * radius
		var options: Array[Vector2] = [enemy.crowd_lane]
		for step in [1, -1, 2, -2, 3, -3, 4]:
			options.append(enemy.crowd_lane.rotated(step * TAU / 8))
		for offset in options:
			var at: Vector2 = goal + offset
			if arena.navigation.point_clear(at) and MineAwareness.point_clear(at, hazards) and room_for_lane(arena, enemy, at):
				destination = at
				enemy.crowd_lane = offset
				break
	var route: Array[Vector2] = arena.navigation.path(enemy.global_position, destination, hazards, zones)
	# Congestion changes preference, never whether the only corridor is usable.
	if route.is_empty() and destination != goal:
		route = arena.navigation.path(enemy.global_position, goal, hazards, zones)
	return route

static func room_for_lane(arena: Node2D, enemy: DuelTank, at: Vector2) -> bool:
	for other in arena.enemies:
		if other == enemy or not other.alive:
			continue
		if at.distance_to(other.global_position) < PERSONAL_SPACE:
			return false
		if not other.path.is_empty() and at.distance_to(other.path.back()) < PERSONAL_SPACE:
			return false
	return true

static func steer(arena: Node2D, enemy: DuelTank, travel: Vector2, hazards: Array[Vector3]) -> Vector2:
	if travel.length_squared() < 1:
		return travel
	var nearby := neighbors(arena, enemy)
	if nearby.size() < 2:
		return travel
	var push := Vector2.ZERO
	for other in nearby:
		var offset := enemy.global_position - other.global_position
		var distance := offset.length()
		if distance > 0.01 and distance < PERSONAL_SPACE:
			push += offset / distance * (PERSONAL_SPACE - distance)
	if push.is_zero_approx(): return travel
	var direction := (travel.normalized() * 64 + push.limit_length(32)).normalized()
	var at := enemy.global_position + direction * minf(48, travel.length())
	if arena.navigation.point_clear(at) and arena.navigation.segment_clear(enemy.global_position, at, 17.9) and MineAwareness.segment_clear(enemy.global_position, at, hazards):
		return direction * travel.length()
	return travel
