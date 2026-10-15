@tool
extends Marker2D

@export_enum("Front", "North", "South", "Rear") var approach: String = "Front"
@export var entrance_gate: NodePath
var opened: bool = false

func _ready() -> void:
	z_as_relative = false
	z_index = -2
	queue_redraw()

func gate() -> Node2D:
	return get_node_or_null(entrance_gate) if not entrance_gate.is_empty() else null

func _draw() -> void:
	if entrance_gate.is_empty() and not Engine.is_editor_hint():
		return
	var tint := Color("ff775c") if opened else Color("c8ac6b")
	draw_circle(Vector2.ZERO, 29, Color("1c2933"))
	draw_arc(Vector2.ZERO, 27, 0, TAU, 24, tint, 3)
	var direction := {"Front": Vector2.LEFT, "Rear": Vector2.RIGHT, "North": Vector2.DOWN, "South": Vector2.UP}
	draw_set_transform(Vector2.ZERO, direction[approach].angle())
	draw_polyline(PackedVector2Array([Vector2(-9, -10), Vector2(7, 0), Vector2(-9, 10)]), tint, 4)
	draw_set_transform(Vector2.ZERO)
	if not entrance_gate.is_empty():
		var label := approach.to_upper()
		var font := ThemeDB.fallback_font
		var width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		draw_rect(Rect2(-width / 2 - 4, 30, width + 8, 20), Color("13222f"))
		draw_string(font, Vector2(-width / 2, 45), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
	if Engine.is_editor_hint():
		draw_string(ThemeDB.fallback_font, Vector2(-35, -40), approach, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
