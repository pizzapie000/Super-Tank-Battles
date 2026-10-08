class_name TankMine
extends StaticBody2D

signal exploded(point: Vector2)

var owner_tank: DuelTank
var arena: Node2D
var age: float = 0.0
var frozen: bool = false
var released: bool = false
var fuse: float = 8.0
var blast_radius: float = 78.0

func _ready() -> void:
	collision_layer = 8
	collision_mask = 0
	var shape := CircleShape2D.new()
	shape.radius = 9.0
	var collider := CollisionShape2D.new()
	collider.shape = shape
	add_child(collider)

func _physics_process(delta: float) -> void:
	if frozen or released:
		return
	age += delta
	if age >= fuse:
		detonate()
		return
	if age >= 0.75:
		for tank in arena.tanks:
			if tank.alive and global_position.distance_to(tank.global_position) < 38.0:
				detonate()
				return
	queue_redraw()

func detonate() -> void:
	if released:
		return
	released = true
	if is_instance_valid(owner_tank):
		owner_tank.active_mines = maxi(0, owner_tank.active_mines - 1)
	exploded.emit(global_position)
	# Resolve every victim before the arena evaluates victory, so trades are fair.
	for tank in arena.tanks:
		if tank.alive and global_position.distance_to(tank.global_position) <= blast_radius:
			tank.take_hit()
	for shell in arena.get_node("Shells").get_children():
		if global_position.distance_to(shell.global_position) <= blast_radius:
			shell.retire()
	for mine in arena.get_node("Mines").get_children():
		if mine != self and not mine.released and global_position.distance_to(mine.global_position) <= blast_radius:
			mine.detonate()
	queue_free()

func _draw() -> void:
	var armed := age >= 0.75
	var flashing := age > fuse - 2.0 and sin(age * 22.0) > 0.0
	var color := Color("ff775c") if flashing else Color("f4cc65")
	draw_circle(Vector2.ZERO, 12.0, Color("101923"))
	draw_circle(Vector2.ZERO, 8.0, color.darkened(0.4))
	draw_arc(Vector2.ZERO, 10.0, 0.0, TAU, 24, color, 2.0, true)
	draw_circle(Vector2.ZERO, 3.0, color if armed else Color("8296a5"))
	if armed:
		draw_arc(Vector2.ZERO, 18.0, 0.0, TAU * minf(1.0, age / fuse), 32, Color(color, 0.35), 1.0, true)
