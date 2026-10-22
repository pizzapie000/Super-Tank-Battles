extends SceneTree
## Run with --fixed-fps 60 so these times measure CPU work, not a frame limiter.
## Arguments: players (1-4), checkpoint (7 = Forest 2, 8 = Forest 3, 9 = Forest 4).
## Example: --script res://tests/forest_benchmark.gd -- 4 8

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	seed(143)
	var args := OS.get_cmdline_user_args()
	var crew_size := clampi(int(args[0]), 1, 4) if not args.is_empty() else 1
	StorySession.devices.assign([-1, 7, 9, 12].slice(0, crew_size))
	StorySession.debug_checkpoint = clampi(int(args[1]), 6, 9) if args.size() > 1 else 7
	StorySession.resume_story = false
	var game = load("res://scenes/story/Adventure.tscn").instantiate()
	game.save_progress = false
	game.check_devices = false
	root.add_child(game)
	for crew in game.players:
		crew.invulnerable = true
		crew.position = game.region().global_position + Vector2(620, 550 + crew.player_index * 70)
	# Keep the same encounter alive in before/after runs, including its mines.
	for enemy in game.enemies:
		enemy.armor = 99
		enemy.max_armor = 99
	for _warmup in range(30): await process_frame
	var samples: Array[float] = []
	for _frame in range(300):
		var tick := Time.get_ticks_usec()
		await process_frame
		samples.append((Time.get_ticks_usec() - tick) / 1000.0)
	samples.sort()
	print("FOREST_BENCHMARK ", JSON.stringify({"players": crew_size, "stage": game.region().title, "frames": samples.size(), "median_ms": samples[samples.size() / 2], "p95_ms": samples[int(samples.size() * 0.95)], "max_ms": samples.back(), "enemies": game.enemies.size(), "headless": DisplayServer.get_name() == "headless"}))
	game.queue_free()
	for _cleanup in range(8): await process_frame
	quit()
