extends SceneTree

const Controls = preload("res://scripts/input/controller_input.gd")
const Parts = preload("res://scripts/story/upgrade_parts.gd")
var wii: Node
var sequence := 0
var remotes: Array[Dictionary] = []
var failures := 0

func _initialize() -> void:
	run.call_deferred()
	create_timer(100).timeout.connect(func(): push_error("Shared setup / upgrade checks timed out"); quit(1))

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func frames(count: int = 2) -> void:
	for _frame in range(count):
		sequence += 1
		wii.accept_snapshot({"version": 1, "token": wii.token, "seq": sequence, "devices": remotes}, wii.seconds())
		await process_frame
		await physics_frame

func tap(bits: int, slot: int = 0) -> void:
	remotes[slot].buttons = bits
	await frames()
	remotes[slot].buttons = 0
	await frames()

func run() -> void:
	wii = Controls.bridge()
	wii.set_process(false)
	wii.calibration.clear()
	PlayerSetup.settings_path = "user://global_setup_smoke.cfg"
	PlayerSetup.loaded = true
	PlayerSetup.bindings = [{"kind": "keyboard", "device": -1}, {"kind": "off"}, {"kind": "off"}, {"kind": "off"}]
	StorySession.settings_path = "user://global_story_settings_smoke.cfg"
	StorySession.save_path = "user://global_story_smoke.cfg"
	for slot in range(4): remotes.append({"slot": slot, "id": "global-smoke-%d" % slot, "connected": true, "nunchuk": true, "stick": [0, 0], "buttons": 0, "c": false, "z": false, "ir": [0.5, 0.5]})
	await frames()
	for slot in range(4): check(PlayerSetup.assign(slot, 1000 + slot).is_empty(), "Every global seat must accept a different Wii Remote")
	check(not PlayerSetup.assign(1, 1000).is_empty(), "A single remote cannot occupy two seats")
	check(PlayerSetup.problem("campaign").is_empty() and PlayerSetup.selected().size() == 4, "A four-remote setup must be ready for campaign")
	PlayerSetup.loaded = false
	PlayerSetup.load_preferences()
	check(PlayerSetup.device(0) == 1000 and PlayerSetup.device(3) == 1003, "Saved Wii identities must restore all global seats")
	var menu = load("res://scenes/game/MainMenu.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	await frames(3)
	check(menu.player_hub.selectors.size() == 4, "The main menu must expose all four player controls")
	menu.start_campaign()
	await frames(3)
	var mission = current_scene
	check(mission.scene_file_path.ends_with("CampaignArena.tscn") and mission.player.device == 1000 and mission.tanks.filter(func(tank): return not tank is EnemyTank).size() == 1, "Missions must launch directly using only global Player 1")
	mission.save_progress = false
	mission.countdown = 0
	mission.active = true
	mission.set_controls(true)
	for enemy in mission.enemies: enemy.controls_enabled = false; enemy.set_physics_process(false)
	mission.player.position = Vector2(400, 400)
	remotes[0].stick = [1, 0]
	remotes[1].stick = [0, 1]
	await frames(20)
	check(mission.player.velocity.x > 100 and absf(mission.player.velocity.y) < 1, "Player 1's Wii Nunchuk must drive missions while Player 2 cannot steer it")
	remotes[0].stick = [0, 0]
	remotes[1].stick = [0, 0]
	await tap(4)
	check(mission.player.active_shells > 0, "The Wii B trigger must fire real mission shells")
	await tap(8)
	check(mission.player.active_mines == 1, "Wii A must lay a mission mine")
	await tap(0x1000)
	check(mission.paused, "Plus must pause missions")
	await tap(0x1000)
	check(not mission.paused, "Plus must resume missions")
	remotes[0].connected = false
	await frames()
	check(mission.paused and mission.missing_controller, "A disconnected mission controller must pause safely")
	remotes[0].connected = true
	await frames()
	await tap(0x1000)
	check(not mission.paused, "The assigned remote must resume after reconnecting")
	mission.queue_free()
	current_scene = null
	await frames()
	StorySession.devices.assign(PlayerSetup.selected())
	StorySession.resume_story = false
	StorySession.debug_checkpoint = 3
	var game = load("res://scenes/story/Adventure.tscn").instantiate()
	game.save_progress = false
	game.stage_ready_duration = 0
	game.check_devices = false
	root.add_child(game)
	game.set_process(false)
	game.set_activity(false)
	game.active = true
	await frames()
	check(game.players.size() == 4 and game.players[3].device == 1003, "Campaign must inherit all four global players")
	var carriers: Array = game.enemies.filter(func(enemy): return not enemy.carried_part.is_empty())
	check(carriers.size() == 4 and carriers.any(func(enemy): return Parts.WEAPONS.has(enemy.carried_part)), "The actual encounter must include flashing weapon and part carriers")
	for pickup in game.region().get_node("Parts").get_children(): check(not pickup.visible, "Campaign powerups must no longer sit on the floor")
	var victim = carriers[0]
	var carried: String = victim.carried_part
	victim.take_damage_from(game.players[1], 20)
	check(game.get_node("Powerups").get_child_count() == 1 and game.players.all(func(crew): return crew.equipped_part.is_empty()), "A carrier kill must drop an upgrade without transferring it to anyone")
	game.tank_destroyed(victim)
	check(game.get_node("Powerups").get_child_count() == 1, "A carrier must never create a duplicate drop")
	var drop = game.get_node("Powerups").get_child(0)
	for crew in game.players: crew.position = drop.position + Vector2(300, 300)
	game.players[2].position = drop.position
	game.paused = true
	game.update_powerup_drops(1)
	await tap(2, 2)
	check(drop.age == 0 and game.players[2].equipped_part.is_empty(), "Pause must freeze the drop and prevent collection")
	game.paused = false
	game.update_powerup_drops(0.1)
	check(game.get_node("Powerups").get_child_count() == 1, "The powerup must appear briefly before it can be collected")
	game.update_powerup_drops(0.3)
	check(game.players[2].equipped_part.is_empty() and drop.prompt.contains("Z / 1 TO EQUIP"), "Standing on a drop must only show the correct controller prompt")
	await tap(2, 1)
	check(game.get_node("Powerups").get_child_count() == 1, "A player outside the pickup radius must not equip a teammate's nearby drop")
	game.players[2].position += Vector2(300, 300)
	remotes[2].buttons = 2
	await frames()
	game.players[2].position = drop.position
	game.update_powerup_drops(1)
	await frames()
	check(game.players[2].equipped_part.is_empty(), "Holding 1 while approaching a drop must never equip it")
	remotes[2].buttons = 0
	await frames()
	await tap(2, 2)
	check(game.players[2].equipped_part == carried and game.players[1].equipped_part.is_empty() and game.get_node("Powerups").get_child_count() == 0, "A fresh Wii 1 press must equip the collector, regardless of who destroyed the carrier")
	var collected_supplies: int = game.supplies
	game.update_powerup_drops(1)
	check(game.supplies == collected_supplies, "Collected drops must never grant a second reward")
	game.award_powerup(game.players[1], carried)
	game.award_powerup(game.players[1], carried)
	game.award_powerup(game.players[1], carried)
	check(game.players[1].part_level == 3, "Repeated copies must improve an upgrade only to level three")
	var shooter = game.players[0]
	for wall in game.get_node("Walls").get_children(): wall.queue_free()
	await frames()
	for shell in game.get_node("Shells").get_children(): shell.retire()
	await frames()
	shooter.position = game.region().get_node("Start").global_position
	shooter.turret_angle = PI
	for kind in Parts.WEAPONS:
		shooter.equip_part(kind, 2)
		game.fire_shell(shooter)
		var shells: Array = game.get_node("Shells").get_children().filter(func(shell): return not shell.released)
		check(shells.size() == (5 if kind == "Shotgun" else 1), "Campaign " + kind + " must launch its real projectile pattern")
		if kind == "Heat Seeker" and not shells.is_empty(): check(shells[0].is_missile and shells[0].homing_turn_rate > 0 and not shells[0].homing_targets.has(game.players[1]), "Crew homing missiles must have trails and seek enemies rather than teammates")
		for shell in shells: shell.retire()
		await frames()
	var last_carrier = carriers.back()
	last_carrier.take_damage_from(game.players[0], 99)
	var waiting_drop = game.get_node("Powerups").get_child(0)
	for crew in game.players: crew.position = waiting_drop.position + Vector2(300, 300)
	game.players[3].position = waiting_drop.position
	game.players[3].alive = false
	game.update_powerup_drops(1)
	await tap(2, 3)
	check(game.get_node("Powerups").get_child_count() == 1 and game.players[3].equipped_part.is_empty(), "A downed tank must not collect a powerup")
	game.players[3].alive = true
	game.load_chapter(15)
	check(game.get_node("Powerups").get_child_count() == 0, "Starting a new checkpoint must clear uncollected drops")
	game.set_process(false)
	game.set_activity(false)
	game.active = true
	# Exercise an actual switch regardless of the weapon carried in this stage.
	game.players[2].equip_part("Loader", 1)
	game.part_loadouts[2] = "Loader"
	game.part_levels[2] = 1
	game.supplies = 20
	game.choose_village("spared")
	check(is_instance_valid(game.upgrade_shop) and game.paused, "Sparing the village must immediately open a safe upgrade shop")
	var shop = game.upgrade_shop
	shop.selected_player = 2
	shop.choose_part("Heat Seeker")
	check(game.players[2].equipped_part == "Heat Seeker" and game.supplies == 20 and game.players[2].part_level == 1, "Switching a selected crew member's powerup must spend three shared supplies")
	shop.improve_current()
	check(game.players[2].part_level == 2 and game.supplies == 18, "The first workshop improvement must cost two supplies")
	shop.improve_current()
	check(game.players[2].part_level == 3 and game.supplies == 14, "The second workshop improvement must cost four supplies")
	shop.improve_current()
	check(game.supplies == 14 and game.players[2].part_level == 3, "The shop must never spend supplies beyond the maximum level")
	game.supplies = 0
	shop.choose_part("Gatling")
	check(game.players[2].equipped_part == "Heat Seeker" and game.supplies == 0, "Unaffordable purchases must not replace a powerup")
	game.debug_mode = false
	game.persist_story()
	var saved := StorySession.checkpoint()
	check(saved.parts[2] == "Heat Seeker" and saved.part_levels[2] == 3 and saved.village == "spared", "Checkpoints must preserve upgrade type, level and workshop access")
	game.close_upgrade_shop()
	check(not game.paused and not is_instance_valid(game.upgrade_shop), "Closing the workshop must restore gameplay")
	game.village_choice = "raided"
	game.open_upgrade_shop()
	check(not is_instance_valid(game.upgrade_shop), "A raided village must never grant shop access")
	game.queue_free()
	await frames(6)
	for path in [PlayerSetup.settings_path, StorySession.settings_path, StorySession.save_path]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	PlayerSetup.settings_path = "user://player_controls.cfg"
	PlayerSetup.loaded = false
	StorySession.settings_path = "user://story_settings.cfg"
	StorySession.save_path = "user://adventure.cfg"
	StorySession.debug_checkpoint = -1
	StorySession.devices = [-1]
	wii.disconnect_all()
	wii.load_calibration()
	print("Shared setup and campaign powerup checks: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)
