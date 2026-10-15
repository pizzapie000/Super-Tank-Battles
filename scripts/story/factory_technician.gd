@tool
extends Node2D

const Art = preload("res://scripts/story/factory_art.gd")
var clock: float = 0

func _ready() -> void:
	z_as_relative = false
	z_index = 1

func _process(delta: float) -> void:
	clock += delta
	queue_redraw()

func _draw() -> void:
	Art.technician(self, Vector2.ZERO, clock)
