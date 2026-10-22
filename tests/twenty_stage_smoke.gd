extends SceneTree

const TitleCard = preload("res://scripts/story/area_title_card.gd")
var failures := 0
var game: Node2D

func _initialize() -> void:
	run.call_deferred()
	create_timer(120).timeout.connect(func(): push_error("Twenty-stage campaign checks timed out"); quit(1))

func check(condition: bool, message: String) -> void:
	if condition: return
	failures += 1
	push_error(message)

func frames(count: int) -> void:
	for _frame in range(count):
		await physics_frame
		await process_frame

func freeze(index: int) -> void:
	game.load_chapter(index)
	game.set_activity(false)
	game.active = true

func press(code: int, device: int = -1) -> void:
	if device < 0:
		var event := InputEventKey.new()
		event.physical_keycode = code
		event.pressed = true
		game._input(event)
	else:
		var event := InputEventJoypadButton.new()
		event.device = device
		event.button_index = code
		event.pressed = true
		game._input(event)

func run() -> void:
	StorySession.save_path = "user://twenty_stage_smoke.cfg"
	StorySession.devices = [-1]
	StorySession.debug_checkpoint = -1
	StorySession.resume_story = false
	game = load("res://scenes/story/Adventure.tscn").instantiate()
	game.save_progress = false
	game.check_devices = false
	root.add_child(game)
	game.set_process(false)
	var expected := ["FactoryBoot", "FactoryEscape", "FactoryFreight", "Wasteland", "WastelandScrapyard", "WastelandSalvage", "RuinedForest", "ForestDepths", "ForestCrossroads", "ForestPass", "Fortress", "FortressBattery", "FortressBastion", "FortressKeep", "VillageApproach", "Village", "Capital", "CapitalSquare", "CapitalSiege", "CapitalCommand"]
	var checkpoints := StorySession.available_checkpoints()
	check(checkpoints.size() == 20 and StorySession.SECTION_COUNT == 20 and game.world_bounds().size.x == 32000, "The connected campaign and debugger must expose exactly twenty stages")
	for i in range(20):
		var region := game.get_node("World").get_child(i)
		check(str(region.name) == expected[i] and region.chapter == i and region.position == Vector2(i * 1600, 0), "Scene order, chapter numbers and world positions must stay aligned")
		check(checkpoints[i].title == region.title and not region.title.is_empty(), "Every checkpoint must use its authored title")
	for crew_size in [1, 4]:
		StorySession.devices.assign([-1, 7, 9, 12].slice(0, crew_size))
		for section in [2, 9, 13, 17, 18]:
			freeze(section)
			var authored: int = game.region().get_node("Enemies").get_child_count()
			check(game.remaining_enemies() == roundi(authored * (1 + 0.4 * (crew_size - 1))), "New encounters must retain gentle co-op count scaling")
			check(game.mine_walls.any(func(wall): return wall.get_parent().get_parent() == game.region()), "New stages must contain editable mine-breakable cover")
			for crew in game.players:
				check(game.navigation.point_clear(crew.position), "All new crew spawns must have full tank clearance")
			check(not game.navigation.path(game.players[0].position, game.region().get_node("Exit").global_position).is_empty(), "Every new level must have a navigable exit")
			for enemy in game.enemies:
				check(game.navigation.point_clear(enemy.position) and not game.navigation.path(enemy.position, game.players[0].position).is_empty(), "New patrols must spawn in reachable, open space")
			if section == 9:
				var origin: Vector2 = game.region().global_position
				for y in [430, 870]:
					check(game.navigation.segment_clear(origin + Vector2(700, y), origin + Vector2(880, y)), "Both new forest bridges must admit full-width tanks")
			for crew in game.players:
				crew.position = game.region().get_node("AmbushTrigger").global_position + Vector2(0, crew.player_index * 35)
			game.update_ambush(0.1)
			check(game.pending_attackers.is_empty(), "All reserved new-stage ambushes must have usable entry points")
			game.set_activity(false)
			game.active = true
			for enemy in game.enemies.duplicate(): enemy.take_shell_hit(99)
			await frames(2)
			check(game.wave_cleared and not game.region().get_node("Gate").visible and game.get_node("Powerups").get_child_count() > 0, "New stages must clear normally and retain dropped powerups")
	# Every previous fifteen-stage save resumes at the same named encounter.
	var previous := ["FactoryBoot", "FactoryEscape", "Wasteland", "WastelandScrapyard", "WastelandSalvage", "RuinedForest", "ForestDepths", "ForestCrossroads", "Fortress", "FortressBattery", "FortressBastion", "VillageApproach", "Village", "Capital", "CapitalCommand"]
	for old in range(previous.size()):
		var file := ConfigFile.new()
		file.set_value("story", "layout_version", 5)
		file.set_value("story", "chapter", old)
		file.set_value("story", "supplies", 17)
		file.set_value("story", "village", "spared")
		file.set_value("story", "complete", old == 14)
		file.set_value("story", "parts", ["Gatling", "Armor", "", ""])
		file.set_value("story", "part_levels", [3, 2, 0, 0])
		file.save(StorySession.save_path)
		var saved := StorySession.checkpoint()
		check(str(game.get_node("World").get_child(saved.chapter).name) == previous[old], "Fifteen-stage saves must retain their named checkpoint after insertion")
		check(saved.supplies == 17 and saved.village == "spared" and saved.complete == (old == 14) and saved.part_levels == [3, 2, 0, 0], "Migration must preserve supplies, village choices, completion and upgrade tiers")
	# Area cards only appear at biome boundaries. Pause and all assigned input
	# families must work while the protected transition is presenting its card.
	StorySession.devices = [-1, 1000]
	for section in [2, 5, 9, 13, 15]:
		freeze(section)
		game.advance_chapter()
		await frames(31)
		check(game.chapter == section + 1 and game.area_title_active and game.transitioning and not game.active, "Each new area must display its title before combat resumes")
		check(TitleCard.AREAS.has(game.region().biome) and game.enemies.all(func(enemy): return not enemy.controls_enabled), "All area cards need distinct artwork and frozen enemies")
		press(JOY_BUTTON_A, 9)
		check(game.area_title_active, "Unassigned controllers must not dismiss an area card")
		game.pause_story()
		var progress: float = game.area_title_progress
		await frames(12)
		check(game.area_title_progress == progress, "Pause must freeze the card and its transition clock")
		game.resume_game()
		press(KEY_ENTER) if section == 2 else press(JOY_BUTTON_A, 1000)
		check(not game.area_title_active and game.transitioning and not game.active, "Keyboard and Wii confirm must skip the card while retaining the safe fade")
		await frames(40)
		check(game.active and not game.transitioning and game.fade_alpha == 0, "Combat must resume after the area card and fade finish")
	freeze(6)
	game.advance_chapter()
	await frames(70)
	check(game.chapter == 7 and not game.area_title_active and not game.transitioning and game.stage_ready_time == 0, "Checkpoints within one area must retain immediate starts without another title or countdown")
	game.debug_mode = true
	freeze(5)
	game.advance_chapter()
	await frames(31)
	game.pause_story()
	game.start_debug_checkpoint(17)
	await frames(220)
	check(game.chapter == 17 and not game.area_title_active and game.fade_alpha == 0, "A debug jump must cancel an in-progress area card and its pending transition")
	game.queue_free()
	await frames(8)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(StorySession.save_path))
	StorySession.save_path = "user://adventure.cfg"
	StorySession.debug_checkpoint = -1
	StorySession.devices = [-1]
	print("TWENTY STAGE SMOKE: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)
