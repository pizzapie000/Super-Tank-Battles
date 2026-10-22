extends SceneTree

var game: Node2D
var failures := 0

func _initialize() -> void:
	run.call_deferred()
	create_timer(120).timeout.connect(func(): push_error("Checkpoint health checks timed out"); quit(1))

func check(condition: bool, message: String) -> void:
	if condition: return
	failures += 1
	push_error(message)

func frames(count: int) -> void:
	for _frame in range(count):
		await physics_frame
		await process_frame

func boot(resuming: bool) -> void:
	if is_instance_valid(game):
		game.queue_free()
		await frames(2)
	StorySession.resume_story = resuming
	game = load("res://scenes/story/Adventure.tscn").instantiate()
	game.check_devices = false
	root.add_child(game)
	game.set_process(false)
	game.set_activity(false)

func freeze(index: int, health: Array[int] = []) -> void:
	game.load_chapter(index, health)
	game.set_activity(false)

func advance() -> void:
	var previous: int = game.chapter
	game.advance_chapter()
	await frames(31)
	check(game.chapter == previous + 1, "The real checkpoint transition must load the next scene")
	for enemy in game.enemies:
		enemy.max_shells = 0
		enemy.max_mines = 0
	if game.area_title_active:
		var event := InputEventKey.new()
		event.physical_keycode = KEY_ENTER
		event.pressed = true
		game._input(event)
	await frames(40)
	check(not game.transitioning, "The protected scene transition must finish normally")
	game.set_activity(false)

func run() -> void:
	StorySession.save_path = "user://checkpoint_health_smoke.cfg"
	StorySession.debug_checkpoint = -1
	StorySession.devices = [-1, 7, 9, 12]
	if FileAccess.file_exists(StorySession.save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(StorySession.save_path))
	check(StorySession.checkpoint().health == [-1, -1, -1, -1], "Missing saves must start with healthy crew slots")
	# Older saves know loadouts, but have no health field. Their old full-health
	# behavior remains valid, including armor III and the engine's smaller hull.
	var file := ConfigFile.new()
	file.set_value("story", "layout_version", StorySession.LAYOUT_VERSION)
	file.set_value("story", "chapter", 3)
	file.set_value("story", "parts", ["", "Armor", "Loader", "Engine"])
	file.set_value("story", "part_levels", [0, 3, 1, 1])
	file.save(StorySession.save_path)
	await boot(true)
	check(game.crew_health() == [3, 6, 3, 2], "Older saves must restore full health for each equipped hull")
	# Both a normal checkpoint and a new-area title transition must carry exact
	# remaining armor, rather than a percentage or a full-health reset.
	freeze(3, [2, 4, 0, 1])
	game.supplies = 10
	await advance()
	check(game.crew_health() == [2, 4, 0, 1] and game.supplies == 12, "All four seats must retain injuries while earning checkpoint supplies")
	check(game.checkpoint_health == [2, 4, 0, 1], "Retry health must snapshot the new checkpoint's entry state")
	check(not game.players[2].alive and not game.players[2].controls_enabled and game.players[2].collision_layer == 0, "Downed teammates must arrive downed with no collision or control")
	var saved := StorySession.checkpoint()
	check(saved.chapter == 4 and saved.health == [2, 4, 0, 1] and saved.supplies == 12 and saved.part_levels[1] == 3, "Automatic saves must keep health, supplies and loadouts together")
	# Repairs and collected upgrades are rolled back together on defeat: a retry
	# cannot keep the healing but refund its cost, or grant a free full heal.
	game.active = true
	game.players[0].repair_held = true
	game.players[0].repair_progress = 2
	game.field_repair(game.players[0])
	check(game.players[0].armor == 3 and game.supplies == 10, "Supplies must still purchase a deliberate repair")
	game.award_powerup(game.players[0], "Gatling")
	for crew in game.players:
		crew.hit_cooldown = 0
		crew.take_shell_hit(99)
	await frames(2)
	check(game.phase == "defeat", "An injured checkpoint must still support whole-party defeat")
	game.retry_checkpoint()
	game.set_activity(false)
	check(game.crew_health() == [2, 4, 0, 1] and game.supplies == 12 and game.players[0].equipped_part.is_empty(), "Retry must restore entry injuries, supplies and upgrades as one state")
	await boot(true)
	check(game.chapter == 4 and game.crew_health() == [2, 4, 0, 1] and game.supplies == 12, "Continue must preserve the same injured and downed crew")
	StorySession.devices = [-1]
	await boot(true)
	check(game.players.size() == 1 and StorySession.checkpoint().health == [2, 4, 0, 1], "Continuing with fewer players must retain the health of seats sitting out")
	StorySession.devices = [-1, 7, 9, 12]
	await boot(true)
	check(game.crew_health() == [2, 4, 0, 1], "Rejoining a saved crew slot must not refill that tank's health")
	# A teammate can still rescue a downed tank after moving to the new stage.
	game.players[0].position = game.players[2].position + Vector2(60, 0)
	game.players[0].interact_held = true
	game.update_revives(2)
	check(game.players[2].alive and game.players[2].armor == 3 and game.players[2].collision_layer == 2, "A carried-down teammate must remain revivable with the existing help action")
	freeze(5, [1, 2, 0, 1])
	await advance()
	check(game.chapter == 6 and game.crew_health() == [1, 2, 0, 1], "An area title must not heal the crew between wasteland and forest")
	# Solo uses the same save/transition path, with no special healing shortcut.
	StorySession.devices = [-1]
	freeze(6, [1])
	await advance()
	await boot(true)
	check(game.chapter == 7 and game.crew_health() == [1, -1, -1, -1], "Solo injuries must survive advancement and Continue")
	StorySession.devices = [-1, 7, 9, 12]
	await boot(true)
	check(game.crew_health() == [1, 6, 3, 2], "Newly joined seats must begin healthy without healing an existing player")
	# Decisions and workshop purchases are durable transactions, so their health
	# snapshot must agree with their saved supplies and changed armor capacity.
	game.village_choice = ""
	freeze(15, [1, 2, 0, 1])
	game.supplies = 20
	game.choose_village("spared")
	check(game.crew_health() == [3, 6, 3, 2] and StorySession.checkpoint().health == [3, 6, 3, 2], "The spared village's intentional free repair must be included in its save")
	game.players[0].armor = 1
	game.shop_purchase(0, "Armor", false)
	check(game.players[0].armor == 2 and game.players[0].max_armor == 4, "Workshop armor must preserve existing missing armor")
	var paid_supplies: int = game.supplies
	game.close_upgrade_shop()
	game.retry_checkpoint()
	game.set_activity(false)
	check(game.players[0].armor == 2 and game.supplies == paid_supplies and StorySession.checkpoint().health[0] == 2, "Workshop saves and retries must agree on purchased armor, injuries and supplies")
	game.village_choice = ""
	freeze(15, [1, 2, 0, 1])
	game.choose_village("raided")
	check(StorySession.checkpoint().health == [1, 2, 0, 1], "Raiding the village must not secretly repair the saved crew")
	# Defensive loading: clamp over-capacity health and ignore malformed fields.
	file.load(StorySession.save_path)
	file.set_value("story", "health", [999, 0, "broken", -8])
	file.save(StorySession.save_path)
	await boot(true)
	check(game.crew_health() == [4, 0, 3, 2], "Stored health must respect the equipped maximum and safely handle malformed slots")
	game.players[1].equip_part("Engine")
	check(game.players[1].armor == 0 and not game.players[1].alive, "Changing a downed tank's equipment must not create health without a revive")
	file.load(StorySession.save_path)
	file.set_value("story", "health", "invalid")
	file.save(StorySession.save_path)
	check(StorySession.checkpoint().health == [-1, -1, -1, -1], "Malformed health data must fall back to the older healthy-save behavior")
	# Returning solo in a previously downed seat must not trap the save in an
	# unwinnable defeat/retry loop. This does not heal surviving returning seats.
	StorySession.save(6, 8, "", false, [], [], [0, 2])
	StorySession.devices = [-1]
	await boot(true)
	check(game.crew_health() == [1, 2, -1, -1] and game.players[0].alive, "A reduced crew with no surviving seat must receive one emergency armor point")
	# Debug jumps remain fresh tests and never change the regular adventure save.
	var saved_bytes := FileAccess.get_file_as_bytes(StorySession.save_path)
	game.debug_mode = true
	game.save_progress = false
	game.start_debug_checkpoint(8)
	check(game.crew_health() == [3, -1, -1, -1] and FileAccess.get_file_as_bytes(StorySession.save_path) == saved_bytes, "Debug checkpoint selection must start healthy without changing saved injuries")
	StorySession.debug_checkpoint = -1
	await boot(false)
	check(game.chapter == 0 and game.crew_health() == [3, -1, -1, -1], "New adventures must begin with fresh healthy tanks")
	game.queue_free()
	await frames(3)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(StorySession.save_path))
	print("Checkpoint health checks: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)
