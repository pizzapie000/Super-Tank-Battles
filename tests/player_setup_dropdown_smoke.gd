extends SceneTree

const Controls = preload("res://scripts/input/controller_input.gd")
var failures := 0
var wii: Node

func _initialize() -> void:
	run.call_deferred()
	create_timer(30).timeout.connect(func(): push_error("Player setup dropdown check timed out"); quit(1))

func check(condition: bool, message: String) -> void:
	if condition: return
	failures += 1
	push_error(message)

func choose(hub: Control, slot: int, label: String) -> void:
	var selector: OptionButton = hub.selectors[slot]
	for index in range(selector.item_count):
		if selector.get_item_text(index).begins_with(label):
			selector.select(index)
			selector.item_selected.emit(index)
			return
	check(false, "The player dropdown must offer " + label)

func run() -> void:
	wii = Controls.bridge()
	wii.set_process(false)
	PlayerSetup.settings_path = "user://player_setup_dropdown_smoke.cfg"
	PlayerSetup.loaded = true
	# Reproduce returning from a shared-keyboard duel to a solo adventure.
	PlayerSetup.bindings = [{"kind": "keyboard", "device": -2}, {"kind": "keyboard", "device": -3}, {"kind": "off"}, {"kind": "off"}]
	var menu = load("res://scenes/game/MainMenu.tscn").instantiate()
	root.add_child(menu)
	var hub: Control = menu.player_hub
	choose(hub, 0, "Keyboard + mouse")
	check(hub.error.is_empty() and PlayerSetup.device(0) == -1, "Selecting keyboard and mouse/trackpad from the real dropdown must never request a controller connection")
	check(hub.selectors[0].get_item_text(hub.selectors[0].selected).begins_with("Keyboard + mouse"), "The dropdown must keep the newly selected keyboard control")
	choose(hub, 1, "Off")
	check(PlayerSetup.problem("campaign").is_empty() and PlayerSetup.selected() == [-1], "Turning off the other duel seat must leave a valid solo WASD/trackpad campaign")
	PlayerSetup.loaded = false
	PlayerSetup.load_preferences()
	check(PlayerSetup.device(0) == -1 and PlayerSetup.device(1) == PlayerSetup.OFF, "The solo keyboard selection must survive a preferences reload")
	# Repeated changes must preserve keyboard codes, Off, and real remote IDs.
	for _round in range(3):
		choose(hub, 0, "Keyboard: ESDF")
		choose(hub, 1, "Keyboard: arrows")
		check(PlayerSetup.device(0) == -2 and PlayerSetup.device(1) == -3 and PlayerSetup.problem("duel").is_empty(), "Both shared-keyboard choices must still form a valid duel")
		choose(hub, 0, "Keyboard + mouse")
		choose(hub, 1, "Off")
		check(PlayerSetup.device(0) == -1 and PlayerSetup.device(1) == PlayerSetup.OFF and hub.error.is_empty(), "Switching back from a duel must consistently restore solo keyboard controls")
	wii.accept_snapshot({"version": 1, "token": wii.token, "seq": 1, "devices": [{"slot": 0, "id": "dropdown-smoke", "connected": true, "nunchuk": true, "stick": [0,0], "buttons": 0, "c": false, "z": false, "ir": null}]}, wii.seconds())
	hub.refresh()
	choose(hub, 0, "Wii Remote 1")
	check(PlayerSetup.device(0) == 1000 and hub.error.is_empty(), "Wii choices must preserve their actual virtual device ID")
	choose(hub, 0, "Keyboard + mouse")
	check(PlayerSetup.device(0) == -1 and hub.error.is_empty(), "Switching from a Wii Remote to a trackpad must not depend on the remote's connection")
	# Preserve ownership checks rather than silently moving another player's control.
	choose(hub, 0, "Keyboard: ESDF")
	choose(hub, 1, "Keyboard + mouse")
	choose(hub, 0, "Keyboard + mouse")
	check(not hub.error.is_empty() and PlayerSetup.device(0) == -2 and PlayerSetup.device(1) == -1, "A duplicate assignment must show its ownership error and keep the existing seats intact")
	choose(hub, 1, "Off")
	choose(hub, 0, "Keyboard + mouse")
	check(hub.error.is_empty() and menu.ready_for_mode("campaign"), "Clearing the other seat must make keyboard and trackpad available again")
	menu.queue_free()
	for _frame in range(6): await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PlayerSetup.settings_path))
	PlayerSetup.settings_path = "user://player_controls.cfg"
	PlayerSetup.loaded = false
	wii.disconnect_all()
	print("PLAYER SETUP DROPDOWN SMOKE: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)
