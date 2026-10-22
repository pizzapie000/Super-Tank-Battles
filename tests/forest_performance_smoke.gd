extends SceneTree

const Navigation = preload("res://scripts/mission_navigation.gd")
var failures := 0

func _initialize() -> void:
	run.call_deferred()
	create_timer(40).timeout.connect(func(): push_error("Forest optimization checks timed out"); quit(1))

func check(condition: bool, message: String) -> void:
	if condition: return
	failures += 1
	push_error(message)

func reference_hit(origin: Vector2, direction: Vector2, walls: Array[Rect2]) -> Dictionary:
	# Straightforward slab oracle independent of the native intersection fast path.
	var nearest := 4000.0
	var result := {}
	for wall in walls:
		var rect := wall.grow(ShotPlanner.RADIUS)
		var low := -INF
		var high := INF
		var normal := Vector2.ZERO
		var misses := false
		for axis in range(2):
			if absf(direction[axis]) < 0.00001:
				if origin[axis] < rect.position[axis] or origin[axis] > rect.end[axis]: misses = true
				continue
			var first: float = (rect.position[axis] - origin[axis]) / direction[axis]
			var last: float = (rect.end[axis] - origin[axis]) / direction[axis]
			if first > last:
				var swap := first
				first = last
				last = swap
			if first > low:
				low = first
				normal = Vector2.ZERO
				normal[axis] = -signf(direction[axis])
			high = minf(high, last)
		if not misses and low > 0.001 and low <= high and low < nearest:
			nearest = low
			result = {"distance": low, "normal": normal, "point": origin + direction * low}
	return result

func compare_hit(origin: Vector2, direction: Vector2, walls: Array[Rect2], boxes: Array[AABB]) -> void:
	var expected := reference_hit(origin, direction, walls)
	var actual := ShotPlanner.first_prepared_wall(origin, direction, boxes)
	check(expected.is_empty() == actual.is_empty(), "Native wall tests must agree with the reference on hits and misses")
	if expected.is_empty() or actual.is_empty(): return
	check(absf(expected.distance - actual.distance) < 0.01 and expected.normal == actual.normal, "Ricochet wall distance and reflection normal must remain unchanged")

func run() -> void:
	StorySession.devices = [-1]
	StorySession.debug_checkpoint = 7
	StorySession.resume_story = false
	var game = load("res://scenes/story/Adventure.tscn").instantiate()
	game.save_progress = false
	game.check_devices = false
	root.add_child(game)
	game.set_process(false)
	game.set_activity(false)
	var walls: Array[Rect2] = game.navigation.walls
	var boxes := ShotPlanner.prepare_walls(walls)
	var rng := RandomNumberGenerator.new()
	rng.seed = 433
	for _ray in range(3000):
		var origin: Vector2 = game.region().global_position + Vector2(rng.randf_range(0, 1600), rng.randf_range(0, 1100))
		var direction := Vector2.RIGHT.rotated(rng.randf_range(-PI, PI))
		compare_hit(origin, direction, walls, boxes)
	for direction in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN, Vector2.ZERO, Vector2(0.000001, 1), Vector2(1, -0.000001)]:
		for wall in walls:
			for origin in [wall.get_center(), wall.position - Vector2(5, 5), wall.end + Vector2(20, 20)]:
				compare_hit(origin, direction, walls, boxes)
	# Reused acceleration data is scoped to one solve, so breached cover cannot linger.
	var removable: Array[Rect2] = [Rect2(100, 0, 20, 100)]
	check(not ShotPlanner.first_wall(Vector2(0, 50), Vector2.RIGHT, removable).is_empty(), "Cover must initially stop the ray")
	removable.clear()
	check(ShotPlanner.first_wall(Vector2(0, 50), Vector2.RIGHT, removable).is_empty(), "Removing a mine-breakable wall must immediately clear subsequent shot tests")
	var navigation := Navigation.new()
	var blocking: Array[Rect2] = [Rect2(100, 100, 100, 100)]
	navigation.build(blocking, Rect2(0, 0, 400, 400))
	var corner := Vector2(87.2, 87.2)
	check(not navigation.path(corner, Vector2(50, 50)).is_empty(), "Fast grid reconnection must retain escape from rounded wall corners")
	navigation.build([], Rect2(0, 0, 400, 400))
	var hazards: Array[Vector3] = [Vector3(144, 144, 25)]
	var safe_cell := navigation.closest_cell(Vector2(141, 141), hazards)
	check(navigation.points.has(safe_cell) and EnemyTank.MineAwareness.point_clear(navigation.points[safe_cell], hazards), "The nearest-cell shortcut must fall back when that cell is threatened by a mine")
	for region in game.get_node("World").get_children():
		check(not region.is_processing(), "Static terrain must keep its cached canvas instead of rebuilding every frame")
	var village = game.village_region()
	village.village_state = "raided"
	check(village.is_processing(), "A raided village must retain its animated smoke")
	village.village_state = "spared"
	check(not village.is_processing(), "A peaceful workshop must return to cached scenery")
	var green = game.enemies.filter(func(enemy): return enemy.enemy_name == "Green")[0]
	green.plan_timer = 0.2
	green.aim_target = null
	green.control_step(0.01)
	check(green.plan_timer > 0.18 and green.shot_plan.is_empty(), "The first target acquisition must preserve the enemy's staggered planning time")
	game.queue_free()
	for _frame in range(8): await process_frame
	StorySession.debug_checkpoint = -1
	print("FOREST PERFORMANCE SMOKE: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)
