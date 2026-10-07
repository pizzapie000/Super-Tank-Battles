class_name DuelShell
extends CharacterBody2D

signal bounced(point: Vector2)
signal impact(point: Vector2)

@export var speed: float = 360.0
@export var lifetime: float = 4.0
var shooter: DuelTank
var direction: Vector2 = Vector2.RIGHT
var tint: Color = Color.WHITE
var age: float = 0.0
var released: bool = false
var armed: bool = false
var flight_enabled: bool = true
var trail: Array[Vector2] = []

func _ready() -> void:
	if is_instance_valid(shooter):
		add_collision_exception_with(shooter)

func _physics_process(delta: float) -> void:
	if not flight_enabled or released:
		return
	age += delta
	if age >= lifetime:
		retire()
		return
	if not armed and age >= 0.09:
		armed = true
		if is_instance_valid(shooter):
			remove_collision_exception_with(shooter)
	trail.push_front(global_position)
	if trail.size() > 8:
		trail.pop_back()
	# Consume the remaining motion after each bounce to avoid tunneling or losing speed.
	var motion := direction * speed * delta
	for iteration in range(4):
		var collision := move_and_collide(motion)
		if collision == null:
			break
		var target := collision.get_collider()
		if target is DuelTank:
			impact.emit(global_position)
			target.take_hit()
			retire()
			return
		direction = direction.bounce(collision.get_normal()).normalized()
		motion = collision.get_remainder().bounce(collision.get_normal())
		bounced.emit(global_position)
	queue_redraw()

func retire() -> void:
	if released:
		return
	released = true
	if is_instance_valid(shooter):
		shooter.active_shells = maxi(0, shooter.active_shells - 1)
	queue_free()

func _draw() -> void:
	for i in range(1, trail.size()):
		var fade := 1.0 - float(i) / trail.size()
		draw_line(to_local(trail[i]), to_local(trail[i - 1]), Color(tint, fade * 0.4), 3.0 * fade, true)
	draw_circle(Vector2.ZERO, 7, Color(tint, 0.12))
	draw_circle(Vector2.ZERO, 3.5, tint)
	draw_circle(Vector2(-1, -1), 1.5, Color.WHITE)
