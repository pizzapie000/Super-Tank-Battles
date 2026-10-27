extends SceneTree
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(value: bool, message: String) -> void:
	if value: return
	failures += 1
	push_error(message)

func run() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 415721
	var walls: Array[Rect2] = []
	for region in range(20):
		var x := region * 2200.0
		walls.append_array([Rect2(x - 10, -10, 1620, 10), Rect2(x - 10, 1100, 1620, 10), Rect2(x - 10, 0, 10, 1100), Rect2(x + 1600, 0, 10, 1100)])
		for _wall in range(15): walls.append(Rect2(x + rng.randi_range(2, 45) * 32, rng.randi_range(2, 30) * 32, rng.randi_range(1, 5) * 16, rng.randi_range(1, 5) * 16))
	var safety := ShotPlanner.prepare_safety(walls)
	for i in range(4000):
		var origin := Vector2(rng.randf_range(-100, 44000), rng.randf_range(-100, 1200))
		var direction := Vector2.RIGHT.rotated(rng.randf_range(-PI, PI))
		if i % 7 == 0: direction = [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN, Vector2.ZERO, Vector2(0.000001, 1), Vector2(1, -0.000001)][(i / 7) % 7]
		var expected := ShotPlanner.first_prepared_wall(origin, direction, safety.boxes, INF)
		var actual := ShotPlanner.first_safety_wall(origin, direction, safety.boxes, safety.groups)
		check(expected.is_empty() == actual.is_empty(), "Safety broad-phase must preserve hit/miss, sample %d" % i)
		if not expected.is_empty() and not actual.is_empty():
			check(actual.distance == expected.distance and actual.normal == expected.normal and actual.point == expected.point, "Safety broad-phase must preserve the original wall and corner tie, sample %d" % i)
		if failures > 5: break
	var room: Array[Rect2] = [Rect2(-10, -10, 660, 10), Rect2(-10, 480, 660, 10), Rect2(-10, 0, 10, 480), Rect2(640, 0, 10, 480), Rect2(200, 180, 60, 200)]
	var all_walls := room.duplicate()
	all_walls.append_array(walls)
	var cached := ShotPlanner.prepare_safety(all_walls)
	for i in range(40):
		var origin := Vector2(rng.randf_range(30, 610), rng.randf_range(30, 450))
		var target := Vector2(rng.randf_range(30, 610), rng.randf_range(30, 450))
		var plain := ShotPlanner.solve(origin, target, Vector2(0, 70), 510, room, 2, [], 1, false, true, all_walls)
		var optimized := ShotPlanner.solve(origin, target, Vector2(0, 70), 510, room, 2, [], 1, false, true, all_walls, cached)
		check(plain == optimized, "Cached complete-flight safety must select identical bank shots")
	all_walls[0] = Rect2(-10, -100, 660, 10)
	var origin := Vector2(300, 100)
	var target := Vector2(100, 300)
	check(ShotPlanner.solve(origin, target, Vector2.ZERO, 510, room, 2, [], 1, false, true, all_walls) == ShotPlanner.solve(origin, target, Vector2.ZERO, 510, room, 2, [], 1, false, true, all_walls, cached), "Changed wall geometry must invalidate the cached safety snapshot")
	print("SHOT SAFETY CACHE SMOKE: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)
