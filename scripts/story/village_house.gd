@tool
extends "res://scripts/mission_wall.gd"

@export_enum("South", "North") var entrance_side: String = "South":
	set(value):
		entrance_side = value
		queue_redraw()
@export var plaster_color: Color = Color("d6b781"):
	set(value):
		plaster_color = value
		queue_redraw()
@export var roof_color: Color = Color("a24f3e"):
	set(value):
		roof_color = value
		queue_redraw()
@export var flower_color: Color = Color("ff76b5"):
	set(value):
		flower_color = value
		queue_redraw()
@export var variation: int = 0:
	set(value):
		variation = value
		queue_redraw()
var ruined: bool = false

func refresh() -> void:
	super.refresh()
	# Keep the original editable wall polygon for physics; draw the home over it.
	color = Color.TRANSPARENT

func set_village_state(state: String) -> void:
	ruined = state == "raided"
	queue_redraw()

func _draw() -> void:
	# The house art follows Size, while the front always faces the village street.
	var art_scale := size / Vector2(160, 110)
	var origin := Vector2(-7, -7)
	if entrance_side == "North":
		origin.y += size.y
		art_scale.y *= -1
	draw_set_transform(origin, 0, art_scale)
	var wall := Color("49423a") if ruined else plaster_color
	var tiles := Color("473a34") if ruined else roof_color
	# Porch, paving and the foundation make the solid footprint easy to read.
	draw_rect(Rect2(6, 8, 160, 110), Color(0.08, 0.07, 0.05, 0.36))
	draw_rect(Rect2(56, 108, 48, 19), Color("695d49"))
	for y in [111, 120]:
		draw_rect(Rect2(58, y, 44, 5), Color("c6b38e") if not ruined else Color("655b4d"))
	draw_rect(Rect2(0, 0, 160, 110), wall)
	draw_rect(Rect2(0, 96, 160, 14), Color("706b58"))
	for x in range(0, 160, 20):
		draw_line(Vector2(x, 97), Vector2(x, 109), Color("474b40"), 2)
	draw_line(Vector2(1, 109), Vector2(159, 109), Color("2e332d"), 3)
	# Timber corners and small worn plaster patches.
	for x in [4, 151]:
		draw_rect(Rect2(x, 28, 5, 68), Color("746047") if not ruined else Color("302c28"))
	for at in [Vector2(14, 87), Vector2(137, 38), Vector2(103, 89)]:
		draw_rect(Rect2(at, Vector2(10, 4)), wall.darkened(0.16))
		draw_line(at + Vector2(4, 0), at + Vector2(4, 4), wall.darkened(0.35), 1)
	draw_door()
	draw_window(Vector2(17, 47), ruined)
	draw_window(Vector2(111, 47), ruined)
	# A chimney stands behind the roof, with a soot-dark opening and stone cap.
	draw_rect(Rect2(114, -43, 15, 38), Color("796b5b") if not ruined else Color("4c4640"))
	for y in range(-36, -6, 8):
		draw_line(Vector2(114, y), Vector2(129, y), Color("463e35"), 2)
	draw_rect(Rect2(111, -45, 21, 6), Color("baaa8c") if not ruined else Color("696154"))
	draw_rect(Rect2(115, -45, 13, 3), Color("2d2d2b"))
	var roof := PackedVector2Array([Vector2(-12, 30), Vector2(80, -43), Vector2(172, 30)])
	draw_colored_polygon(roof, tiles)
	# Tile rows stay within the sloped roof silhouette.
	for y in range(-28, 29, 12):
		var inset := 92.0 * (30 - y) / 73.0
		var left := -12 + inset
		var right := 172 - inset
		draw_line(Vector2(left, y), Vector2(right, y), tiles.darkened(0.32), 2)
		for x in range(int(left) + 12 + (y % 3) * 3, int(right) - 5, 22):
			draw_line(Vector2(x, y), Vector2(x + 5, y + 10), tiles.darkened(0.22), 1.5)
	draw_polyline(PackedVector2Array([Vector2(-12, 30), Vector2(80, -43), Vector2(172, 30)]), tiles.lightened(0.3), 3, true)
	draw_rect(Rect2(-12, 28, 184, 6), Color("564334") if not ruined else Color("2b2926"))
	draw_line(Vector2(-10, 35), Vector2(170, 35), Color(0, 0, 0, 0.3), 4)
	# Attic vent, porch light and a little house plaque.
	draw_circle(Vector2(80, 5), 9, Color("604c3b"))
	draw_circle(Vector2(80, 5), 6, Color("b6c9b6") if not ruined else Color("252b29"))
	draw_line(Vector2(74, 5), Vector2(86, 5), Color("504735"), 2)
	draw_line(Vector2(80, -1), Vector2(80, 11), Color("504735"), 2)
	draw_rect(Rect2(66, 43, 28, 9), Color("715b3e"))
	for x in range(70, 91, 7):
		draw_line(Vector2(x, 46), Vector2(x + 3, 46), Color("e0ca93") if not ruined else Color("746954"), 2)
	draw_line(Vector2(101, 47), Vector2(101, 56), Color("4c4434"), 2)
	draw_rect(Rect2(97, 54, 8, 11), Color("c99d4e") if not ruined else Color("3b3730"))
	draw_rect(Rect2(99, 56, 4, 6), Color("fff0a7") if not ruined else Color("242925"))
	draw_planter(Vector2(-15, 88), variation)
	draw_planter(Vector2(176, 94), variation + 2)
	# A rain barrel and a small stack of firewood sit beside the wall.
	draw_rect(Rect2(166, 42, 19, 28), Color("73604a") if not ruined else Color("423d35"))
	for y in [47, 61]:
		draw_line(Vector2(166, y), Vector2(185, y), Color("3c4d49"), 3)
	paint_oval(Vector2(175.5, 42), Vector2(10, 4), Color("af9570") if not ruined else Color("5f5649"))
	paint_oval(Vector2(175.5, 42), Vector2(7, 2), Color("3b5451") if not ruined else Color("2b302a"))
	for i in range(3):
		var at := Vector2(-20 + (i % 2) * 11, 48 + (i / 2) * 8)
		draw_line(at, at + Vector2(13, 0), Color("624a33") if not ruined else Color("38322b"), 7)
		draw_circle(at, 3, Color("c19c66") if not ruined else Color("68604e"))
	if ruined:
		for x in [30, 130]:
			draw_line(Vector2(x - 10, 45), Vector2(x + 13, 77), Color("302d28"), 4)
		draw_polyline(PackedVector2Array([Vector2(29, 33), Vector2(39, 44), Vector2(34, 56), Vector2(43, 68)]), Color("2b2c27"), 3)
		draw_colored_polygon(PackedVector2Array([Vector2(113, 24), Vector2(120, 7), Vector2(135, 18), Vector2(129, 30)]), Color("302d29"))
	draw_set_transform(Vector2.ZERO)

func draw_door() -> void:
	draw_rect(Rect2(62, 59, 36, 50), Color("5a4936") if not ruined else Color("282b27"))
	draw_rect(Rect2(66, 63, 28, 45), Color("87603e") if not ruined else Color("423a30"))
	for x in [72, 79, 86]:
		draw_line(Vector2(x, 64), Vector2(x, 106), Color("503e2f") if not ruined else Color("2b2b26"), 1.5)
	for y in [70, 96]:
		draw_rect(Rect2(66, y, 28, 3), Color("9f7a4d") if not ruined else Color("302e28"))
	draw_circle(Vector2(88, 87), 2.5, Color("f1cb6d") if not ruined else Color("7a735e"))
	draw_rect(Rect2(64, 106, 32, 4), Color("c0ae85") if not ruined else Color("5d5749"))

func draw_window(at: Vector2, broken: bool) -> void:
	draw_rect(Rect2(at - Vector2(3, 3), Vector2(36, 33)), Color("6c5239"))
	draw_rect(Rect2(at, Vector2(30, 26)), Color("f4d58a") if not broken else Color("283333"))
	if not broken:
		draw_colored_polygon(PackedVector2Array([at + Vector2(2, 2), at + Vector2(12, 2), at + Vector2(2, 15)]), Color("fff3bd"))
	draw_line(at + Vector2(15, 0), at + Vector2(15, 26), Color("6c5239"), 3)
	draw_line(at + Vector2(0, 13), at + Vector2(30, 13), Color("6c5239"), 3)
	for side in [-1, 1]:
		var shutter_x := at.x - 11 if side < 0 else at.x + 33
		draw_rect(Rect2(shutter_x, at.y - 1, 8, 28), Color("5c8170") if not broken else Color("414b40"))
		for y in range(3, 26, 6):
			draw_line(Vector2(shutter_x + 1, at.y + y), Vector2(shutter_x + 7, at.y + y), Color("354e43"), 1)
	draw_rect(Rect2(at.x - 3, at.y + 27, 36, 5), Color("b8a27b") if not broken else Color("67614f"))
	draw_rect(Rect2(at.x + 1, at.y + 31, 28, 8), Color("986043") if not broken else Color("4b4033"))
	for i in range(4):
		var leaf := at + Vector2(4 + i * 7, 31)
		draw_circle(leaf, 4, Color("477b45") if not broken else Color("5a5338"))
		if not broken:
			draw_circle(leaf + Vector2(0, -3), 2.5, flower_color if i % 2 == 0 else Color("ffdb66"))

func draw_planter(at: Vector2, seed_value: int) -> void:
	paint_oval(at + Vector2(3, 5), Vector2(14, 6), Color(0.08, 0.08, 0.05, 0.3))
	draw_colored_polygon(PackedVector2Array([at + Vector2(-9, -2), at + Vector2(9, -2), at + Vector2(7, 12), at + Vector2(-7, 12)]), Color("bc7851") if not ruined else Color("655344"))
	draw_rect(Rect2(at + Vector2(-11, -5), Vector2(22, 5)), Color("df9c6c") if not ruined else Color("80705a"))
	for i in range(5):
		var tip := at + Vector2((i - 2) * 5, -13 - ((i + seed_value) % 3) * 5)
		draw_line(at, tip, Color("437744") if not ruined else Color("645b3b"), 2)
		paint_oval(tip, Vector2(6, 3), Color("75a959") if not ruined else Color("706448"))
		if i % 2 == 0 and not ruined:
			draw_circle(tip - Vector2(0, 2), 4, flower_color)
			draw_circle(tip - Vector2(0, 2), 1.5, Color("ffe49a"))

func paint_oval(at: Vector2, radius: Vector2, tint: Color) -> void:
	var points := PackedVector2Array()
	for i in range(20):
		var angle := i * TAU / 20
		points.append(at + Vector2(cos(angle), sin(angle)) * radius)
	draw_colored_polygon(points, tint)
