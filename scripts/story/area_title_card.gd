extends RefCounted

const DURATION := 2.4
const AREAS := {
	"Factory": {"name": "THE FACTORY", "number": 1, "accent": Color("ffd575"), "motto": "Built for a war. Awakened for something more."},
	"Wasteland": {"name": "THE WASTELAND", "number": 2, "accent": Color("ffb477"), "motto": "Beyond the walls, the forgotten still fight."},
	"Forest": {"name": "THE RUINED FOREST", "number": 3, "accent": Color("8fe3b2"), "motto": "Under the canopy, every road has another angle."},
	"Fortress": {"name": "THE FORTRESS", "number": 4, "accent": Color("b9bbff"), "motto": "Breach the ramparts. Break the line."},
	"Village": {"name": "THE VILLAGE", "number": 5, "accent": Color("f3d997"), "motto": "For the first time, the road asks for mercy."},
	"Capital": {"name": "THE FALLEN CAPITAL", "number": 6, "accent": Color("85d9ff"), "motto": "Through the silent streets, toward the last command."},
}

static func centered(canvas: Node2D, font: Font, text: String, y: float, size: int, color: Color) -> void:
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	canvas.draw_string(font, Vector2((1280 - width) / 2, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

static func opacity(progress: float) -> float:
	return smoothstep(0, 0.14, progress) * (1 - smoothstep(0.85, 1, progress))

static func draw_factory_intro(canvas: Node2D, font: Font, stage: String, count: int, progress: float, skip_hint: String) -> void:
	draw(canvas, font, "Factory", stage, 1, count, progress, "")
	centered(canvas, font, skip_hint, 658, 16, Color(Color("8cabbc"), opacity(progress)))
	# Fade every part of the card to black before the assembly's separate clock starts.
	canvas.draw_rect(Rect2(0, 0, 1280, 800), Color(0, 0, 0, 1 - opacity(progress)))

static func draw(canvas: Node2D, font: Font, biome: String, stage: String, checkpoint: int, count: int, progress: float, skip_buttons: String) -> void:
	var area: Dictionary = AREAS[biome]
	var accent: Color = area.accent
	var alpha := opacity(progress)
	canvas.draw_rect(Rect2(0, 0, 1280, 800), Color("0a141d"))
	canvas.draw_rect(Rect2(0, 96, 1280, 608), Color(accent.darkened(0.88), 0.6))
	for line in range(14):
		var x := float(line * 130) - 260 + progress * 22
		canvas.draw_line(Vector2(x, 96), Vector2(x + 300, 704), Color(accent, 0.025), 1)
	canvas.draw_line(Vector2(96, 96), Vector2(1184, 96), Color(accent, alpha * 0.5), 2)
	canvas.draw_line(Vector2(96, 704), Vector2(1184, 704), Color(accent, alpha * 0.5), 2)
	canvas.draw_string(font, Vector2(935, 633), "%02d" % area.number, HORIZONTAL_ALIGNMENT_LEFT, -1, 210, Color(accent, alpha * 0.055))
	canvas.draw_set_transform(Vector2(0, (1 - smoothstep(0, 0.22, progress)) * 16))
	centered(canvas, font, "AREA %02d" % area.number, 238, 20, Color(accent, alpha))
	centered(canvas, font, area.name, 340, 68, Color(Color("f0f5f6"), alpha))
	canvas.draw_line(Vector2(455, 375), Vector2(825, 375), Color(accent, alpha), 3)
	centered(canvas, font, area.motto, 420, 21, Color(Color("bdcbd1"), alpha))
	centered(canvas, font, stage.to_upper(), 514, 27, Color(accent, alpha))
	centered(canvas, font, "CHECKPOINT %02d / %02d" % [checkpoint, count], 552, 18, Color(Color("bdcbd1"), alpha))
	if not skip_buttons.is_empty():
		centered(canvas, font, skip_buttons + " — continue", 658, 16, Color(Color("8cabbc"), alpha))
	canvas.draw_set_transform(Vector2.ZERO)
