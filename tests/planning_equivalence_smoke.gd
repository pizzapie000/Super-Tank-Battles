extends SceneTree
## Golden fixtures recorded from the pre-optimization planners, with seeded rooms,
## predictive/bank-only/self-safe shots, mines and traffic-weighted routes.
const Navigation = preload("res://scripts/mission_navigation.gd")
const FIXTURE = "res://tests/fixtures/planning_reference.json"
const Awareness = preload("res://scripts/enemy_mine_awareness.gd")
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(value: bool, message: String) -> void:
	if value: return
	failures += 1
	push_error(message)

func rectangles(raw: Array) -> Array[Rect2]:
	var result: Array[Rect2] = []
	for r in raw: result.append(Rect2(r[0], r[1], r[2], r[3]))
	return result

func vectors(raw: Array) -> Array[Vector2]:
	var result: Array[Vector2] = []
	for v in raw: result.append(Vector2(v[0], v[1]))
	return result

func zones(raw: Array) -> Array[Vector3]:
	var result: Array[Vector3] = []
	for v in raw: result.append(Vector3(v[0], v[1], v[2]))
	return result

func shot(c: Dictionary) -> Dictionary:
	return ShotPlanner.solve(Vector2(c.origin[0], c.origin[1]), Vector2(c.target[0], c.target[1]), Vector2(c.velocity[0], c.velocity[1]), c.speed, rectangles(c.walls), c.bounces, vectors(c.allies), c.minimum, c.simple, c.self_safe, rectangles(c.walls))

func route(c: Dictionary) -> Array[Vector2]:
	var navigation := Navigation.new()
	navigation.build(rectangles(c.walls), Rect2(0, 0, 640, 480))
	return navigation.path(Vector2(c.origin[0], c.origin[1]), Vector2(c.target[0], c.target[1]), zones(c.mines), zones(c.traffic))

func grid_cost(c: Dictionary) -> float:
	var navigation := Navigation.new()
	navigation.build(rectangles(c.walls), Rect2(0, 0, 640, 480))
	var hazards := zones(c.mines)
	var traffic := zones(c.traffic)
	var origin := navigation.closest_cell(Vector2(c.origin[0], c.origin[1]), hazards)
	var target := navigation.closest_cell(Vector2(c.target[0], c.target[1]), hazards)
	if not navigation.points.has(origin) or not navigation.points.has(target): return -1
	var path := navigation.grid_path(origin, target, hazards, traffic)
	if path.is_empty(): return -1
	var total := 0.0
	for point in path.slice(1): total += Navigation.STEP * (1 + navigation.congestion(point, traffic))
	return total

func cases() -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 72391
	var result: Array = []
	for i in range(160):
		var walls: Array = [[-10, -10, 660, 10], [-10, 480, 660, 10], [-10, 0, 10, 480], [640, 0, 10, 480]]
		for _wall in range(5): walls.append([96 + rng.randi_range(0, 12) * 32, 64 + rng.randi_range(0, 8) * 32, rng.randi_range(1, 2) * 32, rng.randi_range(1, 3) * 32])
		var c := {"origin": [rng.randf_range(24, 616), rng.randf_range(24, 456)], "target": [rng.randf_range(24, 616), rng.randf_range(24, 456)], "walls": walls,
			"velocity": [rng.randf_range(-90, 90), rng.randf_range(-60, 60)] if i % 5 == 0 else [0, 0], "speed": 510 if i % 5 == 0 else 300,
			"bounces": i % 3, "minimum": 1 if i % 3 > 0 and i % 2 == 0 else 0, "simple": i % 2 == 1, "self_safe": i % 4 == 0,
			"allies": [[rng.randf_range(40, 600), rng.randf_range(40, 440)]] if i % 4 else [], "mines": [], "traffic": []}
		if i < 60:
			for _hazard in range(3):
				if i % 4: c.mines.append([rng.randf_range(60, 580), rng.randf_range(60, 420), 25])
				if i % 5: c.traffic.append([rng.randf_range(60, 580), rng.randf_range(60, 420), rng.randf_range(70, 130)])
		result.append(c)
	return result

func run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 1 and args[0] == "record":
		var data := cases()
		for i in range(data.size()):
			var plan := shot(data[i])
			if not plan.is_empty(): plan.target = [plan.target.x, plan.target.y]
			data[i].shot = plan
			if i < 60:
				data[i].route = route(data[i]).map(func(v): return [v.x, v.y])
				data[i].grid_cost = grid_cost(data[i])
		var file := FileAccess.open(args[1], FileAccess.WRITE)
		file.store_string(JSON.stringify(data))
		print("Recorded planner reference fixtures")
	else:
		var data: Array = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
		check(data.size() == 160, "Seeded shot and route reference fixtures must be present")
		for i in range(data.size()):
			var c: Dictionary = data[i]
			var plan := shot(c)
			check(plan.is_empty() == c.shot.is_empty(), "Shot availability must match the original planner, case %d" % i)
			if not plan.is_empty() and not c.shot.is_empty():
				check(plan.bounces == c.shot.bounces and absf(angle_difference(plan.angle, c.shot.angle)) < 0.00001 and absf(plan.time - c.shot.time) < 0.00001 and plan.target.distance_to(Vector2(c.shot.target[0], c.shot.target[1])) < 0.001, "Predictive and bank-shot selection must remain equivalent, case %d" % i)
			if c.has("route"):
				var path := route(c)
				check(path.is_empty() == c.route.is_empty(), "Mine/traffic route availability must be preserved, case %d" % i)
				check(absf(grid_cost(c) - c.grid_cost) < 0.001, "Native weighted routes must match the original optimal cost, case %d" % i)
				var navigation := Navigation.new()
				navigation.build(rectangles(c.walls), Rect2(0, 0, 640, 480))
				var anchor := Vector2(c.origin[0], c.origin[1])
				for point in path:
					check(navigation.segment_clear(anchor, point, 17.9) and Awareness.segment_clear(anchor, point, zones(c.mines)), "Alternative equal-cost routes must remain wall- and mine-safe, case %d" % i)
					anchor = point
		print("PLANNING EQUIVALENCE SMOKE: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)
