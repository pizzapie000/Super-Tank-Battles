extends SceneTree

const Navigation = preload("res://scripts/mission_navigation.gd")
const Awareness = preload("res://scripts/enemy_mine_awareness.gd")
var failures := 0

func _initialize() -> void:
	run.call_deferred()
	create_timer(40).timeout.connect(func(): push_error("Navigation search checks timed out"); quit(1))

func check(condition: bool, message: String) -> void:
	if condition: return
	failures += 1
	push_error(message)

func reference_cost(navigation, origin: Vector2i, target: Vector2i, hazards: Array[Vector3], traffic: Array[Vector3]) -> float:
	# Independent Dijkstra search: no heap, heuristic, or connectivity cache.
	var pending: Array[Vector2i] = [origin]
	var costs := {origin: 0.0}
	var closed := {}
	while not pending.is_empty():
		var best := 0
		for i in range(1, pending.size()):
			if costs[pending[i]] < costs[pending[best]]: best = i
		var cell := pending[best]
		pending.remove_at(best)
		if cell == target: return costs[cell]
		closed[cell] = true
		for next in navigation.links[cell]:
			if closed.has(next) or not Awareness.point_clear(navigation.points[next], hazards) or not Awareness.segment_clear(navigation.points[cell], navigation.points[next], hazards): continue
			var cost: float = costs[cell] + Navigation.STEP * (1 + navigation.congestion(navigation.points[next], traffic))
			if not costs.has(next): pending.append(next)
			if not costs.has(next) or cost < costs[next]: costs[next] = cost
	return INF

func route_cost(navigation, route: Array[Vector2], traffic: Array[Vector3]) -> float:
	var total := 0.0
	for point in route.slice(1):
		total += Navigation.STEP * (1 + navigation.congestion(point, traffic))
	return total

func reference_clear(from: Vector2, to: Vector2, walls: Array[Rect2], clearance: float) -> bool:
	# Brute-force capsule/rectangle distance, without the swept-bounds cull.
	for wall in walls:
		if wall.has_point(from) or wall.has_point(to): return false
		var corners := [wall.position, Vector2(wall.end.x, wall.position.y), wall.end, Vector2(wall.position.x, wall.end.y)]
		for i in range(4):
			var closest := Geometry2D.get_closest_points_between_segments(from, to, corners[i], corners[(i + 1) % 4])
			if closest[0].distance_squared_to(closest[1]) <= clearance * clearance: return false
	return true

func search_cases() -> void:
	var navigation := Navigation.new()
	var walls: Array[Rect2] = [Rect2(160, 128, 64, 128), Rect2(288, 288, 64, 64)]
	navigation.build(walls, Rect2(0, 0, 448, 416))
	var cells: Array = navigation.points.keys()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7841
	for trial in range(36):
		var origin: Vector2i = cells[rng.randi_range(0, cells.size() - 1)]
		var target: Vector2i = cells[rng.randi_range(0, cells.size() - 1)]
		var hazards: Array[Vector3] = []
		var traffic: Array[Vector3] = []
		if trial % 3 != 0:
			for _zone in range(5):
				traffic.append(Vector3(rng.randf_range(40, 408), rng.randf_range(40, 376), rng.randf_range(60, 150)))
		if trial % 3 == 2: hazards.append(Vector3(272, 208, 55))
		if not Awareness.point_clear(navigation.points[origin], hazards) or not Awareness.point_clear(navigation.points[target], hazards): continue
		var expected := reference_cost(navigation, origin, target, hazards, traffic)
		var route := navigation.grid_path(origin, target, hazards, traffic)
		check(route.is_empty() == is_inf(expected), "Search must agree with independent reachability, including dynamic mines")
		if route.is_empty(): continue
		check(route[0] == navigation.points[origin] and route.back() == navigation.points[target], "Search must preserve its requested endpoints")
		check(absf(route_cost(navigation, route, traffic) - expected) < 0.001, "Native and weighted searches must choose a minimum-cost grid route")
		var simplified := navigation.path(navigation.points[origin], navigation.points[target], hazards, traffic)
		check(not simplified.is_empty(), "A reachable grid route must survive simplification")
		var anchor: Vector2 = navigation.points[origin]
		for point in simplified:
			check(navigation.segment_clear(anchor, point, 17.9) and Awareness.segment_clear(anchor, point, hazards), "Simplified routes must retain tank-body and mine clearance")
			anchor = point
	# A mine must not alter the static graph or poison the next request.
	var start := Vector2(80, 80)
	var finish := Vector2(368, 80)
	var sealed: Array[Vector3] = [Vector3(240, 208, 500)]
	check(navigation.path(start, finish, sealed).is_empty(), "Dynamic hazards must still be able to seal all routes")
	check(navigation.can_reach(start, finish) and not navigation.path(start, finish).is_empty(), "Removing hazards must immediately restore an ordinary route")
	# Simulate mine-breakable cover: all static acceleration must be rebuilt.
	walls.assign([Rect2(192, 0, 64, 416)])
	navigation.build(walls, Rect2(0, 0, 448, 416))
	check(not navigation.can_reach(start, finish) and navigation.path(start, finish).is_empty(), "Separate components must reject unreachable cover destinations")
	navigation.build([], Rect2(0, 0, 448, 416))
	check(navigation.can_reach(start, finish) and not navigation.path(start, finish).is_empty(), "Destroyed cover must refresh both connectivity and the native graph")

func forest_crossings() -> void:
	StorySession.devices = [-1]
	StorySession.debug_checkpoint = 7
	StorySession.resume_story = false
	var game = load("res://scenes/story/Adventure.tscn").instantiate()
	game.save_progress = false
	game.check_devices = false
	root.add_child(game)
	game.set_process(false)
	game.set_activity(false)
	var navigation = game.navigation
	var origin: Vector2 = game.region().global_position
	for y in [350, 800]:
		var start := origin + Vector2(700, y)
		var finish := origin + Vector2(900, y)
		check(navigation.can_reach(start, finish) and not navigation.path(start, finish).is_empty(), "Both Forest 3 bridges must remain usable")
	check(not navigation.segment_clear(origin + Vector2(700, 580), origin + Vector2(900, 580)), "The riverbank between bridges must remain solid")
	var rng := RandomNumberGenerator.new()
	rng.seed = 37921
	for trial in range(2000):
		var start := origin + Vector2(rng.randf_range(0, 1600), rng.randf_range(0, 1100))
		var offset := Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * (50 if trial % 2 == 0 else 1400)
		if trial % 11 == 0: offset = Vector2.ZERO
		elif trial % 7 == 0: offset.x = 0
		elif trial % 5 == 0: offset.y = 0
		var clearance: float = [0.0, 17.9, 20.0, 37.0][trial % 4]
		check(navigation.segment_clear(start, start + offset, clearance) == reference_clear(start, start + offset, navigation.walls, clearance), "Swept-body culling must agree with exact wall distances for short, long, parallel and zero-length segments")
	game.queue_free()
	for _cleanup in range(8): await process_frame
	StorySession.debug_checkpoint = -1

func run() -> void:
	search_cases()
	await forest_crossings()
	print("NAVIGATION SEARCH SMOKE: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)
