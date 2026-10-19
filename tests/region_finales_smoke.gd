extends SceneTree

var failures := 0
var game: Node2D

func _initialize() -> void:
	run.call_deferred()
	create_timer(120).timeout.connect(func():
		push_error("Regional finale checks exceeded their time limit")
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

func run() -> void:
	StorySession.save_path = "user://region_finales_smoke.cfg"
	StorySession.devices = [-1, 7, 9, 12]
	StorySession.resume_story = false
	game = load("res://scenes/story/Adventure.tscn").instantiate()
	game.save_progress = false
	game.check_devices = false
	root.add_child(game)
	game.set_process(false)
	await frames(2)
	# Enter and leave every added stage through actual clears and exit transitions.
	for section in [4, 7, 10]:
		game.stage_ready_duration = 0
		game.load_chapter(section - 1)
		game.set_activity(false)
		game.active = true
		await clear_encounter()
		game.stage_ready_duration = 5
		await leave_stage()
		check(game.chapter == section and game.stage_ready_time == 5, "The preceding encounter must lead to a protected new stage")
		check(game.players.size() == 4 and game.players.all(func(crew): return crew.alive and crew.invulnerable), "All crew members must arrive safely at each new checkpoint")
		game.persist_story()
		check(StorySession.checkpoint().chapter == section, "Each new stage must be a resumable checkpoint")
		var crate = game.region().get_node("Parts/BankShot")
		game.players[0].position = crate.global_position + Vector2(25, 0)
		game.players[0].interact_held = true
		game._process(0.5)
		game.players[0].interact_held = false
		check(crate.claimed and game.players[0].equipped_part == "Bank Shot", "New stages must allow fitting a powerup during arrival")
		game.fire_shell(game.players[0])
		game.drop_mine(game.players[0])
		check(game.get_node("Shells").get_child_count() == 0 and game.get_node("Mines").get_child_count() == 0, "Arrival must prevent combat in every added stage")
		game._process(4.4)
		check(game.stage_ready_time > 0 and game.enemies.all(func(enemy): return not enemy.controls_enabled), "New enemies must wait the full arrival countdown")
		game._process(0.2)
		game.set_activity(false)
		game.active = true
		if section == 7:
			var origin: Vector2 = game.region().global_position
			for bridge_y in [350, 800]:
				check(game.navigation.segment_clear(origin + Vector2(660, bridge_y), origin + Vector2(900, bridge_y)), "Both forest bridges must be wide enough for tanks to cross")
			check(not game.navigation.segment_clear(origin + Vector2(660, 550), origin + Vector2(900, 550)), "The solid middle riverbank must separate the two crossing routes")
		await clear_encounter()
		await leave_stage()
		check(game.chapter == section + 1 and game.stage_ready_time == 5, "Clearing a new stage must reach the next area with arrival protection")
	# Older soundtracks must keep the same areas after stage insertion.
	var former_track := [0, 1, 2, 3, 3, 4, 5, 5, 6, 7, 7, 8, 9, 10, 11]
	for track_count in [12, 13, 15]:
		var tracks: Array[AudioStream] = []
		for i in range(track_count):
			tracks.append(AudioStreamWAV.new())
		game.chapter_music = tracks
		for section in range(15):
			game.chapter = section
			game.play_chapter_music()
			var expected: int = section if track_count == 15 else former_track[section]
			if track_count == 13 and expected >= 8:
				expected += 1
			check(game.music.stream == tracks[expected], "Existing and new soundtracks must stay aligned to their intended area")
	game.chapter_music.clear()
	for child in game.get_children():
		if child is AudioStreamPlayer:
			child.stop()
	game.queue_free()
	await frames(10)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(StorySession.save_path))
	StorySession.save_path = "user://adventure.cfg"
	StorySession.devices = [-1]
	print("REGION FINALES SMOKE: %s" % ("PASS" if failures == 0 else "%d FAILURE(S)" % failures))
	quit(0 if failures == 0 else 1)

func clear_encounter() -> void:
	for crew in game.players:
		crew.position = game.region().get_node("AmbushTrigger").global_position + Vector2(0, crew.player_index * 40)
	game.update_ambush(0.1)
	game.set_activity(false)
	game.active = true
	check(game.pending_attackers.is_empty(), "The whole co-op ambush must be reachable before clearing a new stage")
	for enemy in game.enemies.duplicate():
		enemy.armor = 1
		enemy.phase_two = true
		enemy.take_hit()
	await frames(2)
	check(game.wave_cleared and not game.region().get_node("Gate").visible, "Destroying the patrol and its ambush must open the exit")

func leave_stage() -> void:
	for crew in game.players:
		crew.position = game.region().get_node("Exit").global_position + Vector2(0, crew.player_index * 40)
	game._process(0.01)
	await frames(70)
	game.set_activity(false)
	game.active = true
