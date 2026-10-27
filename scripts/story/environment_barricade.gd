@tool
extends "res://scripts/mission_wall.gd"

const Atlas = preload("res://scripts/story/scenery_atlas.gd")

@export_enum("Factory", "Wasteland", "Forest", "Fortress", "Village", "Capital") var environment: String = "Forest":
	set(value):
		environment = value
		queue_redraw()
@export_enum("Barrier", "Building", "Scrap") var form: String = "Barrier":
	set(value):
		form = value
		queue_redraw()
@export var variation: int = 1:
	set(value):
		variation = value
		queue_redraw()

const COLORS := {
	"Factory": Color("5d7781"), "Wasteland": Color("b09270"),
	"Forest": Color("8c8270"), "Fortress": Color("8e9085"),
	"Village": Color("ac8554"), "Capital": Color("82939d"),
}

func refresh() -> void:
	super.refresh()
	# The inherited rectangle remains the shared physics and ricochet surface.
	color = Color.TRANSPARENT

func _draw() -> void:
	if Atlas.draw(self, Atlas.wall_key(environment, form, variation, size)): return
	draw_rect(Rect2(Vector2(-3, -1), size), Color(0.02, 0.025, 0.02, 0.38))
	var span := size
	var origin := Vector2(-7, -7)
	var turn := 0.0
	# Long wall pieces repeat their detail along the wall, without rotating physics.
	if form != "Building" and size.y > size.x * 1.4:
		origin.x += size.x
		turn = PI / 2
		span = Vector2(size.y, size.x)
	draw_set_transform(origin, turn)
	var base: Color = COLORS.get(environment, COLORS.Forest)
	draw_rect(Rect2(Vector2.ZERO, span), base.darkened(0.4))
	if minf(span.x, span.y) >= 16:
		match environment:
			"Factory": draw_factory(span)
			"Wasteland":
				if form == "Building" and minf(span.x, span.y) >= 48: draw_building(span, false)
				else: draw_salvage(span)
			"Forest": draw_forest(span)
			"Fortress": draw_fortress(span)
			"Village": draw_timber(span)
			"Capital":
				if form == "Building" and minf(span.x, span.y) >= 48: draw_building(span, true)
				else: draw_city_barrier(span)
	# A continuous rim marks the actual solid face beneath chips, vines and cracks.
	draw_line(Vector2(1, 1), Vector2(span.x - 1, 1), base.lightened(0.35), 2)
	draw_line(Vector2(1, 1), Vector2(1, span.y - 1), base.lightened(0.1), 2)
	draw_line(Vector2(1, span.y - 1), span - Vector2.ONE, base.darkened(0.65), 3)
	draw_set_transform(Vector2.ZERO)

func draw_factory(span: Vector2) -> void:
	draw_rect(Rect2(Vector2(3, 3), span - Vector2(6, 6)), Color("354b56"))
	for x in range(6, int(span.x) - 8, 90):
		var width := minf(82, span.x - x - 5)
		draw_rect(Rect2(x, 5, width, span.y - 11), Color("64808a"))
		draw_line(Vector2(x + width - 2, 6), Vector2(x + width - 2, span.y - 7), Color("263d49"), 3)
		for y in [10.0, span.y - 15]:
			for bx in [float(x + 5), x + width - 7]:
				draw_circle(Vector2(bx, y), 2, Color("b6c8c7"))
		if width > 44 and span.y > 35:
			var vent := Rect2(x + 15, 14, width - 30, span.y - 33)
			draw_rect(vent, Color("243b47"))
			for y in range(int(vent.position.y) + 3, int(vent.end.y), 6):
				draw_line(Vector2(vent.position.x + 2, y), Vector2(vent.end.x - 2, y), Color("8da5a8"), 2)
	if span.y >= 28:
		draw_rect(Rect2(3, span.y - 11, span.x - 6, 8), Color("dcb755"))
		for x in range(5, int(span.x) - 15, 23):
			draw_colored_polygon(PackedVector2Array([Vector2(x, span.y - 11), Vector2(x + 7, span.y - 11), Vector2(x + 15, span.y - 3), Vector2(x + 8, span.y - 3)]), Color("283943"))
	if span.y > 60:
		for x in range(22, int(span.x) - 30, 180):
			draw_rect(Rect2(x, 18, 13, 24), Color("253b43"))
			draw_circle(Vector2(x + 6, 24), 3, Color("9ef2c7"))
			draw_circle(Vector2(x + 6, 35), 2, Color("ffc763"))

func draw_salvage(span: Vector2) -> void:
	draw_rect(Rect2(Vector2(3, 3), span - Vector2(6, 6)), Color("6f6550"))
	for y in range(6, int(span.y) - 6, 16):
		var height := minf(13, span.y - y - 4)
		draw_rect(Rect2(5, y, span.x - 10, height), Color("947149") if y % 3 == 0 else Color("686b5b"))
		draw_line(Vector2(6, y + height), Vector2(span.x - 6, y + height), Color("393d33"), 2)
	for x in [span.x * 0.2, span.x * 0.78]:
		draw_rect(Rect2(x, 4, 5, span.y - 8), Color("54483a"))
		draw_circle(Vector2(x + 2.5, 9), 2, Color("c7aa73"))
		draw_circle(Vector2(x + 2.5, span.y - 9), 2, Color("c7aa73"))
	var rng := detail_rng()
	for i in range(6):
		var at := Vector2(rng.randf_range(8, span.x - 10), rng.randf_range(5, span.y - 9))
		draw_rect(Rect2(at, Vector2(minf(12, span.x - at.x - 3), 4)), Color("ae663d"))
	paint_crack(span, Color("343b31"))

func draw_building(span: Vector2, urban: bool) -> void:
	var plaster := Color("8e9da3") if urban else Color("b79a73")
	var trim := Color("4f626c") if urban else Color("746048")
	draw_rect(Rect2(Vector2(3, 3), span - Vector2(6, 6)), plaster)
	# Missing plaster exposes old brick, with urban structures showing steel too.
	var patch := Vector2(minf(42, span.x * 0.33), minf(32, span.y * 0.32))
	paint_bricks(Rect2(Vector2(4, span.y - patch.y - 5), patch), Vector2(17, 9), Color("86634c") if not urban else Color("687b83"))
	if not urban:
		paint_bricks(Rect2(Vector2(span.x - patch.x * 0.7 - 4, 14), Vector2(patch.x * 0.7, patch.y * 0.7)), Vector2(15, 8), Color("947255"))
	else:
		for x in [4.0, span.x - 11]:
			draw_rect(Rect2(x, 13, 7, span.y - 20), Color("627983"))
	draw_rect(Rect2(2, 2, span.x - 4, 12), trim)
	for x in range(7, int(span.x) - 12, 28):
		var roof_width := minf(23, span.x - x - 4)
		draw_colored_polygon(PackedVector2Array([Vector2(x, 4), Vector2(x + roof_width, 4), Vector2(x + roof_width - 3, 10 + (x + variation) % 6), Vector2(x + 3, 12)]), trim.lightened(0.26))
	var window_width := minf(25, span.x * 0.19)
	var window_height := minf(27, maxf(16, span.y * 0.28))
	var rows := maxi(1, int((span.y - 16) / 46)) if urban else maxi(1, int((span.y - 24) / 60))
	var columns := 3 if urban and span.x >= 150 else 2
	for row in range(rows):
		var y := 22.0 + row * 41
		for side in range(columns):
			if columns == 3 and side == 1 and y + window_height > span.y - 43:
				continue
			var x := 13.0 + side * (span.x - 26 - window_width) / (columns - 1)
			var window := Rect2(x, y, window_width, minf(window_height, span.y - y - 10))
			draw_rect(window.grow(3), trim)
			draw_rect(window, Color("25363d") if urban else Color("3d3d30"))
			draw_line(Vector2(x, y + window.size.y * 0.5), Vector2(window.end.x, y + window.size.y * 0.5), trim.lightened(0.15), 2)
			if (row + side + variation) % 2 == 0:
				draw_colored_polygon(PackedVector2Array([Vector2(x + 2, y + 2), Vector2(x + window_width * 0.6, y + 2), Vector2(x + 2, y + window.size.y * 0.55)]), Color("8ca8af") if urban else Color("8c8c65"))
			if not urban or (side + variation) % 3 == 0:
				draw_line(window.position + Vector2(1, window.size.y * 0.75), window.end - Vector2(1, window.size.y * 0.75), Color("826747") if not urban else Color("637179"), 5)
	var door_width := minf(27, span.x * 0.2)
	var door_height := minf(36, span.y * 0.45)
	var door := Rect2(span.x * 0.5 - door_width * 0.5, span.y - door_height - 4, door_width, door_height)
	draw_rect(door.grow(3), trim)
	draw_rect(door, Color("3d4440") if urban else Color("5b4b37"))
	draw_line(door.position + Vector2(2, 5), door.end - Vector2(2, 5), Color("8d7658") if not urban else Color("52656c"), 4)
	draw_rect(Rect2(2, span.y - 7, span.x - 4, 5), trim)
	paint_crack(span, Color("4e5247") if not urban else Color("4e626d"))
	# Exposed reinforcing rods stay inside the solid concrete footprint.
	if urban:
		for y in range(56, int(span.y) - 35, 41):
			draw_rect(Rect2(4, y, span.x - 8, 5), Color("546e7b"))
			draw_line(Vector2(4, y), Vector2(span.x - 4, y), Color("b4c0bc"), 2)
		for x in range(8, int(span.x) - 10, 32):
			draw_line(Vector2(x, 5), Vector2(x + 7, 17), Color("344c58"), 2)
		draw_rect(Rect2(span.x * 0.39, 18, span.x * 0.22, 6), Color("4d798d"))
	else:
		draw_colored_polygon(PackedVector2Array([Vector2(4, span.y - 4), Vector2(4, span.y - 11), Vector2(span.x * 0.2, span.y - 7), Vector2(span.x * 0.31, span.y - 13), Vector2(span.x * 0.44, span.y - 4)]), Color("8b7652"))
		for i in range(4):
			var x := span.x * 0.55 + i * 7
			draw_rect(Rect2(x, span.y * 0.48 + i % 2 * 6, 5, 3), Color("e1c295"))

func draw_forest(span: Vector2) -> void:
	paint_bricks(Rect2(Vector2(3, 3), span - Vector2(6, 6)), Vector2(31, 17), Color("958370"))
	paint_crack(span, Color("43483c"))
	var rng := detail_rng()
	# Moss gathers along the damp capstones and between the surviving bricks.
	for x in range(4, int(span.x) - 4, 9):
		var depth := rng.randf_range(5, minf(15, span.y * 0.38))
		draw_rect(Rect2(x, 3, minf(10, span.x - x - 3), depth), Color("4f7742"))
		draw_circle(Vector2(x + 2, 5), 3, Color("88a458"))
	for i in range(maxi(1, int(span.x / 75))):
		var at := Vector2(rng.randf_range(8, span.x - 8), rng.randf_range(8, span.y - 8))
		for j in range(4):
			var offset := Vector2(j * 3 - 4, (j % 2) * 3)
			draw_circle(at + offset, minf(5, span.y * 0.2), Color("4b6f3d") if j % 2 else Color("70914d"))
	for start_x in [span.x * 0.18, span.x * 0.72]:
		var vine := PackedVector2Array()
		for i in range(6):
			var at := Vector2(start_x + sin(i * 1.7 + variation) * minf(9, span.x * 0.08), 5 + i * (span.y - 10) / 5)
			vine.append(at)
			draw_line(at, at + Vector2(5 if i % 2 == 0 else -5, -3), Color("7da459"), 3)
			draw_circle(at + Vector2(4 if i % 2 == 0 else -4, -2), 3, Color("628f48"))
		draw_polyline(vine, Color("34533b"), 2, true)
	for x in [8.0, span.x - 9]:
		draw_colored_polygon(PackedVector2Array([Vector2(x, span.y - 4), Vector2(x - 4, span.y - 12), Vector2(x + 1, span.y - 9), Vector2(x + 5, span.y - 15), Vector2(x + 3, span.y - 4)]), Color("607c47"))

func draw_fortress(span: Vector2) -> void:
	paint_bricks(Rect2(Vector2(3, 3), span - Vector2(6, 6)), Vector2(43, 23), Color("99998b"))
	for x in range(12, int(span.x) - 6, 84):
		draw_rect(Rect2(x, 3, minf(7, span.x - x - 3), span.y - 6), Color("4e605e"))
		for y in [7.0, span.y - 8]:
			draw_circle(Vector2(x + 3, y), 2, Color("dcc88b"))
	if span.y > 40:
		for x in range(30, int(span.x) - 17, 84):
			draw_rect(Rect2(x, 10, 18, minf(25, span.y - 18)), Color("66594a"))
			draw_rect(Rect2(x + 3, 12, 12, minf(18, span.y - 22)), Color("d0b770"))
			draw_line(Vector2(x + 9, 15), Vector2(x + 9, minf(28, span.y - 8)), Color("77683e"), 2)
	else:
		for x in range(12, int(span.x) - 12, 43):
			draw_rect(Rect2(x, 4, minf(24, span.x - x - 3), minf(5, span.y - 8)), Color("c3be9f"))

func draw_timber(span: Vector2) -> void:
	draw_rect(Rect2(Vector2(3, 3), span - Vector2(6, 6)), Color("644d33"))
	for y in range(4, int(span.y) - 3, 14):
		var height := minf(11, span.y - y - 3)
		draw_rect(Rect2(4, y, span.x - 8, height), Color("b28b57") if y % 3 else Color("9f744b"))
		draw_line(Vector2(7, y + 3), Vector2(span.x - 8, y + 3), Color("d3ac71"), 1)
		for x in range(21, int(span.x) - 15, 42):
			draw_arc(Vector2(x, y + 6), 3, 0, TAU, 10, Color("7c5836"), 1)
	for x in [13.0, span.x - 19]:
		draw_rect(Rect2(x - 1, 3, 8, span.y - 6), Color("5b4934"))
		for offset in [0, 3]:
			draw_line(Vector2(x + offset, 4), Vector2(x + offset, span.y - 5), Color("d0bb80"), 2)
	for x in range(25, int(span.x) - 10, 34):
		draw_line(Vector2(x, span.y - 4), Vector2(x - 2, span.y - 10), Color("617544"), 2)
		draw_circle(Vector2(x - 2, span.y - 10), 2.5, Color("e7c76e") if (x + variation) % 2 else Color("e491a0"))

func draw_city_barrier(span: Vector2) -> void:
	draw_rect(Rect2(Vector2(3, 3), span - Vector2(6, 6)), Color("8b9ca3"))
	draw_rect(Rect2(4, span.y * 0.58, span.x - 8, minf(11, span.y * 0.28)), Color("4c7187"))
	for x in range(9, int(span.x) - 13, 31):
		draw_rect(Rect2(x, span.y * 0.58 + 2, 14, minf(6, span.y * 0.17)), Color("c4cfc9"))
	paint_crack(span, Color("425e6b"))
	for x in range(14, int(span.x) - 8, 44):
		draw_line(Vector2(x, 4), Vector2(x + 8, minf(17, span.y - 4)), Color("3a515b"), 2)
		draw_rect(Rect2(x - 3, 3, 9, 4), Color("b7c0b9"))

func paint_bricks(bounds: Rect2, brick_size: Vector2, tint: Color) -> void:
	draw_rect(bounds, tint.darkened(0.4))
	var row := 0
	for y in range(int(bounds.position.y), int(bounds.end.y), int(brick_size.y)):
		var offset := brick_size.x * 0.5 if (row + variation) % 2 else 0.0
		for x in range(int(bounds.position.x - offset), int(bounds.end.x), int(brick_size.x)):
			var block := Rect2(Vector2(x + 1, y + 1), brick_size - Vector2(3, 3)).intersection(bounds)
			if block.size.x > 0 and block.size.y > 0:
				var shade := ((x + y + variation * 7) % 13) / 100.0
				draw_rect(block, tint.lightened(shade - 0.06))
				draw_line(block.position, block.position + Vector2(block.size.x, 0), tint.lightened(0.2), 1)
		row += 1

func paint_crack(span: Vector2, tint: Color) -> void:
	var x := span.x * (0.35 + (variation % 4) * 0.09)
	draw_polyline(PackedVector2Array([Vector2(x, 3), Vector2(x - 6, span.y * 0.3), Vector2(x + 7, span.y * 0.52), Vector2(x - 1, span.y * 0.7), Vector2(x + 5, span.y - 4)]), tint, 2, true)

func detail_rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = variation * 941 + 37
	return rng
