@tool
extends Polygon2D

## Editable starting position. These markers become live tanks in the arena.
@export_enum("Player", "Brown", "Ash", "Marine", "Yellow", "Pink", "Green", "Violet", "White", "Black") var tank_type: String = "Brown":
	set(value):
		tank_type = value
		refresh()

func _ready() -> void:
	refresh()

func refresh() -> void:
	polygon = PackedVector2Array([Vector2(-23, -21), Vector2(23, -21), Vector2(23, 21), Vector2(-23, 21)])
	color = DuelTank.PLAYER_COLORS[0] if tank_type == "Player" else Color(EnemyProfiles.get_profile(tank_type).color)
	queue_redraw()

func _draw() -> void:
	for y in [-21, 15]:
		draw_rect(Rect2(-23, y, 46, 6), Color("131d25"))
	draw_rect(Rect2(-15, -12, 30, 24), color.lightened(0.15))
	draw_line(Vector2.ZERO, Vector2(31, 0), Color("edf4f6"), 6)
	var marker: String = "1" if tank_type == "Player" else EnemyProfiles.get_profile(tank_type).marker
	DuelTank.draw_identification(self, marker, Vector2.ZERO)
	# Labels stay upright even when a starting direction is rotated in the editor.
	draw_set_transform(Vector2.ZERO, -rotation)
	var font := ThemeDB.fallback_font
	var width := font.get_string_size(tank_type, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	draw_string(font, Vector2(-width / 2, 41), tank_type, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)
