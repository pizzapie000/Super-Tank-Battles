@tool
extends Node2D

const Art = preload("res://scripts/story/factory_art.gd")
@export var flee_destination := Vector2(70, 300)
@export_range(80, 300) var run_speed: float = 185
var clock: float = 0
var home: Vector2
var fleeing: bool = false
var at_safety: bool = false
var panic_time: float = 0

func _ready() -> void:
	z_as_relative = false
	z_index = 1
	home = position
	set_process(Engine.is_editor_hint())

func _process(delta: float) -> void:
	clock += delta
	queue_redraw()

func reset_technician() -> void:
	position = home
	clock = 0
	panic_time = 0
	fleeing = false
	at_safety = false
	show()

func leave_after_intro() -> void:
	fleeing = true
	at_safety = true
	position = flee_destination
	hide()

func update_reaction(crew: Array, delta: float) -> void:
	if at_safety:
		return
	clock += delta
	if not fleeing:
		for tank in crew:
			if tank.moved_distance > 8:
				fleeing = true
				break
	if fleeing:
		panic_time += delta
		if panic_time >= 0.18:
			position = position.move_toward(flee_destination, run_speed * delta)
			if position.distance_to(flee_destination) < 4:
				leave_after_intro()
	queue_redraw()

func _draw() -> void:
	Art.technician(self, Vector2.ZERO, clock, fleeing and panic_time >= 0.18, fleeing)
