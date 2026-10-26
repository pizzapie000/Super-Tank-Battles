extends SceneTree

const Controls = preload("res://scripts/input/controller_input.gd")
var wii: Node
var failures := 0
var sequence := 0
var remotes: Array[Dictionary] = []

func _initialize() -> void:
	run.call_deferred()
	create_timer(60).timeout.connect(func(): push_error("Wii menu check timed out"); quit(1))

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func frames(count: int = 2) -> void:
	for _frame in range(count):
		sequence += 1
		wii.accept_snapshot({"version": 1, "token": wii.token, "seq": sequence, "devices": remotes}, wii.seconds())
		wii.advance_pointers(1.0 / 60) # Autoload processing is disabled for synthetic input.
		await process_frame
		await physics_frame

func tap(bits: int, remote: int = 0) -> void:
	remotes[remote].buttons = bits
	await frames()
	remotes[remote].buttons = 0
	await frames()

func point_at(button: Control) -> void:
	var point: Vector2 = button.get_global_transform_with_canvas() * (button.size * 0.5) / root.get_visible_rect().size
	remotes[0].ir = [1 - point.x, point.y]
	# Deliberately return to pointing after a navigation test's brief focus lock.
	for helper in get_nodes_in_group("wii_menus"): helper.pointer_resume_at.clear()
	await frames(8)

func named_button(scope: Node, title: String) -> BaseButton:
	for button in scope.find_children("*", "BaseButton", true, false):
		if button.text == title: return button
	return null

func run() -> void:
	wii = Controls.bridge()
	wii.set_process(false)
	wii.calibration.clear()
	PlayerSetup.settings_path = "user://wii_menu_players_smoke.cfg"
	PlayerSetup.loaded = true
	PlayerSetup.bindings = [{"kind": "wii", "id": "menu-smoke-0"}, {"kind": "off"}, {"kind": "off"}, {"kind": "off"}]
	StorySession.settings_path = "user://wii_menu_settings_smoke.cfg"
	StorySession.save_path = "user://wii_menu_story_smoke.cfg"
	StorySession.skip_tutorial = false
	StorySession.resume_story = false
	for slot in range(2):
		remotes.append({"slot": slot, "id": "menu-smoke-%d" % slot, "connected": true, "nunchuk": true, "stick": [0, 0], "buttons": 0, "c": false, "z": false, "ir": null})
	await frames()
	var menu = load("res://scenes/game/MainMenu.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	await frames(4)
	await point_at(menu.skip_tutorial_checkbox)
	await tap(8)
	check(menu.skip_tutorial_checkbox.button_pressed and StorySession.skip_tutorial, "Pointing and A must toggle the real tutorial checkbox")
	await tap(8)
	check(not StorySession.skip_tutorial, "A second press must toggle the checkbox back off")
	await point_at(named_button(menu, "ENEMY FIELD GUIDE"))
	await tap(8)
	check(is_instance_valid(menu.guide), "The pointer must open the field guide without the A release closing it")
	await tap(4)
	check(not is_instance_valid(menu.guide), "The remote B trigger must close a menu without firing gameplay shells")
	await point_at(named_button(menu, "WII REMOTE SETUP"))
	await tap(8)
	var setup: Node
	for child in menu.get_children():
		if child.scene_file_path.ends_with("WiiSetup.tscn"): setup = child
	check(is_instance_valid(setup), "The main menu must open Wii Setup using the pointer")
	# A modal must not click through to the field guide beneath it.
	await point_at(named_button(menu, "ENEMY FIELD GUIDE"))
	await tap(8)
	check(not is_instance_valid(menu.guide), "A setup overlay must block buttons behind it")
	remotes[0].z = true
	await frames()
	remotes[0].z = false
	await frames()
	check(not is_instance_valid(setup), "Nunchuk Z must return from Wii Setup")
	remotes[0].ir = null
	menu.skip_tutorial_checkbox.grab_focus()
	var before: Control = root.gui_get_focus_owner()
	await tap(0x0400)
	check(root.gui_get_focus_owner() != before, "The Wii directional pad must navigate without the sensor bar")
	before = root.gui_get_focus_owner()
	remotes[0].stick = [0, 1]
	await frames(3)
	check(root.gui_get_focus_owner() != before, "The Nunchuk must move menu focus without relying on native joypad state")
	remotes[0].stick = [0, 0]
	await frames()
	# All enabled main-menu controls must be reachable by directional navigation.
	var helper = menu.get_node("WiiMenu")
	var reachable: Array[Control] = [named_button(menu, "NEW ADVENTURE")]
	var cursor := 0
	while cursor < reachable.size():
		var start := reachable[cursor]
		cursor += 1
		for direction in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
			start.grab_focus()
			helper.move_focus(direction)
			var reached := root.gui_get_focus_owner()
			if reached != null and not reachable.has(reached): reachable.append(reached)
	for control in helper.buttons(): check(reachable.has(control), "Directional navigation must reach " + control.text)
	# Dropdowns use A to open/confirm, stick/pad to choose, B to cancel.
	menu.mission_select.add_item("Menu smoke mission", 99)
	menu.mission_select.select(0)
	await point_at(menu.mission_select)
	await tap(8)
	check(menu.mission_select.get_popup().visible, "A must open a mission dropdown")
	remotes[0].ir = null
	await tap(0x0400)
	await tap(8)
	check(menu.mission_select.selected == 1 and not menu.mission_select.get_popup().visible, "Pad and A must choose a dropdown item and close it")
	await tap(8)
	await tap(4)
	check(not menu.mission_select.get_popup().visible and menu.mission_select.selected == 1, "B must cancel a dropdown without changing its selection")
	await point_at(named_button(menu, "NEW ADVENTURE"))
	await tap(8)
	await frames(35)
	var game = current_scene
	check(game.scene_file_path.ends_with("Adventure.tscn") and game.phase == "intro" and StorySession.devices == [1000], "The shared main-menu setup must start the adventure directly with its assigned Wii player")
	game.save_progress = false
	game.set_process(false)
	await tap(8, 1)
	check(game.phase == "intro", "An unassigned remote must not skip another crew's intro")
	await tap(8)
	check(game.phase == "tutorial" and game.tutorial_step == 0 and not game.intro_engine_audio.playing, "Wii A must skip assembly once, stop its audio, and preserve the tutorial")
	game.load_chapter(0)
	game.phase = "intro"
	game.set_activity(false)
	await tap(0x1000)
	check(game.phase == "tutorial", "Plus must also skip the assembly cutscene")
	remotes[0].c = true
	await frames()
	game._process(2.01)
	remotes[0].c = false
	await frames()
	check(game.chapter == 1 and game.stage_ready_time == 0, "Holding Nunchuk C must skip training directly into the factory escape")
	game.pause_story()
	await frames()
	await point_at(named_button(game.modal, "ENEMY FIELD GUIDE"))
	await tap(8)
	check(is_instance_valid(game.field_guide) and game.paused, "Pointer + A must open the in-battle field guide while preserving pause")
	await tap(4)
	check(not is_instance_valid(game.field_guide) and game.paused, "B must return to the pause menu without resuming combat")
	await point_at(named_button(game.modal, "RESUME"))
	await tap(8)
	check(not game.paused and not is_instance_valid(game.modal), "Pointer + A must resume from the pause menu")
	game.queue_free()
	current_scene = null
	await frames()
	for path in [StorySession.settings_path, StorySession.save_path, PlayerSetup.settings_path]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	PlayerSetup.settings_path = "user://player_controls.cfg"
	PlayerSetup.loaded = false
	StorySession.settings_path = "user://story_settings.cfg"
	StorySession.save_path = "user://adventure.cfg"
	StorySession.devices = [-1]
	StorySession.load_preferences()
	wii.disconnect_all()
	wii.load_calibration()
	print("Wii menu checks: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)
