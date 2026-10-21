extends "res://scripts/duel_arena.gd"

const ControllerInput = preload("res://scripts/input/controller_input.gd")
const ControlHints = preload("res://scripts/input/control_hints.gd")

const Session = preload("res://scripts/pvp/duel_session.gd")
const PvpTankScene = preload("res://scenes/tanks/PvpTank.tscn")
const PvpTank = preload("res://scripts/pvp/pvp_tank.gd")
const Pickup = preload("res://scripts/pvp/weapon_pickup.gd")
const FIRST_PICKUP_TIME: float = 5.0
const PICKUP_INTERVAL: float = 7.0
const MAX_PICKUPS: int = 3
@export var check_devices: bool = true
var round_elapsed: float = 0
var pickup_timer: float = FIRST_PICKUP_TIME
var pickups: Array[Node2D] = []
var weapon_order: Array[String] = []
var first_pickup_wave: bool = true
var controls_button: Button
var missing_controller: bool = false

func _ready() -> void:
	super._ready()
	controls_button = Button.new()
	controls_button.text = "PLAYER SETUP / MAIN MENU"
	controls_button.position = Vector2(440, 555)
	controls_button.size = Vector2(400, 50)
	controls_button.hide()
	controls_button.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/game/MainMenu.tscn"))
	pause_guide_layer.add_child(controls_button)
	ControllerInput.connect_changes(connection_changed)
	check_controller_connections()

func create_duel_tank() -> DuelTank:
	return PvpTankScene.instantiate()

func start_round() -> void:
	for pickup in pickups:
		if is_instance_valid(pickup): pickup.free()
	pickups.clear()
	round_elapsed = 0
	pickup_timer = FIRST_PICKUP_TIME
	first_pickup_wave = true
	weapon_order.assign(["gatling", "shotgun", "homing"])
	weapon_order.shuffle()
	super.start_round()
	for i in range(tanks.size()):
		tanks[i].configure_input(Session.devices[i])
	check_controller_connections()

func _process(delta: float) -> void:
	var battle_delta := maxf(0, delta - countdown) if countdown > 0 else delta
	super._process(delta)
	check_controller_connections()
	if active and not paused and not field_guide_input_blocked():
		update_pickups(battle_delta)

func update_pickups(delta: float) -> void:
	round_elapsed += delta
	for pickup in pickups.duplicate():
		pickup.age += delta
		if pickup.age >= Pickup.LIFETIME:
			remove_pickup(pickup)
			continue
		pickup.queue_redraw()
		var collector: DuelTank
		var nearest: float = 30.0
		for tank in tanks:
			var distance := tank.position.distance_to(pickup.position)
			if tank.alive and distance < nearest:
				collector = tank
				nearest = distance
		if collector != null:
			collector.equip_weapon(pickup.weapon_kind)
			burst(pickup.position, PvpTank.WEAPONS[pickup.weapon_kind].color, false)
			remove_pickup(pickup)
	pickup_timer -= delta
	if pickup_timer <= 0.00001:
		for i in range(2 if first_pickup_wave else 1):
			if pickups.size() < MAX_PICKUPS: spawn_pickup()
		first_pickup_wave = false
		pickup_timer = PICKUP_INTERVAL

func spawn_pickup() -> Node2D:
	var candidates: Array[Vector2] = []
	for y in range(ROWS):
		for x in range(COLS):
			var point := BOARD.position + (Vector2(x, y) + Vector2.ONE * 0.5) * CELL
			if not pickup_position_clear(point): continue
			candidates.append(point)
	if candidates.is_empty():
		return null
	var pickup := Pickup.new()
	pickup.weapon_kind = weapon_order.pop_front()
	weapon_order.append(pickup.weapon_kind)
	pickup.position = candidates.pick_random()
	# Clear with round effects, while placing the crate above ground impressions.
	pickup.z_index = 1
	$Effects.add_child(pickup)
	pickups.append(pickup)
	return pickup

func pickup_position_clear(point: Vector2) -> bool:
	if not BOARD.grow(-26).has_point(point): return false
	for wall in wall_rects:
		if wall.grow(26).has_point(point): return false
	for tank in tanks:
		if tank.alive and point.distance_to(tank.position) < 95: return false
	for pickup in pickups:
		if point.distance_to(pickup.position) < 110: return false
	return true

func remove_pickup(pickup: Node2D) -> void:
	pickups.erase(pickup)
	pickup.get_parent().remove_child(pickup)
	pickup.queue_free()

func fire_shell(tank: DuelTank) -> void:
	if not active or paused or not tank.alive or tank.active_shells >= tank.max_shells:
		return
	if tank.weapon_kind.is_empty():
		super.fire_shell(tank)
		return
	var kind: String = tank.weapon_kind
	var direction := tank.firing_direction()
	var fired := 0
	if kind == "shotgun":
		if tank.max_shells - tank.active_shells < 5: return
		for pellet in range(-2, 3):
			# Adjacent muzzles start over two shell radii apart. Pellets fan out
			# without colliding at birth; every shot remains fully damageable.
			var shell := launch_shell(tank, direction.rotated(pellet * 0.15), -direction.orthogonal() * pellet * 4, false)
			if shell != null: fired += 1
	else:
		var shell := launch_shell(tank, direction, Vector2.ZERO, false)
		if shell != null:
			fired = 1
			if kind == "homing":
				shell.is_missile = true
				shell.homing_targets.assign(tanks)
				shell.homing_turn_rate = 1.8
	if fired > 0:
		tank.spend_weapon_ammo()
		play_sound(SHOOT, -21 if kind == "gatling" else -17, 0.78 if kind == "shotgun" else 1.15)

func set_duel_paused(value: bool) -> void:
	paused = value
	set_controls(active and not paused)
	for shell in $Shells.get_children():
		shell.flight_enabled = active and not paused
	set_pause_menu_visible(paused)
	queue_redraw()
	$Overlay.queue_redraw()

func check_controller_connections() -> void:
	missing_controller = false
	if check_devices:
		for device in Session.devices:
			if device >= 0 and not ControllerInput.connected_devices().has(device):
				missing_controller = true
	if missing_controller and not paused and not match_finished:
		set_duel_paused(true)

func connection_changed(_device: int, _connected: bool) -> void:
	check_controller_connections()

func set_pause_menu_visible(shown: bool) -> void:
	super.set_pause_menu_visible(shown)
	if is_instance_valid(controls_button): controls_button.visible = shown

func _input(event: InputEvent) -> void:
	if field_guide_input_blocked(): return
	if event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_START and Session.devices.has(event.device):
		if match_finished:
			scores.assign([0, 0])
			round_number = 0
			start_round()
		elif not missing_controller:
			set_duel_paused(not paused)
		get_viewport().set_input_as_handled()

func duel_control_hint(index: int) -> String:
	var device: int = Session.devices[index]
	if not ControlHints.active_devices([device]).has(device): return "Reconnect this player's assigned control."
	if ControllerInput.is_wii(device): return "NUNCHUK  drive   POINT  aim   B  fire"
	if device >= 0: return "L stick  drive   R stick  aim   RT / RB  fire"
	if device == Session.KEYBOARD: return "WASD / ARROWS  drive   MOUSE  aim   CLICK  fire"
	return super.duel_control_hint(index)

func duel_footer_hint() -> String:
	var devices := ControlHints.active_devices(Session.devices)
	if devices.is_empty(): return "Reconnect your assigned controls, or use Player Setup in the main menu."
	var result := ControlHints.buttons("pause", devices) + " pause"
	if devices.any(func(device): return device >= 0): result += " · " + ControlHints.buttons("pause", devices.filter(func(device): return device >= 0)) + " rematch"
	if devices.any(func(device): return device < 0): result += " · R new arena · ENTER rematch · BACKSPACE menu"
	return result

func duel_resume_hint() -> String:
	var buttons := ControlHints.buttons("pause", Session.devices)
	return buttons + " to resume" if not buttons.is_empty() else "Reconnect your assigned control to resume."

func duel_rematch_hint() -> String:
	var choices: Array[String] = []
	var devices := ControlHints.active_devices(Session.devices)
	if devices.any(func(device): return device < 0): choices.append("ENTER")
	var pads: Array = devices.filter(func(device): return device >= 0)
	if not pads.is_empty(): choices.append(ControlHints.buttons("pause", pads))
	return " / ".join(choices) + " for a rematch" if not choices.is_empty() else "Reconnect your assigned control for a rematch."

func draw_duel_weapon(tank: DuelTank, left: float) -> void:
	if tank.weapon_kind.is_empty():
		super.draw_duel_weapon(tank, left)
		return
	var weapon: Dictionary = PvpTank.WEAPONS[tank.weapon_kind]
	var units := "BLASTS" if tank.weapon_kind == "shotgun" else ("MISSILES" if tank.weapon_kind == "homing" else "ROUNDS")
	text_at("%s   %d %s" % [weapon.title, tank.weapon_ammo, units], Vector2(left, 740), 14, weapon.color)

func duel_round_hint() -> String:
	if round_elapsed < FIRST_PICKUP_TIME:
		return "WEAPON CRATES IN %.1f s" % (FIRST_PICKUP_TIME - round_elapsed)
	return "DRIVE OVER A WEAPON CRATE TO EQUIP IT"

func duel_rules_hint() -> String:
	return "Pickups replace your weapon. Limited ammo; then normal shells return. Every shot can hit you."

func draw_overlay() -> void:
	super.draw_overlay()
	if paused and missing_controller:
		$Overlay.draw_rect(Rect2(300, 417, 680, 40), Color(0.04, 0.08, 0.12, 1))
		var message := "Controller disconnected. Reconnect, then resume."
		var width := font.get_string_size(message, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		$Overlay.draw_string(font, Vector2(640 - width / 2, 439), message, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("ffdc81"))
