extends SceneTree
## Default: cache regression. -- image /absolute/output.png: rendered reference.
var failures := 0

func _initialize() -> void:
	run.call_deferred()
	create_timer(30).timeout.connect(func(): push_error("Tank art checks timed out"); quit(1))

func check(value: bool, message: String) -> void:
	if value: return
	failures += 1
	push_error(message)

func frames(count: int) -> void:
	for _frame in range(count): await process_frame

func run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 2 and args[2] == "vector": set_meta("scenery_vector", true)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(720, 300)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var tanks: Array = []
	for i in range(8):
		var path := "res://scenes/tanks/Tank.tscn"
		if i in [4, 5, 6]: path = "res://scenes/story/StoryEnemy.tscn"
		if i == 7: path = "res://scenes/story/StoryTank.tscn"
		var tank = load(path).instantiate()
		tank.position = Vector2(90 + (i % 4) * 180, 80 + (i / 4) * 145)
		tank.rotation = [0.0, 0.7, 1.8, 3.0][i % 4]
		tank.separate_turret = true
		tank.turret_angle = [-0.4, 1.5, 0.2, -1.0][i % 4]
		tank.recoil = 4 if i % 2 else 0
		tank.tread_phase = 1.7
		tank.tint = Color("2455ff") if i % 2 == 0 else Color("ff5cb6")
		tank.identification = "triangle" if i % 2 == 0 else "2"
		viewport.add_child(tank)
		tank.set_physics_process(false)
		if i == 4:
			tank.damaged_model = true
			tank.visual_time = 1.25
			tank.armor = 2
			tank.max_armor = 3
		if i == 5:
			tank.equip_carrier("Engine")
			tank.visual_time = 0.2
		if i == 6: tank.body_opacity = 0.35
		if i == 7:
			tank.alive = false
			tank.revive_progress = 0.8
		tanks.append(tank)
	await frames(5)
	if args.size() > 1 and args[0] == "image":
		RenderingServer.force_draw(false)
		var snapshot := viewport.get_texture().get_image()
		check(not snapshot.is_empty() and snapshot.save_png(args[1]) == OK, "Rendered tank comparison must save successfully")
	else:
		var tank = tanks[0]
		var visual = tank.get_node("TankArtwork")
		var paints: Array[Color] = StorySession.COLORS.duplicate()
		for profile in EnemyProfiles.TYPES: paints.append(Color(profile.color))
		for paint in paints:
			for part in ["Hull", "Armor", "Ring", "Barrel", "Cap"]:
				check(not visual.Atlas.lookup(visual, visual.Atlas.tank_key(part, paint)).is_empty(), "All standard tank colors and static parts must be present in the shared atlas")
		check(visual.Atlas.lookup(visual, visual.Atlas.tank_key("Armor", Color(0.123, 0.456, 0.789))).is_empty(), "Custom colors must retain the vector fallback")
		var counts := {}
		for canvas in visual.find_children("*", "Node2D", true, false):
			counts[canvas.name] = 0
			canvas.draw.connect(func(): counts[canvas.name] += 1)
		for i in range(12):
			tank.rotation += 0.12
			tank.turret_angle += 0.25
			tank.recoil = 4.0 - i * 0.2
			tank.tread_phase = fposmod(i * 0.7, tank.Art.TREAD_SPACING)
			await frames(1)
		await frames(2)
		for label in ["Hull", "Armor", "Ring", "Barrel", "Cap"]:
			check(counts[label] == 0, "Moving/aiming/recoil must reuse the cached %s artwork" % label)
		check(counts["Treads"] > 5, "Moving tread strips must continue animating")
		check(is_equal_approx(visual.turret.rotation, tank.turret_angle - tank.rotation) and is_equal_approx(visual.barrel.position.x, -tank.recoil), "Cached gun transforms must match aiming and recoil")
		tank.tint = Color("ff5cb6")
		await frames(3)
		for label in ["Armor", "Barrel", "Cap"]:
			check(counts[label] == 1, "Recoloring must refresh the cached %s exactly once" % label)
		check(counts["Hull"] == 0 and counts["Ring"] == 0, "Recoloring must retain untinted details")
		tank.self_modulate = Color(1, 0.4, 0.7)
		tank.body_opacity = 0
		await frames(2)
		check(not visual.visible and tank.modulate.a == 0, "Cloaking must hide all cached tank parts")
		tank.body_opacity = 1
		tank.alive = false
		await frames(2)
		check(not visual.visible, "Downed tanks must hide cached bodies beneath revive artwork")
		tank.alive = true
		await frames(2)
		check(visual.visible and visual.modulate == tank.self_modulate, "Revival and powerup flashing must reach cached parts")
	viewport.queue_free()
	await frames(3)
	print("TANK ART CACHE SMOKE: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)
