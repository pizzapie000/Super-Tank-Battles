extends SceneTree

var failures := 0

func _initialize() -> void:
	run.call_deferred()
	create_timer(90).timeout.connect(func(): quit(1))

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func frames(count: int) -> void:
	for i in range(count):
		await physics_frame
		await process_frame

func key(code: int) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await frames(1)
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await frames(2)

func button_in(node: Node, title: String) -> Button:
	for button in node.find_children("*", "Button", true, false):
		if button.text == title: return button
	return null

func enter(game: Node2D) -> void:
	Input.action_press("rematch")
	game._process(0)
	Input.action_release("rematch")
	await frames(2)

func run() -> void:
	var old_path := CampaignProgress.save_path
	CampaignProgress.save_path = "user://mission_debug_smoke.cfg"
	var config := ConfigFile.new()
	config.set_value("campaign", "unlocked", 20)
	config.save(CampaignProgress.save_path)
	var saved := FileAccess.get_file_as_bytes(CampaignProgress.save_path)
	var menu = load("res://scenes/game/MainMenu.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	await frames(3)
	check(menu.mission_select.item_count == 20, "Regular mission selection must keep its normal unlock limit")
	var debug_button := button_in(menu, "DEBUG MISSIONS")
	check(debug_button != null, "Classic Missions must expose a Debug Missions button")
	debug_button.grab_focus()
	debug_button.pressed.emit()
	await frames(3)
	check(menu.mission_picker.checkpoint_buttons.size() == 50, "Mission debugging must list all 50 missions")
	await key(KEY_DOWN)
	check(root.gui_get_focus_owner() == menu.mission_picker.checkpoint_buttons[20], "The mission picker must start at saved progress and navigate to locked missions")
	await key(KEY_ESCAPE)
	check(not is_instance_valid(menu.mission_picker) and root.gui_get_focus_owner() == debug_button, "Cancel must return focus without changing the normal selection")
	check(FileAccess.get_file_as_bytes(CampaignProgress.save_path) == saved, "Browsing debug missions must leave normal progress untouched")
	debug_button.pressed.emit()
	await frames(3)
	menu.mission_picker.checkpoint_buttons[49].grab_focus()
	menu.mission_picker.keep_focus_visible()
	await frames(3)
	check(menu.mission_picker.scroll.scroll_vertical > 0, "The mission picker must scroll to mission 50")
	await key(KEY_ENTER)
	var game = current_scene
	game.set_process(false)
	check(game.mission == 50 and game.debug_mode and not game.save_progress and game.lives == 3, "A locked mission must launch directly as a separate no-save debug run")
	for mission in range(1, 51):
		game.mission = mission
		game.start_round()
		await frames(1)
		check(game.player.alive and game.tanks.size() == game.enemies.size() + 1 and not game.save_progress, "Every numbered mission must load normally in debug mode")
	game.mission = 20
	game.start_round()
	game.countdown = 0
	game.active = true
	game.player.position = Vector2(300, 300)
	game.player.turret_angle = 0
	game.fire_shell(game.player)
	game.drop_mine(game.player)
	Input.action_press("pause_game")
	game._process(0)
	Input.action_release("pause_game")
	await frames(2)
	game.show_debug_missions()
	await frames(3)
	var shell = game.get_node("Shells").get_child(0)
	var mine = game.get_node("Mines").get_child(0)
	var point: Vector2 = shell.position
	var age: float = mine.age
	await frames(12)
	check(game.paused and shell.position == point and mine.age == age, "Choosing another debug mission must keep shells and mines frozen")
	await key(KEY_ESCAPE)
	check(game.paused and game.debug_mission_button.visible and not is_instance_valid(game.mission_picker), "Canceling the in-battle picker must preserve pause")
	game.show_debug_missions()
	await frames(3)
	game.mission_picker.checkpoint_buttons[24].grab_focus()
	await key(KEY_ENTER)
	check(game.mission == 25 and not game.paused and game.countdown > 0 and game.lives == 3 and game.get_node("Shells").get_child_count() == 0 and game.get_node("Mines").get_child_count() == 0, "Switching missions must start fresh and clear previous combat")
	game.lives = 1
	game.player.take_hit()
	await frames(3)
	await enter(game)
	check(game.mission == 25 and game.lives == 3 and game.player.alive, "Losing all debug lives must retry the same mission instead of returning to mission one")
	for enemy in game.enemies: enemy.take_hit()
	await frames(3)
	await enter(game)
	check(game.mission == 26, "Debug victories must still advance to the next mission")
	game.mission = 50
	game.start_round()
	for enemy in game.enemies: enemy.take_hit()
	await frames(3)
	await enter(game)
	check(game.mission == 50 and game.lives == 3, "Finishing a debug campaign must permit another mission 50 attempt")
	check(FileAccess.get_file_as_bytes(CampaignProgress.save_path) == saved, "Debug clears, retries and mission 50 completion must never alter normal unlocks")
	change_scene_to_file("res://scenes/game/MainMenu.tscn")
	await frames(3)
	menu = current_scene
	check(CampaignProgress.debug_mission == 0 and menu.mission_select.item_count == 20, "Returning to the main menu must leave debug mode and preserve regular progress")
	menu.start_campaign()
	await frames(3)
	game = current_scene
	game.set_process(false)
	check(not game.debug_mode and game.save_progress and game.mission == 20 and not is_instance_valid(game.debug_mission_button), "Regular Play Missions must restore normal mode at the saved mission")
	for enemy in game.enemies: enemy.take_hit()
	await frames(3)
	check(CampaignProgress.highest_mission() == 21, "Regular victories must still save new mission unlocks")
	for child in game.get_children():
		if child is AudioStreamPlayer: child.stop()
	game.queue_free()
	await frames(10)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(CampaignProgress.save_path))
	CampaignProgress.save_path = old_path
	CampaignProgress.debug_mission = 0
	print("MISSION DEBUG SMOKE: %s" % ("PASS" if failures == 0 else "%d FAILURE(S)" % failures))
	quit(0 if failures == 0 else 1)
