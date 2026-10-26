extends SceneTree
## --headless --fixed-fps 15 --script res://tests/tank_redraw_smoke.gd
## Four physics ticks per displayed frame reproduce the redraw feedback loop.

class BasicProbe extends DuelTank:
	func control_step(delta: float) -> Vector2:
		turret_angle += delta
		return Vector2(0, 0.4)

class StoryProbe extends "res://scripts/story/story_tank.gd":
	func control_step(delta: float) -> Vector2:
		drive_direction = Vector2.RIGHT
		turret_angle += delta
		return Vector2(0, 0.4)

class EnemyProbe extends EnemyTank:
	func control_step(delta: float) -> Vector2:
		turret_angle += delta
		return Vector2(0, 0.4)

class StoryEnemyProbe extends "res://scripts/story/story_enemy.gd":
	func control_step(delta: float) -> Vector2:
		turret_angle += delta
		return Vector2(0, 0.4)

class ProbeArena extends Node2D:
	var paused := false

var failures := 0
var probes: Array[DuelTank] = []
var draws: Dictionary = {}

func _initialize() -> void:
	Engine.physics_ticks_per_second = 60
	run.call_deferred()
	create_timer(30).timeout.connect(func(): push_error("Tank redraw checks timed out"); quit(1))

func check(condition: bool, message: String) -> void:
	if condition: return
	failures += 1
	push_error(message)

func capture(tank: DuelTank) -> void:
	draws[tank.name].append({"frame": Engine.get_process_frames(), "aim": tank.turret_angle,
		"treads": tank.tread_phase, "opacity": tank.body_opacity, "alive": tank.alive})

func measure(label: String, count: int) -> void:
	var start := Engine.get_process_frames()
	var physics_start := Engine.get_physics_frames()
	for _frame in range(count): await process_frame
	var end := Engine.get_process_frames()
	if label == "active":
		check(Engine.get_physics_frames() - physics_start >= count * 3, "Run this check at --fixed-fps 15 so physics catches up between display updates")
	for tank in probes:
		var counts := {}
		var samples: Array = draws[tank.name].filter(func(row): return row.frame >= start and row.frame < end)
		for row in samples: counts[row.frame] = counts.get(row.frame, 0) + 1
		check(counts.values().all(func(value): return value == 1), "%s %s: physics catch-up must not rebuild the same tank art multiple times per displayed frame" % [tank.name, label])
		if label == "active" and tank.controls_enabled:
			check(counts.size() == count, "%s: continuously changing artwork must refresh every display frame" % tank.name)
			if not samples.is_empty():
				check(samples.back().aim > samples.front().aim and samples.back().treads != samples.front().treads, "%s: turret aim and animated treads must keep updating" % tank.name)
		if label == "inactive and downed" and tank.name == "Story":
			check(samples.any(func(row): return not row.alive), "A downed crew member must refresh its revive artwork with physics disabled")
		if label == "cloaked" and tank.name == "StoryEnemy":
			check(samples.any(func(row): return row.opacity == 0), "The latest cloaked state must reach drawing")
		if label == "restored" and tank.name == "StoryEnemy":
			check(samples.any(func(row): return row.opacity == 1), "A visible powerup carrier must refresh after cloaking")

func run() -> void:
	var arena := ProbeArena.new()
	root.add_child(arena)
	probes.assign([BasicProbe.new(), StoryProbe.new(), EnemyProbe.new(), StoryEnemyProbe.new(),
		load("res://scripts/pvp/pvp_tank.gd").new(), load("res://scripts/input/mission_tank.gd").new()])
	var names := ["Duel", "Story", "Enemy", "StoryEnemy", "PvP", "Mission"]
	for i in range(probes.size()):
		var tank := probes[i]
		tank.name = names[i]
		tank.position = Vector2(120, 80 + i * 80)
		tank.controls_enabled = true
		tank.separate_turret = true
		draws[tank.name] = []
		tank.draw.connect(capture.bind(tank))
		if tank is EnemyTank: tank.arena = arena
		root.add_child(tank)
	# The PvP/mission probes use real input paths with no buttons held.
	probes[4].controls_enabled = false
	probes[5].controls_enabled = false
	for _frame in range(3): await process_frame
	await measure("active", 24)
	for tank in probes:
		tank.controls_enabled = false
		tank.set_physics_process(false)
	probes[1].alive = false
	probes[1].revive_progress = 0.8
	probes[3].dormant = true
	arena.paused = true
	await measure("inactive and downed", 4)
	probes[3].body_opacity = 0
	await measure("cloaked", 4)
	probes[3].equip_carrier("Armor")
	await measure("restored", 4)
	for tank in probes: tank.queue_free()
	arena.queue_free()
	for _frame in range(3): await process_frame
	print("TANK REDRAW SMOKE: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)
