extends RefCounted

# Filter in screen space AFTER calibration. The reticle and turret both read this
# one position; filtering only the artwork would make shots disagree with aim.
var position := Vector2.ZERO
var target := Vector2.ZERO
var initialized := false
var sample_sequence: int = -1

func sample(point: Vector2, sequence: int) -> void:
	if sequence >= 0 and sequence == sample_sequence: return
	sample_sequence = sequence
	target = point
	if not initialized:
		position = point
		initialized = true

func advance(delta: float) -> void:
	if not initialized: return
	# Suppress small hand/camera jitter, with a fast response to deliberate sweeps.
	var cutoff := lerpf(6.0, 30.0, clampf(position.distance_to(target) / 0.08, 0, 1))
	position = position.lerp(target, 1.0 - exp(-TAU * cutoff * maxf(delta, 0)))
