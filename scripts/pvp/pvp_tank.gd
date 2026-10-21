extends DuelTank

const ControllerInput = preload("res://scripts/input/controller_input.gd")

const Session = preload("res://scripts/pvp/duel_session.gd")
const WEAPONS: Dictionary = {
	"gatling": {"title": "GATLING", "ammo": 36, "cooldown": 0.10, "cap": 16, "speed": 360.0, "color": Color("ffdc54")},
	"shotgun": {"title": "SHOTGUN", "ammo": 5, "cooldown": 0.65, "cap": 20, "speed": 320.0, "color": Color("ff5cb6")},
	"homing": {"title": "HEAT SEEKER", "ammo": 3, "cooldown": 0.85, "cap": 5, "speed": 260.0, "color": Color("51edcf")},
}
var device: int = Session.SHARED_LEFT
var weapon_kind: String = ""
var weapon_ammo: int = 0

func configure_input(assigned_device: int) -> void:
	device = assigned_device
	campaign_controls = device >= Session.KEYBOARD
	separate_turret = campaign_controls
	if campaign_controls:
		turn_speed = 6.0
		turret_angle = rotation

func control_step(delta: float) -> Vector2:
	if device < Session.KEYBOARD:
		var prefix := "p1_" if device == Session.SHARED_LEFT else "p2_"
		return Vector2(Input.get_axis(prefix + "left", prefix + "right"), Input.get_axis(prefix + "back", prefix + "forward"))
	if device == Session.KEYBOARD:
		turret_angle = (get_global_mouse_position() - global_position).angle()
		return directional_control(Input.get_vector("solo_left", "solo_right", "solo_forward", "solo_back"))
	var drive := StorySession.stick(Vector2(ControllerInput.axis(device, JOY_AXIS_LEFT_X), ControllerInput.axis(device, JOY_AXIS_LEFT_Y)))
	var aim = ControllerInput.aim(device, self)
	if aim != null:
		turret_angle = (aim - global_position).angle()
	return directional_control(drive)

func wants_fire() -> bool:
	if device < Session.KEYBOARD:
		return Input.is_action_pressed("p1_fire" if device == Session.SHARED_LEFT else "p2_fire")
	if device == Session.KEYBOARD:
		return Input.is_action_pressed("solo_fire")
	return ControllerInput.axis(device, JOY_AXIS_TRIGGER_RIGHT) > 0.25 or ControllerInput.button(device, JOY_BUTTON_RIGHT_SHOULDER)

func wants_mine() -> bool:
	return false

func equip_weapon(kind: String) -> void:
	if not WEAPONS.has(kind):
		return
	weapon_kind = kind
	weapon_ammo = int(WEAPONS[kind].ammo)
	apply_weapon_stats()
	cooldown = maxf(cooldown, 0.15)
	queue_redraw()

func spend_weapon_ammo() -> void:
	weapon_ammo = maxi(0, weapon_ammo - 1)
	if weapon_ammo == 0:
		weapon_kind = ""
		apply_weapon_stats()
	queue_redraw()

func apply_weapon_stats() -> void:
	shot_cooldown = float(WEAPONS[weapon_kind].cooldown) if not weapon_kind.is_empty() else 0.32
	max_shells = int(WEAPONS[weapon_kind].cap) if not weapon_kind.is_empty() else 5
	shell_speed = float(WEAPONS[weapon_kind].speed) if not weapon_kind.is_empty() else 300.0

func _draw() -> void:
	super._draw()
	if alive and not weapon_kind.is_empty():
		draw_arc(Vector2.ZERO, 26, -PI * 0.7, PI * 0.7, 28, Color(WEAPONS[weapon_kind].color, 0.75), 2.0, true)
