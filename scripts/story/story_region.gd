@tool
extends Node2D

@export_range(0, 14) var chapter: int = 0
@export_enum("Factory", "Wasteland", "Forest", "Fortress", "Village", "Capital") var biome: String = "Factory"
@export var title: String = "First Light"
@export_multiline var briefing: String = "Operator: One last polish. Let's see if that engine has a soul."
@export_enum("Tutorial", "Escape", "Battle", "Approach", "Village", "Final") var section_type: String = "Battle"
@export_range(1, 30) var reinforcement_interval: float = 5.0
@export var coop_fortress: bool = false
@export var specialist_pool: Array[String] = []
@export var boss_reinforcements: bool = true
@export var forest_crossings: Array[Vector2] = [Vector2(410, 675)]
@export var area: Rect2 = Rect2(0, 0, 1600, 1100)
var clock: float = 0
var village_state: String = "":
	set(value):
		village_state = value
		update_village_houses()
		queue_redraw()

func reset_villagers() -> void:
	for villager in find_children("*", "", true, false):
		if villager.has_method("reset_villager"):
			villager.reset_villager()

func update_villagers(crew_positions: Array[Vector2], delta: float) -> void:
	for villager in find_children("*", "", true, false):
		if villager.has_method("update_flee"):
			villager.update_flee(crew_positions, delta)

func _ready() -> void:
	# Terrain sits below ground props, actors, and the overhead tree canopies.
	z_index = -10
	update_village_houses()

func _process(delta: float) -> void:
	clock += delta
	queue_redraw()

func _draw() -> void:
	var colors := {"Factory": Color("26333b"), "Wasteland": Color("514637"), "Forest": Color("253c33"), "Fortress": Color("303746"), "Village": Color("514838"), "Capital": Color("283747")}
	draw_rect(area, colors[biome])
	var rng := RandomNumberGenerator.new()
	rng.seed = chapter * 347 + 5
	for i in range(70):
		var at := Vector2(rng.randf_range(70, 1530), rng.randf_range(45, 1050))
		match biome:
			"Factory":
				if i < 24:
					draw_rect(Rect2(at, Vector2(50, 3)), Color("394b53"))
			"Wasteland":
				if i % 3 == 0:
					draw_arc(at, rng.randf_range(12, 35), 0, TAU, 24, Color("322d29"), 3)
				else:
					draw_line(at, at + Vector2(16, -6), Color("8a7758"), 2)
			"Forest":
				draw_circle(at, 3, Color("738060"))
			"Fortress", "Capital":
				draw_rect(Rect2(at, Vector2(24, 5)), Color("475563"))
			"Village":
				draw_circle(at, 2, Color("8b7958"))
	# Each location has a recognizable route and landmarks rather than a maze.
	match biome:
		"Factory":
			for x in range(260, 1450, 250):
				draw_rect(Rect2(x, 860, 170, 75), Color("172229"))
				for y in range(868, 935, 12):
					draw_line(Vector2(x + 4, y), Vector2(x + 166, y), Color("536168"), 3)
				for i in range(8):
					draw_line(Vector2(x + i * 20, 942), Vector2(x + i * 20 + 15, 957), Color("dcb957"), 5)
			if chapter == 0:
				for x in [640, 900, 1160]:
					draw_rect(Rect2(x - 50, 345, 100, 210), Color(0.6, 0.75, 0.8, 0.08))
		"Wasteland":
			draw_polyline(PackedVector2Array([Vector2(0, 550), Vector2(420, 630), Vector2(880, 490), Vector2(1600, 550)]), Color("6c5b43"), 125)
			for at in [Vector2(440, 910), Vector2(1250, 220)]:
				draw_set_transform(at, -0.4)
				draw_rect(Rect2(-80, -22, 160, 44), Color("282b28"))
				draw_line(Vector2(-100, 0), Vector2(50, 0), Color("74715c"), 9)
			draw_set_transform(Vector2.ZERO)
		"Forest":
			if forest_crossings.size() == 1:
				draw_polyline(PackedVector2Array([Vector2(0, 550), Vector2(480, 600), Vector2(990, 440), Vector2(1600, 550)]), Color("48513b"), 160)
			else:
				for crossing in forest_crossings:
					var route_y := (crossing.x + crossing.y) * 0.5
					draw_polyline(PackedVector2Array([Vector2(0, 550), Vector2(480, route_y), Vector2(1020, route_y), Vector2(1600, 550)]), Color("48513b"), 120)
			draw_rect(Rect2(740, 0, 100, 1100), Color("16363f"))
			for crossing in forest_crossings:
				draw_rect(Rect2(700, crossing.x, 180, crossing.y - crossing.x), Color("80735b"))
				for y in range(int(crossing.x) + 10, int(crossing.y) - 5, 22):
					draw_line(Vector2(700, y), Vector2(880, y), Color("b09c75"), 3)
		"Fortress":
			draw_rect(Rect2(950, 150, 560, 780), Color("26313e"))
			for x in [990, 1420]:
				draw_rect(Rect2(x, 180, 60, 65), Color("c9b16b"))
				draw_line(Vector2(x + 30, 240), Vector2(x + 30, 900), Color("526278"), 4)
		"Village":
			draw_village_road()
			if section_type == "Village":
				draw_village()
		"Capital":
			draw_rect(Rect2(0, 380, 1600, 340), Color("1d2b37"))
			for x in range(0, 1600, 120):
				draw_rect(Rect2(x, 545, 60, 7), Color("aa9b70"))
			for x in [190, 670, 1190]:
				for y in [100, 835]:
					draw_rect(Rect2(x, y, 170, 150), Color("192734"))
					for wx in range(x + 15, x + 160, 28):
						draw_rect(Rect2(wx, y + 24, 12, 25), Color("667d87"))
	if has_node("Exit"):
		var exit_at: Vector2 = $Exit.position
		var exit_color := Color("ff775c") if $Gate.visible else Color("7cf4bc")
		draw_arc(exit_at, 58, 0, TAU, 32, Color(exit_color, 0.5), 3)
		draw_polyline(PackedVector2Array([exit_at + Vector2(-10, -18), exit_at + Vector2(12, 0), exit_at + Vector2(-10, 18)]), exit_color, 5)
	if Engine.is_editor_hint():
		var font := ThemeDB.fallback_font
		draw_string(font, Vector2(80, 65), "%02d  %s" % [chapter + 1, title.to_upper()], HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color.WHITE)
		for marker_name in ["Start", "Exit"]:
			if has_node(marker_name):
				var at: Vector2 = get_node(marker_name).position
				draw_arc(at, 60, 0, TAU, 32, Color("7cf4bc"), 3)
				draw_string(font, at + Vector2(-35, -75), marker_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color.WHITE)

func draw_village_road() -> void:
	var road := PackedVector2Array([Vector2(0, 550), Vector2(400, 590), Vector2(800, 490), Vector2(1200, 555), Vector2(1600, 550)])
	draw_polyline(road, Color("382f25"), 190)
	draw_polyline(road, Color("9c8055"), 165)
	for side in [-1, 1]:
		var track := PackedVector2Array()
		for point in road:
			track.append(point + Vector2(0, side * 37))
		draw_polyline(track, Color("725c40"), 8)
	if section_type == "Approach":
		for x in range(240, 1500, 220):
			for y in [290, 800]:
				draw_line(Vector2(x, y), Vector2(x + 150, y), Color("b09a6f"), 4)
				for post in [x, x + 150]:
					draw_rect(Rect2(post - 4, y - 18, 8, 32), Color("594832"))

func village_houses() -> Array[Rect2]:
	var houses: Array[Rect2] = []
	for piece in $Walls.get_children():
		if str(piece.name).begins_with("House") and piece.has_method("wall_rect"):
			var bounds: Rect2 = piece.wall_rect()
			houses.append(Rect2(to_local(bounds.position), bounds.size))
	return houses

func draw_village() -> void:
	for house in village_houses():
		var at := house.position
		var north_row := house.get_center().y < 550
		var doorstep := Vector2(house.get_center().x, house.end.y + 22 if north_row else house.position.y - 22)
		var road := Vector2(doorstep.x + 20, 550)
		draw_line(doorstep, road, Color("82704f"), 29)
		for i in range(1, 8):
			var stone := doorstep.lerp(road, i / 8.0)
			draw_rect(Rect2(stone - Vector2(7, 4), Vector2(14, 8)), Color("a59473") if village_state != "raided" else Color("675d4a"))
		if village_state == "raided":
			for i in range(5):
				var age := fmod(clock * 0.3 + i * 0.2, 1)
				draw_circle(at + Vector2(80 + age * 40, -age * 100), 10 + age * 30, Color(0.1, 0.1, 0.1, (1 - age) * 0.45))
	draw_circle($RepairStation.position, 75, Color("244d49") if village_state != "raided" else Color("2d2926"))
	var repair_color := Color("7cf4bc") if village_state != "raided" else Color("594b40")
	draw_line($RepairStation.position - Vector2(20, 0), $RepairStation.position + Vector2(20, 0), repair_color, 10)
	draw_line($RepairStation.position - Vector2(0, 20), $RepairStation.position + Vector2(0, 20), repair_color, 10)

func update_village_houses() -> void:
	var walls := get_node_or_null("Walls")
	if walls == null:
		return
	for house in walls.get_children():
		if house.has_method("set_village_state"):
			house.set_village_state(village_state)

func human(at: Vector2, shirt: Color, arm: float) -> void:
	draw_circle(at - Vector2(0, 15), 7, Color("e2bc91"))
	draw_rect(Rect2(at - Vector2(7, 7), Vector2(14, 20)), shirt)
	draw_line(at + Vector2(-4, 13), at + Vector2(-7, 24), Color("1b2835"), 5)
	draw_line(at + Vector2(4, 13), at + Vector2(7, 24), Color("1b2835"), 5)
	draw_line(at + Vector2(7, -3), at + Vector2(20, -5 + arm * 15), Color("e2bc91"), 4)
