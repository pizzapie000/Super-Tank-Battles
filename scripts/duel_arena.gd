extends Node2D

const TankScene = preload("res://scenes/tanks/Tank.tscn")
const ShellScene = preload("res://scenes/projectiles/Shell.tscn")
const BurstScript = preload("res://scripts/burst.gd")
const FLOOR = preload("res://assets/Floor Tiles/Clay brick floor tile.jpg")
const SHOOT = preload("res://assets/audio/shoot.wav")
const BOUNCE = preload("res://assets/audio/bounce.wav")
const EXPLOSION = preload("res://assets/audio/explosion.wav")
const COLORS: Array[Color] = [Color("52d8ed"), Color("ffae67")]
const BOARD := Rect2(64, 152, 1152, 512)
const COLS: int = 9
const ROWS: int = 4
const CELL: int = 128
const WALL: float = 14.0
const TARGET_SCORE: int = 7
const DIRECTIONS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]

var tanks: Array[DuelTank] = []
var wall_rects: Array[Rect2] = []
var passages: Dictionary = {}
var scores: Array[int] = [0, 0]
var round_number: int = 0
var active: bool = false
var resolution_pending: bool = false
var round_timer: float = 0.0
var countdown: float = 0.0
var match_finished: bool = false
var paused: bool = false
var banner: String = ""
var banner_color: Color = Color.WHITE
var elapsed: float = 0.0
var bounce_time: int = 0
var font: Font
var maze_loops: float = 0.24
var maze_seed: int = 0
var mine_collisions: bool = false

func _ready() -> void:
	font = ThemeDB.fallback_font
	$Overlay.draw.connect(draw_overlay)
	start_round()

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("return_menu"):
		get_tree().change_scene_to_file("res://scenes/game/MainMenu.tscn")
		return
	if Input.is_action_just_pressed("pause_game") and not match_finished:
		paused = not paused
		set_controls(active and not paused)
		for shell in $Shells.get_children():
			shell.flight_enabled = not paused and active
	if Input.is_action_just_pressed("restart_round"):
		start_round()
	if match_finished and Input.is_action_just_pressed("rematch"):
		scores = [0, 0]
		round_number = 0
		start_round()
	if not paused:
		elapsed += delta
		if countdown > 0:
			countdown = maxf(0.0, countdown - delta)
			if countdown <= 0:
				active = true
				set_controls(true)
		if round_timer > 0:
			round_timer -= delta
			if round_timer <= 0 and not match_finished:
				start_round()
	queue_redraw()
	$Overlay.queue_redraw()

func set_controls(enabled: bool) -> void:
	for tank in tanks:
		tank.controls_enabled = enabled

func start_round() -> void:
	# Remove physics bodies immediately; otherwise old walls remain for one frame.
	for container in [$Walls, $Tanks, $Shells, $Effects]:
		for child in container.get_children():
			container.remove_child(child)
			child.queue_free()
	tanks.clear()
	wall_rects.clear()
	round_number += 1
	active = false
	paused = false
	match_finished = false
	resolution_pending = false
	round_timer = 0
	countdown = 1.4
	banner = ""
	generate_maze()
	for index in range(2):
		var tank: DuelTank = TankScene.instantiate()
		tank.player_index = index
		tank.tint = COLORS[index]
		var cell := Vector2i(0, 0) if index == 0 else Vector2i(COLS - 1, ROWS - 1)
		tank.position = BOARD.position + Vector2(cell) * CELL + Vector2.ONE * CELL * 0.5
		for direction in DIRECTIONS:
			if passages.has(edge_key(cell, cell + direction)):
				tank.rotation = Vector2(direction).angle()
				break
		tank.shot_requested.connect(fire_shell)
		tank.destroyed.connect(tank_destroyed)
		$Tanks.add_child(tank)
		tanks.append(tank)

func edge_key(a: Vector2i, b: Vector2i) -> String:
	var first := a.y * COLS + a.x
	var second := b.y * COLS + b.x
	return "%d:%d" % [mini(first, second), maxi(first, second)]

func valid_cell(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < COLS and cell.y < ROWS

func generate_maze() -> void:
	# Depth-first carving guarantees every cell is reachable. Extra openings create loops.
	var rng := RandomNumberGenerator.new()
	if maze_seed == 0:
		rng.randomize()
	else:
		rng.seed = maze_seed
	passages.clear()
	var visited: Dictionary = {Vector2i.ZERO: true}
	var stack: Array[Vector2i] = [Vector2i.ZERO]
	while not stack.is_empty():
		var cell: Vector2i = stack.back()
		var choices: Array[Vector2i] = []
		for direction in DIRECTIONS:
			var next := cell + direction
			if valid_cell(next) and not visited.has(next):
				choices.append(next)
		if choices.is_empty():
			stack.pop_back()
		else:
			var next: Vector2i = choices[rng.randi_range(0, choices.size() - 1)]
			passages[edge_key(cell, next)] = true
			visited[next] = true
			stack.append(next)
	for y in range(ROWS):
		for x in range(COLS):
			var cell := Vector2i(x, y)
			for direction in [Vector2i.RIGHT, Vector2i.DOWN]:
				var next: Vector2i = cell + direction
				if valid_cell(next) and rng.randf() < maze_loops:
					passages[edge_key(cell, next)] = true
	add_wall(Rect2(BOARD.position - Vector2(WALL, WALL), Vector2(BOARD.size.x + WALL * 2, WALL)))
	add_wall(Rect2(Vector2(BOARD.position.x - WALL, BOARD.end.y), Vector2(BOARD.size.x + WALL * 2, WALL)))
	add_wall(Rect2(BOARD.position - Vector2(WALL, 0), Vector2(WALL, BOARD.size.y)))
	add_wall(Rect2(Vector2(BOARD.end.x, BOARD.position.y), Vector2(WALL, BOARD.size.y)))
	for y in range(ROWS):
		for x in range(COLS):
			var cell := Vector2i(x, y)
			var origin := BOARD.position + Vector2(cell) * CELL
			if x < COLS - 1 and not passages.has(edge_key(cell, cell + Vector2i.RIGHT)):
				add_wall(Rect2(origin + Vector2(CELL - WALL * 0.5, -WALL * 0.5), Vector2(WALL, CELL + WALL)))
			if y < ROWS - 1 and not passages.has(edge_key(cell, cell + Vector2i.DOWN)):
				add_wall(Rect2(origin + Vector2(-WALL * 0.5, CELL - WALL * 0.5), Vector2(CELL + WALL, WALL)))

func add_wall(rect: Rect2) -> void:
	wall_rects.append(rect)
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = rect.get_center()
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	var collision := CollisionShape2D.new()
	collision.shape = shape
	body.add_child(collision)
	$Walls.add_child(body)

func fire_shell(tank: DuelTank) -> void:
	if not active or paused or not tank.alive or tank.active_shells >= tank.max_shells:
		return
	var direction := tank.firing_direction()
	var muzzle := tank.global_position + direction * 31
	# Do not spawn a shell on the far side of a wall when the barrel touches it.
	var ray := PhysicsRayQueryParameters2D.create(tank.global_position, muzzle + direction * 4, 1)
	if not get_world_2d().direct_space_state.intersect_ray(ray).is_empty():
		tank.cooldown = 0.1
		return
	var shell: DuelShell = ShellScene.instantiate()
	shell.shooter = tank
	shell.tint = tank.tint
	shell.direction = direction
	shell.position = muzzle
	shell.speed = tank.shell_speed
	shell.max_bounces = tank.shell_wall_hits
	if mine_collisions:
		shell.collision_mask |= 8
	shell.bounced.connect(shell_bounced)
	tank.register_shot()
	$Shells.add_child(shell)
	burst(muzzle, tank.tint, false)
	play_sound(SHOOT, -17.0, randf_range(0.95, 1.05))

func shell_bounced(point: Vector2) -> void:
	burst(point, Color("ffe2a3"), false)
	var now := Time.get_ticks_msec()
	if now - bounce_time > 55:
		bounce_time = now
		play_sound(BOUNCE, -24.0, randf_range(0.9, 1.15))

func tank_destroyed(tank: DuelTank) -> void:
	burst(tank.position, tank.tint, true)
	play_sound(EXPLOSION, -13.0)
	if not resolution_pending:
		resolution_pending = true
		resolve_round.call_deferred()

func resolve_round() -> void:
	if not resolution_pending:
		return
	resolution_pending = false
	active = false
	set_controls(false)
	for shell in $Shells.get_children():
		shell.flight_enabled = false
	var survivors: Array[DuelTank] = []
	for tank in tanks:
		if tank.alive:
			survivors.append(tank)
	banner_color = Color("d5e2e8")
	if survivors.size() == 1:
		var winner := survivors[0].player_index
		scores[winner] += 1
		banner_color = COLORS[winner]
		match_finished = scores[winner] >= TARGET_SCORE
		banner = ("CYAN" if winner == 0 else "AMBER") + (" WINS THE MATCH" if match_finished else " TAKES THE ROUND")
	else:
		banner = "DOUBLE KNOCKOUT"
	round_timer = 0.0 if match_finished else 2.4

func burst(point: Vector2, tint: Color, large: bool) -> void:
	var effect = BurstScript.new()
	effect.position = point
	effect.tint = tint
	effect.large = large
	effect.duration = 0.65 if large else 0.2
	$Effects.add_child(effect)

func play_sound(stream: AudioStream, volume: float, pitch: float = 1.0) -> void:
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = volume
	player.pitch_scale = pitch
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()

func text_at(value: String, at: Vector2, size: int, color: Color) -> void:
	draw_string(font, at, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func centered(value: String, at: Vector2, size: int, color: Color) -> void:
	text_at(value, at - Vector2(font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x * 0.5, 0), size, color)

func draw_board() -> void:
	draw_rect(BOARD.grow(20), Color("090f16"))
	draw_rect(BOARD, Color("21303a"))
	draw_texture_rect(FLOOR, BOARD, false, Color(0.65, 0.75, 0.85, 0.16))
	for x in range(COLS + 1):
		draw_line(BOARD.position + Vector2(x * CELL, 0), BOARD.position + Vector2(x * CELL, BOARD.size.y), Color(0.8, 0.9, 1, 0.025))
	for y in range(ROWS + 1):
		draw_line(BOARD.position + Vector2(0, y * CELL), BOARD.position + Vector2(BOARD.size.x, y * CELL), Color(0.8, 0.9, 1, 0.025))
	for rect in wall_rects:
		draw_rect(Rect2(rect.position + Vector2(3, 5), rect.size), Color(0, 0, 0, 0.35))
		draw_rect(rect, Color("52616b"))
		draw_rect(Rect2(rect.position, Vector2(rect.size.x, 2)), Color("8f9ba0"))
		draw_rect(rect.grow(-3), Color("384952"))

func _draw() -> void:
	if font == null:
		return
	var muted := Color("8296a5")
	draw_rect(Rect2(0, 0, 1280, 800), Color("101923"))
	text_at("SUPER TANK BATTLES", Vector2(50, 43), 27, Color("ecf4f6"))
	text_at("LOCAL DUEL  /  RICOCHET ARENA", Vector2(51, 66), 13, muted)
	text_at("FIRST TO %d" % TARGET_SCORE, Vector2(1116, 42), 15, muted)
	for i in range(2):
		var left: float = 52 if i == 0 else 1024
		draw_rect(Rect2(left, 86, 204, 40), Color(COLORS[i], 0.1))
		draw_rect(Rect2(left, 86, 3, 40), COLORS[i])
		text_at("CYAN  /  P1" if i == 0 else "AMBER  /  P2", Vector2(left + 15, 111), 16, COLORS[i])
		text_at(str(scores[i]), Vector2(left + 174, 114), 25, Color("eff5f7"))
	centered("ROUND %02d" % round_number, Vector2(640, 106), 18, Color("d5e2e8"))
	centered("ANGLE. FIRE. GET CLEAR.", Vector2(640, 127), 12, muted)
	draw_board()
	for i in range(tanks.size()):
		var left: float = 52 if i == 0 else 870
		text_at("E/D  drive    S/F  turn    Q  fire" if i == 0 else "ARROWS  move / turn     M  fire", Vector2(left, 716), 16, COLORS[i])
		var available := tanks[i].max_shells - tanks[i].active_shells
		for slot in range(5):
			draw_rect(Rect2(left + slot * 19, 730, 13, 5), COLORS[i] if slot < available else Color("334450"))
		text_at("SHOTS READY", Vector2(left + 106, 738), 11, muted)
	centered("Shots break on the third wall hit. Returning shots are deadly.", Vector2(640, 752), 14, Color("bdcbd1"))
	centered("ESC  pause     R  new arena     ENTER  rematch     BACKSPACE  menu", Vector2(640, 781), 12, muted)

func draw_overlay() -> void:
	var overlay: Node2D = $Overlay
	var muted := Color("8296a5")
	if paused or countdown > 0 or not banner.is_empty():
		var title := "PAUSED" if paused else ("READY" if countdown > 0.5 else "GO!")
		var subtitle := "ESC to resume" if paused else "One hit. One point. Watch the bounce."
		var color := Color("ecf4f6")
		if not paused and not banner.is_empty():
			title = banner
			subtitle = "ENTER for a rematch" if match_finished else "Next arena in a moment"
			color = banner_color
		overlay.draw_rect(Rect2(296, 352, 688, 114), Color(0.04, 0.08, 0.12, 0.94))
		overlay.draw_rect(Rect2(296, 352, 688, 2), color)
		var title_width := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 28).x
		overlay.draw_string(font, Vector2(640 - title_width * 0.5, 405), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, color)
		var subtitle_width := font.get_string_size(subtitle, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		overlay.draw_string(font, Vector2(640 - subtitle_width * 0.5, 439), subtitle, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, muted)
