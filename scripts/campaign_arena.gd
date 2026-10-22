extends "res://scripts/duel_arena.gd"

const EnemyScene = preload("res://scenes/tanks/EnemyTank.tscn")
const MineScript = preload("res://scripts/tank_mine.gd")
const NavigationScript = preload("res://scripts/mission_navigation.gd")
const ControllerInput = preload("res://scripts/input/controller_input.gd")
const ControlHints = preload("res://scripts/input/control_hints.gd")
const MissionTank = preload("res://scenes/tanks/MissionTank.tscn")

@export_range(0, 50) var mission_override: int = 0
var external_layout: Node2D
var navigation = NavigationScript.new()

var mission: int = 1
var lives: int = 3
var player: DuelTank
var enemies: Array[EnemyTank] = []
var outcome: String = ""
var save_progress: bool = true
var debug_mode: bool = false
var mission_picker: Control
var debug_mission_button: Button
var check_devices := true
var player_device := -1
var missing_controller := false
var controller_menu: Control
var controller_root: Control

func _ready() -> void:
	font = ThemeDB.fallback_font
	$Overlay.draw.connect(draw_overlay)
	setup_pause_guide()
	mission = mission_override if mission_override > 0 else CampaignProgress.selected_mission
	debug_mode = mission_override == 0 and CampaignProgress.debug_mission > 0
	if debug_mode:
		mission = clampi(CampaignProgress.debug_mission, 1, 50)
		save_progress = false
		debug_mission_button = Button.new()
		debug_mission_button.text = "DEBUG MISSIONS"
		debug_mission_button.position = Vector2(440, 555)
		debug_mission_button.size = Vector2(400, 50)
		debug_mission_button.pressed.connect(show_debug_missions)
		pause_guide_layer.add_child(debug_mission_button)
	mine_collisions = true
	player_device = PlayerSetup.device(0)
	controller_root = Control.new()
	controller_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	controller_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pause_guide_layer.add_child(controller_root)
	pause_guide_button.reparent(controller_root)
	if is_instance_valid(debug_mission_button): debug_mission_button.reparent(controller_root)
	var return_to_game := func():
		if paused and not missing_controller: set_mission_paused(false)
	preload("res://scripts/input/wii_menu.gd").attach(controller_root, return_to_game, [player_device], Callable(), func(): return (paused or not outcome.is_empty()) and not field_guide_input_blocked())
	ControllerInput.connect_changes(controller_changed)
	start_round()

func _process(delta: float) -> void:
	if check_devices and (player_device < -3 or (player_device >= 0 and not ControllerInput.connected_devices().has(player_device))) and not paused:
		missing_controller = true
		set_mission_paused(true)
	if field_guide_input_blocked():
		return
	if Input.is_action_just_pressed("return_menu"):
		get_tree().change_scene_to_file("res://scenes/game/MainMenu.tscn")
		return
	if Input.is_action_just_pressed("pause_game") and outcome.is_empty():
		if not missing_controller: set_mission_paused(not paused)
	if not outcome.is_empty() and Input.is_action_just_pressed("rematch"):
		if outcome == "clear" and mission < 50:
			mission += 1
		elif debug_mode and (outcome == "complete" or lives <= 0):
			lives = 3
		elif outcome == "complete" or lives <= 0:
			mission = 1
			lives = 3
		start_round()
	if not paused:
		elapsed += delta
		if countdown > 0.0:
			countdown = maxf(0.0, countdown - delta)
			if countdown <= 0.0:
				active = true
				set_controls(true)
				freeze_ordnance(false)
	queue_redraw()
	$Overlay.queue_redraw()

func start_round() -> void:
	close_debug_missions()
	close_field_guide()
	set_pause_menu_visible(false)
	for container in [$Walls, $Tanks, $Shells, $Mines, $Effects]:
		for child in container.get_children():
			container.remove_child(child)
			child.queue_free()
	tanks.clear()
	mine_walls.clear()
	enemies.clear()
	wall_rects.clear()
	outcome = ""
	banner = ""
	active = false
	paused = false
	resolution_pending = false
	countdown = 1.6
	var layout: Node2D = external_layout
	var temporary_layout := false
	if layout == null or layout.mission_number != mission:
		layout = load("res://scenes/levels/missions/Mission%02d.tscn" % mission).instantiate()
		temporary_layout = true
	for rect in layout.boundary_rectangles():
		add_wall(rect)
	for piece in layout.find_children("*", "", true, false):
		if piece.has_method("break_from_mine"):
			var wall = piece.duplicate()
			wall.position = piece.global_position
			wall.restore_mine_wall()
			$Walls.add_child(wall)
			wall.activate()
			mine_walls.append(wall)
			wall_rects.append(wall.wall_rect())
		elif piece.has_method("wall_rect"):
			add_wall(piece.wall_rect())
	rebuild_navigation()
	player = MissionTank.instantiate()
	player.configure_input(player_device)
	player.name = "Player"
	player.player_index = 0
	player.campaign_controls = player_device >= -1
	# Match the True Campaign crew's directional steering and hull response.
	player.turn_speed = 6.0 if player_device >= -1 else 2.6
	player.separate_turret = player_device >= -1
	player.tint = COLORS[0]
	player.max_mines = 2
	player.mine_cooldown = 1.2
	# One ricochet means surviving the first wall and breaking on the second.
	player.shell_wall_hits = 2
	player.position = layout.get_node("PlayerSpawn").global_position
	player.rotation = layout.get_node("PlayerSpawn").global_rotation
	connect_tank(player)
	for marker in layout.enemy_spawns():
		var enemy: EnemyTank = EnemyScene.instantiate()
		enemy.configure(marker.tank_type, self)
		enemy.position = marker.global_position
		enemy.rotation = marker.global_rotation
		enemy.turret_angle = (player.position - enemy.position).angle()
		connect_tank(enemy)
		enemies.append(enemy)
	if temporary_layout:
		layout.free()
	if enemies.is_empty():
		resolve_round.call_deferred()
	refresh_controller_menu()

func next_mission() -> void:
	if outcome == "clear" and mission < 50: mission += 1
	elif outcome == "complete" or lives <= 0:
		if not debug_mode: mission = 1
		lives = 3
	start_round()

func set_mission_paused(value: bool) -> void:
	paused = value
	set_controls(active and not paused)
	freeze_ordnance(paused or not active)
	set_pause_menu_visible(paused)
	refresh_controller_menu()

func set_controls(enabled: bool) -> void:
	# A used to select Resume/Continue must be released before it can place a mine.
	if enabled and is_instance_valid(player) and not player.controls_enabled and ControllerInput.is_wii(player_device):
		player.set("was_mine_held", ControllerInput.button(player_device, ControllerInput.mine_button(player_device)))
	super.set_controls(enabled)

func refresh_controller_menu() -> void:
	if is_instance_valid(controller_menu):
		controller_menu.get_parent().remove_child(controller_menu)
		controller_menu.queue_free()
	controller_menu = null
	if not paused and outcome.is_empty(): return
	controller_menu = VBoxContainer.new()
	controller_menu.position = Vector2(440, 480)
	controller_menu.size.x = 400
	controller_menu.add_theme_constant_override("separation", 8)
	ensure_guide_layer()
	controller_root.add_child(controller_menu)
	var options: Dictionary = {"RESUME" if outcome.is_empty() else "NEXT / RETRY": func(): set_mission_paused(false) if outcome.is_empty() else next_mission(), "PLAYER SETUP / MAIN MENU": func(): get_tree().change_scene_to_file("res://scenes/game/MainMenu.tscn")}
	for title in options:
		var button := Button.new()
		button.text = title
		button.custom_minimum_size.y = 42
		button.disabled = missing_controller and title == "RESUME"
		button.pressed.connect(options[title])
		controller_menu.add_child(button)
	pause_guide_button.position.y = 590
	if is_instance_valid(debug_mission_button): debug_mission_button.position.y = 640
	for button in controller_menu.get_children():
		if button is Button and not button.disabled: button.grab_focus(); break

func controller_changed(_device: int, _connected: bool) -> void:
	var resolved := PlayerSetup.device(0)
	if resolved >= -3 and resolved != PlayerSetup.OFF:
		player_device = resolved
		if is_instance_valid(player): player.configure_input(player_device)
	missing_controller = player_device >= 0 and not ControllerInput.connected_devices().has(player_device)
	controller_root.get_node("WiiMenu").allowed_devices.assign([player_device])
	if paused: refresh_controller_menu()

func show_field_guide() -> void:
	super.show_field_guide()
	if is_instance_valid(field_guide):
		field_guide.allowed_devices.assign([player_device])
		field_guide.get_node("WiiMenu").allowed_devices.assign([player_device])

func _input(event: InputEvent) -> void:
	if field_guide_input_blocked(): return
	if event is InputEventJoypadButton and event.pressed and event.device == player_device:
		if event.button_index == JOY_BUTTON_START:
			if not outcome.is_empty(): next_mission()
			elif not missing_controller: set_mission_paused(not paused)
			get_viewport().set_input_as_handled()
		elif event.button_index == JOY_BUTTON_A and not outcome.is_empty():
			next_mission()
			get_viewport().set_input_as_handled()

func rebuild_navigation() -> void:
	navigation.build(wall_rects)
	# Keep coarse cell links for defensive tactics and maze inspection, while
	# movement itself uses the finer graph built from the edited wall geometry.
	passages.clear()
	for y in range(ROWS):
		for x in range(COLS):
			var cell := Vector2i(x, y)
			for direction in [Vector2i.RIGHT, Vector2i.DOWN]:
				var next: Vector2i = cell + direction
				if valid_cell(next) and navigation.segment_clear(cell_center(cell), cell_center(next)):
					passages[edge_key(cell, next)] = true

func connect_tank(tank: DuelTank) -> void:
	tank.shot_requested.connect(fire_shell)
	tank.mine_requested.connect(drop_mine)
	tank.destroyed.connect(tank_destroyed)
	$Tanks.add_child(tank)
	tanks.append(tank)

func freeze_ordnance(frozen: bool) -> void:
	for shell in $Shells.get_children():
		shell.flight_enabled = not frozen
	for mine in $Mines.get_children():
		mine.frozen = frozen

func drop_mine(tank: DuelTank) -> void:
	if not active or paused or not tank.alive or tank.mine_timer > 0.0 or tank.active_mines >= tank.max_mines:
		return
	for existing in $Mines.get_children():
		if existing.position.distance_to(tank.position) < 28.0:
			return
	var mine: TankMine = MineScript.new()
	mine.position = tank.position
	mine.owner_tank = tank
	mine.arena = self
	mine.exploded.connect(mine_exploded)
	tank.register_mine()
	$Mines.add_child(mine)
	play_sound(SHOOT, -25.0, 0.55)

func mine_exploded(point: Vector2) -> void:
	burst(point, Color("f4cc65"), true)
	play_sound(EXPLOSION, -16.0, 0.8)

func tank_destroyed(tank: DuelTank) -> void:
	burst(tank.position, tank.tint, true)
	play_sound(EXPLOSION, -13.0)
	if not resolution_pending:
		resolution_pending = true
		resolve_round.call_deferred()

func resolve_round() -> void:
	resolution_pending = false
	if not outcome.is_empty():
		return
	if not player.alive:
		lives -= 1
		outcome = "defeat"
	elif remaining_enemies() == 0:
		outcome = "complete" if mission == 50 else "clear"
		if save_progress and not debug_mode:
			CampaignProgress.unlock(mini(50, mission + 1))
	else:
		return
	active = false
	set_controls(false)
	freeze_ordnance(true)
	refresh_controller_menu()

func remaining_enemies() -> int:
	var count: int = 0
	for enemy in enemies:
		if enemy.alive:
			count += 1
	return count

func set_pause_menu_visible(shown: bool) -> void:
	super.set_pause_menu_visible(shown)
	if is_instance_valid(debug_mission_button):
		debug_mission_button.visible = shown
	if is_instance_valid(controller_menu): controller_menu.visible = shown or not outcome.is_empty()

func field_guide_input_blocked() -> bool:
	return is_instance_valid(mission_picker) or super.field_guide_input_blocked()

func show_debug_missions() -> void:
	if not debug_mode or not paused or is_instance_valid(mission_picker):
		return
	set_pause_menu_visible(false)
	mission_picker = preload("res://scripts/mission_picker.gd").new()
	mission_picker.current_checkpoint = mission - 1
	mission_picker.allowed_devices.assign([player_device])
	mission_picker.closed.connect(close_debug_missions)
	mission_picker.checkpoint_selected.connect(func(index: int):
		close_debug_missions()
		mission = clampi(index + 1, 1, 50)
		CampaignProgress.debug_mission = mission
		lives = 3
		start_round()
	)
	pause_guide_layer.add_child(mission_picker)

func close_debug_missions() -> void:
	if not is_instance_valid(mission_picker):
		return
	pause_guide_layer.remove_child(mission_picker)
	mission_picker.queue_free()
	mission_picker = null
	guide_closed_frame = Engine.get_process_frames() + 1
	set_pause_menu_visible(paused)
	if paused and is_instance_valid(debug_mission_button):
		debug_mission_button.grab_focus()

func cell_center(cell: Vector2i) -> Vector2:
	return BOARD.position + Vector2(cell) * CELL + Vector2.ONE * CELL * 0.5

func world_cell(point: Vector2) -> Vector2i:
	var local := (point - BOARD.position) / CELL
	return Vector2i(clampi(int(local.x), 0, COLS - 1), clampi(int(local.y), 0, ROWS - 1))

func neighbors(cell: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for direction in DIRECTIONS:
		var next := cell + direction
		if valid_cell(next) and passages.has(edge_key(cell, next)):
			result.append(next)
	return result

func navigation_path(enemy: EnemyTank, has_shot: bool) -> Array[Vector2]:
	var origin := world_cell(enemy.position)
	var target := world_cell(player.position)
	var distance := enemy.position.distance_to(player.position)
	var retreat := enemy.behavior == "Defensive" and distance < 320.0
	var orbit := has_shot and enemy.behavior == "Defensive" and distance < 480.0
	var orbit_radius: float = 370.0
	if enemy.behavior == "Dynamic":
		retreat = fmod(elapsed, 5.0) < 2.0 and distance < 420.0
	if enemy.behavior in ["Offensive", "Dynamic"] and not retreat:
		orbit = distance < 190.0
		orbit_radius = 180.0
	if retreat or orbit:
		var choices := neighbors(origin)
		if not choices.is_empty():
			target = choices[0]
			for choice in choices:
				var candidate_distance := cell_center(choice).distance_to(player.position)
				var target_distance := cell_center(target).distance_to(player.position)
				if (retreat and candidate_distance > target_distance) or (not retreat and absf(candidate_distance - orbit_radius) < absf(target_distance - orbit_radius)):
					target = choice
	var goal := cell_center(target) if retreat or orbit else player.position
	return EnemyTank.Spacing.path(self, enemy, goal, EnemyTank.MineAwareness.hazards(self, enemy))

func friendly_positions(shooter: EnemyTank) -> Array[Vector2]:
	var positions: Array[Vector2] = []
	for enemy in enemies:
		if enemy != shooter and enemy.alive:
			positions.append(enemy.global_position)
	return positions

func evasion_vector(tank: EnemyTank) -> Vector2:
	for shell in $Shells.get_children():
		if shell.released:
			continue
		var offset: Vector2 = tank.position - shell.position
		var along: float = offset.dot(shell.direction)
		if along > 0.0 and along < shell.speed * 0.85:
			var side: Vector2 = offset - shell.direction * along
			if side.length() < 42.0:
				return shell.direction.orthogonal() * (128.0 if side.dot(shell.direction.orthogonal()) >= 0.0 else -128.0)
	return Vector2.ZERO

func mission_control_hint() -> String:
	return ControlHints.mission_controls(player_device)

func mission_footer_hint() -> String:
	if ControlHints.active_devices([player_device]).is_empty(): return "Reconnect Player 1's assigned control, or use Player Setup in the main menu."
	if player_device < 0: return "ESC pause · ENTER next / retry · BACKSPACE menu"
	return "%s pause · %s next / retry · Player Setup in the main menu" % [ControlHints.for_device("pause", player_device), ControlHints.for_device("skip_intro", player_device)]

func _draw() -> void:
	if font == null:
		return
	var muted := Color("8296a5")
	draw_rect(Rect2(0, 0, 1280, 800), Color("101923"))
	text_at("SUPER TANK BATTLES", Vector2(50, 43), 27, Color("ecf4f6"))
	text_at("DEBUG · NO SAVE  /  CLEAR EVERY ENEMY" if debug_mode else "SINGLE PLAYER  /  CLEAR EVERY ENEMY", Vector2(51, 66), 13, muted)
	text_at("MISSION %02d / 50" % mission, Vector2(1000, 43), 22, Color("f4cc65"))
	text_at("LIVES  %d" % lives, Vector2(52, 112), 20, DuelTank.readable_tint(COLORS[0]))
	centered("%d ENEMIES REMAINING" % remaining_enemies(), Vector2(640, 108), 18, Color("ecf4f6"))
	var names: Array[String] = []
	for enemy in enemies:
		if not names.has(enemy.enemy_name):
			names.append(enemy.enemy_name)
	centered(" / ".join(names).to_upper(), Vector2(640, 130), 12, muted)
	text_at("ONE HIT TO DESTROY", Vector2(1024, 112), 14, muted)
	draw_board()
	text_at(mission_control_hint(), Vector2(52, 713), 16, Color("d5e2e8"))
	if is_instance_valid(player):
		text_at("SHOTS  %d / 5    MINES  %d / 2" % [player.max_shells - player.active_shells, player.max_mines - player.active_mines], Vector2(52, 743), 15, DuelTank.readable_tint(COLORS[0]))
	text_at("Crumbly walls need mines. Blasts and ricochets can hit you.", Vector2(490, 743), 14, muted)
	centered(mission_footer_hint(), Vector2(640, 781), 13, muted)
	# A small cursor helps line up the independent turret without exposing enemy AI.
	if active and not paused and player_device == -1:
		var aim := get_global_mouse_position()
		if BOARD.has_point(aim):
			draw_arc(aim, 9.0, 0.0, TAU, 24, Color(DuelTank.readable_tint(COLORS[0]), 0.9), 1.5, true)
			draw_line(aim - Vector2(14, 0), aim + Vector2(14, 0), Color(DuelTank.readable_tint(COLORS[0]), 0.8), 1.0)
			draw_line(aim - Vector2(0, 14), aim + Vector2(0, 14), Color(DuelTank.readable_tint(COLORS[0]), 0.8), 1.0)

func draw_overlay() -> void:
	if not paused and countdown <= 0.0 and outcome.is_empty():
		return
	var title := "PAUSED" if paused else "MISSION %02d" % mission
	var subtitle := "ESC to resume" if paused else "Clear the enemy tanks. Keep moving."
	if paused and missing_controller: subtitle = "Reconnect Player 1's controller, or return to Player Setup."
	elif paused and player_device >= 0: subtitle = "%s resumes · %s selects a menu button" % [ControlHints.buttons("pause", [player_device]), ControlHints.buttons("accept", [player_device])]
	var color := Color("ecf4f6")
	if not outcome.is_empty():
		if outcome == "clear":
			title = "MISSION CLEAR"
			subtitle = "ENTER for Mission %02d" % (mission + 1)
			color = DuelTank.readable_tint(COLORS[0])
		elif outcome == "complete":
			title = "CAMPAIGN COMPLETE"
			subtitle = "All 50 missions cleared. ENTER for a new campaign."
			color = Color("f4cc65")
		else:
			title = "TANK DESTROYED" if lives > 0 else "OUT OF LIVES"
			subtitle = "ENTER to retry  /  %d lives left" % lives if lives > 0 else "ENTER for a new campaign  /  BACKSPACE for mission select"
			color = Color("ff8a73")
	if player_device >= 0:
		subtitle = subtitle.replace("ENTER", ControlHints.buttons("skip_intro", [player_device]))
		subtitle = subtitle.replace("BACKSPACE for mission select", "Use Player Setup in the main menu")
		if ControlHints.active_devices([player_device]).is_empty(): subtitle = "Reconnect Player 1's control, or return to Player Setup."
	var overlay: Node2D = $Overlay
	overlay.draw_rect(Rect2(252, 346, 776, 126), Color(0.04, 0.08, 0.12, 0.96))
	overlay.draw_rect(Rect2(252, 346, 776, 2), color)
	var width := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 28).x
	overlay.draw_string(font, Vector2(640 - width * 0.5, 402), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, color)
	width = font.get_string_size(subtitle, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
	overlay.draw_string(font, Vector2(640 - width * 0.5, 438), subtitle, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("bdcbd1"))
