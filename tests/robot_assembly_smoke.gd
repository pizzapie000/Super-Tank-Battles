extends SceneTree

const Intro = preload("res://scripts/story/intro_sequence.gd")
const Assembly = preload("res://scripts/story/factory_assembly.gd")
var failures := 0

func _initialize() -> void:
	run.call_deferred()
	create_timer(60).timeout.connect(func():
		push_error("Robot assembly checks exceeded their time limit")
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
	# Parts must remain in the jaws throughout transport, then stay fitted while
	# the robot opens and retracts. Fixed link lengths catch unreachable poses.
	for job in Assembly.JOBS:
		for step in range(11):
			var time: float = lerpf(job.carry, job.release, step / 10.0)
			var pose := Assembly.handler_pose(job.arm, time)
			check(pose.holding == job.part and pose.opening == 0, "The %s must stay gripped during transport and seating" % job.part)
			check(pose.wrist.distance_to(Assembly.part_position(job, time) + job.grip) < 0.001, "The %s must not float away from its robot" % job.part)
		check(Assembly.part_position(job, job.seat + 0.1).is_equal_approx(job.target) and Assembly.part_position(job, 13).is_equal_approx(job.target), "The fitted %s must stay on the hull after release" % job.part)
		var released := Assembly.handler_pose(job.arm, job.release + 0.2)
		check(released.holding == "" and released.opening == 1, "The %s jaws must open before retracting" % job.part)
	for step in range(1601):
		var time := step * 0.01
		for arm in range(4):
			var wrist: Vector2
			if arm < 3:
				wrist = Assembly.handler_pose(arm, time).wrist
			else:
				var contact: Vector2 = Assembly.weld_pose(time).contact
				wrist = contact + (Assembly.BASES[3] - contact).normalized() * 9
			var first := 42.0 if arm == 3 else 36.0
			var second := 41.0 if arm == 3 else 34.0
			var base: Vector2 = Assembly.BASES[arm]
			var joint := Assembly.elbow(base, wrist, first, second, 1 if arm in [0, 2] else -1)
			if absf(joint.distance_to(base) - first) > 0.01 or absf(joint.distance_to(wrist) - second) > 0.01:
				check(false, "Robot %d must reach its tool without stretching at %.2f" % [arm, time])
				break
			if not Assembly.CELL_BOUNDS.grow(4).has_point(joint) or not Assembly.CELL_BOUNDS.grow(4).has_point(wrist):
				check(false, "Robot %d must remain inside its assembly bay at %.2f" % [arm, time])
				break
	for seam in Assembly.WELDS:
		var time: float = (seam.start + seam.end) * 0.5
		var pose := Assembly.weld_pose(time)
		check(pose.active and pose.contact.distance_to(seam.from.lerp(seam.to, 0.5)) < 0.001, "Welding must follow the fitted seam")
	check(not Assembly.weld_pose(11.5).active, "The arc must stop before the technician starts polishing")
	StorySession.save_path = "user://robot_assembly_smoke.cfg"
	StorySession.resume_story = false
	StorySession.skip_tutorial = false
	StorySession.debug_checkpoint = -1
	for count in range(1, 5):
		# A controller-only crew must have the same assembly coverage as a keyboard crew.
		StorySession.devices = [6]
		for i in range(1, count): StorySession.devices.append(6 + i)
		var game = load("res://scenes/story/Adventure.tscn").instantiate()
		# Audio cue timing is covered by intro_startup_smoke; this test seeks the movie.
		game.intro_music = null
		game.save_progress = false
		game.check_devices = false
		root.add_child(game)
		game.set_process(false)
		await frames(2)
		var stations: Array[Dictionary] = game.intro_stations()
		check(game.phase == "intro" and stations.size() == count, "Every joined tank needs its own visible assembly station")
		for i in range(count):
			check(stations[i].tint == game.players[i].tint and stations[i].marker == str(i + 1), "Movie tank colors and numbers must match the gameplay crew")
			var bounds := Rect2(stations[i].home + Assembly.CELL_BOUNDS.position * stations[i].scale, Assembly.CELL_BOUNDS.size * stations[i].scale)
			check(Rect2(0, 122, 1280, 618).encloses(bounds), "Assembly bay %d must fit between the title and captions" % i)
			for j in range(i):
				var other := Rect2(stations[j].home + Assembly.CELL_BOUNDS.position * stations[j].scale, Assembly.CELL_BOUNDS.size * stations[j].scale)
				check(not bounds.intersects(other), "Crew assembly bays must not overlap")
		game.players[0].tint = Color("ffcc22")
		check(game.intro_stations()[0].tint == game.players[0].tint, "The movie must use actual tank colors rather than a fixed blue tank")
		for sample in [2.2, 4.0, 6.2, 7.2, 8.4, 10.1, 13.2, 14.8]:
			game.intro_time = sample
			game.get_node("HUD/Overlay").queue_redraw()
			await frames(2)
		game.intro_time = 15.9
		game._process(0.2)
		check(game.phase == "tutorial" and game.players.size() == count and game.stage_ready_time == 0, "The assembled crew must enter safe training together without an arrival wait")
		for child in game.get_children():
			if child is AudioStreamPlayer: child.stop()
		game.queue_free()
		await frames(4)
	StorySession.save_path = "user://adventure.cfg"
	StorySession.devices = [-1]
	print("ROBOT ASSEMBLY SMOKE: %s" % ("PASS" if failures == 0 else "%d FAILURE(S)" % failures))
	quit(0 if failures == 0 else 1)
