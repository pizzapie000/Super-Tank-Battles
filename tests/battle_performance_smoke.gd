extends SceneTree

var failures := 0

class TestShell extends DuelShell:
	var clear_fraction := 1.0
	var sweeps := 0
	var heading := Vector2.INF
	func unobstructed_fraction(_delta: float, _heading: Vector2 = Vector2.INF) -> float:
		sweeps += 1
		return clear_fraction
	func guided_direction(_delta: float) -> Vector2:
		return heading if heading.is_finite() else direction

class TestArena extends Node2D:
	var player: DuelTank

class TestEnemy extends EnemyTank:
	var validations := 0
	func aimed_path() -> Dictionary:
		validations += 1
		return {"bounces": 0}

func _initialize() -> void:
	run.call_deferred()
	create_timer(40).timeout.connect(func(): push_error("Battle optimization checks timed out"); quit(1))

func check(condition: bool, message: String) -> void:
	if condition: return
	failures += 1
	push_error(message)

func reference(shots: Array[Node], delta: float) -> Dictionary:
	# Exhaustive relative sweeps, with no grid or swept-box candidate filtering.
	var hits: Array[Dictionary] = []
	for i in range(shots.size()):
		for j in range(i + 1, shots.size()):
			if shots[i].released or shots[j].released or not shots[i].flight_enabled or not shots[j].flight_enabled: continue
			var offset: Vector2 = shots[i].position - shots[j].position
			var relative: Vector2 = (shots[i].guided_direction(delta) * shots[i].speed - shots[j].guided_direction(delta) * shots[j].speed) * delta
			var a := relative.length_squared()
			var c := offset.length_squared() - 49.0
			var time := 0.0
			if c > 0:
				if a < 0.00001: continue
				var b := 2 * offset.dot(relative)
				var discriminant := b * b - 4 * a * c
				if discriminant < 0: continue
				time = (-b - sqrt(discriminant)) / (2 * a)
			if time >= 0 and time <= minf(shots[i].clear_fraction, shots[j].clear_fraction):
				hits.append({"time": time, "first": i, "second": j})
	hits.sort_custom(func(a: Dictionary, b: Dictionary): return a.time < b.time)
	var retired := {}
	for hit in hits:
		if not retired.has(hit.first) and not retired.has(hit.second):
			retired[hit.first] = true
			retired[hit.second] = true
	return retired

func shot(at: Vector2, direction: Vector2, speed: float = 300.0) -> TestShell:
	var shell := TestShell.new()
	shell.position = at
	shell.direction = direction
	shell.speed = speed
	root.add_child(shell)
	shell.set_physics_process(false)
	return shell

func compare(shots: Array[Node], delta: float) -> void:
	var expected := reference(shots, delta)
	DuelShell.resolve_interceptions(shots, delta)
	for i in range(shots.size()):
		check(shots[i].released == expected.has(i), "Spatial interception candidates must match exhaustive sweeps, including simultaneous and wall-limited hits")
		shots[i].queue_free()

func run() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 90374
	for trial in range(180):
		var shots: Array[Node] = []
		var count := rng.randi_range(2, 80)
		var delta: float = [1.0 / 60, 0.08, 0.3][trial % 3]
		for i in range(count):
			var at := Vector2(rng.randf_range(-800, 800), rng.randf_range(-550, 550))
			if trial % 4 == 0: at *= 0.12
			var shell := shot(at, Vector2.RIGHT.rotated(rng.randf_range(-PI, PI)), rng.randf_range(100, 2200))
			if i % 7 == 0: shell.clear_fraction = rng.randf_range(0.01, 0.5)
			if i % 11 == 0: shell.heading = shell.direction.rotated(0.2)
			if i % 13 == 0: shell.flight_enabled = false
			shots.append(shell)
		compare(shots, delta)
		if trial % 10 == 0: await process_frame
	# Grid boundaries, negative coordinates, huge sweeps, stationary overlap,
	# and three simultaneous impacts must all retain the original pair order.
	for offset in [Vector2.ZERO, Vector2(-64, -64), Vector2(64, 64)]:
		var shots: Array[Node] = []
		for i in range(3): shots.append(shot(offset, Vector2.RIGHT.rotated(i), 0))
		for i in range(15): shots.append(shot(Vector2(500 + i * 100, 800), Vector2.UP))
		compare(shots, 1.0 / 60)
		shots = [shot(offset - Vector2(10, 0), Vector2.RIGHT, 1200), shot(offset - Vector2(0, 10), Vector2.DOWN, 1200)]
		for i in range(15): shots.append(shot(Vector2(500 + i * 100, 800), Vector2.UP))
		compare(shots, 1.0 / 60)
	var tangent: Array[Node] = [shot(Vector2.ZERO, Vector2.RIGHT, 600), shot(Vector2(10, 7), Vector2.LEFT, 600)]
	for i in range(15): tangent.append(shot(Vector2(500 + i * 100, 800), Vector2.UP))
	compare(tangent, 1.0 / 60)
	var fast: Array[Node] = [shot(Vector2(-100000, 0), Vector2.RIGHT, 200000), shot(Vector2(0, -100000), Vector2.DOWN, 200000)]
	compare(fast, 1.0)
	var spread: Array[Node] = []
	for i in range(100): spread.append(shot(Vector2(i * 200, 200), Vector2.RIGHT))
	DuelShell.resolve_interceptions(spread, 1.0 / 60)
	check(spread.all(func(shell): return shell.sweeps == 0 and not shell.released), "Separated shots must require no speculative physics sweeps")
	for shell in spread: shell.queue_free()
	var arena := TestArena.new()
	root.add_child(arena)
	arena.player = DuelTank.new()
	arena.add_child(arena.player)
	arena.player.position = Vector2(300, 0)
	var enemy := TestEnemy.new()
	arena.add_child(enemy)
	enemy.configure("Brown", arena)
	enemy.aim_target = arena.player
	enemy.plan_timer = 999
	enemy.shot_plan = {"angle": 0.0}
	enemy.cooldown = 0.5
	enemy.control_step(0.01)
	check(enemy.validations == 0 and not enemy.fire_intent, "Reloading enemies must not repeatedly validate a shot they cannot fire")
	enemy.cooldown = 0
	enemy.active_shells = enemy.max_shells
	enemy.control_step(0.01)
	check(enemy.validations == 0 and not enemy.fire_intent, "Enemies with full ammunition slots must skip redundant barrel checks")
	enemy.active_shells = 0
	enemy.control_step(0.01)
	check(enemy.validations == 1 and enemy.fire_intent, "An aligned enemy ready to fire must still validate its actual barrel path")
	arena.queue_free()
	for _cleanup in range(8): await process_frame
	print("BATTLE PERFORMANCE SMOKE: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)
