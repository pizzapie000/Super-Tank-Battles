extends SceneTree
## --headless --fixed-fps 15: catch-up ticks must not rebuild effects repeatedly.
class Field extends Node2D:
	var tanks: Array[DuelTank] = []
	var active := true
	var paused := false

class Driver extends DuelTank:
	func control_step(_delta: float) -> Vector2: return Vector2(0, 0.4)

var failures := 0
var seen := {}

func _initialize() -> void:
	run.call_deferred()

func check(value: bool, message: String) -> void:
	if value: return
	failures += 1
	push_error(message)

func run() -> void:
	var field := Field.new()
	root.add_child(field)
	var driver := Driver.new()
	driver.position = Vector2(100, 100)
	driver.controls_enabled = true
	root.add_child(driver)
	field.tanks.append(driver)
	var shell = load("res://scenes/projectiles/Shell.tscn").instantiate()
	shell.position = Vector2(100, 300)
	shell.speed = 100
	shell.is_missile = true
	root.add_child(shell)
	var mine = load("res://scripts/tank_mine.gd").new()
	mine.position = Vector2(500, 400)
	mine.arena = field
	mine.fuse = 100
	root.add_child(mine)
	var ground = load("res://scripts/tank_ground_feedback.gd").new()
	ground.arena = field
	root.add_child(ground)
	var effects := {"shell": shell, "mine": mine, "ground": ground}
	for label in effects:
		seen[label] = []
		effects[label].draw.connect(func(): seen[label].append(Engine.get_process_frames()))
	for _frame in range(3): await process_frame
	var start := Engine.get_process_frames()
	var physics := Engine.get_physics_frames()
	for _frame in range(24): await process_frame
	var end := Engine.get_process_frames()
	check(Engine.get_physics_frames() - physics >= 72, "Run effect checks with --fixed-fps 15")
	for label in effects:
		var counts := {}
		for frame in seen[label]:
			if frame >= start and frame < end: counts[frame] = counts.get(frame, 0) + 1
		check(counts.size() == 24 and counts.values().all(func(v): return v == 1), "Animated %s must refresh once per display frame during physics catch-up" % label)
	check(shell.trail.size() == 30 and not ground.marks.is_empty() and mine.age > 1, "Trail samples, tread marks and mine timing must still advance on physics ticks")
	field.paused = true
	driver.set_physics_process(false)
	shell.flight_enabled = false
	mine.frozen = true
	for _frame in range(3): await process_frame
	var shell_age: float = shell.age
	var mine_age: float = mine.age
	var mark_age: float = ground.marks[0].age
	for label in effects: seen[label].clear()
	for _frame in range(5): await process_frame
	check(shell.age == shell_age and mine.age == mine_age and ground.marks[0].age == mark_age, "Pausing must freeze simulation ages")
	for label in effects: check(seen[label].is_empty(), "Paused %s must retain its drawing commands" % label)
	ground.movement_audio.stop()
	field.tanks.clear()
	for effect in effects.values(): effect.queue_free()
	driver.queue_free()
	field.queue_free()
	for _frame in range(3): await process_frame
	print("EFFECT REDRAW SMOKE: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)
