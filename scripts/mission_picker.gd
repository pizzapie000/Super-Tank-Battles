extends "res://scripts/story/checkpoint_picker.gd"

func _init() -> void:
	heading = "DEBUG / CHOOSE A MISSION"
	description = "Jump to any mission with three lives. Normal mission unlocks stay unchanged."
	item_name = "missions"
	for mission in range(1, 51):
		entries.append({"index": mission - 1, "label": "MISSION %02d" % mission})
