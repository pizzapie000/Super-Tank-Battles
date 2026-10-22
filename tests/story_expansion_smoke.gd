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

func freeze_chapter(index: int) -> void:
	game.load_chapter(index)
	game.set_activity(false)
	game.active = true
	game.get_node("Camera").position = game.region().get_node("Start").global_position
	game.update_camera(1)

func run() -> void:
	StorySession.save_path = "user://story_expansion_smoke.cfg"
	StorySession.devices = [-1, 7, 9, 12]
	StorySession.resume_story = false
	game = load("res://scenes/story/Adventure.tscn").instantiate()
	game.save_progress = false
	game.stage_ready_duration = 0
	game.check_devices = false
	root.add_child(game)
	game.set_process(false)
	await frames(2)
	check(game.get_node("World").get_child_count() == 20 and game.world_bounds().size.x == 32000, "The campaign must have twenty checkpoints, including the new factory, forest, fortress and capital stages")
	# Every extended encounter needs connected crew and enemy routes, including exits.
	for section in [3, 4, 5, 6, 7, 8, 10, 11, 12, 16, 19]:
		freeze_chapter(section)
		await frames(2)
		var exit_at: Vector2 = game.region().get_node("Exit").global_position
		check(not game.navigation.path(game.players[0].position, exit_at).is_empty(), "New cover must leave an actual crew route to the exit in section %d" % section)
		for enemy in game.enemies:
			check(game.navigation.point_clear(enemy.position), "An extended encounter must not spawn tanks in its scenery")
			if enemy.forward_speed > 0:
				check(not game.navigation_path(enemy, false).is_empty(), "Extended patrols must reach the crew around rubble and trees")
	# The factory uses a timed chase and a blast gate, without requiring a full clear.
	freeze_chapter(1)
	await frames(2)
	var initial: int = game.enemies.size()
	game.update_reinforcements(4.99)
	check(game.enemies.size() == initial, "Security must wait five seconds between waves")
	game.update_reinforcements(0.02)
	check(game.enemies.size() == initial + 2, "Four-player factory waves must gently scale to two pursuing tanks")
	var screen_left: float = game.get_node("Camera").position.x - 640 / game.get_node("Camera").zoom.x
	var pursuer = game.enemies.back()
	for enemy in game.enemies.slice(initial):
		check(enemy.position.x + 40 < screen_left, "Reinforcements must enter beyond the left edge of the shared camera")
		check(not game.navigation_path(enemy, false).is_empty(), "Offscreen security needs a real route through the factory entrance")
		check(enemy.pursuer and enemy.forward_speed > 0, "Security must chase the crew instead of defending its spawn")
	check(not game.wave_cleared and game.region().get_node("Gate").visible and game.remaining_enemies() > 0, "The blast gate must stay locked while security pursues the crew")
	var at: Vector2 = pursuer.position
	for crew in game.players:
		crew.invulnerable = true
	for enemy in game.enemies:
		enemy.shot_cooldown = 999
	await frames(60)
	check(pursuer.position.distance_to(at) > 25, "A spawned pursuer must actually drive toward the crew")
	game.set_activity(false)
	game.active = true
	initial = game.enemies.size()
	game.paused = true
	game.update_reinforcements(20)
	check(game.enemies.size() == initial, "Pause must freeze the reinforcement clock")
	game.paused = false
	game.update_reinforcements(5)
	check(game.enemies.size() > initial, "Reinforcements must keep arriving on subsequent five-second intervals")
	for i in range(30):
		game.update_reinforcements(5)
	check(game.remaining_enemies() <= 22, "Long factory escapes must keep live enemy counts bounded")
	game.players[0].position = game.region().get_node("Exit").global_position
	game._process(0.1)
	check(not game.transitioning, "One player reaching the factory exit must wait for the rest of the crew")
	var blast_gate = game.region().get_node("SecurityGate")
	blast_gate.take_shell_hit(blast_gate.max_health)
	await frames(2)
	check(game.wave_cleared and game.remaining_enemies() > 0, "Breaching the gate must allow an escape while pursuers are still alive")
	for crew in game.players:
		crew.position = game.region().get_node("Exit").global_position + Vector2(0, crew.player_index * 35)
	game._process(0.1)
	await frames(70)
	check(game.chapter == 2, "The full crew must escape to the freight yard while pursuing enemies remain alive")
	StorySession.devices = [-1]
	freeze_chapter(1)
	initial = game.enemies.size()
	game.update_reinforcements(5)
	check(game.enemies.size() == initial + 1, "Solo factory escape must use one pursuer per wave")
	StorySession.devices = [-1, 7, 9, 12]
	# Road signs and fleeing villagers happen before the chief's gate decision.
	game.village_choice = ""
	freeze_chapter(14)
	await frames(2)
	check(game.region().get_node("Signs").get_child_count() == 3 and game.remaining_enemies() == 0, "The village approach must have peace signs and no combat patrol")
	var villager = game.region().get_node("Villagers").get_child(0)
	at = villager.position
	game.players[0].position = villager.global_position - Vector2(80, 0)
	game._process(0.5)
	check(villager.fleeing and villager.position.distance_to(at) > 30 and game.phase != "choice", "Approaching tanks must make villagers run away along the road without triggering the gate choice early")
	game.pause_story()
	at = villager.position
	game._process(1)
	check(villager.position == at, "Paused play must freeze fleeing villagers")
	game.close_modal()
	game.paused = false
	freeze_chapter(15)
	await frames(2)
	check(game.region().get_node("EntryBarrier").visible and game.phase == "village", "The chief's gate must be closed on first arrival")
	var fence_right: float = game.region().get_node("EntryBarrier").wall_rect().end.x
	check(game.region().village_houses().size() == 4, "The village must retain all four editable houses")
	for house in game.region().village_houses():
		check(game.region().global_position.x + house.position.x - 12 >= fence_right + 48, "House walls and overhanging roofs must sit fully inside the village with a tank-width gap from the fence")
	for resident in game.region().get_node("Villagers").get_children():
		check(game.navigation.point_clear(resident.global_position), "Village buildings must leave the chief and residents in open space")
		if not resident.chief:
			check(game.navigation.point_clear(game.region().global_position + resident.safe_position), "Fleeing residents must have a safe destination outside the moved houses")
	game._process(0.1)
	check(game.phase == "village", "The decision must wait until the crew reaches the gate")
	game.players[0].position = game.region().get_node("ChoiceTrigger").global_position
	game._process(0.1)
	check(game.phase == "choice" and is_instance_valid(game.modal) and not game.active, "Reaching the gate must pause play for the chief's plea and shared choice")
	check(game.region().get_node("Villagers/Chief").chief, "A visible village chief must wait beside the gate")
	game.choose_village("spared")
	check(not game.region().get_node("EntryBarrier").visible and not game.region().get_node("Gate").visible, "Mercy must open both the village entrance and the onward route")
	check(not game.navigation.path(game.players[0].position, game.region().get_node("Exit").global_position).is_empty(), "Opening the village must rebuild a usable route through its gate")
	game.village_choice = ""
	freeze_chapter(15)
	game.show_village_choice()
	game.choose_village("raided")
	freeze_chapter(16)
	check(not game.village_region().get_node("Villagers/Chief").visible, "A destroyed village must stay deserted after moving to the capital")
	freeze_chapter(15)
	check(not game.region().get_node("Villagers/Chief").visible and not game.region().get_node("EntryBarrier").visible, "Returning to a destroyed village must preserve its opened gate and absent inhabitants")
	check(game.phase == "village_decided" and game.wave_cleared, "Retrying or continuing a saved village decision must allow onward progress without asking again")
	for crew in game.players:
		crew.position = game.region().get_node("Exit").global_position + Vector2(0, crew.player_index * 35)
	game._process(0.1)
	await frames(70)
	check(game.chapter == 16, "A crew with a persisted village choice must be able to continue to the capital")
	# Old saves retain their supplies and decision while moving to matching areas.
	for old_section in range(7):
		var old := ConfigFile.new()
		old.set_value("story", "chapter", old_section)
		old.set_value("story", "supplies", 13)
		old.set_value("story", "village", "spared")
		old.save(StorySession.save_path)
		var saved := StorySession.checkpoint()
		check(saved.chapter == [0, 1, 3, 6, 10, 15, 16][old_section] and saved.supplies == 13 and saved.village == "spared", "Earlier campaign checkpoints must migrate to the matching area")
	StorySession.save(19, 9, "raided")
	check(StorySession.checkpoint().chapter == 19, "New checkpoints must preserve the final extended section")
	for node in game.get_children():
		if node is AudioStreamPlayer:
			node.stop()
	game.queue_free()
	await frames(15)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(StorySession.save_path))
	StorySession.save_path = "user://adventure.cfg"
	StorySession.devices = [-1]
	StorySession.resume_story = false
	print("STORY EXPANSION SMOKE: %s" % ("PASS" if failures == 0 else "%d FAILURE(S)" % failures))
	quit(0 if failures == 0 else 1)
