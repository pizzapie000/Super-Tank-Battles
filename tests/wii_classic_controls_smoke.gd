extends SceneTree

const Controls = preload("res://scripts/input/controller_input.gd")
const Hints = preload("res://scripts/input/control_hints.gd")
const Drop = preload("res://scripts/story/powerup_drop.gd")
var wii: Node
var game: Node2D
var remotes: Array[Dictionary] = []
var sequence := 0
var failures := 0

func _initialize() -> void:
	run.call_deferred()
	create_timer(90).timeout.connect(func(): push_error("Classic Wii control checks timed out"); quit(1))

func check(value: bool, message: String) -> void:
	if value: return
	failures += 1
	push_error(message)

func frames(count: int = 2) -> void:
	for _frame in range(count):
		sequence += 1
		wii.accept_snapshot({"version": 1, "token": wii.token, "seq": sequence, "devices": remotes}, wii.seconds())
		await physics_frame
		await process_frame

func tap(bits: int, slot: int = 0) -> void:
	remotes[slot].buttons = bits
	await frames()
	remotes[slot].buttons = 0
	await frames()

func freeze_enemies(arena: Node2D) -> void:
	for enemy in arena.enemies:
		enemy.set_physics_process(false)
		enemy.controls_enabled = false
	for tank in arena.players if arena == game else [arena.player]:
		tank.collision_mask = 0
		tank.max_shells = 0

func run() -> void:
	wii = Controls.bridge()
	wii.set_process(false)
	wii.calibration.clear()
	PlayerSetup.loaded = true
	PlayerSetup.bindings = [{"kind": "wii", "id": "classic-wii-0"}, {"kind": "off"}, {"kind": "off"}, {"kind": "off"}]
	StorySession.devices = [1000, 1001]
	StorySession.debug_checkpoint = 3
	for slot in range(2):
		remotes.append({"slot": slot, "id": "classic-wii-%d" % slot, "connected": true, "nunchuk": slot == 1, "stick": [0, 0], "buttons": 0, "c": false, "z": false, "ir": [0.5, 0.4]})
	await frames()
	check(Controls.connected_devices().has(1000) and wii.pointer(1000) != null, "A remote without a Nunchuk must support setup and pointer aiming")
	check(Hints.for_device("move", 1000) == "D-PAD" and Hints.for_device("interact", 1000) == "1" and Hints.for_device("repair", 1000) == "MINUS", "Remote-only hints must omit unattached Nunchuk controls")
	check(Hints.for_device("mine", 1001) == "A" and Hints.for_device("interact", 1001) == "Z / 1", "Attached Nunchuks must retain separate mine and interaction prompts")
	game = load("res://scenes/story/Adventure.tscn").instantiate()
	game.save_progress = false
	game.check_devices = true
	root.add_child(game)
	game.set_process(false)
	freeze_enemies(game)
	for crew in game.players: crew.invulnerable = true
	var first = game.players[0]
	var second = game.players[1]
	first.position = game.region().global_position + Vector2(400, 400)
	second.position = first.position + Vector2(0, 180)
	var start: Vector2 = first.position
	remotes[0].buttons = 0x0200
	remotes[1].stick = [0, 1]
	await frames(30)
	check(first.position.x > start.x + 30 and second.velocity.y > 149, "The D-pad and another player's Nunchuk must drive independently in campaign")
	var aim = Controls.aim(1000, first)
	check(aim != null and first.firing_direction().dot((aim - first.global_position).normalized()) > 0.98, "D-pad driving must preserve independent pointer aiming")
	remotes[0].buttons = 0x0a00
	await frames(25)
	check(first.velocity.x > 90 and first.velocity.y < -90 and first.velocity.length() <= first.forward_speed + 0.01, "Diagonal D-pad movement must be normalized to ordinary tank speed")
	remotes[0].buttons = 0
	remotes[1].buttons = 0x0800
	remotes[1].stick = [1, 0]
	await frames(25)
	check(second.velocity.y < -149 and absf(second.velocity.x) < 0.1, "The D-pad must override a conflicting Nunchuk direction while held")
	remotes[1].buttons = 0
	remotes[1].nunchuk = false
	remotes[1].z = true
	remotes[1].c = true
	await frames(25)
	check(not game.paused and not game.missing_device and second.velocity.is_zero_approx() and not second.interact_held and not second.repair_held, "Unplugging a Nunchuk must release stale extension inputs and leave D-pad controls available")
	remotes[1].nunchuk = true
	remotes[1].z = false
	remotes[1].c = false
	remotes[1].stick = [0, 0]
	await frames()
	var drop := Drop.new()
	drop.position = first.position
	drop.part_type = "Loader"
	drop.age = 1
	game.get_node("Powerups").add_child(drop)
	game.update_powerup_drops(0)
	check(drop.prompt.contains("1 TO EQUIP"), "A remote-only tank's nearby powerup must prompt for 1")
	await tap(8)
	check(first.active_mines == 1 and first.equipped_part.is_empty() and game.get_node("Powerups").get_child_count() == 1, "A must deploy a real mine without collecting the upgrade underneath it")
	await tap(2)
	check(first.equipped_part == "Loader" and first.active_mines == 1, "1 must equip the upgrade without dropping another mine")
	drop = Drop.new()
	drop.position = second.position
	drop.part_type = "Engine"
	drop.age = 1
	game.get_node("Powerups").add_child(drop)
	remotes[1].z = true
	await frames()
	remotes[1].z = false
	await frames()
	check(second.equipped_part == "Engine" and second.active_mines == 0, "Nunchuk Z must equip its own nearby upgrade without placing a mine")
	for mine in game.get_node("Mines").get_children(): mine.queue_free()
	first.active_mines = 0
	await frames()
	first.max_shells = 5
	await tap(4)
	check(first.active_shells > 0, "The physical B trigger must still launch real campaign shells")
	for shell in game.get_node("Shells").get_children(): shell.retire()
	first.max_shells = 0
	first.mine_timer = 0
	await tap(0x1000)
	check(game.paused and not first.controls_enabled, "Plus must pause campaign play")
	remotes[0].ir = null
	var resume: Button
	for button in game.modal.find_children("*", "Button", true, false):
		if button.text == "RESUME": resume = button
	resume.grab_focus()
	await frames()
	var mine_count: int = game.get_node("Mines").get_child_count()
	await tap(8)
	check(not game.paused and game.get_node("Mines").get_child_count() == mine_count, "A used to resume from the pause menu must not also deploy a mine")
	game.queue_free()
	await frames(3)
	# Missions use the same physical controls, while still restricting play to P1.
	var mission = load("res://scenes/game/CampaignArena.tscn").instantiate()
	mission.save_progress = false
	root.add_child(mission)
	mission.set_process(false)
	mission.countdown = 0
	mission.active = true
	mission.set_controls(true)
	freeze_enemies(mission)
	mission.player.position = Vector2(500, 400)
	start = mission.player.position
	remotes[0].buttons = 0x0100
	await frames(25)
	check(mission.player.position.x < start.x - 20, "A remote without a Nunchuk must drive singleplayer missions using its D-pad")
	remotes[0].buttons = 0
	await frames()
	await tap(8)
	check(mission.player.active_mines == 1, "A must place a real singleplayer mission mine")
	for mine in mission.get_node("Mines").get_children(): mine.queue_free()
	mission.player.active_mines = 0
	await frames()
	mission.player.mine_timer = 0
	await tap(0x1000)
	check(mission.paused, "Plus must pause singleplayer missions")
	remotes[0].buttons = 8
	await frames()
	mission.set_mission_paused(false)
	await frames()
	check(mission.get_node("Mines").get_child_count() == 0, "A held when mission controls resume must require release before placing a mine")
	remotes[0].buttons = 0
	await frames()
	await tap(8)
	check(mission.player.active_mines == 1, "A fresh post-menu A press must still place a mine")
	mission.queue_free()
	await frames(3)
	wii.disconnect_all()
	print("Classic Wii control checks: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)
