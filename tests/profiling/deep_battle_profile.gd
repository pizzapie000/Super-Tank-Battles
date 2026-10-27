extends "res://tests/battle_benchmark.gd"
## Arguments: mode, checkpoint, players, maximum measured frames, output JSON,
## timing probes (0/1), forced render (0/1), stable cover (0/1), real-time seconds.
## Run each case in a fresh process, sequentially, with a visible window.

const Metrics = preload("res://tests/profiling/profile_metrics.gd")
var render_started_us := 0
var render_wall_ms := 0.0
var render_frames := 0
var hidden_rids: Array[RID] = []
var masked_items := 0

class FramePresenter extends Node:
	func _process(_delta: float) -> void:
		present.call_deferred()
	func present() -> void:
		RenderingServer.force_draw(true)

class TankVisualRefresh extends Node:
	var game: Node
	func _process(_delta: float) -> void:
		if not is_instance_valid(game): return
		for tank in game.tanks:
			if is_instance_valid(tank): tank.queue_redraw()

func _initialize() -> void:
	RenderingServer.frame_pre_draw.connect(func(): render_started_us = Time.get_ticks_usec())
	RenderingServer.frame_post_draw.connect(func():
		render_wall_ms = (Time.get_ticks_usec() - render_started_us) / 1000.0
		render_frames += 1)
	run.call_deferred()
	create_timer(180).timeout.connect(func(): push_error("Deep profile timed out"); quit(1))

func hide_art(item: Node) -> void:
	if item is CanvasItem:
		var rid: RID = item.get_canvas_item()
		RenderingServer.canvas_item_set_visible(rid, false)
		hidden_rids.append(rid)
		masked_items += 1

func script_path(item: Node) -> String:
	return item.get_script().resource_path if item.get_script() != null else ""

func mask_category(game: Node, mode: String) -> void:
	match mode:
		"blank":
			hide_art(game)
			hide_art(game.get_node("HUD/Overlay"))
		"no_world": hide_art(game.get_node("World"))
		"no_tanks":
			for tank in game.tanks: hide_art(tank)
		"no_projectiles":
			for name in ["Shells", "Mines", "Effects"]: hide_art(game.get_node(name))
		"no_marks": hide_art(game.ground_feedback)
		"no_hud": hide_art(game.get_node("HUD/Overlay"))
		"no_trees", "no_solid_props":
			for item in game.get_node("World").find_children("*", "CanvasItem", true, false):
				var tree := script_path(item).ends_with("cover_tree.gd")
				if (mode == "no_trees" and tree) or (mode == "no_solid_props" and not tree and item.has_method("wall_rect")):
					hide_art(item)
		"no_render_loop": RenderingServer.render_loop_enabled = false
	# Server-only masks deliberately leave Node.visible, collision shapes, and
	# the navigation geometry untouched. The simulation still builds its art.

func stats(values: Array) -> Dictionary:
	if values.is_empty(): return {}
	var ordered := values.duplicate()
	ordered.sort()
	var total := 0.0
	for value in ordered: total += float(value)
	return {"median": ordered[ordered.size() / 2], "p95": ordered[mini(ordered.size() - 1, int(ordered.size() * 0.95))], "p99": ordered[mini(ordered.size() - 1, int(ordered.size() * 0.99))], "max": ordered.back(), "mean": total / ordered.size()}

func run() -> void:
	seed(143)
	var args := OS.get_cmdline_user_args()
	var mode := args[0] if args.size() > 0 else "baseline"
	var checkpoint := clampi(int(args[1]), 0, 19) if args.size() > 1 else 8
	var crew_size := clampi(int(args[2]), 1, 4) if args.size() > 2 else 2
	var count := clampi(int(args[3]), 120, 3600) if args.size() > 3 else 360
	var output_path := args[4] if args.size() > 4 else "/private/tmp/super_tank_deep_profile.json"
	DirAccess.make_dir_recursive_absolute(output_path.get_base_dir())
	Metrics.enabled = args.size() > 5 and args[5] == "1"
	var forced_render := args.size() > 6 and args[6] == "1"
	var stable_geometry := args.size() > 7 and args[7] == "1"
	var real_time_seconds := float(args[8]) if args.size() > 8 else 0.0
	Metrics.freeze_tank_art = false
	Metrics.suppress_enemy_idle_redraw = false
	Metrics.disable_tank_aa = false
	Metrics.render_once = false
	if DisplayServer.get_name() != "headless":
		root.title = "Profiling %s — %d" % [mode, OS.get_process_id()]
		DisplayServer.window_move_to_foreground()
	# The ordinary settings and saves are read-only during the experiment.
	PlayerSetup.loaded = true
	PlayerSetup.bindings = [{"kind": "keyboard", "device": -1}, {"kind": "off"}, {"kind": "off"}, {"kind": "off"}]
	StorySession.devices.assign([-1, 7, 9, 12].slice(0, crew_size))
	StorySession.debug_checkpoint = checkpoint
	StorySession.resume_story = false
	var scene_setup_start := Time.get_ticks_usec()
	var game = load("res://scenes/story/Adventure.tscn").instantiate()
	game.save_progress = false
	game.check_devices = false
	root.add_child(game)
	var scene_setup_ms := (Time.get_ticks_usec() - scene_setup_start) / 1000.0
	game.ensure_ground_feedback()
	for crew in game.players:
		var properties := {}
		for property in crew.get_property_list():
			if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE: properties[property.name] = crew.get(property.name)
		crew.set_script(TestDriver)
		for key in properties: crew.set(key, properties[key])
		if not crew.shot_requested.is_connected(game.fire_shell): crew.shot_requested.connect(game.fire_shell)
		crew.invulnerable = true
		crew.position = game.region().global_position + Vector2(620, 550 + crew.player_index * 70)
		crew.equip_part(["Gatling", "Shotgun", "Heat Seeker", "Gatling"][crew.player_index], 3)
	game.update_ambush(0.1)
	if stable_geometry: game.mine_walls.clear()
	var roster: Array = []
	for enemy in game.enemies:
		enemy.armor = 999
		enemy.max_armor = 999
		roster.append({"type": enemy.enemy_name, "position": [enemy.position.x, enemy.position.y]})
	var geometry_hash := hash(var_to_bytes(game.wall_rects))
	var measuring := mode != "timers_off"
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), measuring)
	if real_time_seconds > 0:
		while game.scene_time < 3.0: await process_frame
	else:
		for frame in range(120): await process_frame
	mask_category(game, mode)
	Metrics.render_once = mode == "render_once"
	if Metrics.render_once:
		var refresher := TankVisualRefresh.new()
		refresher.game = game
		refresher.process_priority = 999999
		root.add_child(refresher)
	if forced_render and mode != "no_render_loop" and DisplayServer.get_name() != "headless":
		# Explicitly render once after draw-command rebuilding. This diagnostic
		# path bypasses macOS's automatic window-occlusion skip; compare its full
		# baseline with a normally presented baseline before using its ablations.
		RenderingServer.render_loop_enabled = false
		var presenter := FramePresenter.new()
		presenter.process_priority = 1000000
		root.add_child(presenter)
	Metrics.freeze_tank_art = mode == "freeze_tank_art"
	Metrics.suppress_enemy_idle_redraw = mode == "single_enemy_redraw"
	Metrics.disable_tank_aa = mode == "no_tank_aa"
	if DisplayServer.get_name() != "headless": DisplayServer.window_move_to_foreground()
	if real_time_seconds > 0:
		var settle_until: float = game.scene_time + 0.5
		while game.scene_time < settle_until: await process_frame
	else:
		for frame in range(30): await process_frame
	Metrics.reset()
	var columns := {"frame_ms": [], "process_recent_peak_ms": [], "physics_recent_peak_ms": [], "render_wall_ms": [], "render_setup_cpu_ms": [], "viewport_cpu_ms": [], "viewport_gpu_ms": [], "draw_calls": [], "objects": [], "primitives": [], "shells": [], "marks": []}
	var raw: Array = []
	var ready := FileAccess.open(output_path + ".ready", FileAccess.WRITE)
	ready.store_string(str(OS.get_process_id()))
	ready.close()
	var renders_at_start := render_frames
	var frame_base := Engine.get_process_frames()
	var physics_base := Engine.get_physics_frames()
	var simulation_base: float = game.scene_time
	for frame in range(count):
		var started := Time.get_ticks_usec()
		await process_frame
		var row := {"frame_ms": (Time.get_ticks_usec() - started) / 1000.0,
			"process_recent_peak_ms": Performance.get_monitor(Performance.TIME_PROCESS) * 1000,
			"physics_recent_peak_ms": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000,
			"render_wall_ms": render_wall_ms,
			"render_setup_cpu_ms": RenderingServer.get_frame_setup_time_cpu(),
			"viewport_cpu_ms": RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid()),
			"viewport_gpu_ms": RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()),
			"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			"objects": Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
			"primitives": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
			"shells": game.get_node("Shells").get_child_count(), "marks": game.ground_feedback.marks.size()}
		for key in columns: columns[key].append(row[key])
		row["engine_frame"] = Engine.get_process_frames()
		row["can_draw"] = DisplayServer.window_can_draw() if DisplayServer.get_name() != "headless" else false
		raw.append(row)
		if real_time_seconds > 0 and game.scene_time - simulation_base >= real_time_seconds: break
	var summary := {}
	for key in columns: summary[key] = stats(columns[key])
	var device := RenderingServer.get_rendering_device()
	var timestamp_names: Array = []
	if device != null:
		for index in range(device.get_captured_timestamps_count()): timestamp_names.append(device.get_captured_timestamp_name(index))
	var result := {"mode": mode, "stage": game.region().title, "checkpoint": checkpoint, "players": crew_size,
		"pid": OS.get_process_id(), "version": Engine.get_version_info(), "debug": OS.is_debug_build(),
		"headless": DisplayServer.get_name() == "headless", "renderer": RenderingServer.get_current_rendering_method(),
		"driver": RenderingServer.get_current_rendering_driver_name(), "window_size": str(root.size),
		"texture_size": str(root.get_texture().get_size()), "canvas_transform": str(game.get_canvas_transform()),
		"refresh_hz": DisplayServer.screen_get_refresh_rate() if DisplayServer.get_name() != "headless" else 0,
		"vsync": DisplayServer.window_get_vsync_mode() if DisplayServer.get_name() != "headless" else -1,
		"frame_count": raw.size(), "rendered_frames": render_frames - renders_at_start, "process_frames": Engine.get_process_frames() - frame_base,
		"physics_ticks": Engine.get_physics_frames() - physics_base, "simulation_seconds": game.scene_time - simulation_base,
		"real_time_window_seconds": real_time_seconds,
		"timing_enabled": measuring, "masked_items": masked_items, "geometry_hash": geometry_hash,
		"forced_render": forced_render,
		"stable_geometry": stable_geometry,
		"scene_setup_ms": scene_setup_ms,
		"texture_memory_bytes": Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED),
		"geometry_hash_end": hash(var_to_bytes(game.wall_rects)), "enemy_roster": roster, "enemies": game.enemies.size(),
		"player_shots": game.players.map(func(crew): return crew.total_shots), "summary": summary,
		"script_metrics": Metrics.entries.duplicate(true), "script_frame_metrics": Metrics.frame_entries.duplicate(true),
		"gpu_timestamp_names": timestamp_names, "gpu_timer_available": summary.viewport_gpu_ms.max > 0,
		"render_loop_enabled": RenderingServer.render_loop_enabled, "frames": raw}
	var output := FileAccess.open(output_path, FileAccess.WRITE)
	output.store_string(JSON.stringify(result, "\t"))
	output.close()
	print("DEEP_PROFILE ", JSON.stringify({"mode": mode, "stage": result.stage, "frame_ms": summary.frame_ms, "viewport_cpu_ms": summary.viewport_cpu_ms, "viewport_gpu_ms": summary.viewport_gpu_ms, "render_wall_ms": summary.render_wall_ms, "draw_calls": summary.draw_calls.median, "output": output_path}))
	RenderingServer.render_loop_enabled = true
	Metrics.enabled = false
	game.queue_free()
	for frame in range(8): await process_frame
	StorySession.debug_checkpoint = -1
	quit()
