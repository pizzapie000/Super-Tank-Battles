extends Control

const ControlHints = preload("res://scripts/input/control_hints.gd")
var mission_select: OptionButton
var clock: float = 0.0
var guide: PanelContainer
var loading_story: bool = false
var skip_tutorial_checkbox: CheckBox
var checkpoint_picker: Control
var mission_picker: Control
var player_hub: Control
var wii_auto_starting := false
var control_hint_label: Label

func _ready() -> void:
	StorySession.load_preferences()
	PlayerSetup.load_preferences()
	if OS.get_name() == "macOS" and DisplayServer.get_name() != "headless" and PlayerSetup.bindings.any(func(binding): return binding.get("kind") == "wii"):
		wii_auto_starting = true
		preload("res://scripts/input/controller_input.gd").bridge().launch_bridge.call_deferred()
	StorySession.debug_checkpoint = -1
	CampaignProgress.debug_mission = 0
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var theme_resource := Theme.new()
	theme_resource.default_font = ThemeDB.fallback_font
	theme_resource.default_font_size = 17
	theme = theme_resource
	label("SUPER TANK\nBATTLES", Vector2(52, 115), Vector2(530, 126), 51, Color("ecf4f6"))
	label("ANGLE YOUR SHOTS. WATCH YOUR BACK.", Vector2(55, 261), Vector2(520, 30), 15, DuelTank.readable_tint(DuelTank.PLAYER_COLORS[0]))
	label("BUILD YOUR CREW. CHOOSE YOUR ROAD.", Vector2(55, 305), Vector2(530, 26), 18, Color("a9bdc9"))
	player_hub = preload("res://scripts/input/player_hub.gd").new()
	add_child(player_hub)
	label("ONE CREW. EVERY CHOICE COUNTS.", Vector2(55, 704), Vector2(500, 35), 16, Color("8296a5"))
	var wii_button := button(self, "WII REMOTE SETUP", Color("51edcf"), show_wii_setup)
	wii_button.position = Vector2(55, 650)
	wii_button.size = Vector2(450, 42)
	wii_button.custom_minimum_size.y = 42
	var column := VBoxContainer.new()
	column.position = Vector2(650, 40)
	column.size = Vector2(560, 700)
	column.add_theme_constant_override("separation", 12)
	add_child(column)
	var adventure := card(column, Color("ffd575"))
	text(adventure, "01  /  TRUE CAMPAIGN", 23, Color("ffd575"))
	text(adventure, "1–4 local players. One story. Choices that stay with you.", 15, Color("bdcbd1"))
	text(adventure, "Keyboard + controllers, or up to four controllers.", 14, Color("8296a5"))
	var story_row := HBoxContainer.new()
	story_row.add_theme_constant_override("separation", 10)
	adventure.add_child(story_row)
	var new_story := button(story_row, "NEW ADVENTURE", Color("ffd575"), func(): start_story(false))
	var continue_story := button(story_row, "CONTINUE", Color("ffd575"), func(): start_story(true))
	continue_story.disabled = not FileAccess.file_exists(StorySession.save_path) or bool(StorySession.checkpoint().complete)
	skip_tutorial_checkbox = CheckBox.new()
	skip_tutorial_checkbox.text = "Skip factory tutorial"
	skip_tutorial_checkbox.button_pressed = StorySession.skip_tutorial
	skip_tutorial_checkbox.custom_minimum_size.y = 30
	skip_tutorial_checkbox.toggled.connect(StorySession.set_skip_tutorial)
	var story_options := HBoxContainer.new()
	story_options.add_theme_constant_override("separation", 18)
	adventure.add_child(story_options)
	story_options.add_child(skip_tutorial_checkbox)
	var debug_button := button(story_options, "DEBUG CHECKPOINTS", Color("8296a5"), show_checkpoint_picker)
	debug_button.custom_minimum_size.y = 32
	debug_button.add_theme_font_size_override("font_size", 14)
	new_story.grab_focus()
	var campaign := card(column, DuelTank.readable_tint(DuelTank.PLAYER_COLORS[0]))
	text(campaign, "02  /  CLASSIC MISSIONS", 22, DuelTank.readable_tint(DuelTank.PLAYER_COLORS[0]))
	text(campaign, "Clear 50 arenas. Nine enemy types. Three lives.", 16, Color("bdcbd1"))
	text(campaign, "Singleplayer — uses Player 1's controls from the shared setup.", 15, Color("8296a5"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	campaign.add_child(row)
	mission_select = OptionButton.new()
	mission_select.custom_minimum_size = Vector2(170, 50)
	var unlocked := CampaignProgress.highest_mission()
	for mission in range(1, unlocked + 1):
		mission_select.add_item("Mission %02d" % mission, mission)
	mission_select.select(unlocked - 1)
	row.add_child(mission_select)
	button(row, "PLAY MISSIONS", DuelTank.readable_tint(DuelTank.PLAYER_COLORS[0]), start_campaign)
	var debug_missions := button(campaign, "DEBUG MISSIONS", Color("8296a5"), show_mission_picker)
	debug_missions.custom_minimum_size.y = 32
	debug_missions.add_theme_font_size_override("font_size", 14)
	var duel := card(column, DuelTank.PLAYER_COLORS[1])
	text(duel, "03  /  TWO PLAYER DUEL", 22, DuelTank.PLAYER_COLORS[1])
	text(duel, "A new maze each round. First to seven wins.", 16, Color("bdcbd1"))
	text(duel, "Shared keyboard or controllers. Weapons arrive after 5 seconds.", 14, Color("8296a5"))
	button(duel, "PLAY LOCAL DUEL", DuelTank.PLAYER_COLORS[1], start_duel)
	button(column, "ENEMY FIELD GUIDE", Color("8296a5"), show_guide)
	label("Story checkpoints and classic mission unlocks save separately.", Vector2(650, 748), Vector2(570, 42), 13, Color("8296a5"))
	control_hint_label = label("", Vector2(55, 741), Vector2(570, 57), 12, Color("8296a5"))
	refresh_control_hint()
	preload("res://scripts/input/wii_menu.gd").attach(self, Callable(), [], Callable(), func(): return not loading_story)

func label(value: String, at: Vector2, size: Vector2, font_size: int, color: Color) -> Label:
	var node := Label.new()
	node.text = value
	node.position = at
	node.size = size
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.add_theme_font_size_override("font_size", font_size)
	node.add_theme_color_override("font_color", color)
	add_child(node)
	return node

func text(parent: Node, value: String, font_size: int, color: Color) -> void:
	var node := Label.new()
	node.text = value
	node.add_theme_font_size_override("font_size", font_size)
	node.add_theme_color_override("font_color", color)
	parent.add_child(node)

func panel_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("172631")
	style.border_color = Color(color, 0.5)
	style.set_border_width_all(1)
	style.border_width_left = 3
	style.set_corner_radius_all(7)
	style.content_margin_left = 22
	style.content_margin_right = 22
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	return style

func card(parent: Node, color: Color) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", panel_style(color))
	parent.add_child(panel)
	var contents := VBoxContainer.new()
	contents.add_theme_constant_override("separation", 7)
	panel.add_child(contents)
	return contents

func button(parent: Node, value: String, color: Color, action: Callable) -> Button:
	var node := Button.new()
	node.text = value
	node.custom_minimum_size = Vector2(0, 50)
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.add_theme_font_size_override("font_size", 17)
	node.add_theme_color_override("font_color", Color("ecf4f6"))
	var normal := panel_style(color)
	normal.bg_color = Color(color, 0.12)
	normal.content_margin_top = 8
	normal.content_margin_bottom = 8
	node.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(color, 0.25)
	node.add_theme_stylebox_override("hover", hover)
	node.add_theme_stylebox_override("pressed", hover)
	node.pressed.connect(action)
	parent.add_child(node)
	return node

func start_campaign() -> void:
	if not ready_for_mode("missions"): return
	CampaignProgress.debug_mission = 0
	CampaignProgress.selected_mission = mission_select.get_selected_id()
	get_tree().change_scene_to_file("res://scenes/game/CampaignArena.tscn")

func show_mission_picker() -> void:
	if loading_story or is_instance_valid(mission_picker):
		return
	var previous_focus := get_viewport().gui_get_focus_owner()
	mission_picker = preload("res://scripts/mission_picker.gd").new()
	mission_picker.current_checkpoint = mission_select.get_selected_id() - 1
	mission_picker.closed.connect(func():
		close_mission_picker()
		if is_instance_valid(previous_focus): previous_focus.grab_focus()
	)
	mission_picker.checkpoint_selected.connect(func(index: int):
		if not ready_for_mode("missions"): return
		close_mission_picker()
		CampaignProgress.debug_mission = index + 1
		get_tree().change_scene_to_file("res://scenes/game/CampaignArena.tscn")
	)
	add_child(mission_picker)

func close_mission_picker() -> void:
	if is_instance_valid(mission_picker):
		remove_child(mission_picker)
		mission_picker.queue_free()
	mission_picker = null

func start_duel() -> void:
	if not ready_for_mode("duel"): return
	preload("res://scripts/pvp/duel_session.gd").devices.assign(PlayerSetup.selected(2))
	get_tree().change_scene_to_file("res://scenes/game/DuelArena.tscn")

func ready_for_mode(mode: String) -> bool:
	var problem := PlayerSetup.problem(mode)
	if problem.is_empty(): return true
	player_hub.show_problem(problem)
	return false

func show_wii_setup() -> void:
	var previous_focus := get_viewport().gui_get_focus_owner()
	var setup = preload("res://scenes/game/WiiSetup.tscn").instantiate()
	setup.closed.connect(func():
		setup.queue_free()
		if is_instance_valid(previous_focus): previous_focus.grab_focus()
	)
	add_child(setup)

func start_story(resume_saved: bool, debug_section: int = -1) -> void:
	if loading_story:
		return
	if not ready_for_mode("campaign"): return
	StorySession.devices.assign(PlayerSetup.selected())
	loading_story = true
	StorySession.resume_story = resume_saved
	StorySession.debug_checkpoint = debug_section
	var fade := ColorRect.new()
	fade.color = Color(0, 0, 0, 0)
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fade)
	var tween := create_tween()
	tween.tween_property(fade, "color:a", 1.0, 0.4)
	tween.tween_callback(func(): get_tree().change_scene_to_file("res://scenes/story/Adventure.tscn"))

func show_checkpoint_picker() -> void:
	if loading_story or is_instance_valid(checkpoint_picker):
		return
	var previous_focus := get_viewport().gui_get_focus_owner()
	checkpoint_picker = preload("res://scripts/story/checkpoint_picker.gd").new()
	checkpoint_picker.current_checkpoint = int(StorySession.checkpoint().chapter)
	checkpoint_picker.closed.connect(func():
		close_checkpoint_picker()
		if is_instance_valid(previous_focus):
			previous_focus.grab_focus()
	)
	checkpoint_picker.checkpoint_selected.connect(func(index: int):
		close_checkpoint_picker()
		start_story(false, index)
	)
	add_child(checkpoint_picker)

func close_checkpoint_picker() -> void:
	if is_instance_valid(checkpoint_picker):
		remove_child(checkpoint_picker)
		checkpoint_picker.queue_free()
	checkpoint_picker = null

func show_guide() -> void:
	if is_instance_valid(guide):
		return
	var previous_focus := get_viewport().gui_get_focus_owner()
	guide = preload("res://scripts/enemy_field_guide.gd").new()
	guide.closed.connect(func():
		remove_child(guide)
		guide.queue_free()
		guide = null
		if is_instance_valid(previous_focus):
			previous_focus.grab_focus()
	)
	add_child(guide)

func refresh_control_hint() -> void:
	var devices := ControlHints.active_devices(PlayerSetup.selected())
	var lines: Array[String] = []
	if devices.any(func(device): return device < 0): lines.append("KEYBOARD: arrows to browse · Enter to select · Esc to go back")
	if devices.any(func(device): return device >= 0 and not ControlHints.Controls.is_wii(device)): lines.append("CONTROLLER: left stick / D-pad to browse · A to select · B to go back")
	if devices.any(ControlHints.Controls.is_wii): lines.append("WII: point + A to select · Nunchuk / D-pad to browse · B / Z / 1 back")
	control_hint_label.text = "\n".join(lines) if not lines.is_empty() else "Use the mouse to choose your player controls."

func _process(delta: float) -> void:
	refresh_control_hint()
	if wii_auto_starting and not preload("res://scripts/input/controller_input.gd").bridge().connected_devices().is_empty():
		wii_auto_starting = false
		DisplayServer.window_move_to_foreground()
	clock += delta
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(0, 0, 1280, 800), Color("101923"))
	for x in range(0, 1280, 40):
		draw_line(Vector2(x, 0), Vector2(x, 800), Color(0.55, 0.75, 0.8, 0.035))
	for y in range(0, 800, 40):
		draw_line(Vector2(0, y), Vector2(1280, y), Color(0.55, 0.75, 0.8, 0.035))
	draw_arc(Vector2(300, 532), 133.0, -0.3, 4.0, 64, Color("263d4a"), 2.0, true)
	draw_arc(Vector2(300, 532), 157.0, 0.5, 3.2, 64, Color("1e333f"), 1.0, true)
	draw_set_transform(Vector2(535, 185), sin(clock * 0.35) * 0.2 - 0.2, Vector2(1.5, 1.5))
	DuelTank.Art.chassis(self, Vector2.ZERO)
	DuelTank.Art.tracks(self, Vector2.ZERO, -1, clock * 3)
	DuelTank.Art.tracks(self, Vector2.ZERO, 1, clock * 3)
	DuelTank.Art.armor(self, DuelTank.PLAYER_COLORS[0], Vector2.ZERO)
	DuelTank.Art.turret(self, DuelTank.PLAYER_COLORS[0], Vector2.ZERO)
	DuelTank.draw_identification(self, "1")
	draw_set_transform(Vector2.ZERO)
