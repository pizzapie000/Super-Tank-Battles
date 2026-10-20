extends SceneTree

const Heart = preload("res://scripts/kiss_heart.gd")
const KISS = preload("res://assets/audio/kiss.wav")
var failures := 0
var hearts: Array[Node2D] = []
var sounds := 0

func _initialize() -> void:
	run.call_deferred()
	create_timer(45).timeout.connect(func():
		push_error("Tank contact checks exceeded their time limit")
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

func watch(game: Node2D) -> void:
	hearts.clear()
	sounds = 0
	if game.has_meta("kiss_observer"):
		return
	game.set_meta("kiss_observer", true)
	game.get_node("Effects").child_entered_tree.connect(func(effect: Node):
		if effect.get_script() == Heart:
			hearts.append(effect)
	)
	game.child_entered_tree.connect(func(child: Node):
		if child is AudioStreamPlayer and child.stream == KISS:
			sounds += 1
	)

func prepare(game: Node2D) -> void:
	game.set_process(false)
	game.countdown = 0
	game.active = true
	for tank in game.tanks:
		tank.controls_enabled = false
		tank.set_physics_process(false)
	for body in game.get_node("Walls").get_children():
		game.get_node("Walls").remove_child(body)
		body.queue_free()
	game.wall_rects.clear()
	watch(game)

func run() -> void:
	var game = load("res://scenes/game/DuelArena.tscn").instantiate()
	root.add_child(game)
	prepare(game)
	game.position = Vector2(40, 20)
	var first: DuelTank = game.tanks[0]
	var second: DuelTank = game.tanks[1]
	first.position = Vector2(300, 300)
	second.position = Vector2(380, 300)
	first.rotation = 0
	first.controls_enabled = true
	first.set_physics_process(true)
	Input.action_press("p1_forward")
	await frames(70)
	Input.action_release("p1_forward")
	first.controls_enabled = false
	check(first.get_slide_collision_count() > 0 and first.position.distance_to(second.position) >= 36, "The test must reach a real tank-body collision")
	check(hearts.size() == 1 and sounds == 1, "A physical tank bump must create exactly one heart and kiss")
	if hearts.size() == 1 and is_instance_valid(hearts[0]):
		var heart := hearts[0]
		check(heart.global_position.distance_to((first.global_position + second.global_position) * 0.5) < 1, "The heart must spawn at the world-space contact midpoint, even in a translated arena")
		game.paused = true
		var frozen_age: float = heart.age
		await frames(12)
		check(heart.age == frozen_age, "Floating hearts must freeze while paused")
		game.paused = false
	else:
		check(false, "A fresh contact heart must remain visible long enough to float")
	first.position = second.position - Vector2(60, 0)
	await frames(2)
	first.position = second.position - Vector2(36.1, 0)
	await frames(2)
	check(hearts.size() == 1, "Quickly bumping again must respect the pair's cooldown")
	await frames(200)
	check(hearts.size() == 1 and sounds == 1, "Resting or rubbing together must not repeat after the cooldown")
	check(game.get_node("Effects").get_child_count() == 0, "Hearts must disappear after floating away")
	first.position = second.position - Vector2(60, 0)
	await frames(2)
	first.position = second.position - Vector2(36.1, 0)
	await frames(2)
	check(hearts.size() == 2 and sounds == 2, "Separating and returning after the cooldown must create another kiss")
	second.alive = false
	first.position = second.position - Vector2(60, 0)
	await frames(2)
	first.position = second.position - Vector2(36.1, 0)
	await frames(2)
	check(hearts.size() == 2, "Destroyed or downed tanks must not trigger kisses")
	# Resetting a round replaces tanks and clears old effects and contact history.
	game.start_round()
	prepare(game)
	first = game.tanks[0]
	second = game.tanks[1]
	first.position = Vector2(300, 300)
	second.position = Vector2(336.1, 300)
	await frames(2)
	check(hearts.size() == 1 and game.get_node("Effects").get_child_count() == 1 and game.tank_contacts.pairs.size() == 1, "A new round must trigger normally and discard old tank IDs")
	game.queue_free()
	await frames(3)
	# The shared hook must also apply to enemies, without team or AI restrictions.
	game = load("res://scenes/game/CampaignArena.tscn").instantiate()
	game.mission_override = 15
	game.save_progress = false
	root.add_child(game)
	prepare(game)
	for i in range(game.tanks.size()):
		game.tanks[i].position = Vector2(800 + i * 80, 550)
	game.player.position = Vector2(300, 300)
	game.enemies[0].position = Vector2(336.1, 300)
	await frames(2)
	check(hearts.size() == 1 and sounds == 1, "Players and enemy tanks must be able to kiss in classic missions")
	game.enemies[1].position = Vector2(500, 300)
	game.enemies[2].position = Vector2(536.1, 300)
	await frames(2)
	check(hearts.size() == 2, "Enemy tanks bumping each other must also get a heart")
	game.queue_free()
	await frames(3)
	var saved_devices := StorySession.devices.duplicate()
	var saved_debug := StorySession.debug_checkpoint
	StorySession.devices = [-1, 7, 9, 12]
	StorySession.debug_checkpoint = 2
	game = load("res://scenes/story/Adventure.tscn").instantiate()
	game.save_progress = false
	game.check_devices = false
	root.add_child(game)
	game.set_activity(false)
	prepare(game)
	for i in range(game.tanks.size()):
		game.tanks[i].position = Vector2(1600 + i * 80, 900)
	for i in range(4):
		game.players[i].position = Vector2(300 + (i / 2) * 200 + (i % 2) * 36.1, 300)
	var supplies: int = game.supplies
	var armor: int = game.players[0].armor
	await frames(2)
	check(hearts.size() == 2 and sounds == 1, "Simultaneous co-op contacts must each get a heart without stacking kiss sounds")
	check(game.supplies == supplies and game.players[0].armor == armor, "The easter egg must not change resources or combat health")
	game.paused = true
	game.set_activity(true)
	var age: float = hearts[0].age if not hearts.is_empty() else -1
	await frames(10)
	check(not hearts.is_empty() and hearts[0].age == age, "Story pause must also freeze hearts")
	game.queue_free()
	await frames(3)
	StorySession.devices.assign(saved_devices)
	StorySession.debug_checkpoint = saved_debug
	print("Tank contact checks: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)
