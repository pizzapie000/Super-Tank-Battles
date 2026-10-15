extends DuelTank

const Parts = preload("res://scripts/story/upgrade_parts.gd")
var device: int = -1
var armor: int = 3
var max_armor: int = 3
var equipped_part: String = ""
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
var battlefield: Node2D

func _physics_process(delta: float) -> void:
	if controls_enabled:
		hit_cooldown = maxf(0, hit_cooldown - delta)
		part_cooldown = maxf(0, part_cooldown - delta)
	var before := position
	super._physics_process(delta)
	if is_instance_valid(battlefield) and not battlefield.party_position_allowed(self, position, before):
		position = before
		velocity = Vector2.ZERO
	moved_distance += position.distance_to(before)
	queue_redraw()

func control_step(delta: float) -> Vector2:
	var drive := Vector2.ZERO
	if device < 0:
		drive = Vector2(float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)), float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
		turret_angle = (get_global_mouse_position() - global_position).angle()
		fire_held = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_physical_key_pressed(KEY_SPACE)
		mine_held = Input.is_physical_key_pressed(KEY_E)
		interact_held = Input.is_physical_key_pressed(KEY_F)
	else:
		drive = StorySession.stick(Vector2(Input.get_joy_axis(device, JOY_AXIS_LEFT_X), Input.get_joy_axis(device, JOY_AXIS_LEFT_Y)))
		var aim := StorySession.stick(Vector2(Input.get_joy_axis(device, JOY_AXIS_RIGHT_X), Input.get_joy_axis(device, JOY_AXIS_RIGHT_Y)))
		if not aim.is_zero_approx():
			turret_angle = aim.angle()
		fire_held = Input.get_joy_axis(device, JOY_AXIS_TRIGGER_RIGHT) > 0.25 or Input.is_joy_button_pressed(device, JOY_BUTTON_RIGHT_SHOULDER)
		mine_held = Input.is_joy_button_pressed(device, JOY_BUTTON_B)
		interact_held = Input.is_joy_button_pressed(device, JOY_BUTTON_A)
	if drive.length() > 0.01:
		rotation = drive.angle()
		return Vector2(0, drive.limit_length().length())
	return Vector2.ZERO

func wants_fire() -> bool:
	return fire_held

func wants_mine() -> bool:
	var pressed := mine_held and not was_mine_held
	was_mine_held = mine_held
	return pressed

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
		Input.start_joy_vibration(device, 0.25, 0.6, 0.15)
	if armor <= 0:
		alive = false
		controls_enabled = false
		velocity = Vector2.ZERO
		collision_layer = 0
		destroyed.emit(self)

func revive(at: Vector2) -> void:
	position = at
	armor = max_armor
	alive = true
	visible = true
	collision_layer = 2
	controls_enabled = true
	revive_progress = 0
	hit_cooldown = 1.5

func equip_part(part: String) -> void:
	if not Parts.TYPES.has(part):
		return
	var lost_armor := max_armor - armor
	equipped_part = part
	max_armor = 3
	forward_speed = 150
	reverse_speed = 110
	shot_cooldown = 0.32
	shell_wall_hits = 2
	ricochet_bonus_damage = 0
	match part:
		"Loader":
			shot_cooldown = 0.22
		"Armor":
			max_armor = 4
			forward_speed = 135
			reverse_speed = 99
		"Bank Shot":
			shell_wall_hits = 3
			ricochet_bonus_damage = 1
		"Engine":
			max_armor = 2
			forward_speed = 185
			reverse_speed = 140
	armor = clampi(max_armor - lost_armor, 1, max_armor)
	queue_redraw()

func _draw() -> void:
	if not alive:
		draw_circle(Vector2.ZERO, 25, Color(tint, 0.2))
		draw_arc(Vector2.ZERO, 25, -PI / 2, -PI / 2 + TAU * revive_progress / 2.0, 32, Color.WHITE, 3)
		draw_line(Vector2(-7, 0), Vector2(7, 0), Color.WHITE, 4)
		draw_line(Vector2(0, -7), Vector2(0, 7), Color.WHITE, 4)
		return
	super._draw()
	if hit_cooldown > 0:
		draw_arc(Vector2.ZERO, 26, 0, TAU, 32, Color(1, 1, 1, 0.3 + sin(hit_cooldown * 30) * 0.2), 2)
