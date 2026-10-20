extends RefCounted

static func role(slot: int, crew_size: int, stationary: bool) -> String:
	if crew_size <= 1:
		return "Independent"
	if stationary:
		return "Sentry"
	return ["Assault", "Flank", "Support", "Flank"][slot % 4]

static func usable(arena: Node2D, enemy: EnemyTank, at: Vector2) -> bool:
	if not arena.navigation.point_clear(at):
		return false
	for ally in arena.enemies:
		if ally != enemy and ally.alive and ally.position.distance_to(at) < 65:
			return false
	return true

static func cover_goal(arena: Node2D, enemy: EnemyTank, target: DuelTank) -> Vector2:
	var best := Vector2.INF
	var score := INF
	for wall in arena.navigation.walls:
		if wall.get_center().distance_to(enemy.position) > 480 or wall.size.x > 800 or wall.size.y > 800:
			continue
		for side in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
			var candidate: Vector2 = wall.get_center() + side * (wall.size * 0.5 + Vector2.ONE * 38)
			var distance := candidate.distance_to(target.position)
			if distance < 180 or distance > 650 or not usable(arena, enemy, candidate):
				continue
			# Cover must actually block a direct shot; a tree canopy alone is not cover.
			if arena.navigation.segment_clear(candidate, target.position, 0):
				continue
			var value := enemy.position.distance_to(candidate) + absf(distance - 380) * 0.35
			if value < score and not arena.navigation.path(enemy.position, candidate).is_empty():
				best = candidate
				score = value
	return best

static func goal(arena: Node2D, enemy: EnemyTank, target: DuelTank, has_shot: bool) -> Vector2:
	var goal_at := target.position
	var distance := enemy.position.distance_to(goal_at)
	if enemy.pursuer:
		return goal_at
	if arena.players.size() == 1:
		if (enemy.behavior == "Defensive" and distance < (420 if has_shot else 280)) or (enemy.behavior == "Dynamic" and distance < 240):
			var candidate := enemy.position + (enemy.position - goal_at).normalized() * 120
			if arena.navigation.point_clear(candidate):
				return candidate
		return goal_at
	if enemy.tactical_role == "Flank":
		var angle := float(enemy.tactical_slot % 8) * TAU / 8
		goal_at += Vector2.RIGHT.rotated(angle) * (200 + arena.players.size() * 25)
	elif enemy.tactical_role == "Support":
		var cover := cover_goal(arena, enemy, target)
		if cover.is_finite():
			return cover
		var away := (enemy.position - goal_at).normalized()
		goal_at += away * 350
	else:
		goal_at += Vector2(0, (enemy.tactical_slot % 3 - 1) * 85)
	goal_at = goal_at.clamp(arena.navigation.bounds.position + Vector2.ONE * 40, arena.navigation.bounds.end - Vector2.ONE * 40)
	# The chosen attack lane must be both open and reachable with full tank clearance.
	if usable(arena, enemy, goal_at) and not arena.navigation.path(enemy.position, goal_at).is_empty():
		return goal_at
	var best := goal_at
	var score := INF
	for cell in arena.navigation.points:
		var candidate: Vector2 = arena.navigation.points[cell]
		var value := candidate.distance_squared_to(goal_at)
		if value < score and value < 180 * 180 and usable(arena, enemy, candidate) and not arena.navigation.path(enemy.position, candidate).is_empty():
			best = candidate
			score = value
	return best if score < INF else target.position
