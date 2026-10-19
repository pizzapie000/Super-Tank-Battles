@tool
extends RefCounted

const TREAD_COUNT := 7
const TREAD_LENGTH := 38.0
const TREAD_SPACING := TREAD_LENGTH / TREAD_COUNT

# Shared, individually drawable components for live tanks and the assembly shot.
static func tracks(canvas: CanvasItem, at: Vector2, side: int, phase: float = 0) -> void:
	var center := at + Vector2(0, side * 17)
	var outline := PackedVector2Array([center + Vector2(-22, -3), center + Vector2(-18, -5), center + Vector2(17, -5), center + Vector2(21, -2), center + Vector2(21, 3), center + Vector2(17, 5), center + Vector2(-18, 5), center + Vector2(-22, 2)])
	canvas.draw_colored_polygon(outline, Color("101923"))
	canvas.draw_polyline(outline + PackedVector2Array([outline[0]]), Color("566772"), 1, true)
	for x in [-14, -5, 4, 13]:
		canvas.draw_circle(center + Vector2(x, 0), 3.5, Color("2a3943"))
		canvas.draw_arc(center + Vector2(x, 0), 2.6, 0, TAU, 12, Color("93a1a6"), 1, true)
	for i in range(TREAD_COUNT):
		var x := -19 + fposmod(i * TREAD_SPACING + phase, TREAD_LENGTH)
		canvas.draw_line(center + Vector2(x, -4), center + Vector2(x, 4), Color("7b8c93"), 1.6)
		canvas.draw_line(center + Vector2(x, side * 3), center + Vector2(x + 2, side * 3), Color("bfcbcb"), 1)

static func chassis(canvas: CanvasItem, at: Vector2) -> void:
	canvas.draw_rect(Rect2(at + Vector2(-18, -13), Vector2(35, 26)), Color("1d2b37"))
	for x in [-14, 13]:
		canvas.draw_line(at + Vector2(x, -18), at + Vector2(x, 18), Color("82929a"), 3)
		canvas.draw_circle(at + Vector2(x, 0), 3.5, Color("536777"))
	canvas.draw_rect(Rect2(at + Vector2(-14, -8), Vector2(10, 16)), Color("485761"))
	for y in range(-6, 8, 3):
		canvas.draw_line(at + Vector2(-13, y), at + Vector2(-5, y), Color("c3cac5"), 1)
	canvas.draw_rect(Rect2(at + Vector2(2, -8), Vector2(11, 16)), Color("697572"))

static func armor(canvas: CanvasItem, tint: Color, at: Vector2) -> void:
	var shape := PackedVector2Array([at + Vector2(-19, -8), at + Vector2(-13, -13), at + Vector2(12, -13), at + Vector2(18, -7), at + Vector2(18, 8), at + Vector2(12, 13), at + Vector2(-14, 13), at + Vector2(-19, 8)])
	canvas.draw_colored_polygon(shape, tint.darkened(0.08))
	canvas.draw_polyline(shape + PackedVector2Array([shape[0]]), Color("e9f2ff"), 1, true)
	canvas.draw_colored_polygon(PackedVector2Array([at + Vector2(-13, -12), at + Vector2(11, -12), at + Vector2(14, -8), at + Vector2(-16, -8)]), tint.lightened(0.24))
	canvas.draw_line(at + Vector2(13, -7), at + Vector2(13, 8), tint.darkened(0.45), 2)
	canvas.draw_line(at + Vector2(-17, 9), at + Vector2(11, 9), tint.darkened(0.4), 2)
	# Engine grille, exhaust pipe, tow eyes and corner fasteners.
	canvas.draw_rect(Rect2(at + Vector2(-17, -7), Vector2(8, 14)), Color("142332"))
	for y in [-5, -2, 1, 4]:
		canvas.draw_line(at + Vector2(-16, y), at + Vector2(-10, y), Color("a7b8c2"), 1)
	canvas.draw_line(at + Vector2(-19, 7), at + Vector2(-23, 7), Color("677882"), 3)
	for point in [Vector2(-13, -10), Vector2(10, -10), Vector2(-13, 10), Vector2(10, 10)]:
		canvas.draw_circle(at + point, 1.2, Color("e7eef1"))
	for y in [-7, 7]:
		canvas.draw_arc(at + Vector2(17, y), 2, -PI / 2, PI / 2, 8, Color("becbd0"), 1.2, true)

static func turret(canvas: CanvasItem, tint: Color, at: Vector2, recoil: float = 0, barrel_installed: bool = true) -> void:
	canvas.draw_circle(at, 11, Color("13222f"))
	canvas.draw_arc(at, 10, 0, TAU, 28, Color("93a5ae"), 1.5, true)
	if barrel_installed:
		barrel(canvas, tint, at, recoil)
	var shape := PackedVector2Array([at + Vector2(-9, -5), at + Vector2(-5, -9), at + Vector2(4, -9), at + Vector2(9, -4), at + Vector2(9, 4), at + Vector2(4, 9), at + Vector2(-5, 9), at + Vector2(-9, 5)])
	canvas.draw_colored_polygon(shape, tint)
	canvas.draw_polyline(shape + PackedVector2Array([shape[0]]), tint.lightened(0.5), 1, true)
	canvas.draw_line(at + Vector2(-6, -6), at + Vector2(3, -6), tint.lightened(0.5), 1.4)
	canvas.draw_circle(at + Vector2(-5, -4), 3.2, Color("192d3d"))
	canvas.draw_arc(at + Vector2(-5, -4), 2.6, 0, TAU, 16, Color("c8d6dc"), 0.8, true)
	canvas.draw_rect(Rect2(at + Vector2(3, -9), Vector2(4, 2)), Color("93e4ef"))

static func barrel(canvas: CanvasItem, tint: Color, at: Vector2, recoil: float = 0) -> void:
	at -= Vector2(recoil, 0)
	canvas.draw_rect(Rect2(at + Vector2(6, -4), Vector2(21, 8)), Color("172935"))
	canvas.draw_rect(Rect2(at + Vector2(7, -2.5), Vector2(20, 5)), tint.lightened(0.28))
	for x in [12, 21]:
		canvas.draw_rect(Rect2(at + Vector2(x, -3.5), Vector2(2, 7)), Color("7e9aa8"))
	canvas.draw_rect(Rect2(at + Vector2(25, -5), Vector2(6, 10)), Color("344b5b"))
	canvas.draw_line(at + Vector2(26, -4), at + Vector2(30, -4), Color("d4e3e9"), 1)
	canvas.draw_line(at + Vector2(30, -2), at + Vector2(30, 2), Color("0b131c"), 2)
