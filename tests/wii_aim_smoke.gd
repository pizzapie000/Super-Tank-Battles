extends SceneTree

const Filter = preload("res://scripts/input/wii_pointer_filter.gd")
const Controls = preload("res://scripts/input/controller_input.gd")
var failures := 0
var sequence := 0
var wii: Node

func _initialize() -> void:
	run.call_deferred()
	create_timer(30).timeout.connect(func(): push_error("Wii aiming check timed out"); quit(1))

func check(condition: bool, message: String) -> void:
	if condition: return
	failures += 1
	push_error(message)

func feed(devices: Array) -> bool:
	sequence += 1
	return wii.accept_snapshot({"version": 1, "token": wii.token, "seq": sequence, "devices": devices}, wii.seconds())

func remote(slot: int, point: Variant, sample_sequence: int) -> Dictionary:
	return {"slot": slot, "id": "aim-smoke-%d" % slot, "connected": true, "nunchuk": true, "stick": [0, 0], "buttons": 0, "c": false, "z": false, "ir": point, "ir_seq": sample_sequence, "ir_status": "tracked", "input_hz": 60, "ir_hz": 60, "dots": [[0.3, 0.4], [0.5, 0.4]]}

func run() -> void:
	wii = Controls.bridge()
	wii.set_process(false)
	var saved_calibration: Dictionary = wii.calibration.duplicate(true)
	wii.calibration.clear()
	# Alternating camera quantization should be reduced without making sweeps slow.
	for fps in [30, 60, 120]:
		var filter := Filter.new()
		filter.sample(Vector2(0.5, 0.5), 0)
		var raw_energy := 0.0
		var filtered_energy := 0.0
		for frame in range(fps * 2):
			var jitter := 0.004 if frame % 2 == 0 else -0.004
			filter.sample(Vector2(0.5 + jitter, 0.5), frame + 1)
			filter.advance(1.0 / fps)
			raw_energy += jitter * jitter
			filtered_energy += pow(filter.position.x - 0.5, 2)
		check(filtered_energy < raw_energy * 0.55, "Small pointer jitter must be reduced at %d FPS" % fps)
		filter.sample(Vector2(0.9, 0.2), fps * 2 + 1)
		for frame in range(ceili(fps * 0.05)): filter.advance(1.0 / fps)
		check(filter.position.distance_to(Vector2(0.9, 0.2)) < 0.01, "A deliberate sweep must respond within 50 ms at %d FPS" % fps)
	# Four pointers remain independent, including different raw reporting rates.
	var devices: Array = []
	for slot in range(4): devices.append(remote(slot, [0.2 + slot * 0.15, 0.3 + slot * 0.1], 0))
	check(feed(devices), "Fresh tracking metadata must be accepted")
	for frame in range(1, 121):
		for slot in range(4):
			var interval: int = [1, 2, 3, 6][slot] # 60, 30, 20 and 10 camera updates/s
			if frame % interval == 0:
				devices[slot].ir = [0.2 + slot * 0.15 + frame * 0.001, 0.3 + slot * 0.1]
				devices[slot].ir_seq += 1
		check(feed(devices), "Camera updates and repeated heartbeats must be accepted")
		wii.advance_pointers(1.0 / 60)
		for slot in range(4):
			var aim: Vector2 = wii.pointer(1000 + slot)
			check(aim.distance_to(Vector2(1 - devices[slot].ir[0], devices[slot].ir[1])) < 0.04, "Slow camera streams must remain responsive without mixing players")
	devices[0].ir = [0.99, 0.99] # Same sample sequence: not a fresh measurement.
	feed(devices)
	check(wii.pointer_filters[1000].target.distance_to(Vector2(0.01, 0.99)) > 0.1, "Bridge heartbeat must not masquerade as a new camera sample")
	devices[0].ir = null
	feed(devices)
	check(wii.pointer(1000) == null and wii.pointer(1001) != null, "Losing one camera must leave other pointers working")
	devices[0].ir = [0.15, 0.8]
	devices[0].ir_seq += 1
	feed(devices)
	check(wii.pointer(1000).distance_to(Vector2(0.85, 0.8)) < 0.0001, "Reacquisition must snap to fresh aim without an old-position glide")
	devices[0].id = "replacement-remote"
	devices[0].ir = [0.8, 0.1]
	feed(devices)
	check(wii.pointer(1000).distance_to(Vector2(0.2, 0.1)) < 0.0001, "A replacement remote must not inherit another player's smoothing history")
	wii.calibration[devices[0].id] = {"top_left": Vector2(0.8, 0.2), "bottom_right": Vector2(0.2, 0.8)}
	wii.pointer_filters.clear()
	devices[0].ir = [0.5, 0.5]
	feed(devices)
	check(wii.pointer(1000).distance_to(Vector2(0.5, 0.5)) < 0.0001, "Saved corner calibration must be applied before smoothing")
	var setup = load("res://scenes/game/WiiSetup.tscn").instantiate()
	root.add_child(setup)
	devices[0].ir_status = "partial"
	feed(devices)
	setup.begin_calibration()
	setup.capture_corner()
	check(setup.phase == 0, "Estimated one-point recovery must never be used to save calibration")
	setup._process(0)
	check(setup.detail_label.text.contains("60 updates/s") and setup.detail_label.text.contains("one-point recovery"), "Setup must show actual report rates and recovery state")
	setup.free()
	var tank = load("res://scripts/story/story_tank.gd").new()
	tank.controls_enabled = false
	root.add_child(tank)
	check(wii.world_aim(1000, tank).distance_to(tank.get_canvas_transform().affine_inverse() * (wii.pointer(1000) * root.get_visible_rect().size)) < 0.001, "The turret and visible reticle must use the exact same aim point")
	tank.queue_free()
	devices[0].ir_seq = -1
	check(not feed(devices), "Invalid camera metadata must be rejected atomically")
	check(wii.pointer(1000) != null, "Rejecting bad metadata must preserve the last complete snapshot")
	wii.disconnect_all()
	check(wii.pointer_filters.is_empty(), "Disconnect must clear all pointer histories")
	wii.calibration = saved_calibration
	print("Wii aiming checks: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)
