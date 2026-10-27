extends SceneTree

const Filter = preload("res://scripts/input/wii_pointer_filter.gd")
var failures := 0
var results: Array = []

func _initialize() -> void:
	run.call_deferred()
	create_timer(30).timeout.connect(func(): push_error("Wii stability check timed out"); quit(1))

func check(value: bool, message: String) -> void:
	if value: return
	failures += 1
	push_error(message)

func measure(script: Script, fps: int, camera_hz: int) -> Dictionary:
	var filter = script.new()
	var center := Vector2(0.5, 0.5)
	filter.sample(center, 0)
	var sequence := 0
	var next_sample := 0.0
	var energy := 0.0
	var raw_energy := 0.0
	var worst := 0.0
	var raw := center
	for frame in range(fps * 3):
		var time := float(frame) / fps
		while next_sample <= time:
			sequence += 1
			# Repeatable mixed camera quantization plus larger one-report spikes.
			raw = center + Vector2(sin(sequence * 2.1), cos(sequence * 1.7)) * 0.007
			if sequence % 31 == 0: raw += Vector2(0.24, -0.19)
			filter.sample(raw, sequence)
			next_sample += 1.0 / camera_hz
		filter.advance(1.0 / fps)
		if time >= 0.5:
			energy += filter.position.distance_squared_to(center)
			raw_energy += raw.distance_squared_to(center)
			worst = maxf(worst, filter.position.distance_to(center))
	var target := Vector2(0.85, 0.2)
	var settle := 1.0
	next_sample = 0
	for frame in range(ceili(fps * 0.2)):
		var time := float(frame) / fps
		if next_sample <= time:
			sequence += 1
			filter.sample(target, sequence)
			next_sample += 1.0 / camera_hz
		filter.advance(1.0 / fps)
		if filter.position.distance_to(target) < 0.01:
			settle = float(frame + 1) / fps
			break
	return {"display_fps": fps, "camera_hz": camera_hz, "energy": energy, "raw_energy": raw_energy, "worst_normalized_excursion": worst, "sweep_settle_seconds": settle}

func run() -> void:
	var args := OS.get_cmdline_user_args()
	var old: Script = load(args[1]) if args.size() >= 3 and args[0] == "compare" else null
	for fps in [30, 60, 120, 240]:
		for hz in [30, 60, 100]:
			var result := measure(Filter, fps, hz)
			check(result.worst_normalized_excursion < 0.015, "Single-report spikes must not throw aim across the screen at %d FPS / %d Hz" % [fps, hz])
			check(result.energy < result.raw_energy * 0.12, "Mixed jitter and isolated spikes must be strongly attenuated")
			check(result.sweep_settle_seconds <= 0.067, "A real sweep must reach its target promptly at %d FPS / %d Hz" % [fps, hz])
			if old != null: result["before"] = measure(old, fps, hz)
			results.append(result)
	# Timestamped samples must give the same filter target/rate when the UDP
	# queue drains in a batch. Display pauses cannot masquerade as camera speed.
	var batch := Filter.new()
	var spaced := Filter.new()
	for i in range(30):
		var point := Vector2(0.2 + i * 0.01, 0.4)
		batch.sample(point, i, 1000 + i / 60.0)
		spaced.sample(point, i, 1000 + i / 60.0)
		spaced.advance(1.0 / 60)
	check(batch.target == spaced.target and is_equal_approx(batch.cutoff, spaced.cutoff), "Native camera timestamps must isolate velocity from packet batching")
	var before := batch.target
	batch.sample(Vector2.ONE, 29, 1000.5)
	check(batch.target == before, "Repeated heartbeats must not confirm a false camera spike")
	var wii := root.get_node("WiiInput")
	wii.set_process(false)
	var directory: String = wii.aim_trace_directory
	wii.aim_trace_directory = "user://wii_stability_smoke"
	wii.accept_snapshot({"version": 1, "token": wii.token, "seq": 1, "devices": [{"slot": 0, "id": "private-test-identity", "connected": true, "nunchuk": true, "stick": [0, 0], "buttons": 4, "c": false, "z": false, "ir": [0.5, 0.5], "ir_seq": 1, "ir_time": 1000.5}]}, wii.seconds())
	var now: float = wii.seconds()
	wii.pointer_delivery[1000] = [now - 1.5, now - 0.5, now - 0.1]
	check(wii.delivery_hz(1000) == 2, "Game aim rate must count received fresh samples, independently of the bridge camera counter")
	wii.start_aim_trace()
	wii.record_aim_frame(0.02)
	check(wii.aim_trace.size() == 1 and wii.aim_trace[0].has("queued_packets"), "Optional recording must capture frame and backlog timing")
	check(wii.aim_trace[0].devices.size() == 1 and wii.aim_trace[0].devices[0].filtered == [0.5, 0.5] and wii.aim_trace[0].devices[0].buttons == 4, "Aiming traces must capture anonymous raw/filtered readings and fire input together")
	wii.finish_aim_trace()
	var path := ProjectSettings.globalize_path(wii.aim_trace_directory)
	var files := DirAccess.get_files_at(path)
	check(files.size() == 1, "Optional aim test must save a bounded diagnostic file")
	for file in files:
		var text := FileAccess.get_file_as_string(path.path_join(file))
		check(not text.contains(wii.token) and not text.contains("calibration") and not text.contains("identity"), "Aiming diagnostics must exclude connection secrets and saved settings")
		DirAccess.remove_absolute(path.path_join(file))
	DirAccess.remove_absolute(path)
	wii.aim_trace_directory = directory
	if old != null:
		var file := FileAccess.open(args[2], FileAccess.WRITE)
		file.store_string(JSON.stringify(results, "\t"))
	print("WII STABILITY SMOKE: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)
