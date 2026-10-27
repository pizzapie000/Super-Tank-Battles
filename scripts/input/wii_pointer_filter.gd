extends RefCounted

# Filter in screen space AFTER calibration. The reticle and turret both read this
# one position; filtering only the artwork would make shots disagree with aim.
var position := Vector2.ZERO
var target := Vector2.ZERO
var initialized := false
var sample_sequence: int = -1
var clock := 0.0
var last_sample_time := 0.0
var previous := Vector2.ZERO
var velocity := Vector2.ZERO
var cutoff := 2.0
var history: Array[Vector2] = []

func sample(point: Vector2, sequence: int, measured_at: float = -1) -> void:
	if sequence >= 0 and sequence == sample_sequence: return
	sample_sequence = sequence
	var now := clock if measured_at < 0 else measured_at
	if not initialized:
		position = point
		target = point
		previous = point
		history.assign([point, point])
		last_sample_time = now
		initialized = true
		return
	# A three-measurement median rejects isolated camera spikes. Heartbeats do
	# not enter this window, so a bad reading cannot confirm itself repeatedly.
	history.append(point)
	if history.size() > 3: history.pop_front()
	target = Vector2(median(history[0].x, history[1].x, history[2].x), median(history[0].y, history[1].y, history[2].y))
	var interval := clampf(now - last_sample_time, 0.004, 0.25)
	var measured_velocity := (target - previous) / interval
	velocity = velocity.lerp(measured_velocity, 1.0 - exp(-TAU * 1.5 * interval))
	# Speed-adaptive low-pass: settle steady aim strongly, follow real sweeps
	# quickly. Camera timestamps keep batching and display FPS out of this rate.
	cutoff = clampf(2.0 + 35.0 * velocity.length(), 2.0, 60.0)
	previous = target
	last_sample_time = now

func median(a: float, b: float, c: float) -> float:
	return maxf(minf(a, b), minf(maxf(a, b), c))

func advance(delta: float) -> void:
	clock += maxf(delta, 0)
	if not initialized: return
	position = position.lerp(target, 1.0 - exp(-TAU * cutoff * maxf(delta, 0)))
