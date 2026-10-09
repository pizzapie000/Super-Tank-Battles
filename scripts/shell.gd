class_name DuelShell
extends CharacterBody2D

signal bounced(point: Vector2)
signal impact(point: Vector2)

@export var speed: float = 300.0
@export var max_bounces: int = 3
@export var is_missile: bool = false
const RADIUS: float = 3.5
var shooter: DuelTank
var direction: Vector2 = Vector2.RIGHT
var tint: Color = Color.WHITE
var age: float = 0.0
var bounce_count: int = 0
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
	if not armed and age >= 0.09:
		armed = true
		if is_instance_valid(shooter):
			remove_collision_exception_with(shooter)
	trail.push_front(global_position)
	if trail.size() > (30 if is_missile else 8):
		trail.pop_back()
	# Consume the remaining motion after each bounce to avoid tunneling or losing speed.
	var motion := direction * speed * delta
	for iteration in range(4):
		var collision := move_and_collide(motion)
		if collision == null:
			break
		var target := collision.get_collider()
		if target is DuelShell:
			if target.released:
				add_collision_exception_with(target)
				motion = collision.get_remainder()
				continue
			impact.emit((global_position + target.global_position) * 0.5)
			target.retire()
			retire()
			return
		if target.has_method("detonate"):
			target.detonate()
			retire()
			return
		if target is DuelTank:
			impact.emit(global_position)
			target.take_hit()
			retire()
			return
		direction = direction.bounce(collision.get_normal()).normalized()
		motion = collision.get_remainder().bounce(collision.get_normal())
		bounce_count += 1
		bounced.emit(global_position)
		if bounce_count >= max_bounces:
			retire()
			return
	queue_redraw()

func retire() -> void:
	if released:
		return
	released = true
	# Remove the body immediately so a third shot cannot collide with a shot
	# already waiting for queue_free at the end of this frame.
	collision_layer = 0
	collision_mask = 0
	visible = false
	if is_instance_valid(shooter):
		shooter.active_shells = maxi(0, shooter.active_shells - 1)
	queue_free()

func unobstructed_fraction(delta: float) -> float:
	var motion := direction * speed * delta
	if motion.is_zero_approx():
		return 1.0
	var saved_mask := collision_mask
	collision_mask &= ~4
	var hit := move_and_collide(motion, true)
	collision_mask = saved_mask
	return clampf(hit.get_travel().length() / motion.length(), 0.0, 1.0) if hit != null else 1.0

static func resolve_interceptions(children: Array[Node], delta: float) -> void:
	# Use relative swept motion for both shots. Sequential body movement alone
	# can miss perpendicular paths when fast shots cross between physics ticks.
	var shells: Array[DuelShell] = []
	var limits: Array[float] = []
	for child in children:
		if child is DuelShell and not child.released and child.flight_enabled:
			shells.append(child)
			limits.append(child.unobstructed_fraction(delta))
	var encounters: Array[Dictionary] = []
	for i in range(shells.size()):
		for j in range(i + 1, shells.size()):
			var first := shells[i]
			var second := shells[j]
			var offset := first.global_position - second.global_position
			var relative := (first.direction * first.speed - second.direction * second.speed) * delta
			var a := relative.length_squared()
			var c := offset.length_squared() - pow(RADIUS * 2.0, 2.0)
			var time: float = 0.0
			if c > 0.0:
				if a < 0.00001:
					continue
				var b := 2.0 * offset.dot(relative)
				var discriminant := b * b - 4.0 * a * c
				if discriminant < 0.0:
					continue
				time = (-b - sqrt(discriminant)) / (2.0 * a)
			if time < 0.0 or time > minf(limits[i], limits[j]):
				continue
			var point := (first.global_position + first.direction * first.speed * delta * time + second.global_position + second.direction * second.speed * delta * time) * 0.5
			encounters.append({"time": time, "first": first, "second": second, "point": point})
	encounters.sort_custom(func(a: Dictionary, b: Dictionary): return float(a.time) < float(b.time))
	for encounter in encounters:
		var first: DuelShell = encounter.first
		var second: DuelShell = encounter.second
		if first.released or second.released:
			continue
		first.impact.emit(encounter.point)
		first.retire()
		second.retire()

func _draw() -> void:
	for i in range(1, trail.size()):
		var fade := 1.0 - float(i) / trail.size()
		if is_missile:
			draw_line(to_local(trail[i]), to_local(trail[i - 1]), Color("b9c8c2", fade * 0.45), 6.0 * fade, true)
			draw_circle(to_local(trail[i]), 2.0 + (1.0 - fade) * 4.0, Color("8bada0", fade * 0.13))
		else:
			draw_line(to_local(trail[i]), to_local(trail[i - 1]), Color(tint, fade * 0.4), 3.0 * fade, true)
	if is_missile:
		draw_set_transform(Vector2.ZERO, direction.angle())
		draw_circle(Vector2.ZERO, 8, Color(tint, 0.16))
		draw_colored_polygon(PackedVector2Array([Vector2(-6, -2), Vector2(-17 - sin(age * 45.0) * 3, 0), Vector2(-6, 2)]), Color("ffb754"))
		draw_colored_polygon(PackedVector2Array([Vector2(-5, -3), Vector2(-8, -6), Vector2(-2, -3), Vector2(5, -3), Vector2(10, 0), Vector2(5, 3), Vector2(-2, 3), Vector2(-8, 6), Vector2(-5, 3)]), tint.lightened(0.45))
		draw_line(Vector2(-4, 0), Vector2(5, 0), Color("f1f7ee"), 2.0)
		draw_set_transform(Vector2.ZERO)
		return
	draw_circle(Vector2.ZERO, 7, Color(tint, 0.12))
	draw_circle(Vector2.ZERO, 3.5, tint)
	draw_circle(Vector2(-1, -1), 1.5, Color.WHITE)
