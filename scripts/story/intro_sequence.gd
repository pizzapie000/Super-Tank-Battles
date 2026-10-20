extends RefCounted

const LENGTH := 16.0
const ENGINE_START := 12.1
const IGNITION := 12.8
const DRIVE_START := 14.0
const FLEE_START := 14.18
const TANK_SCALE := 4.5
const TANK_HOME := Vector2(640, 440)
const WORKER_HOME := Vector2(520, 472)

static func time_at(elapsed: float, duration: float) -> float:
	return clampf(elapsed * LENGTH / maxf(duration, 0.01), 0, LENGTH)

static func stations(crew_size: int) -> Array[Dictionary]:
	var count := clampi(crew_size, 1, 4)
	var result: Array[Dictionary] = []
	for i in range(count):
		var home := TANK_HOME
		var scale := 3.6
		if count == 2:
			home = Vector2(340 + i * 600, 430)
			scale = 2.85
		elif count >= 3:
			home = Vector2(340 + (i % 2) * 600, 300 + (i / 2) * 295)
			if count == 3 and i == 2:
				home.x = 640
			scale = 1.75
		result.append({"home": home, "scale": scale})
	return result

static func tank_offset(time: float) -> Vector2:
	return Vector2(smoothstep(DRIVE_START, 15.5, time) * 95, 0)

static func tank_position(time: float, home: Vector2 = TANK_HOME, scale: float = TANK_SCALE) -> Vector2:
	var vibration := Vector2.ZERO
	if time >= IGNITION:
		vibration = Vector2(sin(time * 47) * 1.4, sin(time * 71) * 0.8)
	return home + (tank_offset(time) + vibration) * scale / TANK_SCALE

static func track_phase(time: float) -> float:
	return tank_offset(time).x / TANK_SCALE

static func worker_position(time: float) -> Vector2:
	var recoil := Vector2(-18, 8) * smoothstep(DRIVE_START, FLEE_START, time)
	var sprint := clampf((time - FLEE_START) / 1.1, 0, 1)
	return WORKER_HOME + recoil + Vector2(-370, 115) * sprint

static func exhaust_puffs(time: float, home: Vector2 = TANK_HOME, scale: float = TANK_SCALE) -> Array[Dictionary]:
	var puffs: Array[Dictionary] = []
	var ratio := scale / TANK_SCALE
	for i in range(7):
		var emitted := IGNITION + i * 0.12 if i < 4 else DRIVE_START + (i - 4) * 0.18
		var age := time - emitted
		if age < 0 or age > 0.85:
			continue
		var pipe := home + tank_offset(emitted) * ratio + Vector2(-23, 7) * scale
		puffs.append({"position": pipe + Vector2(age * 15, -age * 85 + sin(i * 2.1) * 3) * ratio, "radius": (4 + age * 12) * ratio, "alpha": (1 - age / 0.85) * 0.42})
	return puffs
