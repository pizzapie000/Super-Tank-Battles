extends Control

var mission_select: OptionButton
var clock: float = 0.0
var guide: PanelContainer

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var theme_resource := Theme.new()
	theme_resource.default_font = ThemeDB.fallback_font
	theme_resource.default_font_size = 17
	theme = theme_resource
	label("SUPER TANK\nBATTLES", Vector2(52, 115), Vector2(530, 126), 51, Color("ecf4f6"))
	label("ANGLE YOUR SHOTS. WATCH YOUR BACK.", Vector2(55, 261), Vector2(520, 30), 15, DuelTank.readable_tint(DuelTank.PLAYER_COLORS[0]))
	label("Fight through a 50-mission campaign, or settle a rivalry on one keyboard.", Vector2(55, 310), Vector2(450, 82), 21, Color("a9bdc9"))
	label("ONE HIT. EVERY SHOT COUNTS.", Vector2(55, 704), Vector2(500, 35), 16, Color("8296a5"))
	var column := VBoxContainer.new()
	column.position = Vector2(650, 122)
	column.size = Vector2(560, 555)
	column.add_theme_constant_override("separation", 16)
	add_child(column)
	var campaign := card(column, DuelTank.readable_tint(DuelTank.PLAYER_COLORS[0]))
	text(campaign, "01  /  SINGLE PLAYER", 25, DuelTank.readable_tint(DuelTank.PLAYER_COLORS[0]))
	text(campaign, "Clear 50 arenas. Nine enemy types. Three lives.", 16, Color("bdcbd1"))
	text(campaign, "WASD / arrows drive  •  Mouse aim\nClick / Space fire  •  E mine", 15, Color("8296a5"))
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
	button(row, "PLAY CAMPAIGN", DuelTank.readable_tint(DuelTank.PLAYER_COLORS[0]), start_campaign)
	var duel := card(column, DuelTank.PLAYER_COLORS[1])
	text(duel, "02  /  TWO PLAYER DUEL", 25, DuelTank.PLAYER_COLORS[1])
	text(duel, "A new maze each round. First to seven wins.", 16, Color("bdcbd1"))
	text(duel, "Left: ESDF + Q  •  Right: arrows + M", 15, Color("8296a5"))
	button(duel, "PLAY LOCAL DUEL", DuelTank.PLAYER_COLORS[1], start_duel)
	button(column, "ENEMY FIELD GUIDE", Color("8296a5"), show_guide)
	label("Cleared missions unlock here and save automatically.", Vector2(650, 716), Vector2(570, 42), 14, Color("8296a5"))

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
	style.content_margin_top = 20
	style.content_margin_bottom = 20
	return style

func card(parent: Node, color: Color) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", panel_style(color))
	parent.add_child(panel)
	var contents := VBoxContainer.new()
	contents.add_theme_constant_override("separation", 12)
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
	CampaignProgress.selected_mission = mission_select.get_selected_id()
	get_tree().change_scene_to_file("res://scenes/game/CampaignArena.tscn")

func start_duel() -> void:
	get_tree().change_scene_to_file("res://scenes/game/DuelArena.tscn")

func show_guide() -> void:
	if is_instance_valid(guide):
		return
	guide = PanelContainer.new()
	guide.position = Vector2(90, 65)
	guide.size = Vector2(1100, 670)
	guide.add_theme_stylebox_override("panel", panel_style(DuelTank.readable_tint(DuelTank.PLAYER_COLORS[0])))
	add_child(guide)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 13)
	guide.add_child(column)
	text(column, "ENEMY FIELD GUIDE", 29, Color("ecf4f6"))
	text(column, "Ricochets count reflections before the final wall impact. Friendly fire is deadly.", 15, Color("8296a5"))
	var details := {
		"Brown": "Holds position. Slowly tracks you. One normal shell; one ricochet.",
		"Ash": "Slow patrols. Dodges shells and keeps distance. One normal shell.",
		"Marine": "Defensive movement. One fast shell that breaks at the first wall.",
		"Yellow": "Aggressive movement with little caution. Rapidly lays up to four mines.",
		"Pink": "Slow pursuit, quick aim and fire. Up to three normal shells.",
		"Green": "Ricochet-only missiles. Leads you through one or two bank shots.",
		"Violet": "Fast pursuit and quick fire. Five shells, one ricochet, two mines.",
		"White": "Fades out at mission start. Follow its tracks. Five shells and two mines.",
		"Black": "Very fast. Switches between attack and retreat. Three fast shells, two mines.",
	}
	for profile in EnemyProfiles.TYPES:
		var row := HBoxContainer.new()
		row.custom_minimum_size.y = 40
		column.add_child(row)
		var icon := Control.new()
		icon.custom_minimum_size = Vector2(27, 40)
		icon.draw.connect(DuelTank.draw_identification.bind(icon, String(profile.marker), Vector2(13, 20)))
		row.add_child(icon)
		var title := Label.new()
		title.custom_minimum_size.x = 210
		title.text = "%s  /  M%02d" % [profile.name, profile.mission]
		title.add_theme_color_override("font_color", DuelTank.readable_tint(Color(profile.color)))
		row.add_child(title)
		text(row, details[profile.name], 15, Color("bdcbd1"))
	button(column, "BACK TO MODES", DuelTank.readable_tint(DuelTank.PLAYER_COLORS[0]), func(): guide.queue_free())

func _process(delta: float) -> void:
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
	draw_set_transform(Vector2(300, 532), sin(clock * 0.35) * 0.2 - 0.2, Vector2(3.2, 3.2))
	for y in [-19.0, 12.0]:
		draw_rect(Rect2(-22, y, 44, 7), Color("314952"))
		for x in range(-20, 22, 7):
			draw_line(Vector2(x, y), Vector2(x, y + 7), Color("8296a5"), 1.0)
	draw_rect(Rect2(-19, -12, 36, 24), DuelTank.PLAYER_COLORS[0].darkened(0.08))
	draw_rect(Rect2(0, -4, 31, 8), DuelTank.PLAYER_COLORS[0])
	draw_circle(Vector2.ZERO, 10, DuelTank.PLAYER_COLORS[0])
	DuelTank.draw_identification(self, "1")
	draw_set_transform(Vector2.ZERO)
