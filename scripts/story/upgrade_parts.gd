extends RefCounted

const TYPES := ["", "Loader", "Armor", "Bank Shot", "Engine", "Gatling", "Shotgun", "Heat Seeker"]
const MAX_LEVEL := 3
const WEAPONS := ["Gatling", "Shotgun", "Heat Seeker"]
const DESCRIPTIONS := {
	"Loader": "Faster reload (0.22s).",
	"Armor": "Four armor points; slightly slower movement.",
	"Bank Shot": "One extra bounce; bank shots deal two damage.",
	"Engine": "Faster movement; two armor points.",
	"Gatling": "Rapid fire with a larger shell capacity.",
	"Shotgun": "Five shells fan out with each blast.",
	"Heat Seeker": "Smoke-trailing missiles pursue the nearest enemy.",
}
const COLORS := {"Loader": Color("ffe600"), "Armor": Color("00dfd0"), "Bank Shot": Color("ff1493"), "Engine": Color("7cf4bc"), "Gatling": Color("ffb52e"), "Shotgun": Color("ff5cb6"), "Heat Seeker": Color("51edcf")}

static func detail(part: String, level: int) -> String:
	var rank := maxi(0, level - 1)
	match part:
		"Loader": return "Reload %.2fs" % (0.22 - rank * 0.035)
		"Armor": return "%d armor · speed 135" % (4 + rank)
		"Bank Shot": return "%d ricochets · %d bank-shot damage" % [2 + rank, 2 + rank]
		"Engine": return "Speed %d · two armor" % (185 + rank * 15)
		"Gatling": return "Reload %.2fs · %d active shots" % [0.13 - rank * 0.02, 12 + rank * 3]
		"Shotgun": return "Five-shell spread · reload %.2fs" % (0.75 - rank * 0.1)
		"Heat Seeker": return "Reload %.2fs · steering %.2f" % [1.05 - rank * 0.15, 1.25 + rank * 0.35]
	return "Normal shells · three armor"

static func levels(values: Array, parts: Array) -> Array[int]:
	var result: Array[int] = []
	for i in range(4): result.append(clampi(int(values[i]), 1, MAX_LEVEL) if i < values.size() and i < parts.size() and not str(parts[i]).is_empty() else (1 if i < parts.size() and not str(parts[i]).is_empty() else 0))
	return result

static func weapon_stats(tank: DuelTank, part: String, level: int, enemy: bool = false) -> void:
	var rank := clampi(level, 1, MAX_LEVEL) - 1
	match part:
		"Gatling":
			tank.shot_cooldown = (0.30 if enemy else 0.13) - rank * (0.035 if enemy else 0.02)
			tank.max_shells = 12 + rank * 3
			tank.shell_speed = 330 + rank * 15
		"Shotgun":
			tank.shot_cooldown = (1.5 if enemy else 0.75) - rank * 0.1
			tank.max_shells = 15 + rank * 5
			tank.shell_speed = 290 + rank * 15
		"Heat Seeker":
			tank.shot_cooldown = (2.4 if enemy else 1.05) - rank * 0.15
			tank.max_shells = 2 + rank
			tank.shell_speed = 240 + rank * 10
			tank.shell_is_missile = true

static func fire_weapon(arena: Node2D, tank: DuelTank, part: String, level: int, targets: Array[DuelTank]) -> void:
	if not arena.active or arena.paused or not tank.alive: return
	var direction := tank.firing_direction()
	if part == "Shotgun":
		if tank.max_shells - tank.active_shells < 5: return
		for pellet in range(-2, 3): arena.launch_shell(tank, direction.rotated(pellet * 0.15), -direction.orthogonal() * pellet * 4, false)
	else:
		var shell: DuelShell = arena.launch_shell(tank, direction, Vector2.ZERO, false)
		if shell != null and part == "Heat Seeker":
			shell.is_missile = true
			shell.homing_targets.assign(targets)
			shell.homing_turn_rate = 1.25 + (level - 1) * 0.35
	arena.play_sound(arena.SHOOT, -21 if part == "Gatling" else -17, 0.8 if part == "Shotgun" else 1.1)

static func sanitize(values: Array) -> Array[String]:
	var result: Array[String] = []
	for i in range(4):
		var value := str(values[i]) if i < values.size() else ""
		result.append(value if TYPES.has(value) else "")
	return result
