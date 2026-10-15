@tool
extends Node2D

@export var safe_position: Vector2 = Vector2(1350, 550):
	set(value):
		safe_position = value
		queue_redraw()
@export_range(80, 500) var flee_radius: float = 260
@export_range(40, 240) var run_speed: float = 125
@export var shirt: Color = Color("d9b16c"):
	set(value):
		shirt = value
		queue_redraw()
@export var chief: bool = false:
	set(value):
		chief = value
		queue_redraw()
var home: Vector2
var fleeing: bool = false
var at_safety: bool = false
var clock: float = 0

func _ready() -> void:
	# People are scenery; they cannot block tanks or intercept shells.
	z_as_relative = false
	z_index = 2
	home = position
	queue_redraw()

func reset_villager() -> void:
	position = home
	fleeing = false
	at_safety = false
	visible = true
	clock = 0
	queue_redraw()

func update_flee(crew_positions: Array[Vector2], delta: float) -> void:
	clock += delta
	if chief or at_safety:
		queue_redraw()
		return
	for at in crew_positions:
		if global_position.distance_to(at) < flee_radius:
			fleeing = true
	if fleeing:
		position = position.move_toward(safe_position, run_speed * delta)
		if position.distance_to(safe_position) < 4:
			at_safety = true
			hide()
	queue_redraw()

func _draw() -> void:
	var stride := sin(clock * 14) * 8 if fleeing and not at_safety else sin(clock * 2) * 1.5
	draw_ellipse_shadow()
	draw_line(Vector2(-5, 8), Vector2(-6 + stride, 22), Color("24313a"), 5)
	draw_line(Vector2(5, 8), Vector2(6 - stride, 22), Color("24313a"), 5)
	if chief:
		draw_colored_polygon(PackedVector2Array([Vector2(-9, -8), Vector2(9, -8), Vector2(13, 16), Vector2(-13, 16)]), shirt)
		draw_line(Vector2(0, -4), Vector2(0, 15), Color("f4dda1"), 3)
	else:
		draw_rect(Rect2(-8, -8, 16, 22), shirt)
	draw_line(Vector2(-8, -4), Vector2(-16, 7 + stride), Color("e2bc91"), 4)
	draw_line(Vector2(8, -4), Vector2(16, 7 - stride), Color("e2bc91"), 4)
	draw_circle(Vector2(0, -16), 8, Color("e2bc91"))
	draw_arc(Vector2(0, -19), 8, PI, TAU, 12, Color("ded7bb") if chief else Color("594431"), 4)
	if chief:
		draw_colored_polygon(PackedVector2Array([Vector2(-6, -12), Vector2(6, -12), Vector2(0, 1)]), Color("ded7bb"))
		draw_line(Vector2(18, -18), Vector2(18, 25), Color("c8a570"), 3)
		draw_string(ThemeDB.fallback_font, Vector2(-66, -40), "VILLAGE CHIEF", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("fff0b8"))
	if Engine.is_editor_hint() and not chief:
		draw_line(Vector2.ZERO, safe_position - position, Color(0.9, 0.85, 0.6, 0.5), 2)
		draw_circle(safe_position - position, 8, Color(0.9, 0.85, 0.6, 0.5))

func draw_ellipse_shadow() -> void:
	draw_set_transform(Vector2(2, 18), 0, Vector2(1, 0.4))
	draw_circle(Vector2.ZERO, 14, Color(0, 0, 0, 0.3))
	draw_set_transform(Vector2.ZERO)
