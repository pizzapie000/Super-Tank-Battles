class_name EnemyTank
extends DuelTank

const MineAwareness = preload("res://scripts/enemy_mine_awareness.gd")
const Spacing = preload("res://scripts/enemy_spacing.gd")
var profile: Dictionary = {}
var arena: Node2D
var enemy_name: String = "Brown"
var behavior: String = "Passive"
var aim_speed: float = 1.1
var ricochets: int = 1
var predictive: bool = false
var min_ricochets: int = 0
var invisible_tank: bool = false
var cloak_time: float = 0.0
var plan_timer: float = 0.0
var path_timer: float = 0.0
var shot_plan: Dictionary = {}
var path: Array[Vector2] = []
var fire_intent: bool = false
var mine_intent: bool = false
var aim_target: DuelTank
var motion_position := Vector2.INF
var drive_request: float = 0
var stalled_time: float = 0
var recovery_goal := Vector2.INF
var recovery_time: float = 0
var mine_escape_goal := Vector2.INF
var mine_escape_origin := Vector2.ZERO
var escaping_mine: bool = false
var crowd_time: float = 0
var crowd_traffic: Array[Vector3] = []
var crowd_lane := Vector2.ZERO

func current_target() -> DuelTank:
	if arena.has_method("target_for_enemy"):
		return arena.target_for_enemy(self)
	return arena.player

func configure(type_name: String, battlefield: Node2D) -> void:
	profile = EnemyProfiles.get_profile(type_name)
	arena = battlefield
	enemy_name = type_name
	behavior = profile.behavior
	tint = Color(profile.color)
	identification = profile.marker
	forward_speed = float(profile.move)
	reverse_speed = forward_speed * 0.7
	turn_speed = 3.4 if forward_speed > 150.0 else 2.6
	shell_speed = float(profile.bullet)
	aim_speed = float(profile.aim)
	ricochets = int(profile.ricochets)
	shell_wall_hits = ricochets + 1
	max_shells = int(profile.shots)
	max_mines = int(profile.mines)
	mine_cooldown = 1.0 if type_name == "Yellow" else 3.5
	shot_cooldown = 1.65 if aim_speed < 2.0 else 0.7
	predictive = bool(profile.get("predictive", false))
	min_ricochets = 1 if bool(profile.get("bank_only", false)) else 0
	shell_is_missile = bool(profile.get("missile", false))
	invisible_tank = bool(profile.get("invisible", false))
	separate_turret = true
	plan_timer = randf_range(0.0, 0.35)
	mine_timer = randf_range(1.0, 3.0)
	motion_position = Vector2.INF
	drive_request = 0
	stalled_time = 0
	recovery_goal = Vector2.INF
	recovery_time = 0
	mine_escape_goal = Vector2.INF
	escaping_mine = false
	crowd_time = 0
	crowd_traffic.clear()
	crowd_lane = Vector2.ZERO

func control_step(delta: float) -> Vector2:
	crowd_time = maxf(0, crowd_time - delta)
	fire_intent = false
	mine_intent = false
	var target := current_target()
	if not is_instance_valid(target) or not target.alive:
		return Vector2.ZERO
	if invisible_tank:
		cloak_time += delta
		body_opacity = maxf(0.0, 1.0 - cloak_time / 0.8)
	if target != aim_target:
		aim_target = target
		plan_timer = 0
		path_timer = 0
		crowd_time = 0
		crowd_traffic.clear()
		crowd_lane = Vector2.ZERO
	plan_timer -= delta
	path_timer -= delta
	if plan_timer <= 0.0:
		var aiming_walls: Array[Rect2] = arena.aiming_walls(self, target) if arena.has_method("aiming_walls") else arena.wall_rects
		if arena.has_method("plan_enemy_shot"):
			shot_plan = arena.plan_enemy_shot(self, target, aiming_walls)
		else:
			shot_plan = ShotPlanner.solve(global_position, target.global_position, target.velocity if predictive else Vector2.ZERO, shell_speed, aiming_walls, ricochets, arena.friendly_positions(self), min_ricochets)
		plan_timer = 0.4 if predictive else 0.3
	var aim: float = float(shot_plan.get("angle", (target.global_position - global_position).angle()))
	turret_angle = rotate_toward(turret_angle, aim, aim_speed * delta)
	if not shot_plan.is_empty() and absf(angle_difference(turret_angle, aim)) < 0.055:
		# Recheck the barrel's real path rather than firing through cover or an ally.
		fire_intent = not aimed_path().is_empty()
	var distance := global_position.distance_to(target.global_position)
	mine_intent = max_mines > 0 and distance < (400.0 if enemy_name == "Yellow" else 260.0)
	if forward_speed == 0.0:
		return Vector2.ZERO
	var hazards := MineAwareness.hazards(arena, self)
	observe_motion(delta)
	if escaping_mine:
		fire_intent = false
		mine_intent = false
		if global_position.distance_to(mine_escape_origin) >= 106:
			escaping_mine = false
			path_timer = 0
		else:
			if not mine_escape_goal.is_finite() or test_move(global_transform, mine_escape_goal - global_position) or not MineAwareness.segment_clear(global_position, mine_escape_goal, hazards):
				mine_escape_goal = find_mine_escape(hazards)
			if mine_escape_goal.is_finite():
				return drive_toward(mine_escape_goal - global_position, delta, hazards, true)
			# If another tank blocks the lane after planting, the regular
			# mine-aware pathfinder and corner recovery can find another way out.
	if recovery_goal.is_finite():
		recovery_time -= delta
		if global_position.distance_to(recovery_goal) < 6 or recovery_time <= 0 or not MineAwareness.segment_clear(global_position, recovery_goal, hazards):
			recovery_goal = Vector2.INF
			path_timer = 0
			stalled_time = 0
		else:
			return drive_toward(recovery_goal - global_position, delta, hazards, true)
	if stalled_time >= 0.65:
		recovery_goal = escape_corner(hazards)
		recovery_time = 2.0
		stalled_time = 0
		path.clear()
		path_timer = 0
		if recovery_goal.is_finite():
			return drive_toward(recovery_goal - global_position, delta, hazards, true)
	if path_timer <= 0.0 or (not path.is_empty() and not MineAwareness.segment_clear(global_position, path[0], hazards)):
		path = arena.navigation_path(self, not shot_plan.is_empty())
		# Spread crowded replans over several frames instead of updating the
		# whole wave's weighted paths in the same frame.
		path_timer = 0.45 + float(get_instance_id() % 7) * 0.02
	while not path.is_empty() and global_position.distance_to(path[0]) < 8.0:
		# Reaching a corner early must not cut across the wall on the next leg.
		if path.size() > 1 and (not arena.navigation.segment_clear(global_position, path[1]) or not MineAwareness.segment_clear(global_position, path[1], hazards)):
			break
		path.pop_front()
	var travel := path[0] - global_position if not path.is_empty() else Vector2.ZERO
	travel = Spacing.steer(arena, self, travel, hazards)
	if behavior != "Incautious":
		var evasion: Vector2 = arena.evasion_vector(self)
		if not evasion.is_zero_approx() and MineAwareness.segment_clear(global_position, global_position + evasion.limit_length(80), hazards):
			travel = evasion
	return drive_toward(travel, delta, hazards)

func observe_motion(delta: float) -> void:
	# Judge actual displacement after move_and_slide, rather than requested velocity.
	if motion_position.is_finite() and absf(drive_request) > 0.01:
		var speed := forward_speed if drive_request > 0 else reverse_speed
		var minimum := maxf(0.05, absf(drive_request) * speed * delta * 0.2)
		stalled_time = stalled_time + delta if global_position.distance_to(motion_position) < minimum else 0.0
	else:
		stalled_time = 0
	motion_position = global_position
	drive_request = 0

func escape_corner(hazards: Array[Vector3]) -> Vector2:
	var away := Vector2.ZERO
	for i in range(get_slide_collision_count()):
		away += get_slide_collision(i).get_normal()
	var backwards := -Vector2.RIGHT.rotated(rotation)
	var basis := away.normalized() if not away.is_zero_approx() else backwards
	var best := Vector2.INF
	var score := -INF
	for step in range(8):
		var direction := basis.rotated(step * TAU / 8)
		for distance in [64.0, 48.0, 32.0]:
			var at: Vector2 = global_position + direction * distance
			# The real body sweep includes other tanks as well as walls. Require
			# a safe destination and a mine-free route; never teleport out of cover.
			if test_move(global_transform, direction * distance) or not arena.navigation.point_clear(at):
				continue
			if not arena.navigation.segment_clear(global_position, at, 17.9) or not MineAwareness.segment_clear(global_position, at, hazards):
				continue
			var value: float = direction.dot(basis) * 3 + direction.dot(backwards) + distance * 0.01
			if value > score:
				best = at
				score = value
	return best

func drive_toward(travel: Vector2, delta: float, hazards: Array[Vector3], allow_reverse: bool = false) -> Vector2:
	if travel.length_squared() < 1.0:
		return Vector2.ZERO
	var turn := angle_difference(rotation, travel.angle())
	var drive := 1.0
	if allow_reverse and absf(turn) > PI * 0.5:
		turn = angle_difference(rotation, travel.angle() + PI)
		drive = -1.0
	var heading := rotation + turn_rate_after(clampf(turn * 3, -1, 1), delta) * delta
	var direction := Vector2.RIGHT.rotated(heading) * drive
	var speed := forward_speed if drive > 0 else reverse_speed
	var ahead := global_position + direction * minf(travel.length(), maxf(45, speed * 0.35))
	var safe := MineAwareness.segment_clear(global_position, ahead, hazards)
	if absf(turn) < 0.35 and safe:
		# Avoid overshooting a close corner waypoint. Check the actual heading,
		# since the clear planned segment may differ while the hull is turning.
		var brake_acceleration := maxf(forward_speed, reverse_speed) / maxf(braking_time, 0.01)
		var arrival_speed := sqrt(2 * brake_acceleration * travel.length())
		drive_request = drive * minf(1, arrival_speed / maxf(0.01, speed))
		var step := direction * minf(travel.length(), maxf(12, speed * delta * 3))
		if arena.navigation.segment_clear(global_position, global_position + step, 17.9):
			return Vector2(clampf(turn * 3, -1, 1), drive_request)
	return Vector2(clampf(turn * 3, -1, 1), 0)

func wants_fire() -> bool:
	return fire_intent

func aimed_path() -> Dictionary:
	var target := current_target()
	if shot_plan.is_empty() or not is_instance_valid(target) or not target.alive:
		return {}
	var muzzle := global_position + firing_direction() * 31.0
	if min_ricochets > 0 and not ShotPlanner.trace(muzzle, firing_direction(), target.global_position, arena.wall_rects, 0).is_empty():
		return {}
	return ShotPlanner.trace(muzzle, firing_direction(), shot_plan.target, arena.wall_rects, ricochets, arena.friendly_positions(self), maxi(min_ricochets, int(shot_plan.get("min_bounces", 0))))

func wants_mine() -> bool:
	if not mine_intent or escaping_mine or mine_timer > 0 or active_mines >= max_mines:
		return false
	mine_escape_goal = find_mine_escape(MineAwareness.hazards(arena, self))
	return mine_escape_goal.is_finite()

func register_mine() -> void:
	super.register_mine()
	mine_escape_origin = global_position
	if not mine_escape_goal.is_finite():
		mine_escape_goal = find_mine_escape(MineAwareness.hazards(arena, self))
	escaping_mine = mine_escape_goal.is_finite()
	recovery_goal = Vector2.INF
	path.clear()
	path_timer = 0
	# The escape begins on the next physics tick. Don't shoot the mine under
	# our own barrel or lay another until outside the full blast area.
	fire_intent = false

func find_mine_escape(hazards: Array[Vector3]) -> Vector2:
	var acceleration := maxf(forward_speed, reverse_speed) / maxf(acceleration_time, 0.01)
	for angle in [0.0, 0.2, -0.2, PI, PI + 0.2, PI - 0.2]:
		var direction := Vector2.RIGHT.rotated(rotation + angle)
		var speed := forward_speed if absf(angle) < PI / 2 else reverse_speed
		# Leave the proximity trigger before the 0.75-second arming time, with
		# a margin for acceleration. Slow tanks wait for a forward escape lane.
		if speed <= 0 or 46 / speed + speed / (2 * maxf(acceleration, 0.01)) > 0.7:
			continue
		if not escaping_mine and velocity.dot(direction) < -forward_speed * 0.1:
			continue
		var destination := global_position + direction * 130
		if test_move(global_transform, direction * 130) or not arena.navigation.point_clear(destination):
			continue
		if arena.navigation.segment_clear(global_position, destination, 17.9) and MineAwareness.segment_clear(global_position, destination, hazards):
			return destination
	return Vector2.INF
