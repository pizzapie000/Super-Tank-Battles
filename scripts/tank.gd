class_name DuelTank
extends CharacterBody2D

signal shot_requested(tank: DuelTank)
signal destroyed(tank: DuelTank)

@export var forward_speed: float = 185.0
@export var reverse_speed: float = 135.0
@export var turn_speed: float = 3.1
@export var shot_cooldown: float = 0.32
@export var max_shells: int = 5

var player_index: int = 0
var tint: Color = Color("52d8ed")
var alive: bool = true
var controls_enabled: bool = false
var active_shells: int = 0
var cooldown: float = 0.0
var tread_phase: float = 0.0
var recoil: float = 0.0

func _physics_process(delta: float) -> void:
	cooldown = maxf(0.0, cooldown - delta)
	recoil = move_toward(recoil, 0.0, delta * 24.0)
	if not alive or not controls_enabled:
		velocity = Vector2.ZERO
		return
	var prefix := "p%d_" % (player_index + 1)
	var steering := Input.get_axis(prefix + "left", prefix + "right")
	rotation += steering * turn_speed * delta
	var drive := Input.get_axis(prefix + "back", prefix + "forward")
	velocity = Vector2.RIGHT.rotated(rotation) * drive * (forward_speed if drive > 0.0 else reverse_speed)
	move_and_slide()
	tread_phase = fmod(tread_phase + velocity.length() * delta * 0.15, 8.0)
	if Input.is_action_pressed(prefix + "fire") and cooldown <= 0.0 and active_shells < max_shells:
		shot_requested.emit(self)
	queue_redraw()

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
	# The body points right; turning the body also aims the barrel.
	draw_circle(Vector2(2, 3), 22, Color(0, 0, 0, 0.22))
	for y in [-19.0, 11.0]:
		draw_rect(Rect2(-20, y, 38, 8), Color("101b26"))
		for x in range(-18, 18, 6):
			draw_line(Vector2(x + tread_phase * 0.5, y + 1), Vector2(x + tread_phase * 0.5, y + 7), Color("63727c"), 2)
	draw_style_box(_plate(tint.darkened(0.32)), Rect2(-18, -12, 34, 24))
	draw_line(Vector2(-12, -9), Vector2(10, -9), tint.lightened(0.3), 2)
	draw_rect(Rect2(0 - recoil, -5, 28, 10), Color("0d1925"))
	draw_rect(Rect2(1 - recoil, -3, 26, 6), tint.lightened(0.15))
	draw_circle(Vector2(-2, 0), 10, tint)
	draw_arc(Vector2(-2, 0), 7, PI * 0.8, PI * 1.8, 12, tint.lightened(0.45), 2, true)
	draw_circle(Vector2(-2, 0), 3, Color("203545"))

func _plate(color: Color) -> StyleBoxFlat:
	var plate := StyleBoxFlat.new()
	plate.bg_color = color
	plate.set_corner_radius_all(4)
	return plate
