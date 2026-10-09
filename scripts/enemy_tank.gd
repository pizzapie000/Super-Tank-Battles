class_name EnemyTank
extends DuelTank

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

func control_step(delta: float) -> Vector2:
	fire_intent = false
	mine_intent = false
	if not is_instance_valid(arena.player) or not arena.player.alive:
		return Vector2.ZERO
	if invisible_tank:
		cloak_time += delta
		body_opacity = maxf(0.0, 1.0 - cloak_time / 0.8)
	var target: DuelTank = arena.player
	plan_timer -= delta
	path_timer -= delta
	if plan_timer <= 0.0:
		shot_plan = ShotPlanner.solve(global_position, target.global_position, target.velocity if predictive else Vector2.ZERO, shell_speed, arena.wall_rects, ricochets, arena.friendly_positions(self), min_ricochets)
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
	if path_timer <= 0.0:
		path = arena.navigation_path(self, not shot_plan.is_empty())
		path_timer = 0.45
	while not path.is_empty() and global_position.distance_to(path[0]) < 20.0:
		path.pop_front()
	var travel := path[0] - global_position if not path.is_empty() else Vector2.ZERO
	if behavior != "Incautious":
		var evasion: Vector2 = arena.evasion_vector(self)
		if not evasion.is_zero_approx():
			travel = evasion
	if travel.length_squared() < 25.0:
		return Vector2.ZERO
	var turn := angle_difference(rotation, travel.angle())
	return Vector2(clampf(turn * 3.0, -1.0, 1.0), 1.0 if absf(turn) < 0.65 else 0.0)

func wants_fire() -> bool:
	return fire_intent

func aimed_path() -> Dictionary:
	if shot_plan.is_empty() or not is_instance_valid(arena.player) or not arena.player.alive:
		return {}
	var muzzle := global_position + firing_direction() * 31.0
	if min_ricochets > 0 and not ShotPlanner.trace(muzzle, firing_direction(), arena.player.global_position, arena.wall_rects, 0).is_empty():
		return {}
	return ShotPlanner.trace(muzzle, firing_direction(), shot_plan.target, arena.wall_rects, ricochets, arena.friendly_positions(self), min_ricochets)

func wants_mine() -> bool:
	return mine_intent
