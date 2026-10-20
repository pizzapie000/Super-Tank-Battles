extends SceneTree

var failures := 0
var game: Node2D

func _initialize() -> void:
	run.call_deferred()

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

func pad_button(device: int, button: int, pressed: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.device = device
	event.button_index = button
	event.pressed = pressed
	Input.parse_input_event(event)

func pad_axis(device: int, axis: int, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.device = device
	event.axis = axis
	event.axis_value = value
	Input.parse_input_event(event)

func run() -> void:
	# Isolate saves from the player's real adventure.
	StorySession.save_path = "user://story_smoke_checkpoint.cfg"
	StorySession.resume_story = false
	StorySession.devices = [-1]
	check(StorySession.add_device(7) and not StorySession.add_device(7), "Controller IDs must join only once")
	check(StorySession.add_device(9) and StorySession.add_device(12) and not StorySession.add_device(13), "Crew must be capped at four distinct input devices")
	check(StorySession.stick(Vector2(0.1, 0.1)) == Vector2.ZERO and StorySession.stick(Vector2(1, 1)).length() <= 1.001, "Stick deadzone must reject drift and clamp diagonal speed")
	game = load("res://scenes/story/Adventure.tscn").instantiate()
	game.save_progress = false
	game.stage_ready_duration = 0
	game.check_devices = false
	root.add_child(game)
	game.set_process(false)
	await frames(2)
	check(game.players.size() == 4 and game.phase == "intro", "New adventure must assemble four players before the intro")
	check(game.players[1].device == 7 and game.players[2].device == 9, "Each tank must retain its own controller ID, including nonconsecutive IDs")
	game.intro_duration = 20
	game._process(19)
	check(game.phase == "intro", "The opening must respect the composer's configured duration")
	game._process(1.1)
	check(game.phase == "tutorial" and game.players[0].invulnerable, "Intro must lead to the safe factory tutorial")
	check(game.remaining_enemies() == 0 and game.enemies.size() == 3, "Practice tanks must be inactive and unable to attack")
	var armor: int = game.players[0].armor
	game.players[0].take_hit()
	check(game.players[0].armor == armor, "Tutorial must protect the crew from damage")
	# Welcome waits for confirmation before movement practice.
	game.update_tutorial(4)
	game.confirm_tutorial()
	# Actual keyboard movement and simulated per-device controller input.
	var keyboard_start: Vector2 = game.players[0].position
	key(KEY_D, true)
	await frames(15)
	key(KEY_D, false)
	check(game.players[0].position.x > keyboard_start.x + 15, "WASD must actually move the keyboard tank")
	var first_start: Vector2 = game.players[1].position
	var second_start: Vector2 = game.players[2].position
	pad_axis(7, JOY_AXIS_LEFT_X, 1)
	pad_axis(7, JOY_AXIS_RIGHT_Y, -1)
	await frames(15)
	pad_axis(7, JOY_AXIS_LEFT_X, 0)
	check(game.players[1].position.x > first_start.x + 15 and game.players[2].position.distance_to(second_start) < 2, "One controller must move only its assigned tank")
	check(absf(angle_difference(game.players[1].turret_angle, -PI / 2)) < 0.01, "Right stick must aim independently")
	pad_axis(7, JOY_AXIS_TRIGGER_RIGHT, 1)
	await frames(3)
	pad_axis(7, JOY_AXIS_TRIGGER_RIGHT, 0)
	check(game.players[1].total_shots > 0 and game.players[2].total_shots == 0, "Controller trigger must fire only its tank")
	pad_button(7, JOY_BUTTON_B, true)
	await frames(3)
	pad_button(7, JOY_BUTTON_B, false)
	check(game.players[1].total_mines == 1, "Controller B must deploy one mine per press")
	game.players[0].moved_distance = 300
	game.update_tutorial(3)
	game.confirm_tutorial()
	game.enemies[0].take_hit()
	game.enemies[1].take_hit()
	await frames(2)
	game.update_tutorial(4)
	game.confirm_tutorial()
	game.update_tutorial(4)
	game.confirm_tutorial()
	var training_part = game.region().get_node("Parts/Loader")
	game.players[0].position = training_part.global_position + Vector2(30, 0)
	game.players[0].interact_held = true
	game.update_part_pickups(0.5)
	game.players[0].interact_held = false
	game.update_tutorial(4)
	game.confirm_tutorial()
	game.update_tutorial(6)
	game.confirm_tutorial()
	check(game.phase == "alarm" and game.remaining_enemies() == 2 and not game.players[0].invulnerable, "Practice kills and mine lesson must trigger the factory alarm and real security fight")
	# Co-op shells and mines damage allies and their own owner.
	game.load_chapter(1)
	await frames(2)
	game.set_activity(false)
	for enemy in game.enemies:
		enemy.controls_enabled = false
	game.active = true
	var first = game.players[0]
	var friend = game.players[1]
	first.position = Vector2(1780, 550)
	friend.position = Vector2(1860, 550)
	first.turret_angle = 0
	game.fire_shell(first)
	await frames(25)
	check(friend.armor == 2, "A real friendly shell must damage a teammate")
	friend.position = Vector2(1860, 620)
	first.cooldown = 0
	game.add_wall(Rect2(1920, 520, 12, 70))
	await frames(2)
	game.fire_shell(first)
	await frames(65)
	check(first.armor == 2, "A real ricochet must damage the tank that fired it")
	game.drop_mine(first)
	await frames(2)
	var mine = game.get_node("Mines").get_child(0)
	friend.position = first.position + Vector2(35, 0)
	first.hit_cooldown = 0
	friend.hit_cooldown = 0
	mine.detonate()
	await frames(2)
	check(first.armor == 1 and friend.armor == 1, "Friendly mine blasts must damage their owner and nearby crew")
	friend.invulnerable = false
	for i in range(3):
		friend.hit_cooldown = 0
		friend.take_hit()
	check(not friend.alive and friend.visible, "Zero armor must leave a visible, revivable downed tank")
	first.interact_held = true
	game.update_revives(2.1)
	check(friend.alive and friend.armor == 3, "A nearby teammate holding help must revive a downed tank")
	first.interact_held = false
	# AI must still fight when P1 is down, targeting another active player.
	first.invulnerable = false
	for i in range(3):
		first.hit_cooldown = 0
		first.take_hit()
	check(game.target_for_enemy(game.enemies[0]) != first, "AI must target live co-op players when the first player is down")
	var shell_count := game.get_node("Shells").get_child_count()
	friend.turret_angle = PI / 2
	game.fire_shell(friend)
	game.pause_story()
	check(game.paused and is_instance_valid(game.modal) and not friend.controls_enabled, "Pause must show controls and stop the crew")
	if game.get_node("Shells").get_child_count() > shell_count:
		var shell = game.get_node("Shells").get_child(shell_count)
		var at: Vector2 = shell.position
		await frames(5)
		check(shell.position == at, "Pause must freeze actual co-op projectiles")
	game.resume_game()
	# Every outdoor chapter has real editable geometry and routes from its spawns.
	for chapter in range(2, StorySession.SECTION_COUNT):
		game.load_chapter(chapter)
		game.set_activity(false)
		await frames(2)
		check(game.wall_rects.size() > 4, "Story chapters must load real obstacles")
		for crew in game.players:
			for rect in game.wall_rects:
				check(not rect.grow(18).has_point(crew.position), "Story crew spawns must be clear of walls")
		for enemy in game.enemies:
			for rect in game.wall_rects:
				check(not rect.grow(18).has_point(enemy.position), "Story enemy spawns must be clear of walls")
			if enemy.forward_speed > 0:
				check(not game.navigation_path(enemy, false).is_empty(), "Story AI must navigate through the designed world")
		if chapter == 2:
			check(game.enemies[0].damaged_model and game.enemies[0].forward_speed == 0, "Wasteland Brown tanks must have broken treads/engines and visible damage")
		if chapter == 8:
			var boss = game.enemies.back()
			var count: int = game.enemies.size()
			boss.armor = boss.max_armor / 2 + 1
			boss.take_hit()
			check(boss.phase_two and game.enemies.size() == count and boss.enemy_name == "Pink", "The slower Pink Gatekeeper must change phase without adding more reinforcements")
	for crew in game.players:
		crew.position = Vector2(10000 + crew.player_index * 60, 50)
	game.update_camera(1)
	for crew in game.players:
		var screen_point: Vector2 = (crew.position - game.get_node("Camera").position) * game.get_node("Camera").zoom + Vector2(640, 400)
		check(screen_point.y > 96 and screen_point.y < 741, "The shared camera must keep crew members visible near the top of the world")
	game.village_choice = ""
	game.load_chapter(12)
	game.supplies = 5
	game.show_village_choice()
	game.check_devices = true
	game.controller_changed(7, false)
	check(game.missing_device and game.paused, "A disconnected crew controller must safely pause the story")
	StorySession.devices = [-1]
	game.controller_changed(7, true)
	check(game.phase == "choice" and is_instance_valid(game.modal) and not game.active, "Reconnection must restore an interrupted village decision")
	StorySession.devices = [-1, 7, 9, 12]
	game.check_devices = false
	game.choose_village("spared")
	check(game.village_choice == "spared" and game.supplies == 8 and not game.region().get_node("Gate").visible, "Mercy must grant supplies, preserve repair access and open the story route")
	game.players[0].position = game.village_region().get_node("RepairStation").global_position
	game.players[0].armor = 1
	game.players[0].interact_held = true
	game.update_repairs()
	check(game.players[0].armor == 3 and game.supplies == 8, "Spared villagers must repair the crew without consuming field supplies")
	game.village_choice = ""
	game.load_chapter(12)
	game.supplies = 5
	game.choose_village("raided")
	game.players[0].position = game.village_region().get_node("RepairStation").global_position
	game.players[0].armor = 1
	game.players[0].interact_held = true
	game.repair_cooldown = 0
	game.update_repairs()
	check(game.supplies == 13 and game.players[0].armor == 1 and game.region().village_state == "raided", "Destruction must give the quick reward, destroy the village and remove free repairs")
	game.players[0].repair_held = true
	game.players[0].repair_progress = 2
	game.field_repair(game.players[0])
	game.players[0].repair_held = false
	game.players[0].cancel_repair()
	check(game.supplies == 11 and game.players[0].armor == 3, "Field repairs must spend the alternative reward")
	StorySession.save(14, 11, "raided")
	var saved := StorySession.checkpoint()
	check(saved.chapter == 14 and saved.supplies == 11 and saved.village == "raided", "Chapter checkpoints must persist the village decision and supplies")
	# A whole-party loss retries the chapter rather than silently replacing the crew.
	game.load_chapter(14)
	for crew in game.players:
		for i in range(3):
			crew.hit_cooldown = 0
			crew.take_hit()
	await frames(2)
	check(game.phase == "defeat" and is_instance_valid(game.modal), "Whole-party defeat must show a retry choice")
	game.retry_checkpoint()
	await frames(2)
	check(game.chapter == 14 and game.players.size() == 4 and game.players[0].alive, "Checkpoint retry must restore all co-op players")
	# Chapter exit requires all active players, then heals/returns downed members.
	game.load_chapter(1)
	for enemy in game.enemies:
		enemy.take_hit()
	await frames(2)
	check(not game.wave_cleared and game.region().get_node("Gate").visible, "Factory escape must keep its exit locked until the blast gate is destroyed")
	var blast_gate = game.region().get_node("SecurityGate")
	blast_gate.take_shell_hit(blast_gate.max_health)
	await frames(2)
	check(game.wave_cleared and not game.region().get_node("Gate").visible, "Destroying the blast gate must open the escape route")
	game.set_process(true)
	for crew in game.players:
		crew.position = Vector2(3100, 550 + crew.player_index * 45)
	await frames(70)
	game.set_process(false)
	check(game.chapter == 2 and game.players[0].armor == 3, "The whole crew reaching the exit must advance to the next story checkpoint")
	game.load_chapter(14)
	game.set_activity(false)
	game.active = true
	for crew in game.players:
		crew.position = game.region().get_node("AmbushTrigger").global_position + Vector2(0, crew.player_index * 35)
	game.update_ambush(0.1)
	game.set_activity(false)
	for enemy in game.enemies.duplicate():
		enemy.armor = 1
		enemy.phase_two = true
		enemy.take_hit()
	await frames(2)
	check(game.phase == "ending" and is_instance_valid(game.modal), "The capital boss and guards must lead to the story ending")
	for node in game.get_children():
		if node is AudioStreamPlayer:
			node.stop()
	game.queue_free()
	await frames(15)
	# Lobby join/leave and keyboard removal must support a controller-only crew.
	var lobby = load("res://scenes/story/Lobby.tscn").instantiate()
	root.add_child(lobby)
	lobby.toggle_keyboard()
	for device in [7, 9, 12, 15]:
		pad_button(device, JOY_BUTTON_A, true)
		await frames(1)
		pad_button(device, JOY_BUTTON_A, false)
	check(StorySession.devices.size() == 4 and not StorySession.devices.has(-1), "Lobby must admit four controllers without a keyboard")
	pad_button(9, JOY_BUTTON_B, true)
	await frames(1)
	pad_button(9, JOY_BUTTON_B, false)
	check(not StorySession.devices.has(9) and StorySession.devices.size() == 3, "A controller must be able to leave without removing another player's assignment")
	lobby.queue_free()
	await frames(3)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(StorySession.save_path))
	StorySession.save_path = "user://adventure.cfg"
	StorySession.devices = [-1]
	StorySession.resume_story = false
	print("STORY SMOKE: %s" % ("PASS" if failures == 0 else "%d FAILURE(S)" % failures))
	quit(0 if failures == 0 else 1)
