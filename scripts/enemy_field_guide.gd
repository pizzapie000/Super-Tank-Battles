extends PanelContainer

signal closed

var back_label := "BACK TO MODES"
var allowed_devices: Array[int] = []
var back_button: Button

func _ready() -> void:
	name = "EnemyFieldGuide"
	position = Vector2(90, 65)
	size = Vector2(1100, 670)
	var guide_theme := Theme.new()
	guide_theme.default_font = ThemeDB.fallback_font
	guide_theme.default_font_size = 17
	theme = guide_theme
	add_theme_stylebox_override("panel", panel_style())
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 13)
	add_child(column)
	text(column, "ENEMY FIELD GUIDE", 29, Color("ecf4f6"))
	text(column, "Ricochets count reflections before the final wall impact. Friendly fire is deadly.", 15, Color("8296a5"))
	var details := {
		"Brown": "Holds position. Slowly tracks you. One normal shell; one ricochet.",
		"Ash": "Slow patrols. Dodges shells and keeps distance. One normal shell.",
		"Marine": "Defensive movement. One fast missile with a smoke trail; breaks at the first wall.",
		"Yellow": "Aggressive movement with little caution. Rapidly lays up to four mines.",
		"Pink": "Slow pursuit, quick aim and fire. Up to three normal shells.",
		"Green": "Ricochet-only missiles. Leads you through one or two bank shots.",
		"Violet": "Fast pursuit and quick fire. Five shells, one ricochet, two mines.",
		"White": "Fades out at mission start. Follow its tracks. Five shells and two mines.",
		"Black": "Very fast. Switches between attack and retreat. Three fast missiles with smoke trails, two mines.",
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
	back_button = Button.new()
	back_button.text = back_label
	back_button.custom_minimum_size.y = 50
	back_button.add_theme_font_size_override("font_size", 17)
	back_button.add_theme_color_override("font_color", Color("ecf4f6"))
	var normal := panel_style()
	normal.bg_color = Color(0.3, 0.45, 0.65, 0.12)
	back_button.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.3, 0.45, 0.65, 0.25)
	back_button.add_theme_stylebox_override("hover", hover)
	back_button.add_theme_stylebox_override("pressed", hover)
	back_button.pressed.connect(func(): closed.emit())
	column.add_child(back_button)
	back_button.grab_focus()

func text(parent: Node, value: String, font_size: int, color: Color) -> void:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)

func panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("172631")
	style.border_color = Color("89b5c8")
	style.set_border_width_all(1)
	style.border_width_left = 3
	style.set_corner_radius_all(7)
	style.content_margin_left = 22
	style.content_margin_right = 22
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	return style

func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton and not allowed_devices.is_empty() and not allowed_devices.has(event.device):
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.echo:
		return
	var controller_back: bool = event is InputEventJoypadButton and event.pressed and event.button_index in [JOY_BUTTON_A, JOY_BUTTON_B, JOY_BUTTON_START]
	if event.is_action_pressed("pause_game") or event.is_action_pressed("return_menu") or event.is_action_pressed("ui_cancel") or controller_back:
		get_viewport().set_input_as_handled()
		closed.emit()
