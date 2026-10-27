class_name DuelShell
extends CharacterBody2D

signal bounced(point: Vector2)
signal impact(point: Vector2)

@export var speed: float = 300.0
@export var max_bounces: int = 3
@export var is_missile: bool = false
const RADIUS: float = 3.5
const INTERCEPTION_CELL: float = 64.0
var shooter: DuelTank
var direction: Vector2 = Vector2.RIGHT
var tint: Color = Color.WHITE
var age: float = 0.0
var bounce_count: int = 0
var released: bool = false
var armed: bool = false
var flight_enabled: bool = true
var trail: Array[Vector2] = []
var ricochet_bonus_damage: int = 0
var homing_targets: Array[DuelTank] = []
var homing_turn_rate: float = 0
var visual_dirty := true

func _process(_delta: float) -> void:
	if visual_dirty:
		visual_dirty = false
		queue_redraw()

func _ready() -> void:
	if is_instance_valid(shooter):
		add_collision_exception_with(shooter)

func _physics_process(delta: float) -> void:
	if not flight_enabled or released:
		return
	direction = guided_direction(delta)
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
		if target.has_method("take_hit"):
			impact.emit(global_position)
			# Every damageable body is a valid victim, including allies and the shooter.
			if target is DuelTank:
				target.take_damage_from(shooter if is_instance_valid(shooter) else null, 1 + (ricochet_bonus_damage if bounce_count > 0 else 0))
			elif target.has_method("take_shell_hit"):
				target.take_shell_hit(1 + (ricochet_bonus_damage if bounce_count > 0 else 0))
			else:
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
	visual_dirty = true

func guided_direction(delta: float) -> Vector2:
	if homing_turn_rate <= 0 or age < 0.2:
		return direction
	var nearest: DuelTank
	var distance: float = INF
	for tank in homing_targets:
		if not is_instance_valid(tank) or not tank.alive or tank == shooter:
			continue
		var next := global_position.distance_squared_to(tank.global_position)
		if next < distance:
			nearest = tank
			distance = next
	if nearest == null:
		return direction
	var offset := nearest.global_position - global_position
	if offset.is_zero_approx(): return direction
	var turn := angle_difference(direction.angle(), offset.angle())
	return direction.rotated(clampf(turn, -homing_turn_rate * delta, homing_turn_rate * delta)).normalized()

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

func unobstructed_fraction(delta: float, heading: Vector2 = Vector2.INF) -> float:
	var motion := (heading if heading.is_finite() else guided_direction(delta)) * speed * delta
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
	var headings: Array[Vector2] = []
	var positions: Array[Vector2] = []
	var sweeps: Array[Rect2] = []
	var large_sweep := false
	for child in children:
		if child is DuelShell and not child.released and child.flight_enabled:
			shells.append(child)
			limits.append(-1.0)
			var heading: Vector2 = child.guided_direction(delta)
			headings.append(heading)
			positions.append(child.global_position)
			var sweep := Rect2(child.global_position, heading * child.speed * delta).abs().grow(RADIUS)
			sweeps.append(sweep)
			var span := Vector2i((sweep.end / INTERCEPTION_CELL).floor()) - Vector2i((sweep.position / INTERCEPTION_CELL).floor()) + Vector2i.ONE
			large_sweep = large_sweep or span.x * span.y > 256
	if shells.size() < 2: return
	# Hash the swept bodies, not just their starting cells: fast crossing shots
	# and collisions exactly on a cell boundary must still become candidates.
	# A huge sweep falls back to pair tests rather than allocating a huge grid.
	var use_grid := shells.size() >= 12 and not large_sweep
	var grid: Dictionary = {}
	var occupied: Array[Array] = []
	if use_grid:
		for i in range(shells.size()):
			var cells: Array[Vector2i] = []
			var first := Vector2i((sweeps[i].position / INTERCEPTION_CELL).floor())
			var last := Vector2i((sweeps[i].end / INTERCEPTION_CELL).floor())
			for y in range(first.y, last.y + 1):
				for x in range(first.x, last.x + 1):
					var cell := Vector2i(x, y)
					cells.append(cell)
					if not grid.has(cell): grid[cell] = []
					grid[cell].append(i)
			occupied.append(cells)
	var encounters: Array[Dictionary] = []
	for i in range(shells.size()):
		var candidates: Array = []
		if use_grid:
			var unique: Dictionary = {}
			for cell in occupied[i]:
				for j in grid[cell]:
					if j > i: unique[j] = true
			candidates = unique.keys()
			# Preserve the original pair order for simultaneous three-way hits.
			candidates.sort()
		else:
			candidates = range(i + 1, shells.size())
		for j in candidates:
			if not sweeps[i].intersects(sweeps[j], true): continue
			var first := shells[i]
			var second := shells[j]
			var offset := positions[i] - positions[j]
			var relative := (headings[i] * first.speed - headings[j] * second.speed) * delta
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
			if time < 0.0 or time > 1.0:
				continue
			# Only prospective collisions need a physics sweep against walls/tanks.
			# Reuse the same homing heading rather than finding its target twice.
			if limits[i] < 0: limits[i] = first.unobstructed_fraction(delta, headings[i])
			if limits[j] < 0: limits[j] = second.unobstructed_fraction(delta, headings[j])
			if time > minf(limits[i], limits[j]): continue
			var point := (positions[i] + headings[i] * first.speed * delta * time + positions[j] + headings[j] * second.speed * delta * time) * 0.5
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
		if homing_turn_rate > 0:
			draw_circle(Vector2(6, 0), 2.5, Color("51edcf"))
			draw_arc(Vector2.ZERO, 12, -PI * 0.65, PI * 0.65, 20, Color("51edcf", 0.7), 1.0, true)
		draw_set_transform(Vector2.ZERO)
		return
	draw_circle(Vector2.ZERO, 7, Color(tint, 0.12))
	draw_circle(Vector2.ZERO, 3.5, tint)
	draw_circle(Vector2(-1, -1), 1.5, Color.WHITE)
