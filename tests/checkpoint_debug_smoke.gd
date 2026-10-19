extends SceneTree

var failures := 0

func _initialize() -> void:
	run.call_deferred()
	create_timer(120).timeout.connect(func():
		push_error("Checkpoint debug checks exceeded their time limit")
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

func press_key(code: int) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await frames(1)
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await frames(2)

func press_pad(device: int, button: int) -> void:
	var event := InputEventJoypadButton.new()
	event.device = device
	event.button_index = button
	event.pressed = true
	Input.parse_input_event(event)
	await frames(1)
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await frames(2)

func button_in(node: Node, title: String) -> Button:
	for button in node.find_children("*", "Button", true, false):
		if button.text == title:
			return button
	return null

func run() -> void:
	StorySession.save_path = "user://checkpoint_debug_smoke.cfg"
	StorySession.settings_path = "user://checkpoint_debug_smoke_settings.cfg"
	StorySession.debug_checkpoint = -1
	StorySession.resume_story = false
	StorySession.save(6, 13, "spared", false, ["Loader", "Armor", "Bank Shot", "Engine"])
	var saved_bytes := FileAccess.get_file_as_bytes(StorySession.save_path)
	var menu = load("res://scenes/game/MainMenu.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	await frames(2)
	var debug_button := button_in(menu, "DEBUG CHECKPOINTS")
	check(debug_button != null, "True Campaign must expose the checkpoint debugger from the main menu")
	debug_button.grab_focus()
	debug_button.pressed.emit()
	await frames(3)
	var picker = menu.checkpoint_picker
	var world = load("res://scenes/story/StoryWorld.tscn").instantiate()
	check(picker.checkpoint_buttons.size() == world.get_child_count(), "The picker must list every scene in the current campaign without a separate title list")
	for i in range(world.get_child_count()):
		check(picker.checkpoint_buttons[i].text.begins_with("%02d  /  %s" % [i + 1, world.get_child(i).title]), "Checkpoint numbers and titles must match the actual campaign scenes")
	world.free()
	await press_key(KEY_DOWN)
	check(root.gui_get_focus_owner() == picker.checkpoint_buttons[7], "Keyboard arrows must navigate the checkpoint list")
	await press_key(KEY_ESCAPE)
	check(not is_instance_valid(menu.checkpoint_picker) and root.gui_get_focus_owner() == debug_button, "Cancel must return to the menu without starting or altering a run")
	check(StorySession.debug_checkpoint == -1 and FileAccess.get_file_as_bytes(StorySession.save_path) == saved_bytes, "Browsing the debugger must leave normal progress untouched")
	debug_button.pressed.emit()
	await frames(2)
	picker = menu.checkpoint_picker
	picker.checkpoint_buttons.back().grab_focus()
	picker.keep_focus_visible()
	await frames(2)
	check(picker.scroll.scroll_vertical > 0, "The growing checkpoint list must scroll to its final entry")
	await press_pad(7, JOY_BUTTON_A)
	await frames(35)
	var lobby = current_scene
	check(lobby.scene_file_path.ends_with("Lobby.tscn") and StorySession.debug_checkpoint == 14 and not StorySession.resume_story, "Selecting any checkpoint must lead through the normal crew lobby in debug mode")
	check(button_in(lobby, "TEST THIS CHECKPOINT") != null, "The crew lobby must clearly identify a checkpoint test")
	await press_pad(7, JOY_BUTTON_A)
	check(StorySession.devices == [-1, 7], "Debug runs must still support joining a co-op crew")
	await press_pad(7, JOY_BUTTON_START)
	await frames(43)
	var game = current_scene
	game.set_process(false)
	game.check_devices = false
	check(game.scene_file_path.ends_with("Adventure.tscn") and game.debug_mode and not game.save_progress, "The lobby must launch a test session with saving disabled")
	check(game.chapter == 14 and game.phase == "battle" and game.stage_ready_time > 4 and game.players.size() == 2, "A debug start must reach its selected checkpoint directly with a protected co-op arrival")
	# Every listed stage must load and retain the normal five-second arrival.
	for i in range(game.get_node("World").get_child_count()):
		game.start_debug_checkpoint(i)
		check(game.chapter == i and game.stage_ready_time == 5 and game.players.all(func(crew): return crew.alive and crew.invulnerable), "Every debug checkpoint must spawn a healthy protected crew")
		check(game.phase != "intro", "Checkpoint testing must bypass the assembly movie")
		game.persist_story(true)
		check(FileAccess.get_file_as_bytes(StorySession.save_path) == saved_bytes, "Debug loads and explicit save requests must never overwrite the adventure save")
	game.start_debug_checkpoint(2)
	game.update_stage_ready(5)
	for enemy in game.enemies:
		enemy.max_shells = 0
	game.players[0].turret_angle = PI / 2
	game.fire_shell(game.players[0])
	game.drop_mine(game.players[0])
	game.pause_story()
	debug_button = button_in(game.modal, "DEBUG CHECKPOINTS")
	debug_button.grab_focus()
	debug_button.pressed.emit()
	await frames(3)
	picker = game.checkpoint_picker
	check(game.paused and not game.modal.visible, "The debug pause picker must keep the battle paused")
	var shell = game.get_node("Shells").get_child(0)
	var mine = game.get_node("Mines").get_child(0)
	var at: Vector2 = shell.position
	var age: float = mine.age
	var crew_at: Vector2 = game.players[0].position
	await frames(12)
	game._process(3)
	check(shell.position == at and mine.age == age and game.players[0].position == crew_at, "Actual projectiles, mines and tanks must stay frozen while choosing a checkpoint")
	await press_pad(9, JOY_BUTTON_A)
	check(game.chapter == 2 and is_instance_valid(game.checkpoint_picker), "An unassigned controller must not change checkpoints")
	await press_pad(7, JOY_BUTTON_B)
	check(game.paused and game.modal.visible and not is_instance_valid(game.checkpoint_picker) and root.gui_get_focus_owner() == debug_button, "Cancel must restore the same paused battle and button focus")
	debug_button.pressed.emit()
	await frames(2)
	picker = game.checkpoint_picker
	picker.checkpoint_buttons[7].grab_focus()
	await press_key(KEY_ENTER)
	check(game.chapter == 7 and not game.paused and game.stage_ready_time == 5 and game.get_node("Shells").get_child_count() == 0 and game.get_node("Mines").get_child_count() == 0, "Selecting a new checkpoint must clear the old battle and begin a fresh protected test")
	game.players[0].armor = 1
	game.supplies = 0
	game.retry_checkpoint()
	check(game.players[0].armor == 3 and game.supplies == 2 and game.chapter == 7, "Debug retries must restore the chosen checkpoint's starting crew and supplies")
	# A pending screen transition must not later override the debug selection.
	game.advance_chapter()
	game.pause_story()
	game.show_debug_checkpoints()
	game.checkpoint_picker.checkpoint_buttons[10].grab_focus()
	await press_pad(7, JOY_BUTTON_A)
	await frames(70)
	check(game.chapter == 10 and game.fade_alpha == 0 and game.stage_ready_time == 5, "Jumping during a paused transition must cancel its pending stage change")
	game.start_debug_checkpoint(14)
	game.finish_story()
	check(FileAccess.get_file_as_bytes(StorySession.save_path) == saved_bytes, "Finishing a test run must not mark the regular adventure complete")
	game.return_menu()
	await frames(3)
	check(StorySession.debug_checkpoint == -1, "Returning to modes must exit debug mode")
	menu = current_scene
	menu.start_story(true)
	await frames(35)
	lobby = current_scene
	lobby.start_story()
	await frames(43)
	game = current_scene
	game.set_process(false)
	game.check_devices = false
	game.set_activity(false)
	check(not game.debug_mode and game.save_progress and game.chapter == 6 and game.supplies == 13 and game.village_choice == "spared" and game.part_loadouts[1] == "Armor", "Continue after debugging must restore the untouched normal checkpoint and resume normal saving")
	game.pause_story()
	check(button_in(game.modal, "DEBUG CHECKPOINTS") == null, "Normal adventures must retain their regular pause menu")
	for child in game.get_children():
		if child is AudioStreamPlayer:
			child.stop()
	game.queue_free()
	await frames(8)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(StorySession.save_path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(StorySession.settings_path))
	StorySession.save_path = "user://adventure.cfg"
	StorySession.settings_path = "user://story_settings.cfg"
	StorySession.debug_checkpoint = -1
	StorySession.resume_story = false
	StorySession.devices = [-1]
	print("CHECKPOINT DEBUG SMOKE: %s" % ("PASS" if failures == 0 else "%d FAILURE(S)" % failures))
	quit(0 if failures == 0 else 1)
