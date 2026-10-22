extends SceneTree

var failures := 0

func _initialize() -> void:
	run.call_deferred()
	create_timer(60).timeout.connect(func():
		push_error("Field guide checks exceeded their time limit")
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
	event.keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)

func pad(device: int, button: int, pressed: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.device = device
	event.button_index = button
	event.pressed = pressed
	Input.parse_input_event(event)

func press_key(code: int) -> void:
	key(code, true)
	await frames(2)
	key(code, false)
	await frames(3)

func press_pad(device: int, button: int) -> void:
	pad(device, button, true)
	await frames(2)
	pad(device, button, false)
	await frames(3)

func button_in(node: Node, value: String) -> Button:
	for button in node.find_children("*", "Button", true, false):
		if button.text == value:
			return button
	return null

func check_entries(guide: Control) -> void:
	var titles: Array[String] = []
	for label in guide.find_children("*", "Label", true, false):
		titles.append(label.text)
	for profile in EnemyProfiles.TYPES:
		check(titles.has("%s  /  M%02d" % [profile.name, profile.mission]), "Every guide must include %s with its identifying name and mission" % profile.name)

func dispose(scene: Node) -> void:
	for child in scene.get_children():
		if child is AudioStreamPlayer:
			child.stop()
	scene.queue_free()
	await frames(5)

func run() -> void:
	StorySession.save_path = "user://field_guide_smoke.cfg"
	StorySession.settings_path = "user://field_guide_smoke_settings.cfg"
	StorySession.devices = [-1, 7]
	StorySession.resume_story = false
	var story = load("res://scenes/story/Adventure.tscn").instantiate()
	story.save_progress = false
	story.stage_ready_duration = 0
	story.check_devices = false
	root.add_child(story)
	story.set_process(false)
	story.load_chapter(3)
	for enemy in story.enemies:
		enemy.max_shells = 0
	story.players[0].turret_angle = PI / 2
	story.fire_shell(story.players[0])
	story.drop_mine(story.players[0])
	story.pause_story()
	var guide_button := button_in(story.modal, "ENEMY FIELD GUIDE")
	check(guide_button != null, "The story pause menu must expose the enemy guide")
	await press_pad(7, JOY_BUTTON_DPAD_DOWN)
	check(get_root().gui_get_focus_owner() == guide_button, "Any assigned controller must be able to navigate to the guide button")
	await press_pad(7, JOY_BUTTON_A)
	await frames(2)
	check(is_instance_valid(story.field_guide) and not story.modal.visible and story.paused, "Opening the guide must hide the pause menu and keep the fight paused")
	check_entries(story.field_guide)
	var shell = story.get_node("Shells").get_child(0)
	var mine = story.get_node("Mines").get_child(0)
	var shell_at: Vector2 = shell.position
	var mine_age: float = mine.age
	var tank_at: Vector2 = story.players[0].position
	var enemy_at: Vector2 = story.enemies[0].position
	var supplies: int = story.supplies
	key(KEY_W, true)
	key(KEY_R, true)
	var fire := InputEventJoypadMotion.new()
	fire.device = 7
	fire.axis = JOY_AXIS_TRIGGER_RIGHT
	fire.axis_value = 1
	Input.parse_input_event(fire)
	await frames(12)
	story._process(5)
	key(KEY_W, false)
	key(KEY_R, false)
	fire = fire.duplicate()
	fire.axis_value = 0
	Input.parse_input_event(fire)
	await frames(2)
	check(shell.position == shell_at and mine.age == mine_age and story.players[0].position == tank_at and story.enemies[0].position == enemy_at, "Reading the guide must freeze actual projectiles, mines, players and enemies")
	check(story.supplies == supplies and story.get_node("Shells").get_child_count() == 1, "Gameplay input must not repair or fire through the guide")
	await press_key(KEY_ESCAPE)
	check(not is_instance_valid(story.field_guide) and story.paused and story.modal.visible, "Escape must return to the story pause menu without resuming")
	check(get_root().gui_get_focus_owner() == guide_button, "Returning from the guide must restore pause-menu focus")
	guide_button.pressed.emit()
	await frames(2)
	await press_pad(9, JOY_BUTTON_B)
	check(is_instance_valid(story.field_guide), "An unassigned controller must not dismiss the crew's guide")
	await press_pad(7, JOY_BUTTON_B)
	check(not is_instance_valid(story.field_guide) and story.paused, "Controller B must return to the paused battle menu")
	guide_button.pressed.emit()
	await frames(2)
	await press_pad(7, JOY_BUTTON_A)
	check(not is_instance_valid(story.field_guide) and story.paused, "Controller A must activate the focused Back to Pause button")
	button_in(story.modal, "RESUME").pressed.emit()
	await frames(3)
	check(not story.paused and story.players[0].controls_enabled and shell.flight_enabled, "The crew must explicitly resume before gameplay continues")
	story.pause_story()
	button_in(story.modal, "ENEMY FIELD GUIDE").pressed.emit()
	story.check_devices = true
	story.controller_changed(7, false)
	check(not is_instance_valid(story.field_guide) and story.paused and story.modal.visible and story.missing_device, "A disconnect must replace the guide with the controller recovery menu")
	await dispose(story)
	# Classic missions and local duels share the same guide without losing their battle.
	for path in ["res://scenes/game/CampaignArena.tscn", "res://scenes/game/DuelArena.tscn"]:
		var game = load(path).instantiate()
		if path.contains("Campaign"):
			game.save_progress = false
		root.add_child(game)
		game.set_process(false)
		game.countdown = 0
		game.active = true
		game.set_controls(true)
		if path.contains("Campaign"):
			game.freeze_ordnance(false)
		game.tanks[0].separate_turret = true
		game.tanks[0].turret_angle = PI / 2
		game.fire_shell(game.tanks[0])
		Input.action_press("pause_game")
		game._process(0)
		Input.action_release("pause_game")
		await frames(2)
		check(game.paused and game.pause_guide_button.visible, "Classic and duel pauses must show a guide button")
		game.pause_guide_button.pressed.emit()
		await frames(2)
		check_entries(game.field_guide)
		shell = game.get_node("Shells").get_child(0)
		shell_at = shell.position
		var tank_id: int = game.tanks[0].get_instance_id()
		game.set_process(true)
		await frames(8)
		check(game.paused and shell.position == shell_at and not game.tanks[0].controls_enabled, "The live game loop must remain paused while reading the guide")
		await press_key(KEY_ESCAPE)
		check(game.paused and not is_instance_valid(game.field_guide) and game.pause_guide_button.visible, "Closing the guide with Escape must not also unpause the live game loop")
		game.pause_guide_button.pressed.emit()
		await frames(2)
		await press_key(KEY_ENTER)
		check(game.paused and not is_instance_valid(game.field_guide) and game.tanks[0].get_instance_id() == tank_id, "Enter on Back to Pause must not restart the arena or advance a mission")
		await press_key(KEY_ESCAPE)
		check(not game.paused and not game.pause_guide_button.visible and game.tanks[0].get_instance_id() == tank_id, "Resuming must return to the same battle")
		await dispose(game)
	var menu = load("res://scenes/game/MainMenu.tscn").instantiate()
	root.add_child(menu)
	menu.show_guide()
	await frames(2)
	check_entries(menu.guide)
	await press_key(KEY_BACKSPACE)
	check(not is_instance_valid(menu.guide) and menu.is_inside_tree(), "The main-menu guide must still return to the modes screen")
	await dispose(menu)
	StorySession.save_path = "user://adventure.cfg"
	StorySession.settings_path = "user://story_settings.cfg"
	StorySession.devices = [-1]
	print("FIELD GUIDE SMOKE: %s" % ("PASS" if failures == 0 else "%d FAILURE(S)" % failures))
	quit(0 if failures == 0 else 1)
