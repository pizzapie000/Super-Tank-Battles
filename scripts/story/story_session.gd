class_name StorySession
extends RefCounted

const COLORS: Array[Color] = [Color("2455ff"), Color("ff951a"), Color("ff1493"), Color("00dfd0")]
const SECTION_COUNT := 15
const LAYOUT_VERSION := 5
const LEGACY_SECTIONS := [0, 1, 2, 4, 6, 9, 10]
# Each new third stage inherits its area's former last stage for music and pacing.
const PRE_EXPANSION_SECTIONS := [0, 1, 2, 3, 3, 4, 5, 5, 6, 7, 7, 8, 9, 10, 11]
const Parts = preload("res://scripts/story/upgrade_parts.gd")
static var devices: Array[int] = [-1]
static var resume_story: bool = false
static var save_path: String = "user://adventure.cfg"
static var settings_path: String = "user://story_settings.cfg"
static var skip_tutorial: bool = false
static var debug_checkpoint: int = -1

static func available_checkpoints() -> Array[Dictionary]:
	var world: Node2D = load("res://scenes/story/StoryWorld.tscn").instantiate()
	var result: Array[Dictionary] = []
	for i in range(world.get_child_count()):
		var region := world.get_child(i)
		result.append({"index": i, "title": str(region.title), "biome": str(region.biome)})
	world.free()
	return result

static func checkpoint() -> Dictionary:
	var file := ConfigFile.new()
	if file.load(save_path) != OK:
		return {"chapter": 0, "supplies": 2, "village": "", "complete": false, "parts": Parts.sanitize([]), "part_levels": [0, 0, 0, 0]}
	var section := int(file.get_value("story", "chapter", 0))
	var version := int(file.get_value("story", "layout_version", 1))
	if version < 2:
		section = LEGACY_SECTIONS[clampi(section, 0, LEGACY_SECTIONS.size() - 1)]
	if version < 3 and section >= 7:
		section += 1
	if version < 4:
		# The former standalone boss rejoins the outer gate; the battery stays separate.
		if section == 8:
			section = 6
		elif section > 8:
			section -= 1
	if version < 5:
		# Insert the wasteland, forest and fortress finales before their next areas.
		if section >= 8:
			section += 3
		elif section >= 6:
			section += 2
		elif section >= 4:
			section += 1
	var stored_parts = file.get_value("story", "parts", [])
	var parts := Parts.sanitize(stored_parts if stored_parts is Array else [])
	var stored_levels = file.get_value("story", "part_levels", [])
	return {"chapter": clampi(section, 0, SECTION_COUNT - 1), "supplies": maxi(0, int(file.get_value("story", "supplies", 2))), "village": str(file.get_value("story", "village", "")), "complete": bool(file.get_value("story", "complete", false)), "parts": parts, "part_levels": Parts.levels(stored_levels if stored_levels is Array else [], parts)}

static func save(chapter: int, supplies: int, village: String, complete: bool = false, parts: Array[String] = [], levels: Array[int] = []) -> void:
	var file := ConfigFile.new()
	file.set_value("story", "layout_version", LAYOUT_VERSION)
	file.set_value("story", "chapter", chapter)
	file.set_value("story", "supplies", supplies)
	file.set_value("story", "village", village)
	file.set_value("story", "complete", complete)
	file.set_value("story", "parts", Parts.sanitize(parts))
	file.set_value("story", "part_levels", Parts.levels(levels, parts))
	file.save(save_path)

static func load_preferences() -> void:
	var file := ConfigFile.new()
	file.load(settings_path)
	skip_tutorial = bool(file.get_value("story", "skip_tutorial", false))

static func set_skip_tutorial(enabled: bool) -> void:
	skip_tutorial = enabled
	var file := ConfigFile.new()
	file.set_value("story", "skip_tutorial", enabled)
	file.save(settings_path)

static func add_device(device: int) -> bool:
	if devices.has(device) or devices.size() >= 4:
		return false
	devices.append(device)
	return true

static func stick(value: Vector2, deadzone: float = 0.22) -> Vector2:
	var strength := minf(1, value.length())
	if strength <= deadzone:
		return Vector2.ZERO
	return value.normalized() * (strength - deadzone) / (1 - deadzone)
