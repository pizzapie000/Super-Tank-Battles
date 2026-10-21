extends SceneTree

const Hints = preload("res://scripts/input/control_hints.gd")
const Tutorial = preload("res://scripts/story/tutorial_lessons.gd")
const Controls = preload("res://scripts/input/controller_input.gd")
const DuelSession = preload("res://scripts/pvp/duel_session.gd")
var failures := 0
var sequence := 0
var wii: Node

func _initialize() -> void:
	run.call_deferred()
	create_timer(45).timeout.connect(func(): push_error("Control hint checks timed out"); quit(1))

func check(condition: bool, message: String) -> void:
	if condition: return
	failures += 1
	push_error(message)

func frames(count: int = 2) -> void:
	for _frame in range(count): await process_frame

func remote(connected: bool) -> void:
	sequence += 1
	wii.accept_snapshot({"version": 1, "token": wii.token, "seq": sequence, "devices": [{"slot": 0, "id": "hint-smoke", "connected": connected, "nunchuk": true, "stick": [0, 0], "buttons": 0, "c": false, "z": false, "ir": [0.5, 0.5]}]}, wii.seconds())

func keyboard_only(text: String, context: String) -> void:
	for unwanted in ["STICK", "NUNCHUK", "CONTROLLER", "WII", "PLUS", "MINUS", "RT /", " / A", "TRIANGLE", "CIRCLE"]:
		check(not text.to_upper().contains(unwanted), context + " must hide unused controller prompts: " + unwanted)

func run() -> void:
	wii = Controls.bridge()
	wii.set_process(false)
	wii.disconnect_all()
	PlayerSetup.loaded = true
	PlayerSetup.bindings = [{"kind": "keyboard", "device": -1}, {"kind": "off"}, {"kind": "off"}, {"kind": "off"}]
	StorySession.devices = [-1]
	StorySession.resume_story = false
	StorySession.debug_checkpoint = -1
	StorySession.skip_tutorial = false
	remote(true)
	for step in range(Tutorial.LESSONS.size()):
		var lesson := Tutorial.lesson(step, [-1])
		keyboard_only(lesson.body + " " + " ".join(lesson.controls), "Keyboard lesson %d with an unused connected remote" % step)
	check(Tutorial.lesson(1, [-1]).controls == ["WASD — Move"], "Keyboard movement must name only WASD")
	check(Tutorial.lesson(2, [-1]).controls[0].contains("MOUSE") and Tutorial.lesson(2, [-1]).controls[0].contains("CLICK"), "Keyboard firing must teach mouse aim and click")
	check(Tutorial.lesson(3, [-1]).controls == ["E — Place a mine"], "Keyboard mines must show E alone")
	check(Hints.buttons("repair", [-1]) == "R" and Hints.buttons("skip_tutorial", [-1]) == "T", "Keyboard repairs and skip must hide gamepad alternatives")
	var game = load("res://scenes/story/Adventure.tscn").instantiate()
	game.save_progress = false
	game.check_devices = false
	root.add_child(game)
	game.set_process(false)
	game.finish_intro()
	for step in range(Tutorial.LESSONS.size()):
		game.tutorial_step = step
		game.tutorial_step_time = 100
		var lesson: Dictionary = game.tutorial_presentation()
		keyboard_only(lesson.body + " " + " ".join(lesson.controls) + " " + lesson.status + " " + lesson.skip, "The rendered keyboard tutorial")
	keyboard_only(game.controls_footer() + " " + game.intro_skip_hint(), "Campaign HUD and movie skip")
	StorySession.devices = [1000]
	check(Tutorial.lesson(1, StorySession.devices).controls == ["NUNCHUK STICK — Move"], "An assigned connected remote must teach the Nunchuk")
	check(Tutorial.lesson(2, StorySession.devices).controls[0].contains("POINT AT THE SCREEN") and not Tutorial.lesson(2, StorySession.devices).controls[0].contains("MOUSE"), "Wii aiming must teach pointing without keyboard or gamepad aim")
	check(Tutorial.lesson(3, StorySession.devices).controls == ["Z — Place a mine"], "Wii mines must show Z")
	check(game.intro_skip_hint() == "A / PLUS — skip intro" and not game.controls_footer().contains("START"), "Wii-only HUD and intro must omit gamepad Start and keyboard controls")
	StorySession.devices = [-1, 1000]
	var mixed := Tutorial.lesson(2, StorySession.devices)
	check(mixed.controls.size() == 2 and mixed.controls[0].contains("KEYBOARD") and mixed.controls[1].contains("WII REMOTE"), "Mixed crews must get separate readable hints for each active control family")
	check(not game.controls_footer().contains("START") and game.controls_footer().contains("ESC / PLUS"), "A mixed keyboard/Wii crew must not display ordinary controller buttons")
	remote(false)
	for step in range(Tutorial.LESSONS.size()):
		var lesson := Tutorial.lesson(step, [-1, 1000, 7])
		keyboard_only(lesson.body + " " + " ".join(lesson.controls), "Saved disconnected seats")
	check(Hints.active_devices([-1, 1000, 7]) == [-1], "Disconnected Wii and ordinary controllers must be filtered out")
	StorySession.devices = [1000]
	var waiting: Dictionary = game.tutorial_presentation()
	check(waiting.controls == ["Reconnect your assigned control to continue."] and waiting.skip.is_empty(), "A fully disconnected crew must see recovery text instead of stale button instructions")
	StorySession.devices = [-1, 1000]
	check(Hints.for_device("fire", 7) == "RT / RB" and Hints.for_device("pause", 7) == "START", "Ordinary controller labels must use their own trigger and Start mappings")
	check(Hints.buttons("interact", [-2, -3]) == "H / .", "Shared keyboard hints must use each assigned layout's real interaction key")
	var menu = load("res://scenes/game/MainMenu.tscn").instantiate()
	root.add_child(menu)
	remote(true)
	menu.refresh_control_hint()
	keyboard_only(menu.control_hint_label.text, "Main menu with an unassigned connected remote")
	PlayerSetup.bindings[1] = {"kind": "wii", "id": "hint-smoke"}
	menu.refresh_control_hint()
	check(menu.control_hint_label.text.contains("WII:") and not menu.control_hint_label.text.contains("CONTROLLER:"), "The menu must reveal Wii controls only after the connected remote is assigned")
	var picker = load("res://scripts/story/checkpoint_picker.gd").new()
	picker.allowed_devices.assign([-1, 1000])
	root.add_child(picker)
	check(picker.control_hint_label.text.contains("NUNCHUK"), "Checkpoint navigation must include an active assigned Wii Remote")
	remote(false)
	menu.refresh_control_hint()
	picker.refresh_control_hint()
	keyboard_only(menu.control_hint_label.text, "Menu after Wii disconnect")
	keyboard_only(picker.control_hint_label.text, "Checkpoint picker after Wii disconnect")
	remote(true)
	var mission = load("res://scenes/game/CampaignArena.tscn").instantiate()
	mission.save_progress = false
	mission.check_devices = false
	root.add_child(mission)
	mission.set_process(false)
	keyboard_only(mission.mission_control_hint() + " " + mission.mission_footer_hint(), "Singleplayer missions when only Player 2 uses a Wii Remote")
	mission.player_device = 1000
	check(mission.mission_control_hint().contains("NUNCHUK") and not mission.mission_footer_hint().contains("START"), "Wii missions must show Plus without ordinary gamepad Start")
	DuelSession.devices = [-2, -3]
	var duel = load("res://scenes/game/DuelArena.tscn").instantiate()
	duel.check_devices = false
	root.add_child(duel)
	duel.set_process(false)
	keyboard_only(duel.duel_footer_hint(), "Shared-keyboard duel footer")
	DuelSession.devices = [1000, -2]
	check(duel.duel_control_hint(0).contains("NUNCHUK") and duel.duel_footer_hint().contains("PLUS") and not duel.duel_footer_hint().contains("START"), "Mixed Wii duels must show only the controls in use")
	for node in [game, menu, picker, mission, duel]: node.queue_free()
	await frames(10)
	DuelSession.devices = [-2, -3]
	StorySession.devices = [-1]
	PlayerSetup.loaded = false
	wii.disconnect_all()
	print("CONTROL HINTS SMOKE: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)
