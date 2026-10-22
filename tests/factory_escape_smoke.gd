extends SceneTree

var failures := 0
var game: Node2D

func _initialize() -> void:
	run.call_deferred()
	create_timer(90).timeout.connect(func():
		push_error("Factory escape checks exceeded their time limit")
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

func key(code: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)

func freeze_actors() -> void:
	game.set_activity(false)
	game.active = true
	for enemy in game.enemies:
		enemy.max_shells = 0
		enemy.max_mines = 0
	for crew in game.players:
		crew.invulnerable = true

func run() -> void:
	StorySession.save_path = "user://factory_escape_smoke.cfg"
	StorySession.devices = [-1, 7]
	StorySession.resume_story = false
	game = load("res://scenes/story/Adventure.tscn").instantiate()
	game.save_progress = false
	game.check_devices = false
	root.add_child(game)
	game.set_process(false)
	await frames(2)
	check(not game.alarm_audio.playing and game.factory_alarm_flash() == 0, "The opening cutscene and safe tutorial must not trigger the factory alarm")
	game.load_chapter(1)
	freeze_actors()
	var gate = game.region().get_node("SecurityGate")
	check(game.factory_alarm_active() and game.alarm_audio.playing, "Starting or skipping directly to the escape must start the persistent alarm")
	check(game.alarm_audio.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD and game.alarm_audio.stream.loop_end > 0, "The factory siren must loop continuously rather than play a single sound effect")
	check(game.ALARM.loop_mode == AudioStreamWAV.LOOP_DISABLED, "Looping the factory siren must not change other uses of the alarm sound")
	check(not gate.broken and gate.health == 6 and gate.collision_layer == 1 and not game.wave_cleared, "The escape must begin with a solid six-hit blast gate")
	check(game.stage_ready_time == 0, "The escape must start without an arrival countdown")
	game.scene_time = 0
	var red: float = game.factory_alarm_flash()
	game.scene_time = 0.25
	check(game.factory_alarm_flash() > red and red > 0, "The red warning must visibly pulse throughout the escape")
	game.pause_story()
	check(game.alarm_audio.stream_paused, "Pausing must pause the continuous siren")
	game.show_field_guide()
	var clock: float = game.scene_time
	game._process(3)
	check(game.scene_time == clock and game.alarm_audio.stream_paused and game.stage_ready_time == 0, "Reading the field guide must freeze the red pulse and siren without adding an arrival countdown")
	game.close_field_guide()
	game.resume_game()
	check(not game.alarm_audio.stream_paused and game.alarm_audio.playing, "Resuming must continue the same alarm")
	freeze_actors()
	var start: Vector2 = game.region().get_node("Start").global_position
	var exit_at: Vector2 = game.region().get_node("Exit").global_position
	check(game.navigation.path(start, exit_at).is_empty(), "The intact gate and its side walls must prevent routes around the exit barrier")
	for crew in game.players:
		crew.position = exit_at + Vector2(0, crew.player_index * 45)
	game._process(0.1)
	check(not game.transitioning and game.chapter == 1, "The crew must not be able to advance before breaching the gate, even at the exit marker")
	# Move escorts out of this controlled firing lane: shells must still hit tanks first.
	for enemy in game.enemies:
		enemy.position = game.region().global_position + Vector2(700, 150 + enemy.tactical_slot * 70)
	var first = game.players[0]
	first.position = gate.global_position - Vector2(140, 0)
	game.players[1].position = first.position + Vector2(-40, 120)
	first.controls_enabled = true
	first.set_physics_process(true)
	key(KEY_D, true)
	await frames(80)
	key(KEY_D, false)
	await frames(2)
	check(first.position.x > gate.global_position.x - 60 and first.position.x <= gate.wall_rect().position.x - 17.8 and gate.health == 6, "The real gate collider must stop a driven tank without being damaged by ramming")
	freeze_actors()
	first.turret_angle = 0
	first.cooldown = 0
	game.fire_shell(first)
	await frames(5)
	check(gate.health == 5, "A tank pressed against the gate must still be able to shoot its near face")
	first.position = gate.wall_rect().position - Vector2(140, -gate.size.y / 2)
	first.turret_angle = 0
	# Each real shell must hit the gate itself, rather than an invisible wall copy.
	for hit in range(5):
		first.cooldown = 0
		game.fire_shell(first)
		await frames(32)
		check(gate.health == maxi(0, 4 - hit), "Actual shells must damage the blast gate once per hit")
	check(gate.broken and not gate.visible and gate.collision_layer == 0, "The sixth hit must remove the gate's visible barrier and collider")
	check(game.wave_cleared and not game.region().get_node("Gate").visible and game.remaining_enemies() > 0, "A breached gate must unlock escape without requiring all pursuers to die")
	check(not game.navigation.path(first.position, exit_at).is_empty(), "Breaching must rebuild navigation with a usable route through the gate")
	check(game.alarm_audio.playing and game.factory_alarm_active(), "Breaking the gate must not silence the alarm before the crew escapes")
	# Retry restores the gate; crossing into the wasteland ends the alarm and flash.
	game.retry_checkpoint()
	gate = game.region().get_node("SecurityGate")
	check(gate.health == 6 and not gate.broken and gate.collision_layer == 1 and not game.wave_cleared, "Retrying the escape must restore the blast gate and lock progression again")
	freeze_actors()
	gate.take_shell_hit(6)
	await frames(2)
	game.players[0].position = exit_at
	game._process(0.1)
	check(not game.transitioning, "One tank must still wait for the rest of the crew after the gate is breached")
	for crew in game.players:
		crew.position = exit_at + Vector2(0, crew.player_index * 45)
	game._process(0.1)
	await frames(70)
	check(game.chapter == 2 and game.alarm_audio.playing and game.factory_alarm_flash() > 0, "The factory alarm must continue through its new freight yard")
	check(gate.broken and gate.collision_layer == 0, "A completed factory must not put its barrier back across the crew's route")
	game.advance_chapter()
	await frames(220)
	check(game.chapter == 3 and not game.alarm_audio.playing and game.factory_alarm_flash() == 0, "Leaving the freight yard for the wasteland must end the factory alarm")
	# The original tutorial alarm continues across its transition into the escape.
	game.load_chapter(0)
	game.stage_ready_time = 0
	freeze_actors()
	game.begin_alarm()
	var loop_id: int = game.alarm_audio.stream.get_instance_id()
	check(game.alarm_audio.playing and game.factory_alarm_flash() > 0, "Completing the tutorial must begin the persistent alarm and warning pulse")
	game.load_chapter(1)
	check(game.alarm_audio.playing and game.alarm_audio.stream.get_instance_id() == loop_id, "Moving from the tutorial into the escape must preserve a single continuous siren")
	for child in game.get_children():
		if child is AudioStreamPlayer:
			child.stop()
	game.queue_free()
	await frames(8)
	StorySession.save_path = "user://adventure.cfg"
	StorySession.devices = [-1]
	print("FACTORY ESCAPE SMOKE: %s" % ("PASS" if failures == 0 else "%d FAILURE(S)" % failures))
	quit(0 if failures == 0 else 1)
