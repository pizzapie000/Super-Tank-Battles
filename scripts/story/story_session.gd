class_name StorySession
extends RefCounted

const COLORS: Array[Color] = [Color("2455ff"), Color("ff951a"), Color("ff1493"), Color("00dfd0")]
const SECTION_COUNT := 12
const LAYOUT_VERSION := 2
const LEGACY_SECTIONS := [0, 1, 2, 4, 6, 9, 10]
const Parts = preload("res://scripts/story/upgrade_parts.gd")
static var devices: Array[int] = [-1]
static var resume_story: bool = false
static var save_path: String = "user://adventure.cfg"

static func checkpoint() -> Dictionary:
	var file := ConfigFile.new()
	if file.load(save_path) != OK:
		return {"chapter": 0, "supplies": 2, "village": "", "complete": false, "parts": Parts.sanitize([])}
	var section := int(file.get_value("story", "chapter", 0))
	if int(file.get_value("story", "layout_version", 1)) < LAYOUT_VERSION:
		section = LEGACY_SECTIONS[clampi(section, 0, LEGACY_SECTIONS.size() - 1)]
	var stored_parts = file.get_value("story", "parts", [])
	return {"chapter": clampi(section, 0, SECTION_COUNT - 1), "supplies": maxi(0, int(file.get_value("story", "supplies", 2))), "village": str(file.get_value("story", "village", "")), "complete": bool(file.get_value("story", "complete", false)), "parts": Parts.sanitize(stored_parts if stored_parts is Array else [])}

static func save(chapter: int, supplies: int, village: String, complete: bool = false, parts: Array[String] = []) -> void:
	var file := ConfigFile.new()
	file.set_value("story", "layout_version", LAYOUT_VERSION)
	file.set_value("story", "chapter", chapter)
	file.set_value("story", "supplies", supplies)
	file.set_value("story", "village", village)
	file.set_value("story", "complete", complete)
	file.set_value("story", "parts", Parts.sanitize(parts))
	file.save(save_path)

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
