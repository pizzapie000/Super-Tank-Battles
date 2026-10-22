extends DuelTank

const ControllerInput = preload("res://scripts/input/controller_input.gd")

const Parts = preload("res://scripts/story/upgrade_parts.gd")
var device: int = -1
var armor: int = 3
var max_armor: int = 3
var equipped_part: String = ""
var part_level: int = 0
var part_cooldown: float = 0
var invulnerable: bool = false
var hit_cooldown: float = 0
var revive_progress: float = 0
var moved_distance: float = 0
var total_shots: int = 0
var total_mines: int = 0
var fire_held: bool = false
var mine_held: bool = false
var was_mine_held: bool = false
var interact_held: bool = false
var repair_held: bool = false
var repair_progress: float = 0
var repairing: bool = false
var repair_needs_release: bool = false
var battlefield: Node2D

func _physics_process(delta: float) -> void:
	if controls_enabled:
		hit_cooldown = maxf(0, hit_cooldown - delta)
		part_cooldown = maxf(0, part_cooldown - delta)
	var before := position
	super._physics_process(delta)
	if is_instance_valid(battlefield) and not battlefield.party_position_allowed(self, position, before):
		position = before
		stop_motion()
	moved_distance += position.distance_to(before)
	queue_redraw()

func control_step(delta: float) -> Vector2:
	var drive := Vector2.ZERO
	var shared_control := Vector2.ZERO
	repairing = false
	if device in [-2, -3]:
		var prefix := "p1_" if device == -2 else "p2_"
		separate_turret = false
		fire_held = Input.is_action_pressed(prefix + "fire")
		mine_held = Input.is_physical_key_pressed(KEY_G if device == -2 else KEY_SLASH)
		interact_held = Input.is_physical_key_pressed(KEY_H if device == -2 else KEY_PERIOD)
		repair_held = Input.is_physical_key_pressed(KEY_T if device == -2 else KEY_COMMA)
		shared_control = Vector2(Input.get_axis(prefix + "left", prefix + "right"), Input.get_axis(prefix + "back", prefix + "forward"))
	elif device == -1:
		drive = Vector2(float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)), float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
		turret_angle = (get_global_mouse_position() - global_position).angle()
		fire_held = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_physical_key_pressed(KEY_SPACE)
		mine_held = Input.is_physical_key_pressed(KEY_E)
		interact_held = Input.is_physical_key_pressed(KEY_F)
		repair_held = Input.is_physical_key_pressed(KEY_R)
	else:
		drive = ControllerInput.movement(device)
		var aim = ControllerInput.aim(device, self)
		if aim != null:
			turret_angle = (aim - global_position).angle()
		fire_held = ControllerInput.axis(device, JOY_AXIS_TRIGGER_RIGHT) > 0.25 or ControllerInput.button(device, JOY_BUTTON_RIGHT_SHOULDER)
		mine_held = ControllerInput.button(device, ControllerInput.mine_button(device))
		interact_held = ControllerInput.button(device, ControllerInput.interact_button(device))
		repair_held = ControllerInput.button(device, JOY_BUTTON_Y)
	if not repair_held:
		repair_progress = 0
		repair_needs_release = false
	elif not repair_needs_release and is_instance_valid(battlefield) and battlefield.can_field_repair(self):
		repairing = true
		interact_held = false
		repair_progress += delta
		if repair_progress >= 2:
			battlefield.field_repair(self)
			repair_progress = 0
			repair_needs_release = true
		return Vector2.ZERO
	else:
		repair_progress = 0
	return shared_control if device in [-2, -3] else directional_control(drive)

func desired_velocity(drive: float) -> Vector2:
	if device in [-2, -3]: return Vector2.RIGHT.rotated(rotation) * drive * (forward_speed if drive > 0 else reverse_speed)
	# Keep WASD and the left stick relative to the world. The chassis catches up
	# with the requested heading while momentum blends into the new direction.
	return drive_direction * drive * forward_speed

func movement_locked() -> bool:
	return repairing

func wants_fire() -> bool:
	return fire_held and not repairing

func wants_mine() -> bool:
	var pressed := mine_held and not was_mine_held
	was_mine_held = mine_held
	return pressed and not repairing

func cancel_repair() -> void:
	repair_progress = 0
	repairing = false

func register_shot() -> void:
	super.register_shot()
	total_shots += 1

func register_mine() -> void:
	super.register_mine()
	total_mines += 1

func take_hit() -> void:
	take_shell_hit(1)

func take_shell_hit(damage: int) -> void:
	if not alive or invulnerable or hit_cooldown > 0:
		return
	armor -= damage
	hit_cooldown = 0.8
	if device >= 0:
		ControllerInput.rumble(device, 0.25, 0.6, 0.15)
	if armor <= 0:
		cancel_repair()
		alive = false
		controls_enabled = false
		stop_motion()
		collision_layer = 0
		destroyed.emit(self)

func revive(at: Vector2) -> void:
	cancel_repair()
	stop_motion()
	position = at
	armor = max_armor
	alive = true
	visible = true
	collision_layer = 2
	controls_enabled = true
	revive_progress = 0
	hit_cooldown = 1.5

func restore_health(value: int) -> void:
	cancel_repair()
	stop_motion()
	armor = clampi(value, 0, max_armor)
	alive = armor > 0
	controls_enabled = alive
	collision_layer = 2 if alive else 0
	revive_progress = 0
	queue_redraw()

func equip_part(part: String, level: int = 1) -> void:
	if not Parts.TYPES.has(part):
		return
	var lost_armor := max_armor - armor
	equipped_part = part
	part_level = clampi(level, 1, Parts.MAX_LEVEL) if not part.is_empty() else 0
	var rank := maxi(0, part_level - 1)
	max_armor = 3
	forward_speed = 150
	reverse_speed = 110
	shot_cooldown = 0.32
	shell_wall_hits = 2
	ricochet_bonus_damage = 0
	max_shells = 5
	shell_speed = 300
	shell_is_missile = false
	match part:
		"Loader":
			shot_cooldown = 0.22 - rank * 0.035
		"Armor":
			max_armor = 4 + rank
			forward_speed = 135
			reverse_speed = 99
		"Bank Shot":
			shell_wall_hits = 3 + rank
			ricochet_bonus_damage = 1 + rank
		"Engine":
			max_armor = 2
			forward_speed = 185 + rank * 15
			reverse_speed = 140 + rank * 10
	Parts.weapon_stats(self, part, part_level)
	armor = clampi(max_armor - lost_armor, 1, max_armor) if alive else 0
	queue_redraw()

func _draw() -> void:
	if not alive:
		draw_circle(Vector2.ZERO, 25, Color(tint, 0.2))
		draw_arc(Vector2.ZERO, 25, -PI / 2, -PI / 2 + TAU * revive_progress / 2.0, 32, Color.WHITE, 3)
		draw_line(Vector2(-7, 0), Vector2(7, 0), Color.WHITE, 4)
		draw_line(Vector2(0, -7), Vector2(0, 7), Color.WHITE, 4)
		return
	super._draw()
	if repairing:
		draw_set_transform(Vector2.ZERO, -rotation)
		draw_arc(Vector2.ZERO, 29, -PI / 2, -PI / 2 + TAU * minf(1, repair_progress / 2), 40, Color("7cf4bc"), 4)
		draw_string(ThemeDB.fallback_font, Vector2(-37, -38), "REPAIRING", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("7cf4bc"))
		draw_set_transform(Vector2.ZERO)
	if hit_cooldown > 0:
		draw_arc(Vector2.ZERO, 26, 0, TAU, 32, Color(1, 1, 1, 0.3 + sin(hit_cooldown * 30) * 0.2), 2)
