extends RefCounted

const Intro = preload("res://scripts/story/intro_sequence.gd")
const Art = preload("res://scripts/tank_art.gd")
const FactoryArt = preload("res://scripts/story/factory_art.gd")
const Tank = preload("res://scripts/tank.gd")
const CELL_BOUNDS := Rect2(-98, -87, 196, 163)
const BASES := [Vector2(-59, -32), Vector2(59, -32), Vector2(59, 32), Vector2(-56, 30)]
const PARKS := [Vector2(-34, -37), Vector2(34, -37), Vector2(34, 37), Vector2(-28, 47)]
const ARM_COLORS := [Color("e9ac4b"), Color("65b5c9"), Color("d98e58"), Color("a2bfc0")]
# Each job uses one physical robot. The wrist follows the part until its jaws
# release; the fitted part stays behind as that robot retracts to its safe pose.
const JOBS := [
	{"part": "chassis", "arm": 0, "start": 1.3, "carry": 1.65, "seat": 2.8, "release": 3.0, "source": Vector2(-43, -25), "target": Vector2.ZERO, "grip": Vector2(0, -15), "width": 39.0, "angle": 0.0},
	{"part": "upper_track", "arm": 1, "start": 3.0, "carry": 3.25, "seat": 4.35, "release": 4.5, "source": Vector2(42, -36), "target": Vector2(0, -17), "grip": Vector2(0, -8), "width": 45.0, "angle": 0.0},
	{"part": "lower_track", "arm": 2, "start": 3.5, "carry": 3.75, "seat": 4.85, "release": 5.0, "source": Vector2(42, 36), "target": Vector2(0, 17), "grip": Vector2(0, 8), "width": 45.0, "angle": PI},
	{"part": "armor", "arm": 0, "start": 5.1, "carry": 5.4, "seat": 6.8, "release": 7.05, "source": Vector2(-43, -25), "target": Vector2.ZERO, "grip": Vector2(0, -15), "width": 41.0, "angle": 0.0},
	{"part": "turret", "arm": 1, "start": 7.6, "carry": 7.85, "seat": 8.95, "release": 9.15, "source": Vector2(42, -36), "target": Vector2.ZERO, "grip": Vector2(0, -12), "width": 24.0, "angle": 0.0},
	{"part": "barrel", "arm": 2, "start": 9.4, "carry": 9.65, "seat": 10.4, "release": 10.55, "source": Vector2(30, 32), "target": Vector2.ZERO, "grip": Vector2(18, 8), "width": 25.0, "angle": PI},
]
const WELDS := [
	{"start": 4.45, "end": 4.85, "from": Vector2(-13, -12), "to": Vector2(13, -12)},
	{"start": 4.94, "end": 5.24, "from": Vector2(13, 12), "to": Vector2(-13, 12)},
	{"start": 6.93, "end": 7.5, "from": Vector2(-17, -6), "to": Vector2(-17, 6)},
	{"start": 9.1, "end": 9.4, "from": Vector2(-7, 6), "to": Vector2(7, 6)},
	{"start": 10.56, "end": 10.96, "from": Vector2(9, -3), "to": Vector2(9, 3)},
]

static func part_position(job: Dictionary, time: float) -> Vector2:
	var progress := smoothstep(job.carry, job.seat, time)
	var at: Vector2 = job.source.lerp(job.target, progress)
	# The heavy castings lift clear of their trays before lowering onto the hull.
	if job.part in ["armor", "turret"]:
		at.y -= sin(progress * PI) * 7
	return at

static func handler_pose(arm: int, time: float) -> Dictionary:
	var pose := {"wrist": PARKS[arm], "angle": 0.0 if arm < 2 else PI, "opening": 1.0, "width": 25.0, "holding": ""}
	for job in JOBS:
		if job.arm != arm or time < job.start - 0.35 or time > job.release + 0.6:
			continue
		var contact: Vector2 = part_position(job, time) + job.grip
		pose.width = job.width
		pose.angle = job.angle
		if time < job.start:
			pose.wrist = PARKS[arm].lerp(contact, smoothstep(job.start - 0.35, job.start, time))
		elif time <= job.release:
			pose.wrist = contact
			pose.opening = 1 - smoothstep(job.start, job.carry, time)
			pose.holding = job.part if time >= job.carry else ""
		else:
			pose.opening = smoothstep(job.release, job.release + 0.15, time)
			pose.wrist = contact.lerp(PARKS[arm], smoothstep(job.release + 0.15, job.release + 0.6, time))
	return pose

static func weld_pose(time: float) -> Dictionary:
	var previous_time := 1.0
	var previous: Vector2 = PARKS[3]
	for i in range(WELDS.size()):
		var seam: Dictionary = WELDS[i]
		var next_is_close: bool = i > 0 and seam.start - WELDS[i - 1].end < 0.5
		if not next_is_close:
			previous_time = seam.start - 0.35
			previous = PARKS[3]
		if time < previous_time:
			return {"contact": PARKS[3], "active": false}
		if time < seam.start:
			return {"contact": previous.lerp(seam.from, smoothstep(previous_time, seam.start, time)), "active": false}
		if time <= seam.end:
			return {"contact": seam.from.lerp(seam.to, (time - seam.start) / (seam.end - seam.start)), "active": true}
		previous_time = seam.end
		previous = seam.to
		var close_next: bool = i + 1 < WELDS.size() and WELDS[i + 1].start - seam.end < 0.5
		if not close_next and time < seam.end + 0.35:
			return {"contact": previous.lerp(PARKS[3], smoothstep(seam.end, seam.end + 0.35, time)), "active": false}
	return {"contact": PARKS[3], "active": false}

static func elbow(base: Vector2, wrist: Vector2, first: float, second: float, bend: float) -> Vector2:
	var distance := maxf(base.distance_to(wrist), 0.01)
	var direction := (wrist - base) / distance
	var along := (first * first - second * second + distance * distance) / (2 * distance)
	return base + direction * along + direction.orthogonal() * sqrt(maxf(0, first * first - along * along)) * bend

static func robot(canvas: CanvasItem, arm: int, wrist: Vector2) -> void:
	var base: Vector2 = BASES[arm]
	var first := 42.0 if arm == 3 else 36.0
	var second := 41.0 if arm == 3 else 34.0
	var joint := elbow(base, wrist, first, second, 1 if arm in [0, 2] else -1)
	var color: Color = ARM_COLORS[arm]
	canvas.draw_rect(Rect2(base - Vector2(8, 8), Vector2(16, 16)), Color("172632"))
	for x in [-6, 6]:
		for y in [-6, 6]:
			canvas.draw_circle(base + Vector2(x, y), 0.9, Color("c2d0d0"))
	# Rounded cast links, motor housings, a hydraulic piston and the service hose.
	for link in [[base, joint, 7.0], [joint, wrist, 5.5]]:
		canvas.draw_line(link[0] + Vector2(1, 2), link[1] + Vector2(1, 2), Color(0, 0, 0, 0.35), link[2] + 2, true)
		canvas.draw_line(link[0], link[1], Color("17242c"), link[2] + 1.5, true)
		canvas.draw_line(link[0], link[1], color, link[2], true)
		canvas.draw_line(link[0] + Vector2(-0.8, -1), link[1] + Vector2(-0.8, -1), color.lightened(0.3), 1.1, true)
	var normal := (joint - base).normalized().orthogonal() * 3
	canvas.draw_line(base.lerp(joint, 0.2) + normal, base.lerp(joint, 0.65) + normal, Color("304651"), 3, true)
	canvas.draw_line(base.lerp(joint, 0.55) + normal, joint + normal, Color("d5ded9"), 1.5, true)
	canvas.draw_polyline(PackedVector2Array([base, base.lerp(joint, 0.5) - normal * 2, joint, joint.lerp(wrist, 0.5) + normal, wrist]), Color("15232e"), 1.4, true)
	for point in [base, joint, wrist]:
		canvas.draw_circle(point, 4.5 if point == base else 3.4, Color("20323e"))
		canvas.draw_circle(point, 2.5 if point == base else 1.8, Color("d6ded9"))
	canvas.draw_circle(base + Vector2(-3, -3), 1, Color("7cf4bf"))

static func gripper(canvas: CanvasItem, pose: Dictionary) -> void:
	var wrist: Vector2 = pose.wrist
	var half: float = pose.width * 0.5 + pose.opening * 4
	var angle: float = pose.angle
	var across := Vector2.RIGHT.rotated(angle)
	var down := Vector2.DOWN.rotated(angle)
	canvas.draw_line(wrist - across * half, wrist + across * half, Color("182b35"), 3.2, true)
	canvas.draw_line(wrist - across * half, wrist + across * half, Color("d1dcda"), 1.5, true)
	for side in [-1, 1]:
		var end: Vector2 = wrist + across * half * side
		canvas.draw_polyline(PackedVector2Array([end, end + down * 11, end + down * 11 - across * side * 3]), Color("d1dcda"), 2, true)
		canvas.draw_circle(end, 1.8, Color("526e79"))

static func draw(canvas: Node2D, time: float, station: Dictionary, tint: Color, marker: String, inspector: bool) -> void:
	var home: Vector2 = station.home
	var scale: float = station.scale
	var factor := Vector2.ONE * scale
	canvas.draw_set_transform(home, 0, factor)
	canvas.draw_rect(CELL_BOUNDS, Color("14222d"))
	canvas.draw_rect(CELL_BOUNDS.grow(-1), Color("31434d"), false, 0.6)
	for x in [-90, 90]:
		canvas.draw_line(Vector2(x, -60), Vector2(x, 58), Color("52616a"), 3)
		for y in [-55, 52]:
			canvas.draw_circle(Vector2(x, y), 1.2, Color("c3ceca"))
	# Parts arrive on steel supply trays beside their respective handling robots.
	for at in [Vector2(-43, -25), Vector2(42, -36), Vector2(42, 36)]:
		canvas.draw_rect(Rect2(at - Vector2(26, 14), Vector2(52, 28)), Color("273945"))
		canvas.draw_rect(Rect2(at - Vector2(25, 13), Vector2(50, 26)), Color("60737c"), false, 0.7)
	canvas.draw_set_transform(Vector2.ZERO)
	FactoryArt.conveyor(canvas, Rect2(home + Vector2(-32, -25) * scale, Vector2(86, 50) * scale), time)
	var moving := (Intro.tank_position(time, home, scale) - home) / scale
	canvas.draw_set_transform(home, 0, factor)
	canvas.draw_circle(moving + Vector2(1, 4), 24, Color(0, 0, 0, 0.3))
	for job in JOBS:
		if time < job.start - 0.35:
			continue
		var at := part_position(job, time)
		if time >= job.seat:
			at += moving
		match job.part:
			"chassis": Art.chassis(canvas, at)
			"upper_track": Art.tracks(canvas, at + Vector2(0, 17), -1, Intro.track_phase(time))
			"lower_track": Art.tracks(canvas, at - Vector2(0, 17), 1, Intro.track_phase(time))
			"armor": Art.armor(canvas, tint, at)
			"turret": Art.turret(canvas, tint, at, 0, false)
			"barrel": Art.barrel(canvas, tint, at)
	if time >= 11:
		Tank.draw_identification(canvas, marker, moving)
	if time >= Intro.IGNITION:
		canvas.draw_circle(moving + Vector2(-12.7, -8), 1.1, Color("7ff3c7"))
	for arm in range(3):
		var pose := handler_pose(arm, time)
		robot(canvas, arm, pose.wrist)
		gripper(canvas, pose)
	var weld := weld_pose(time)
	var contact: Vector2 = weld.contact
	var toward_base := (BASES[3] - contact).normalized()
	var wrist := contact + toward_base * 9
	robot(canvas, 3, wrist)
	canvas.draw_line(wrist, contact + toward_base * 2, Color("253d48"), 3.2, true)
	canvas.draw_line(contact + toward_base * 3, contact, Color("d9b987"), 1.5, true)
	if weld.active:
		welding(canvas, contact, time)
	canvas.draw_set_transform(Vector2.ZERO)
	var font := ThemeDB.fallback_font
	canvas.draw_string(font, home + Vector2(-86, -76) * scale, "BAY %02d   /   PLAYER %s" % [int(marker), marker], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, tint.lightened(0.55))
	if time >= 11 and inspector:
		var worker := home + (Intro.worker_position(time) - Intro.TANK_HOME) * scale / Intro.TANK_SCALE
		if time >= Intro.DRIVE_START:
			var drop := clampf((time - Intro.DRIVE_START) / 0.5, 0, 1)
			canvas.draw_set_transform(home + Vector2(-16 - drop * 3, 6 + drop * 22) * scale, drop * 2.2, factor)
			canvas.draw_rect(Rect2(-1.5, -0.9, 3, 1.8), Color("eef2dc"))
		canvas.draw_set_transform(worker, 0, Vector2.ONE * 2.4 * scale / Intro.TANK_SCALE)
		FactoryArt.technician(canvas, Vector2.ZERO, time, time >= Intro.FLEE_START, time >= Intro.DRIVE_START)
	canvas.draw_set_transform(Vector2.ZERO)
	for puff in Intro.exhaust_puffs(time, home, scale):
		canvas.draw_circle(puff.position, puff.radius, Color(0.67, 0.71, 0.69, puff.alpha))

static func welding(canvas: CanvasItem, contact: Vector2, time: float) -> void:
	canvas.draw_circle(contact, 5 + sin(time * 121), Color(0.4, 0.8, 1, 0.14))
	canvas.draw_circle(contact, 2.1, Color("b7efff"))
	canvas.draw_circle(contact, 0.9, Color("ffffff"))
	for i in range(12):
		var age := fposmod(time * 2.7 + i * 0.083, 1)
		var velocity := Vector2.RIGHT.rotated(i * 2.4) * (9 + i % 4 * 3)
		var at := contact + velocity * age + Vector2(0, 9 * age * age)
		canvas.draw_line(at, at - velocity.normalized() * 1.7, Color(1, 0.68 + age * 0.2, 0.3, 1 - age), 0.7, true)
	for i in range(3):
		var age := fposmod(time * 1.8 + i / 3.0, 1)
		canvas.draw_circle(contact + Vector2(sin(i * 2.8 + age) * 3, -age * 12), 1 + age * 3, Color(0.65, 0.78, 0.8, (1 - age) * 0.18))
