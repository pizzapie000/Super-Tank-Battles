extends SceneTree

const Intro = preload("res://scripts/story/intro_sequence.gd")
const TitleCard = preload("res://scripts/story/area_title_card.gd")
var failures := 0
var game: Node2D

func _initialize() -> void:
	run.call_deferred()
	create_timer(90).timeout.connect(func():
		push_error("Intro startup checks exceeded their time limit")
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

func begin_intro(duration: float = 16) -> void:
	game.load_chapter(0)
	game.intro_duration = duration
	game.intro_time = 0
	game.phase = "intro"
	game.set_activity(false)

func key(code: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)

func run() -> void:
	StorySession.save_path = "user://intro_startup_smoke.cfg"
	StorySession.resume_story = false
	StorySession.debug_checkpoint = -1
	StorySession.skip_tutorial = false
	StorySession.devices = [-1, 7]
	game = load("res://scenes/story/Adventure.tscn").instantiate()
	game.save_progress = false
	game.check_devices = false
	root.add_child(game)
	game.set_process(false)
	await frames(2)
	check(game.phase == "intro" and not game.intro_engine_audio.playing, "The engine must remain silent through tank assembly")
	check(game.factory_title_active and game.intro_time == 0 and not game.music.playing, "A new adventure must begin with the factory title alone, before assembly or music")
	var crew_at: Vector2 = game.players[0].position
	game._process(TitleCard.DURATION * 0.7)
	check(game.factory_title_active and game.intro_time == 0 and not game.music.playing and not game.active, "The title's own clock must not consume any of the assembly or soundtrack")
	game.pause_story()
	var frozen_title: float = game.factory_title_time
	game._process(3)
	check(game.factory_title_time == frozen_title and game.intro_time == 0, "Pausing the opening title must freeze it before the building sequence starts")
	game.resume_game()
	game._process(TitleCard.DURATION * 0.3 + 0.1)
	check(not game.factory_title_active and game.intro_time == 0 and game.factory_title_time == TitleCard.DURATION, "The title must fade completely before the assembly starts, including on an overshooting frame")
	check(game.music.playing and game.players[0].position == crew_at and game.players.all(func(tank): return not tank.controls_enabled), "Assembly music must start after the card while the gameplay crew remains frozen")
	check(game.intro_engine_audio.stream.get_length() > 3 and game.intro_engine_audio.stream.loop_mode == AudioStreamWAV.LOOP_DISABLED, "Startup needs its own finite engine sound rather than the factory siren")
	game._process(Intro.ENGINE_START - 0.05)
	check(not game.intro_engine_started, "Cranking must wait until the technician is polishing")
	game._process(0.1)
	check(game.intro_engine_started and game.intro_engine_audio.playing, "The polishing scene must actually start the engine audio")
	await frames(4)
	var playback: float = game.intro_engine_audio.get_playback_position()
	game.update_intro_engine()
	check(game.intro_engine_audio.get_playback_position() >= playback, "Repeated drawing and processing must not restart the sound")
	game.pause_story()
	var frozen_time: float = game.intro_time
	game._process(2)
	check(game.intro_time == frozen_time and game.intro_engine_audio.stream_paused, "A paused intro must freeze the engine cue and animation together")
	game.resume_game()
	check(not game.intro_engine_audio.stream_paused and game.players.all(func(tank): return not tank.controls_enabled), "Resuming the movie must restore audio while keeping gameplay tanks inactive")
	game.finish_intro()
	check(not game.intro_engine_audio.playing and game.phase == "tutorial" and game.stage_ready_time == 0, "Skipping during ignition must stop the sound and enter safe training immediately")
	# If the movie was skipped early, the worker reacts to real player movement.
	var worker = game.region().get_node("Technician")
	var home: Vector2 = worker.position
	check(worker.visible and not worker.fleeing, "An early skip must leave the worker polishing until the tank moves")
	key(KEY_D, true)
	await frames(12)
	key(KEY_D, false)
	game._process(0.02)
	check(game.players[0].moved_distance > 8 and worker.fleeing, "Actual tutorial driving must frighten the polishing technician")
	game._process(0.25)
	check(worker.position.distance_to(home) > 20, "The frightened technician must visibly run away")
	game.pause_story()
	var stopped: Vector2 = worker.position
	game._process(3)
	check(worker.position == stopped, "Pause must freeze the fleeing worker")
	game.resume_game()
	game._process(2)
	check(worker.at_safety and not worker.visible, "The worker must reach safety instead of polishing forever")
	game.load_chapter(0)
	check(worker.visible and not worker.fleeing and worker.position == home, "Retrying the tutorial must reset the technician")
	# The new cues follow the configured music length, including slow and short intros.
	for duration in [8.0, 32.0]:
		begin_intro(duration)
		game._process((Intro.ENGINE_START - 0.05) * duration / Intro.LENGTH)
		check(not game.intro_engine_started, "Retimed assembly must keep the engine quiet until polishing")
		game._process(0.1 * duration / Intro.LENGTH)
		check(game.intro_engine_started and is_equal_approx(game.intro_engine_audio.pitch_scale, Intro.LENGTH / duration), "The engine cue must stay in sync with the configured intro duration")
		game.finish_intro()
	check(Intro.track_phase(13.9) == 0 and Intro.track_phase(14.8) > 0, "Tracks must stay still while assembling and polishing, then turn only while the tank rolls")
	check(Intro.tank_offset(13.9) == Vector2.ZERO and Intro.tank_offset(15.1).x > 60, "The completed tank must actually roll forward")
	check(Intro.worker_position(13.9) == Intro.WORKER_HOME and Intro.worker_position(15).distance_to(Intro.WORKER_HOME) > 200, "The cutscene worker must remain beside the tank until it moves, then sprint away")
	check(Intro.exhaust_puffs(12).is_empty() and not Intro.exhaust_puffs(13).is_empty() and Intro.exhaust_puffs(16).is_empty(), "A short exhaust puff must appear during ignition and dissipate")
	begin_intro()
	game._process(13)
	game._process(3.1)
	check(game.phase == "tutorial" and not game.intro_engine_audio.playing and worker.at_safety and not worker.visible, "Completing the full movie must preserve the worker's escape into the tutorial")
	StorySession.skip_tutorial = true
	begin_intro()
	game._process(12.5)
	game.finish_intro()
	check(game.chapter == 1 and game.stage_ready_time == 0 and not game.intro_engine_audio.playing and game.alarm_audio.playing, "Skipping training after the new movie must start the factory escape immediately")
	for child in game.get_children():
		if child is AudioStreamPlayer:
			child.stop()
	game.queue_free()
	await frames(8)
	StorySession.debug_checkpoint = 0
	game = load("res://scenes/story/Adventure.tscn").instantiate()
	game.check_devices = false
	root.add_child(game)
	game.set_process(false)
	game.update_intro_engine()
	check(game.debug_mode and game.phase == "tutorial" and not game.factory_title_active and not game.intro_engine_audio.playing, "Checkpoint debugging must still bypass both the title and the movie")
	game.queue_free()
	await frames(4)
	StorySession.save_path = "user://adventure.cfg"
	StorySession.debug_checkpoint = -1
	StorySession.skip_tutorial = false
	StorySession.devices = [-1]
	print("INTRO STARTUP SMOKE: %s" % ("PASS" if failures == 0 else "%d FAILURE(S)" % failures))
	quit(0 if failures == 0 else 1)
