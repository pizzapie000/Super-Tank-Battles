extends Node2D
## Ground impressions and a quiet shared engine bed for every battle mode.

const MOVEMENT = preload("res://assets/audio/tank_movement.wav")
const MARK_LIFETIME: float = 5.0
const MARK_SPACING: float = 6.0
const MAX_MARKS: int = 2200
const MAX_VOLUME_DB: float = -24.0

var arena: Node2D
var marks: Array[Dictionary] = []
var samples: Dictionary = {}
var movement_audio: AudioStreamPlayer
var sound_level: float = 0
var visual_dirty := true

func _process(_delta: float) -> void:
	if visual_dirty:
		visual_dirty = false
		queue_redraw()

func _ready() -> void:
	# Sample after tanks finish moving, including StoryTank's party/repair locks.
	process_physics_priority = 10
	movement_audio = AudioStreamPlayer.new()
	movement_audio.name = "MovementRumble"
	var loop: AudioStreamWAV = MOVEMENT.duplicate()
	loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
	loop.loop_begin = 0
	loop.loop_end = roundi(loop.get_length() * loop.mix_rate)
	movement_audio.stream = loop
	movement_audio.volume_db = -80
	add_child(movement_audio)

func _physics_process(delta: float) -> void:
	if is_instance_valid(arena):
		step(arena.tanks, delta, arena.active, arena.paused)

func step(tanks: Array[DuelTank], delta: float, enabled: bool, paused: bool) -> void:
	movement_audio.stream_paused = paused
	if paused:
		return
	var had_marks := not marks.is_empty()
	for mark in marks:
		mark.age += delta
	while not marks.is_empty() and float(marks[0].age) >= MARK_LIFETIME:
		marks.pop_front()
	var present: Dictionary = {}
	var loudest: float = 0
	var focus: Vector2 = get_canvas_transform().affine_inverse() * get_viewport_rect().get_center()
	for tank in tanks:
		if not is_instance_valid(tank) or not tank.alive:
			continue
		var key := tank.get_instance_id()
		present[key] = true
		var at := tank.global_position
		var angle := tank.global_rotation
		var previous: Dictionary = samples.get(key, {"position": at, "angle": angle, "remainder": 0.0})
		var distance: float = at.distance_to(previous.position)
		var turn := angle_difference(float(previous.angle), angle)
		var travel := distance + absf(turn) * 17.0
		var remainder: float = previous.remainder
		# Repositioning a tank or loading a checkpoint must never paint a streak.
		if enabled and distance < maxf(80.0, tank.forward_speed * delta * 2) and absf(turn) < PI * 0.65:
			if travel > 0.01:
				var along := MARK_SPACING - remainder
				while along <= travel:
					var weight := along / travel
					marks.append({
						"position": to_local(previous.position.lerp(at, weight)),
						"angle": lerp_angle(float(previous.angle), angle, weight) - global_rotation,
						"age": 0.0,
						"white": tank is EnemyTank and tank.invisible_tank,
					})
					along += MARK_SPACING
				remainder = fposmod(remainder + travel, MARK_SPACING)
				var proximity := 1.0 - smoothstep(300.0, 1000.0, at.distance_to(focus))
				loudest = maxf(loudest, clampf(travel / maxf(delta, 0.001) / 150.0, 0, 1) * proximity)
		else:
			remainder = 0
		samples[key] = {"position": at, "angle": angle, "remainder": remainder}
	for key in samples.keys():
		if not present.has(key):
			samples.erase(key)
	while marks.size() > MAX_MARKS:
		marks.pop_front()
	update_sound(loudest, delta)
	visual_dirty = visual_dirty or had_marks or not marks.is_empty()

func update_sound(target: float, delta: float) -> void:
	# One capped loop prevents a large wave from stacking dozens of engines.
	sound_level = move_toward(sound_level, target, delta / (0.18 if target > sound_level else 0.3))
	if sound_level <= 0.001:
		movement_audio.stop()
		return
	movement_audio.volume_db = MAX_VOLUME_DB + linear_to_db(sound_level)
	movement_audio.pitch_scale = lerpf(0.88, 1.04, sound_level)
	if not movement_audio.playing:
		movement_audio.play()

func _draw() -> void:
	# Stamp positions never move after creation. Two colored line batches keep
	# the same tread width, spacing and continuous fade without a transform and
	# several canvas commands for every impression on the ground.
	var shadows := PackedVector2Array()
	var edges := PackedVector2Array()
	var shadow_colors := PackedColorArray()
	var edge_colors := PackedColorArray()
	for mark in marks:
		var fade := pow(1.0 - float(mark.age) / MARK_LIFETIME, 1.4)
		var shadow := Color(0.08, 0.10, 0.09, 0.32 * fade)
		var edge := Color(0.58, 0.53, 0.43, 0.20 * fade)
		if mark.white:
			# Cloaked tanks still disturb the ground and can be tracked by players.
			edge = Color(0.65, 0.71, 0.72, 0.48 * fade)
		if not mark.has("shadow_points"):
			var shadow_points := PackedVector2Array()
			var edge_points := PackedVector2Array()
			var transform := Transform2D(mark.angle, mark.position)
			for side in [-1, 1]:
				var y: float = side * 17.0
				shadow_points.append(transform * Vector2(0, y - 4))
				shadow_points.append(transform * Vector2(0, y + 4))
				edge_points.append(transform * Vector2(-1.5, y - 3.5))
				edge_points.append(transform * Vector2(-1.5, y + 3.5))
			mark.shadow_points = shadow_points
			mark.edge_points = edge_points
		shadows.append_array(mark.shadow_points)
		edges.append_array(mark.edge_points)
		for side in [-1, 1]:
			shadow_colors.append(shadow)
			edge_colors.append(edge)
	if not shadows.is_empty():
		draw_multiline_colors(shadows, shadow_colors, 3.0)
		draw_multiline_colors(edges, edge_colors, 1.0)
