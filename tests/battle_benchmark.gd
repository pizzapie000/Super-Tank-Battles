extends SceneTree
## Sustained forest firefight: checkpoint (6-9), crew (1-4), measured frames.
## --headless --fixed-fps 60 --script res://tests/battle_benchmark.gd -- 9 4 600
## Omit --headless to include rendering; use --audio-driver Dummy for silent QA.

class TestDriver extends "res://scripts/story/story_tank.gd":
	var clock := 0.0
	func control_step(delta: float) -> Vector2:
		clock += delta
		turret_angle = fmod(clock * 0.7 + player_index * 0.6, TAU)
		fire_held = true
		return directional_control(Vector2.RIGHT.rotated(clock * 0.8 + player_index * PI / 2) * 0.6)

func _initialize() -> void:
	run.call_deferred()
	create_timer(90).timeout.connect(func(): push_error("Battle benchmark timed out"); quit(1))

func run() -> void:
	seed(143)
	var args := OS.get_cmdline_user_args()
	var checkpoint := clampi(int(args[0]), 6, 9) if args.size() > 0 else 9
	var crew_size := clampi(int(args[1]), 1, 4) if args.size() > 1 else 4
	var count := clampi(int(args[2]), 120, 3600) if args.size() > 2 else 600
	StorySession.devices.assign([-1, 7, 9, 12].slice(0, crew_size))
	StorySession.debug_checkpoint = checkpoint
	StorySession.resume_story = false
	var game = load("res://scenes/story/Adventure.tscn").instantiate()
	game.save_progress = false
	game.check_devices = false
	root.add_child(game)
	game.ensure_ground_feedback()
	for crew in game.players:
		# Preserve the actual spawned tank, its seat, appearance and signals while
		# replacing hardware input with a repeatable driving/firing pattern.
		var properties := {}
		for property in crew.get_property_list():
			if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
				properties[property.name] = crew.get(property.name)
		crew.set_script(TestDriver)
		for key in properties: crew.set(key, properties[key])
		if not crew.shot_requested.is_connected(game.fire_shell): crew.shot_requested.connect(game.fire_shell)
		crew.invulnerable = true
		crew.position = game.region().global_position + Vector2(620, 550 + crew.player_index * 70)
		crew.equip_part(["Gatling", "Shotgun", "Heat Seeker", "Gatling"][crew.player_index], 3)
	game.update_ambush(0.1)
	for enemy in game.enemies:
		enemy.armor = 999
		enemy.max_armor = 999
	var samples: Array[float] = []
	var draw_calls: Array[float] = []
	var peak_shells := 0
	var peak_marks := 0
	for frame in range(count + 120):
		var tick := Time.get_ticks_usec()
		await process_frame
		if frame >= 120:
			samples.append((Time.get_ticks_usec() - tick) / 1000.0)
			draw_calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		peak_shells = maxi(peak_shells, game.get_node("Shells").get_child_count())
		peak_marks = maxi(peak_marks, game.ground_feedback.marks.size())
	samples.sort()
	draw_calls.sort()
	print("BATTLE_BENCHMARK ", JSON.stringify({"stage": game.region().title, "players": crew_size, "enemies": game.enemies.size(), "frames": count, "headless": DisplayServer.get_name() == "headless", "median_ms": samples[count / 2], "p95_ms": samples[int(count * 0.95)], "max_ms": samples.back(), "draw_calls_median": draw_calls[count / 2], "shells_peak": peak_shells, "marks_peak": peak_marks, "player_shots": game.players.map(func(crew): return crew.total_shots)}))
	game.queue_free()
	for _cleanup in range(8): await process_frame
	StorySession.debug_checkpoint = -1
	quit()
