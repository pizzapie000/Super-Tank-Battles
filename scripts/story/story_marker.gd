@tool
extends "res://scripts/mission_spawn.gd"

@export var dormant: bool = false
@export var damaged: bool = false
@export_range(1, 30) var armor: int = 1
@export var boss_title: String = ""

func _ready() -> void:
	super._ready()
	if not Engine.is_editor_hint():
		hide()
