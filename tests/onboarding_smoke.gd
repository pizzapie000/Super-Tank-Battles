extends SceneTree

var failures := 0
var game: Node2D

func _initialize() -> void:
	run.call_deferred()
	create_timer(120).timeout.connect(func():
		push_error("Onboarding checks exceeded their time limit")
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

func key(code: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)

func confirm() -> void:
	key(KEY_ENTER, true)
	await frames(1)
	key(KEY_ENTER, false)
	await frames(1)

func pad_skip(device: int, pressed: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.device = device
	event.button_index = JOY_BUTTON_Y
	event.pressed = pressed
	Input.parse_input_event(event)

func run() -> void:
	StorySession.save_path = "user://onboarding_smoke.cfg"
	StorySession.settings_path = "user://onboarding_smoke_settings.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(StorySession.settings_path))
	StorySession.devices = [-1, 7]
	StorySession.resume_story = false
	var menu = load("res://scenes/game/MainMenu.tscn").instantiate()
	root.add_child(menu)
	check(not menu.skip_tutorial_checkbox.button_pressed, "New players must see training by default")
	menu.skip_tutorial_checkbox.button_pressed = true
	StorySession.skip_tutorial = false
	StorySession.load_preferences()
	check(StorySession.skip_tutorial, "The main-menu checkbox must save the skip preference")
	menu.queue_free()
	await frames(2)
	StorySession.skip_tutorial = false
	game = load("res://scenes/story/Adventure.tscn").instantiate()
	game.save_progress = false
	game.check_devices = false
	root.add_child(game)
	game.set_process(false)
	await frames(2)
	game.finish_intro()
	check(game.phase == "tutorial" and game.stage_ready_time == 0, "Training must begin immediately after the cutscene")
	var start: Vector2 = game.players[0].position
	key(KEY_D, true)
	# Allow the weighted tracks to build speed.
	await frames(18)
	key(KEY_D, false)
	check(game.players[0].position.x > start.x + 15, "Players must be free to move as soon as training begins")
	for enemy in game.enemies:
		check(not enemy.controls_enabled and enemy.modulate.a == 1, "Inactive tutorial targets must be fully visible and unable to fire")
	var armor: int = game.players[0].armor
	game.players[0].take_hit()
	check(game.players[0].armor == armor and game.players[0].invulnerable, "Removing the arrival wait must preserve safe tutorial practice")
	await confirm()
	check(game.tutorial_step == 0, "The welcome must remain visible long enough to read")
	game._process(4)
	await confirm()
	check(game.tutorial_step == 1, "Enter must advance the welcome when the player is ready")
	game._process(30)
	await confirm()
	check(game.tutorial_step == 1, "Lessons must wait for the requested practice instead of racing ahead")
	key(KEY_W, true)
	await frames(105)
	key(KEY_W, false)
	game._process(0.1)
	await confirm()
	check(game.tutorial_step == 2, "Actual movement practice must unlock the aiming lesson")
	key(KEY_D, true)
	await frames(80)
	key(KEY_D, false)
	for enemy in game.enemies.slice(0, 2):
		game.players[0].turret_angle = (enemy.position - game.players[0].position).angle()
		game.fire_shell(game.players[0])
		await frames(135)
	check(game.practice_kills >= 2, "Actual shells must be able to complete the safe target practice")
	game._process(4)
	check(game.tutorial_step == 2, "Completed actions must still wait for the player's confirmation")
	await confirm()
	check(game.tutorial_step == 3, "Confirmed target practice must lead to the mine lesson")
	key(KEY_E, true)
	await frames(3)
	key(KEY_E, false)
	game._process(4)
	await confirm()
	check(game.tutorial_step == 4, "Trying a real mine must lead to the powerup lesson")
	var dropped_part = game.get_node("Powerups").get_child(0)
	game.players[0].position = dropped_part.position
	game.update_powerup_drops(0.4)
	check(game.players[0].equipped_part.is_empty() and dropped_part.prompt.contains("F TO EQUIP"), "The tutorial must wait for an explicit F press beside the drop")
	key(KEY_F, true)
	await frames(1)
	key(KEY_F, false)
	await frames(1)
	game._process(4.1)
	await confirm()
	check(game.tutorial_step == 5 and game.players[0].equipped_part == "Loader", "The expanded tutorial must teach fitting a real part")
	game._process(6)
	check(game.phase == "tutorial", "The alarm must wait until the crew confirms the final lesson")
	await confirm()
	check(game.phase == "alarm" and not game.players[0].invulnerable, "Confirming the final lesson must start real security combat")
	# Hold-to-skip requires a continuous hold, supports assigned pads, and starts safely.
	game.load_chapter(0)
	key(KEY_T, true)
	await frames(1)
	game._process(1.8)
	key(KEY_T, false)
	await frames(1)
	game._process(0.3)
	check(game.chapter == 0 and game.tutorial_skip_time == 0, "Releasing early must cancel the skip hold")
	key(KEY_T, true)
	await frames(1)
	game._process(2)
	key(KEY_T, false)
	await frames(1)
	check(game.chapter == 1 and game.stage_ready_time == 0, "Holding T must skip directly to the factory escape without a countdown")
	game.load_chapter(0)
	pad_skip(9, true)
	await frames(1)
	game._process(2)
	pad_skip(9, false)
	await frames(1)
	check(game.chapter == 0, "An unassigned controller must not skip the crew's tutorial")
	pad_skip(7, true)
	await frames(1)
	game._process(2)
	pad_skip(7, false)
	await frames(1)
	check(game.chapter == 1 and game.stage_ready_time == 0, "Holding Y on an assigned controller must skip directly to the escape")
	# Every checkpoint and retry begins immediately; pause still freezes the game.
	game.load_chapter(2)
	check(game.stage_ready_time == 0 and game.enemies.all(func(enemy): return enemy.controls_enabled and enemy.modulate.a == 1), "A combat checkpoint must start with fully visible, active enemies")
	check(not game.players[0].invulnerable, "Normal checkpoints must begin without an arrival protection countdown")
	var frozen_time: float = game.scene_time
	game.pause_story()
	game._process(4)
	check(game.scene_time == frozen_time, "Pause must still freeze the battlefield clock")
	game.resume_game()
	var carrier = game.enemies.filter(func(enemy): return not enemy.carried_part.is_empty())[0]
	carrier.take_damage_from(game.players[0], 99)
	check(not carrier.alive and game.get_node("Powerups").get_child_count() == 1, "Carriers must be damageable and drop their upgrade immediately after arrival")
	game.fire_shell(game.players[0])
	game.drop_mine(game.players[0])
	check(game.get_node("Shells").get_child_count() > 0 and game.get_node("Mines").get_child_count() == 1, "Players must be able to fire and lay mines without waiting at a new checkpoint")
	game.retry_checkpoint()
	check(game.stage_ready_time == 0 and not game.players[0].invulnerable, "Checkpoint retries must restart combat immediately")
	# Fortress difficulty and old checkpoint numbering.
	for section in [8, 9]:
		game.load_chapter(section)
		var greens := 0
		for enemy in game.enemies:
			greens += int(enemy.enemy_name == "Green")
		if section == 9:
			check(greens == 2 and game.enemies.size() >= 6, "The separate missile battery must pair two Green tanks with a larger escort patrol")
			check(game.enemies.any(func(enemy): return enemy.enemy_name == "Pink") and game.enemies.any(func(enemy): return enemy.enemy_name == "Ash"), "Battery escorts must include moving single-shot and multi-shot tanks")
			check(not game.enemies.any(func(enemy): return enemy.boss), "The missile battery must stay separate from the Gatekeeper encounter")
		else:
			check(greens == 0 and not game.pending_attackers.any(func(spec): return spec.type == "Green"), "The combined gate and boss checkpoint must not mix in Green tanks")
			var boss = game.enemies.filter(func(enemy): return enemy.boss)[0]
			check(boss.enemy_name == "Pink" and boss.max_armor == 4 and boss.max_shells == 3 and boss.max_mines == 0 and boss.forward_speed <= 85, "The Gatekeeper must be a slow Pink tank with four armor, three shells, and no mines")
	for old in range(12):
		var file := ConfigFile.new()
		file.set_value("story", "layout_version", 2)
		file.set_value("story", "chapter", old)
		file.set_value("story", "supplies", 9)
		file.set_value("story", "village", "spared")
		file.set_value("story", "parts", ["Loader", "Armor", "", ""])
		file.save(StorySession.save_path)
		var saved := StorySession.checkpoint()
		check(saved.chapter == [0, 1, 2, 3, 5, 6, 8, 8, 11, 12, 13, 14][old] and saved.supplies == 9 and saved.village == "spared" and saved.parts[1] == "Armor", "Original twelve-stage checkpoints must preserve their matching area, supplies and parts")
	for old in range(13):
		var file := ConfigFile.new()
		file.set_value("story", "layout_version", 3)
		file.set_value("story", "chapter", old)
		file.set_value("story", "supplies", 9)
		file.set_value("story", "village", "spared")
		file.set_value("story", "parts", ["Loader", "Armor", "", ""])
		file.save(StorySession.save_path)
		var saved := StorySession.checkpoint()
		var expected: int = [0, 1, 2, 3, 5, 6, 8, 9, 8, 11, 12, 13, 14][old]
		check(saved.chapter == expected and saved.supplies == 9 and saved.village == "spared" and saved.parts[1] == "Armor", "Thirteen-stage saves must preserve village progress and remap the former boss to the combined fortress gate")
	var previous_stages := ["FactoryBoot", "FactoryEscape", "Wasteland", "WastelandScrapyard", "RuinedForest", "ForestDepths", "Fortress", "FortressBattery", "VillageApproach", "Village", "Capital", "CapitalCommand"]
	for old in range(previous_stages.size()):
		var file := ConfigFile.new()
		file.set_value("story", "layout_version", 4)
		file.set_value("story", "chapter", old)
		file.set_value("story", "supplies", 7)
		file.set_value("story", "village", "raided")
		file.set_value("story", "complete", old == 11)
		file.set_value("story", "parts", ["Loader", "Armor", "Bank Shot", "Engine"])
		file.save(StorySession.save_path)
		var saved := StorySession.checkpoint()
		check(str(game.get_node("World").get_child(saved.chapter).name) == previous_stages[old], "Pre-expansion saves must resume at their original named stage")
		check(saved.supplies == 7 and saved.village == "raided" and saved.complete == (old == 11) and saved.parts == ["Loader", "Armor", "Bank Shot", "Engine"], "Adding stages must preserve all saved crew progress and completed campaigns")
	for section in range(StorySession.SECTION_COUNT):
		StorySession.save(section, 9, "spared")
		check(StorySession.checkpoint().chapter == section, "Current checkpoints must retain their section after saving and continuing")
	# The menu preference takes effect after the assembly intro as well.
	StorySession.skip_tutorial = true
	game.phase = "intro"
	game.finish_intro()
	check(game.chapter == 1 and game.stage_ready_time == 0, "The saved menu choice must bypass training and start the escape immediately")
	for node in game.get_children():
		if node is AudioStreamPlayer:
			node.stop()
	game.queue_free()
	await frames(15)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(StorySession.save_path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(StorySession.settings_path))
	StorySession.save_path = "user://adventure.cfg"
	StorySession.settings_path = "user://story_settings.cfg"
	StorySession.skip_tutorial = false
	StorySession.devices = [-1]
	print("ONBOARDING SMOKE: %s" % ("PASS" if failures == 0 else "%d FAILURE(S)" % failures))
	quit(0 if failures == 0 else 1)
