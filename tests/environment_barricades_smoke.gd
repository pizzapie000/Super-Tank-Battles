extends SceneTree

var failures := 0
var game: Node2D
const PIECES := ["FactoryBarricade", "WastelandRuins", "ForestMasonry", "FortressRampart", "VillageBarricade", "CapitalBarricade"]

func _initialize() -> void:
	run.call_deferred()
	create_timer(60).timeout.connect(func():
		push_error("Environment cover checks exceeded their time limit")
		quit(1)
	)

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func frames(count: int) -> void:
	for i in range(count):
		await physics_frame
		await process_frame

func clear_walls() -> void:
	for wall in game.get_node("Walls").get_children():
		game.get_node("Walls").remove_child(wall)
		wall.queue_free()
	game.wall_rects.clear()

func shoot_face(cover: Node2D) -> void:
	for shell in game.get_node("Shells").get_children():
		shell.retire()
	await frames(2)
	var bounds: Rect2 = cover.wall_rect()
	var tank: DuelTank = game.tanks[0]
	tank.position = Vector2(bounds.get_center().x, bounds.position.y - 75)
	tank.rotation = PI / 2
	tank.cooldown = 0
	var impacts: Array[Vector2] = []
	game.fire_shell(tank)
	var shell: DuelShell = game.get_node("Shells").get_child(0)
	shell.bounced.connect(func(point: Vector2):
		impacts.append(point)
		tank.position.x -= 150
	)
	await frames(30)
	check(not impacts.is_empty(), "%s must reflect a real shell" % cover.name)
	if not impacts.is_empty():
		check(absf(impacts[0].y - bounds.position.y) < 6, "%s must bounce at the visible solid rim" % cover.name)

func run() -> void:
	game = load("res://scenes/game/DuelArena.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.active = true
	game.countdown = 0
	game.set_controls(false)
	game.tanks[1].position = Vector2(1150, 650)
	for piece_name in PIECES:
		clear_walls()
		var cover = load("res://scenes/story/props/%s.tscn" % piece_name).instantiate()
		cover.position = Vector2(900, 430)
		cover.size = Vector2(160, 90)
		root.add_child(cover)
		check(cover.wall_rect() == Rect2(893, 423, 160, 90), "Environment art must preserve the existing wall footprint and overlap")
		game.add_wall(cover.wall_rect())
		await frames(2)
		await shoot_face(cover)
		# Portrait cover must rotate its detail without rotating or distorting physics.
		clear_walls()
		cover.size = Vector2(40, 170)
		cover.form = "Barrier"
		cover.variation = 29
		check(cover.wall_rect() == Rect2(893, 423, 40, 170), "Resizing and changing artwork must preserve an axis-aligned physical face")
		game.add_wall(cover.wall_rect())
		await frames(2)
		await shoot_face(cover)
		var packed := PackedScene.new()
		check(packed.pack(cover) == OK, "Customized environment props must remain editable packed scenes")
		var reloaded = packed.instantiate()
		check(reloaded.size == cover.size and reloaded.form == "Barrier" and reloaded.variation == 29 and reloaded.environment == cover.environment, "Scene serialization must retain the chosen style, form, size and variation")
		reloaded.free()
		cover.queue_free()
		await frames(2)
	# Every converted cover piece should match its actual campaign environment.
	var world = load("res://scenes/story/StoryWorld.tscn").instantiate()
	for region in world.get_children():
		var count := 0
		for piece in region.find_children("*", "Polygon2D", true, false):
			if piece.get_script() == preload("res://scripts/story/environment_barricade.gd"):
				count += 1
				check(piece.environment == region.biome, "Authored barricades must match the surrounding environment")
		if region.section_type != "Village":
			check(count > 0, "Every combat area and the village approach must use the new themed cover")
	world.free()
	for child in game.get_children():
		if child is AudioStreamPlayer:
			child.stop()
	game.queue_free()
	await frames(8)
	print("ENVIRONMENT BARRICADES SMOKE: %s" % ("PASS" if failures == 0 else "%d FAILURE(S)" % failures))
	quit(0 if failures == 0 else 1)
