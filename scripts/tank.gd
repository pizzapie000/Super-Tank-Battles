class_name DuelTank
extends CharacterBody2D

signal shot_requested(tank: DuelTank)
signal destroyed(tank: DuelTank)
signal mine_requested(tank: DuelTank)

const PLAYER_COLORS: Array[Color] = [Color("2455ff"), Color("ff951a")]

@export var forward_speed: float = 150.0
@export var reverse_speed: float = 110.0
@export var turn_speed: float = 2.6
@export var shot_cooldown: float = 0.32
@export var max_shells: int = 5
@export var shell_speed: float = 300.0
@export var shell_wall_hits: int = 3
@export var shell_is_missile: bool = false
@export var max_mines: int = 0
@export var mine_cooldown: float = 3.5

var player_index: int = 0
var tint: Color = PLAYER_COLORS[0]
var identification: String = "1"
var alive: bool = true
var controls_enabled: bool = false
var active_shells: int = 0
var cooldown: float = 0.0
var tread_phase: float = 0.0
var recoil: float = 0.0
var active_mines: int = 0
var mine_timer: float = 0.0
var separate_turret: bool = false
var turret_angle: float = 0.0
var campaign_controls: bool = false
var body_opacity: float = 1.0

func _physics_process(delta: float) -> void:
	cooldown = maxf(0.0, cooldown - delta)
	recoil = move_toward(recoil, 0.0, delta * 24.0)
	mine_timer = maxf(0.0, mine_timer - delta)
	if not alive or not controls_enabled:
		velocity = Vector2.ZERO
		return
	var control := control_step(delta)
	rotation += control.x * turn_speed * delta
	var drive := control.y
	velocity = Vector2.RIGHT.rotated(rotation) * drive * (forward_speed if drive > 0.0 else reverse_speed)
	move_and_slide()
	tread_phase = fmod(tread_phase + velocity.length() * delta * 0.15, 8.0)
	if wants_fire() and cooldown <= 0.0 and active_shells < max_shells:
		shot_requested.emit(self)
	if wants_mine() and mine_timer <= 0.0 and active_mines < max_mines:
		mine_requested.emit(self)
	queue_redraw()

func control_step(_delta: float) -> Vector2:
	var prefix := "solo_" if campaign_controls else "p%d_" % (player_index + 1)
	if campaign_controls:
		turret_angle = (get_global_mouse_position() - global_position).angle()
	return Vector2(Input.get_axis(prefix + "left", prefix + "right"), Input.get_axis(prefix + "back", prefix + "forward"))

func wants_fire() -> bool:
	return Input.is_action_pressed("solo_fire" if campaign_controls else "p%d_fire" % (player_index + 1))

func wants_mine() -> bool:
	return campaign_controls and Input.is_action_just_pressed("solo_mine")

func firing_direction() -> Vector2:
	return Vector2.RIGHT.rotated(turret_angle if separate_turret else rotation)

func register_mine() -> void:
	active_mines += 1
	mine_timer = mine_cooldown

func register_shot() -> void:
	active_shells += 1
	cooldown = shot_cooldown
	recoil = 4.0

func take_hit() -> void:
	if not alive:
		return
	alive = false
	visible = false
	set_collision_layer_value(2, false)
	destroyed.emit(self)

func _draw() -> void:
	# White tanks leave ground tracks in the campaign, but hide their entire body.
	if body_opacity <= 0.01:
		return
	modulate.a = body_opacity
	draw_circle(Vector2(2, 3), 22, Color(0, 0, 0, 0.22))
	for y in [-19.0, 11.0]:
		draw_rect(Rect2(-20, y, 38, 8), Color("101b26"))
		for x in range(-18, 18, 6):
			draw_line(Vector2(x + tread_phase * 0.5, y + 1), Vector2(x + tread_phase * 0.5, y + 7), Color("63727c"), 2)
	draw_style_box(_plate(tint.darkened(0.08)), Rect2(-18, -12, 34, 24))
	draw_line(Vector2(-12, -9), Vector2(10, -9), tint.lightened(0.3), 2)
	if separate_turret:
		draw_set_transform(Vector2.ZERO, turret_angle - rotation)
	draw_rect(Rect2(0 - recoil, -5, 28, 10), Color("0d1925"))
	draw_rect(Rect2(1 - recoil, -3, 26, 6), tint.lightened(0.15))
	draw_circle(Vector2(-2, 0), 10, tint)
	draw_arc(Vector2(-2, 0), 7, PI * 0.8, PI * 1.8, 12, tint.lightened(0.45), 2, true)
	draw_set_transform(Vector2.ZERO)
	# Keep the high-contrast identification mark upright as the tank turns.
	draw_set_transform(Vector2.ZERO, -rotation)
	draw_identification(self, identification)
	draw_set_transform(Vector2.ZERO)

func _plate(color: Color) -> StyleBoxFlat:
	var plate := StyleBoxFlat.new()
	plate.bg_color = color
	plate.border_color = Color("e9f2ff")
	plate.set_border_width_all(1)
	plate.set_corner_radius_all(4)
	return plate

static func readable_tint(color: Color) -> Color:
	# Royal blue and charcoal stay bold on the tank; their text gets enough
	# brightness to read against the dark HUD and field-guide panels.
	while color.srgb_to_linear().get_luminance() < 0.28:
		color = color.lightened(0.1)
	return color

static func draw_identification(canvas: CanvasItem, marker: String, at: Vector2 = Vector2.ZERO) -> void:
	var ink := Color("ffffff")
	canvas.draw_circle(at, 7.5, Color("080e1b"))
	match marker:
		"circle":
			canvas.draw_arc(at, 4, 0, TAU, 24, ink, 2, true)
		"square":
			canvas.draw_rect(Rect2(at - Vector2(4, 4), Vector2(8, 8)), ink, false, 2)
		"triangle":
			canvas.draw_polyline(PackedVector2Array([at + Vector2(0, -5), at + Vector2(5, 4), at + Vector2(-5, 4), at + Vector2(0, -5)]), ink, 2, true)
		"bars":
			for y in [-2.5, 2.5]:
				canvas.draw_line(at + Vector2(-4, y), at + Vector2(4, y), ink, 2, true)
		"cross":
			canvas.draw_line(at - Vector2(4, 4), at + Vector2(4, 4), ink, 2, true)
			canvas.draw_line(at + Vector2(-4, 4), at + Vector2(4, -4), ink, 2, true)
		"chevron":
			canvas.draw_polyline(PackedVector2Array([at + Vector2(-5, 3), at + Vector2(0, -3), at + Vector2(5, 3)]), ink, 2, true)
		"star":
			var points := PackedVector2Array()
			for i in range(10):
				points.append(at + Vector2.RIGHT.rotated(-PI * 0.5 + i * PI * 0.2) * (5.5 if i % 2 == 0 else 2.5))
			canvas.draw_colored_polygon(points, ink)
		"dots":
			canvas.draw_circle(at + Vector2(-3, 0), 2, ink)
			canvas.draw_circle(at + Vector2(3, 0), 2, ink)
		"diamond":
			canvas.draw_polyline(PackedVector2Array([at + Vector2(0, -5), at + Vector2(5, 0), at + Vector2(0, 5), at + Vector2(-5, 0), at + Vector2(0, -5)]), ink, 2, true)
		_:
			var font := ThemeDB.fallback_font
			var width := font.get_string_size(marker, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
			canvas.draw_string(font, at + Vector2(-width * 0.5, 4), marker, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, ink)
