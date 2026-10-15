extends "res://scripts/duel_arena.gd"

const StoryTankScene = preload("res://scenes/story/StoryTank.tscn")
const StoryEnemyScene = preload("res://scenes/story/StoryEnemy.tscn")
const MineScript = preload("res://scripts/tank_mine.gd")
const NavigationScript = preload("res://scripts/mission_navigation.gd")
const ALARM = preload("res://assets/audio/factory_alarm.wav")
const CHIME = preload("res://assets/audio/checkpoint_chime.wav")
const FactoryArt = preload("res://scripts/story/factory_art.gd")
const Encounters = preload("res://scripts/story/co_op_encounters.gd")
const Tactics = preload("res://scripts/story/story_tactics.gd")
const Parts = preload("res://scripts/story/upgrade_parts.gd")

@export var intro_music: AudioStream
@export_range(5, 120) var intro_duration: float = 16.0
@export var chapter_music: Array[AudioStream] = []
@export var save_progress: bool = true
@export var check_devices: bool = true
var players: Array[DuelTank] = []
var enemies: Array[EnemyTank] = []
var player: DuelTank
var navigation = NavigationScript.new()
var chapter: int = 0
var supplies: int = 2
var village_choice: String = ""
var phase: String = "intro"
var scene_time: float = 0
var intro_time: float = 0
var announcement: String = ""
var announcement_time: float = 0
var practice_kills: int = 0
var tutorial_step: int = 0
var wave_cleared: bool = false
var transitioning: bool = false
var fade_alpha: float = 0
var checkpoint_supplies: int = 2
var checkpoint_village: String = ""
var checkpoint_chapter: int = 0
var modal: PanelContainer
var music: AudioStreamPlayer
var missing_device: bool = false
var repair_cooldown: float = 0
var victory_time: float = 0
var transition_tween: Tween
var reinforcement_timer: float = 5
var reinforcement_wave: int = 0
var next_enemy_slot: int = 0
var pending_attackers: Array[Dictionary] = []
var ambush_triggered: bool = false
var ambush_retry: float = 0
var part_loadouts: Array[String] = Parts.sanitize([])
var checkpoint_parts: Array[String] = Parts.sanitize([])

func _ready() -> void:
	font = ThemeDB.fallback_font
	$HUD/Overlay.draw.connect(draw_overlay)
	mine_collisions = true
	music = AudioStreamPlayer.new()
	music.volume_db = -14
	add_child(music)
	music.finished.connect(func():
		if phase != "intro" and music.stream != null:
			music.play()
	)
	if StorySession.resume_story:
		var saved := StorySession.checkpoint()
		chapter = int(saved.chapter)
		supplies = int(saved.supplies)
		village_choice = str(saved.village)
		part_loadouts = Parts.sanitize(saved.parts)
	load_chapter(chapter)
	if not StorySession.resume_story:
		phase = "intro"
		set_activity(false)
		music.stream = intro_music
		if intro_music != null:
			music.play()
	Input.joy_connection_changed.connect(controller_changed)
	$Camera.position = $World.get_child(chapter).get_node("Start").global_position
	$Camera.reset_smoothing()

func _draw() -> void:
	pass

func region() -> Node2D:
	return $World.get_child(chapter)

func village_region() -> Node2D:
	for location in $World.get_children():
		if location.section_type == "Village":
			return location
	return null

func world_bounds() -> Rect2:
	var bounds := Rect2()
	for location in $World.get_children():
		bounds = bounds.merge(Rect2(location.position + location.area.position, location.area.size))
	return bounds

func clear_container(path: String) -> void:
	for child in get_node(path).get_children():
		get_node(path).remove_child(child)
		child.queue_free()

func load_chapter(index: int) -> void:
	for path in ["Shells", "Mines", "Effects", "Tanks"]:
		clear_container(path)
	players.clear()
	enemies.clear()
	tanks.clear()
	chapter = index
	checkpoint_chapter = chapter
	checkpoint_supplies = supplies
	checkpoint_village = village_choice
	checkpoint_parts = part_loadouts.duplicate()
	practice_kills = 0
	tutorial_step = 0
	wave_cleared = false
	reinforcement_timer = region().reinforcement_interval
	reinforcement_wave = 0
	next_enemy_slot = 0
	pending_attackers.clear()
	ambush_triggered = false
	ambush_retry = 0
	paused = false
	active = true
	resolution_pending = false
	transitioning = false
	phase = "tutorial" if region().section_type == "Tutorial" else ("village" if region().section_type == "Village" else "battle")
	if region().section_type == "Village" and not village_choice.is_empty():
		phase = "village_decided"
	for location in $World.get_children():
		location.get_node("Gate").visible = int(location.chapter) >= chapter
		location.village_state = village_choice
		if location.has_node("EntryBarrier"):
			location.get_node("EntryBarrier").visible = village_choice.is_empty()
		if location.has_node("CoopEntries"):
			for entry in location.get_node("CoopEntries").get_children():
				entry.opened = false
				if entry.gate() != null:
					entry.gate().visible = entry.approach != "Rear"
				entry.queue_redraw()
	region().reset_villagers()
	if region().has_node("Parts"):
		for pickup in region().get_node("Parts").get_children():
			pickup.reset_pickup()
	for location in $World.get_children():
		if location.section_type == "Village" and location.has_node("Villagers") and village_choice == "raided":
			for villager in location.get_node("Villagers").get_children():
				villager.hide()
	rebuild_walls()
	var start: Vector2 = region().get_node("Start").global_position
	for i in range(StorySession.devices.size()):
		var tank = StoryTankScene.instantiate()
		tank.device = StorySession.devices[i]
		tank.battlefield = self
		tank.player_index = i
		tank.identification = str(i + 1)
		tank.tint = StorySession.COLORS[i]
		tank.team_id = 0
		tank.max_mines = 2
		tank.mine_cooldown = 1.2
		tank.shell_wall_hits = 2
		tank.separate_turret = true
		tank.invulnerable = chapter == 0
		tank.position = start + Vector2((i % 2) * 62, (i / 2) * 72)
		connect_tank(tank)
		tank.equip_part(part_loadouts[i])
		players.append(tank)
	player = players[0] if not players.is_empty() else null
	for marker in region().get_node("Enemies").get_children():
		spawn_enemy(marker.tank_type, marker.global_position, marker.armor, marker.dormant, marker.damaged, marker.boss_title)
	prepare_coop_encounter()
	if region().section_type in ["Escape", "Approach"] or (region().section_type == "Village" and not village_choice.is_empty()):
		wave_cleared = true
		open_gate()
	set_activity(true)
	play_chapter_music()
	announce(region().briefing, 8)
	if save_progress:
		persist_story()

func persist_story(complete: bool = false) -> void:
	StorySession.save(chapter, supplies, village_choice, complete, part_loadouts)

func play_chapter_music() -> void:
	music.stop()
	music.stream = chapter_music[chapter] if chapter < chapter_music.size() else null
	if music.stream != null:
		music.play()

func connect_tank(tank: DuelTank) -> void:
	tank.shot_requested.connect(fire_shell)
	tank.mine_requested.connect(drop_mine)
	tank.destroyed.connect(tank_destroyed)
	$Tanks.add_child(tank)
	tanks.append(tank)

func spawn_enemy(type_name: String, at: Vector2, armor: int = 1, dormant: bool = false, damaged: bool = false, boss_title: String = "") -> EnemyTank:
	var enemy = StoryEnemyScene.instantiate()
	enemy.configure(type_name, self)
	enemy.position = at
	enemy.rotation = PI
	enemy.turret_angle = PI
	enemy.team_id = 1
	enemy.dormant = dormant
	enemy.damaged_model = damaged
	enemy.boss_title = boss_title
	enemy.boss = not boss_title.is_empty()
	enemy.max_armor = armor
	enemy.armor = enemy.max_armor
	if damaged:
		enemy.forward_speed *= 0.5
		enemy.shot_cooldown = 2.4
	if enemy.boss:
		enemy.forward_speed = 100
		enemy.reverse_speed = 70
	enemy.tactical_slot = next_enemy_slot
	next_enemy_slot += 1
	enemy.tactical_role = Tactics.role(enemy.tactical_slot, players.size(), enemy.forward_speed == 0)
	connect_tank(enemy)
	enemies.append(enemy)
	enemy.controls_enabled = active and not paused and not dormant
	return enemy

func spawn_position(origin: Vector2) -> Vector2:
	for ring in range(5):
		for direction in range(8 if ring > 0 else 1):
			var at := origin + Vector2.RIGHT.rotated(direction * TAU / 8) * ring * 64
			if not navigation.point_clear(at):
				continue
			var occupied := false
			for tank in tanks:
				if tank.alive and tank.position.distance_to(at) < (220 if tank in players else 72):
					occupied = true
			if not occupied:
				for crew in living_players():
					if not navigation.path(at, crew.position).is_empty():
						return at
	return Vector2.INF

func spawn_attacker(spec: Dictionary) -> bool:
	var at := spawn_position(spec.origin)
	if not at.is_finite():
		return false
	spawn_enemy(spec.type, at, spec.armor)
	return true

func prepare_coop_encounter() -> void:
	if players.size() < 2 or region().section_type not in ["Battle", "Final", "Escape"] or not region().has_node("CoopEntries"):
		return
	var base: Array[EnemyTank] = []
	for enemy in enemies:
		if not enemy.boss and not enemy.dormant:
			base.append(enemy)
	if base.is_empty():
		return
	var extra := Encounters.scaled_count(base.size(), players.size()) - base.size()
	var entries := region().get_node("CoopEntries").get_children()
	if entries.is_empty():
		return
	var immediate: Array[Node] = []
	var rear: Node
	for entry in entries:
		if entry.approach == "Rear":
			rear = entry
		else:
			immediate.append(entry)
	if immediate.is_empty():
		immediate = entries
	var lane_index := 0
	for i in range(extra):
		var model: EnemyTank = base[i % base.size()]
		var type_name := Encounters.specialist(chapter, players.size(), i, model.enemy_name)
		var entry: Node
		if region().coop_fortress:
			entry = entries[i % mini(players.size(), entries.size())]
		elif i % 3 == 2 and rear != null:
			entry = rear
		else:
			entry = immediate[lane_index % immediate.size()]
			lane_index += 1
		var spec := {"type": type_name, "armor": model.max_armor if type_name == model.enemy_name else 1, "origin": entry.global_position}
		if region().coop_fortress or (i % 3 == 2 and region().section_type != "Escape") or not spawn_attacker(spec):
			pending_attackers.append(spec)

func update_ambush(delta: float) -> void:
	if paused or not active or transitioning or pending_attackers.is_empty():
		return
	if not ambush_triggered:
		for crew in living_players():
			if crew.position.distance_to(region().get_node("AmbushTrigger").global_position) < 210:
				ambush_triggered = true
				if region().coop_fortress:
					var entries := region().get_node("CoopEntries").get_children()
					for i in range(mini(players.size(), entries.size())):
						entries[i].opened = true
						if entries[i].gate() != null:
							entries[i].gate().hide()
						entries[i].queue_redraw()
					set_activity(false)
					announce("Fortress alarm! %d entrances open — cover different directions!" % players.size(), 7)
					rebuild_walls()
					set_activity(true)
					play_sound(ALARM, -18)
				else:
					announce("Rear ambush! Watch the road behind the crew.", 5)
				break
	if not ambush_triggered:
		return
	ambush_retry -= delta
	if ambush_retry > 0:
		return
	ambush_retry = 1
	for spec in pending_attackers.duplicate():
		if spawn_attacker(spec):
			pending_attackers.erase(spec)

func rebuild_walls() -> void:
	clear_container("Walls")
	wall_rects.clear()
	var world := world_bounds()
	for rect in [Rect2(world.position - Vector2(14, 14), Vector2(world.size.x + 28, 14)), Rect2(Vector2(world.position.x - 14, world.end.y), Vector2(world.size.x + 28, 14)), Rect2(world.position - Vector2(14, 0), Vector2(14, world.size.y)), Rect2(Vector2(world.end.x, world.position.y), Vector2(14, world.size.y))]:
		add_wall(rect)
	for piece in $World.find_children("*", "", true, false):
		if piece.has_method("wall_rect") and piece.visible:
			add_wall(piece.wall_rect())
	var bounds := Rect2(region().global_position + region().area.position, region().area.size)
	# Factory pursuers enter from the already-open tutorial, behind the camera.
	if region().section_type == "Escape" and chapter > 0:
		var previous := $World.get_child(chapter - 1)
		bounds = bounds.merge(Rect2(previous.global_position + previous.area.position, previous.area.size))
	var local_walls: Array[Rect2] = []
	for rect in wall_rects:
		if rect.intersects(bounds.grow(40)):
			local_walls.append(rect)
	navigation.build(local_walls, bounds)

func set_activity(enabled: bool) -> void:
	active = enabled
	for tank in tanks:
		var can_move := enabled and not paused and tank.alive
		if tank is EnemyTank and tank.dormant:
			can_move = false
		tank.controls_enabled = can_move
		tank.set_physics_process(enabled and not paused)
	for shell in $Shells.get_children():
		shell.flight_enabled = enabled and not paused
	for mine in $Mines.get_children():
		mine.frozen = not enabled or paused
	for effect in $Effects.get_children():
		effect.set_process(enabled and not paused)
	for child in get_children():
		if child is AudioStreamPlayer:
			child.stream_paused = paused

func drop_mine(tank: DuelTank) -> void:
	if not active or paused or not tank.alive or tank.mine_timer > 0 or tank.active_mines >= tank.max_mines:
		return
	for existing in $Mines.get_children():
		if existing.position.distance_to(tank.position) < 28:
			return
	var mine: TankMine = MineScript.new()
	mine.position = tank.position
	mine.owner_tank = tank
	mine.arena = self
	mine.exploded.connect(func(point: Vector2):
		burst(point, Color("f4cc65"), true)
		play_sound(EXPLOSION, -16)
	)
	tank.register_mine()
	$Mines.add_child(mine)

func target_for_enemy(enemy: EnemyTank) -> DuelTank:
	var alive := living_players()
	if players.size() > 1 and not alive.is_empty():
		return alive[enemy.tactical_slot % alive.size()]
	var target: DuelTank
	var distance := INF
	for crew in players:
		if crew.alive and enemy.global_position.distance_squared_to(crew.global_position) < distance:
			target = crew
			distance = enemy.global_position.distance_squared_to(crew.global_position)
	return target

func aiming_walls(enemy: EnemyTank, target: DuelTank) -> Array[Rect2]:
	var nearby := Rect2(enemy.position, Vector2.ZERO).expand(target.position).grow(600)
	var result: Array[Rect2] = []
	for wall in wall_rects:
		if wall.intersects(nearby):
			result.append(wall)
	return result

func plan_enemy_shot(enemy: EnemyTank, target: DuelTank, walls: Array[Rect2]) -> Dictionary:
	var velocity := target.velocity if enemy.predictive else Vector2.ZERO
	var allies := friendly_positions(enemy)
	if players.size() >= 3 and enemy.tactical_role == "Support" and enemy.ricochets > 0 and enemy.min_ricochets == 0:
		var bank := ShotPlanner.solve(enemy.position, target.position, velocity, enemy.shell_speed, walls, enemy.ricochets, allies, 1, true)
		if not bank.is_empty():
			bank.min_bounces = 1
			return bank
	return ShotPlanner.solve(enemy.position, target.position, velocity, enemy.shell_speed, walls, enemy.ricochets, allies, enemy.min_ricochets, players.size() > 1)

func navigation_path(enemy: EnemyTank, has_shot: bool) -> Array[Vector2]:
	var target := target_for_enemy(enemy)
	if target == null:
		return []
	if enemy.tactical_timer <= 0 or enemy.tactical_target != target:
		enemy.tactical_target = target
		enemy.tactical_goal = Tactics.goal(self, enemy, target, has_shot)
		enemy.tactical_timer = 1.2
	return navigation.path(enemy.position, enemy.tactical_goal)

func friendly_positions(shooter: EnemyTank) -> Array[Vector2]:
	var result: Array[Vector2] = []
	for enemy in enemies:
		if enemy != shooter and enemy.alive:
			result.append(enemy.position)
	return result

func evasion_vector(tank: EnemyTank) -> Vector2:
	for shell in $Shells.get_children():
		if shell.released:
			continue
		var offset: Vector2 = tank.position - shell.position
		var along: float = offset.dot(shell.direction)
		if along > 0 and along < shell.speed * 0.7:
			var side: Vector2 = offset - shell.direction * along
			if side.length() < 35:
				var dodge: Vector2 = shell.direction.orthogonal() * (85 if side.dot(shell.direction.orthogonal()) >= 0 else -85)
				if navigation.segment_clear(tank.position, tank.position + dodge):
					return dodge
	return Tactics.separation(self, tank)

func party_position_allowed(tank: DuelTank, at: Vector2, before: Vector2) -> bool:
	for crew in players:
		if crew != tank and crew.alive and at.distance_to(crew.position) > 850 and at.distance_to(crew.position) > before.distance_to(crew.position):
			return false
	return true

func tank_destroyed(tank: DuelTank) -> void:
	burst(tank.position, tank.tint, true)
	play_sound(EXPLOSION, -17)
	if tank is EnemyTank and tank.dormant:
		practice_kills += 1
	if not resolution_pending:
		resolution_pending = true
		resolve_round.call_deferred()

func resolve_round() -> void:
	resolution_pending = false
	if phase in ["intro", "tutorial", "defeat", "ending"]:
		return
	if living_players().is_empty():
		phase = "defeat"
		set_activity(false)
		show_modal("CREW DISABLED", "The whole crew is down. Retry from this chapter's checkpoint.", ["RETRY CHECKPOINT", "RETURN TO MODES"], [retry_checkpoint, return_menu])
	elif remaining_enemies() == 0 and region().section_type not in ["Village", "Escape", "Approach"] and not wave_cleared:
		wave_cleared = true
		open_gate()
		announce("Road clear. Bring the crew to the eastern exit.", 6)
		if region().section_type == "Final":
			finish_story()

func living_players() -> Array[DuelTank]:
	var result: Array[DuelTank] = []
	for crew in players:
		if crew.alive:
			result.append(crew)
	return result

func remaining_enemies() -> int:
	var count := pending_attackers.size()
	for enemy in enemies:
		if enemy.alive and not enemy.dormant:
			count += 1
	return count

func open_gate() -> void:
	region().get_node("Gate").hide()
	if region().coop_fortress:
		for entry in region().get_node("CoopEntries").get_children():
			if entry.gate() != null:
				entry.gate().hide()
	rebuild_walls()
	play_sound(CHIME, -14)

func begin_alarm() -> void:
	phase = "alarm"
	for crew in players:
		crew.invulnerable = false
	spawn_enemy("Ash", Vector2(1280, 650))
	spawn_enemy("Brown", Vector2(1320, 410))
	play_sound(ALARM, -11)
	announce("ALARM — Unauthorized activation! Security is coming. Fight your way out!", 9)

func boss_phase(boss: EnemyTank) -> void:
	announce("%s: backup systems online. Reinforcements incoming!" % boss.boss_title, 6)
	play_sound(ALARM, -18)
	var spawned := 0
	for y in [540, 730, 420, 950]:
		for x in [980, 1190, 1350, 710]:
			var at: Vector2 = region().global_position + Vector2(x, y)
			if not navigation.point_clear(at):
				continue
			var occupied := false
			for tank in tanks:
				if tank.alive and tank.position.distance_to(at) < 65:
					occupied = true
			if occupied:
				continue
			spawn_enemy("Ash" if region().biome == "Fortress" else "Marine", at)
			spawned += 1
			if spawned >= Encounters.scaled_count(1, players.size()):
				return

func update_reinforcements(delta: float) -> void:
	if not active or paused or transitioning or region().section_type != "Escape":
		return
	reinforcement_timer -= delta
	if reinforcement_timer > 0:
		return
	reinforcement_timer = region().reinforcement_interval
	var capacity := Encounters.scaled_count(10, players.size())
	if remaining_enemies() >= capacity:
		return
	# Spawn beyond the left edge at every camera zoom, with room for the tank.
	var screen_left: float = $Camera.position.x - 640 / $Camera.zoom.x
	var spawn_x := minf(region().global_position.x + 80, screen_left - 100)
	spawn_x = maxf(navigation.bounds.position.x + 60, spawn_x)
	if spawn_x + 40 >= screen_left:
		return
	var count := mini(Encounters.scaled_count(1, players.size()), capacity - remaining_enemies())
	var spawned := 0
	for offset in range(26):
		var at := Vector2(spawn_x, 130 + ((offset * 3 + reinforcement_wave * 5) % 26) * 32)
		if not navigation.point_clear(at):
			continue
		var occupied := false
		for tank in tanks:
			if tank.alive and tank.position.distance_to(at) < 65:
				occupied = true
		if occupied:
			continue
		var enemy := spawn_enemy("Marine" if reinforcement_wave % 3 == 2 else "Ash", at)
		enemy.pursuer = true
		enemy.behavior = "Offensive"
		enemy.forward_speed = 125
		enemy.reverse_speed = 88
		enemy.rotation = 0
		enemy.turret_angle = 0
		spawned += 1
		if spawned >= count:
			break
	if spawned > 0:
		reinforcement_wave += 1
		if reinforcement_wave == 1:
			announce("Security reinforcements behind us! Keep moving toward the eastern exit.", 6)
	# Retire destroyed reinforcements so long escapes do not accumulate actors.
	for enemy in enemies.duplicate():
		if enemy.pursuer and not enemy.alive:
			enemies.erase(enemy)
			tanks.erase(enemy)
			enemy.queue_free()

func announce(value: String, duration: float = 5) -> void:
	announcement = value
	announcement_time = duration

func _process(delta: float) -> void:
	if paused:
		$HUD/Overlay.queue_redraw()
		return
	scene_time += delta
	elapsed += delta
	announcement_time = maxf(0, announcement_time - delta)
	repair_cooldown = maxf(0, repair_cooldown - delta)
	if phase == "intro":
		intro_time += delta
		if intro_time >= intro_duration:
			finish_intro()
	elif active and not transitioning:
		update_camera(delta)
		update_revives(delta)
		update_part_pickups(delta)
		update_ambush(delta)
		update_reinforcements(delta)
		if phase == "tutorial":
			update_tutorial()
		var positions: Array[Vector2] = []
		for crew in living_players():
			positions.append(crew.position)
		region().update_villagers(positions, delta)
		if region().section_type == "Village" and village_choice.is_empty():
			for crew in living_players():
				if crew.position.distance_to(region().get_node("ChoiceTrigger").global_position) < 140:
					show_village_choice()
					break
		if not village_choice.is_empty():
			update_repairs()
		if wave_cleared and chapter < $World.get_child_count() - 1 and phase != "village":
			var all_at_exit := not living_players().is_empty()
			for crew in living_players():
				if crew.position.x < region().get_node("Exit").global_position.x - 60:
					all_at_exit = false
			if all_at_exit:
				advance_chapter()
	if phase == "ending":
		victory_time += delta
	$HUD/Overlay.queue_redraw()

func update_tutorial() -> void:
	var moved := 0.0
	var mines := 0
	for crew in players:
		moved += crew.moved_distance
		mines += crew.total_mines
	if tutorial_step == 0 and moved >= 120:
		tutorial_step = 1
		announce("Aim at the inactive tanks. Their engines are off; they cannot fight back.", 7)
	if tutorial_step == 1 and practice_kills >= 2:
		tutorial_step = 2
		announce("Last system: deploy a landmine with E or B / Circle. Your crew is safe from friendly blasts.", 7)
	if tutorial_step == 2 and mines >= 1:
		tutorial_step = 3
		begin_alarm()

func finish_intro() -> void:
	if phase != "intro":
		return
	intro_time = intro_duration
	music.stop()
	phase = "tutorial"
	set_activity(true)
	play_chapter_music()
	announce(region().briefing, 8)

func update_camera(delta: float) -> void:
	var alive := living_players()
	if alive.is_empty():
		return
	var box := Rect2(alive[0].position, Vector2.ZERO)
	for crew in alive:
		box = box.expand(crew.position)
	var zoom := minf(1, minf(1100 / maxf(1100, box.size.x + 240), 640 / maxf(640, box.size.y + 240)))
	zoom = maxf(0.5, zoom)
	$Camera.zoom = $Camera.zoom.lerp(Vector2.ONE * zoom, minf(1, delta * 3))
	var center := box.get_center()
	var bounds := world_bounds()
	center.x = clampf(center.x, bounds.position.x + 640 / zoom, bounds.end.x - 640 / zoom)
	# Follow the crew vertically as well: the world is taller than the viewport.
	# Leave room for the HUD when the crew approaches either outer boundary.
	center.y = clampf(center.y, bounds.position.y + 260 / zoom, bounds.end.y - 260 / zoom)
	$Camera.position = $Camera.position.lerp(center, minf(1, delta * 4))

func update_revives(delta: float) -> void:
	for downed in players:
		if downed.alive:
			continue
		var helping := false
		for crew in living_players():
			if crew.interact_held and crew.position.distance_to(downed.position) < 90:
				helping = true
		downed.revive_progress = minf(2, downed.revive_progress + delta) if helping else maxf(0, downed.revive_progress - delta)
		if downed.revive_progress >= 2:
			downed.revive(downed.position)
			play_sound(CHIME, -17)

func nearest_part(crew: Node2D, radius: float = 70) -> Node2D:
	var closest: Node2D
	if not region().has_node("Parts"):
		return null
	for pickup in region().get_node("Parts").get_children():
		var gap: float = crew.position.distance_to(pickup.global_position)
		if not pickup.claimed and gap < radius:
			closest = pickup
			radius = gap
	return closest

func update_part_pickups(delta: float) -> void:
	if paused or not active or transitioning or not region().has_node("Parts"):
		return
	for pickup in region().get_node("Parts").get_children():
		if pickup.claimed:
			continue
		var collector: Node2D
		var distance := 70.0
		for crew in living_players():
			var gap: float = crew.position.distance_to(pickup.global_position)
			if crew.interact_held and crew.part_cooldown <= 0 and gap < distance and nearest_part(crew) == pickup:
				collector = crew
				distance = gap
		if collector == null:
			pickup.progress = 0
			pickup.claimant = null
		else:
			if collector != pickup.claimant:
				pickup.progress = 0
			pickup.claimant = collector
			pickup.progress += delta
			if pickup.progress >= 0.45:
				collector.equip_part(pickup.part_type)
				collector.part_cooldown = 1
				part_loadouts[collector.player_index] = pickup.part_type
				pickup.claimed = true
				pickup.hide()
				play_sound(CHIME, -17)
				announce("P%d fitted %s. %s One part slot per tank." % [collector.player_index + 1, pickup.part_type, Parts.DESCRIPTIONS[pickup.part_type]], 6)
				if save_progress:
					persist_story()
		pickup.queue_redraw()

func update_repairs() -> void:
	if village_choice != "spared" or repair_cooldown > 0:
		return
	var station: Vector2 = village_region().get_node("RepairStation").global_position
	for crew in living_players():
		if crew.interact_held and crew.position.distance_to(station) < 100:
			for tank in players:
				if tank.position.distance_to(station) < 230:
					tank.revive(tank.position)
			play_sound(CHIME, -15)
			repair_cooldown = 2
			announce("The village repairs the crew. This refuge remains open behind you.")
			break

func advance_chapter() -> void:
	if transitioning:
		return
	transitioning = true
	set_activity(false)
	transition_tween = create_tween()
	transition_tween.tween_property(self, "fade_alpha", 1.0, 0.45)
	transition_tween.tween_callback(func():
		supplies += 2
		load_chapter(chapter + 1)
		$Camera.position = region().get_node("Start").global_position
		$Camera.reset_smoothing()
	)
	transition_tween.tween_property(self, "fade_alpha", 0.0, 0.55)

func retry_checkpoint() -> void:
	close_modal()
	supplies = checkpoint_supplies
	village_choice = checkpoint_village
	part_loadouts = checkpoint_parts.duplicate()
	load_chapter(checkpoint_chapter)
	$Camera.position = region().get_node("Start").global_position

func show_village_choice() -> void:
	phase = "choice"
	set_activity(false)
	show_modal("THE CHIEF'S PLEA", "Chief: Please spare our village. We have families here, and nothing left to fight with. Let us live and our workshop will repair your crew.\nSpare: repair refuge + 3 supplies. Destroy: 8 supplies; the refuge is lost.", ["SPARE THE VILLAGE — KEEP THE REPAIR REFUGE", "DESTROY THE VILLAGE — TAKE 8 SUPPLIES"], [func(): choose_village("spared"), func(): choose_village("raided")])

func choose_village(choice: String) -> void:
	if not village_choice.is_empty() or choice not in ["spared", "raided"]:
		return
	village_choice = choice
	supplies += 3 if choice == "spared" else 8
	var village := village_region()
	village.village_state = choice
	village.get_node("EntryBarrier").hide()
	for villager in village.get_node("Villagers").get_children():
		villager.visible = choice == "spared"
	checkpoint_village = choice
	checkpoint_supplies = supplies
	checkpoint_parts = part_loadouts.duplicate()
	if save_progress:
		persist_story()
	close_modal()
	phase = "village_decided"
	wave_cleared = true
	set_activity(true)
	open_gate()
	if choice == "spared":
		for crew in players:
			crew.revive(crew.position)
		announce("Villager: You chose to stop. We'll keep a light on. Hold F / A at the green station for repairs.", 9)
	else:
		for at in [Vector2(440, 210), Vector2(960, 180), Vector2(400, 800), Vector2(1000, 830)]:
			burst(village.global_position + at, Color("ff951a"), true)
		play_sound(EXPLOSION, -17)
		announce("The workshop burns. The village goes dark. The crew keeps its stockpile.", 8)

func field_repair() -> void:
	if not active or paused or supplies < 2 or repair_cooldown > 0:
		return
	supplies -= 2
	for crew in players:
		if crew.alive:
			crew.armor = crew.max_armor
	repair_cooldown = 8
	announce("Field repair: 2 supplies spent. Active crew armor restored.")
	play_sound(CHIME, -15)

func finish_story() -> void:
	phase = "ending"
	set_activity(false)
	if save_progress:
		persist_story(true)
	var ending := "The command signal dies. The village opens its gates to the crew that chose mercy." if village_choice == "spared" else "The command signal dies. The crew has won the capital, but no lights wait at the village."
	show_modal("THE WAR ENDS HERE", ending + "\n\nThe road is yours now.", ["RETURN TO MODES"], [return_menu])

func controller_changed(device: int, connected: bool) -> void:
	if not check_devices:
		return
	if not connected and StorySession.devices.has(device):
		missing_device = true
		pause_story("CONTROLLER DISCONNECTED", "Reconnect the controller to continue, or return to the lobby to change your crew.")
	elif connected and missing_device:
		for i in range(StorySession.devices.size()):
			if StorySession.devices[i] >= 0 and not Input.get_connected_joypads().has(StorySession.devices[i]):
				StorySession.devices[i] = device
				players[i].device = device
				break
		missing_device = false
		for assigned in StorySession.devices:
			if assigned >= 0 and not Input.get_connected_joypads().has(assigned):
				missing_device = true
		if not missing_device:
			close_modal()
			paused = false
			if transition_tween != null and transition_tween.is_valid():
				transition_tween.play()
			set_activity(phase not in ["intro", "ending", "defeat", "choice"])
			if phase == "choice":
				show_village_choice()
			elif phase == "defeat":
				show_modal("CREW DISABLED", "Retry from this chapter's checkpoint.", ["RETRY CHECKPOINT", "RETURN TO MODES"], [retry_checkpoint, return_menu])
			elif phase == "ending":
				finish_story()

func pause_story(title: String = "PAUSED", detail: String = "Stay together. The road will wait.") -> void:
	paused = true
	if transition_tween != null and transition_tween.is_valid():
		transition_tween.pause()
	set_activity(active)
	var labels: Array[String] = []
	var actions: Array[Callable] = []
	if not missing_device:
		labels.append("RESUME")
		actions.append(resume_game)
	labels.append("RETURN TO LOBBY")
	actions.append(return_lobby)
	show_modal(title, detail, labels, actions)

func resume_game() -> void:
	if missing_device:
		return
	close_modal()
	paused = false
	if transition_tween != null and transition_tween.is_valid():
		transition_tween.play()
	set_activity(true)

func return_lobby() -> void:
	StorySession.resume_story = true
	get_tree().change_scene_to_file("res://scenes/story/Lobby.tscn")

func return_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/game/MainMenu.tscn")

func close_modal() -> void:
	if is_instance_valid(modal):
		modal.get_parent().remove_child(modal)
		modal.queue_free()
	modal = null

func show_modal(title: String, detail: String, labels: Array[String], actions: Array[Callable]) -> void:
	close_modal()
	modal = PanelContainer.new()
	modal.position = Vector2(190, 255)
	modal.size = Vector2(900, 330)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("13222f")
	style.border_color = Color("89b5c8")
	style.set_border_width_all(2)
	style.set_content_margin_all(28)
	modal.add_theme_stylebox_override("panel", style)
	$HUD.add_child(modal)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 20)
	modal.add_child(box)
	for value in [title, detail]:
		var label := Label.new()
		label.text = value
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_font_size_override("font_size", 29 if value == title else 19)
		box.add_child(label)
	for i in range(labels.size()):
		var button := Button.new()
		button.text = labels[i]
		button.custom_minimum_size.y = 48
		button.pressed.connect(actions[i])
		box.add_child(button)
		if i == 0:
			button.grab_focus()

func _input(event: InputEvent) -> void:
	var keyboard: bool = event is InputEventKey and event.pressed and not event.echo
	var controller: bool = event is InputEventJoypadButton and event.pressed and StorySession.devices.has(event.device)
	if keyboard and event.physical_keycode == KEY_BACKSPACE:
		return_menu()
		return
	if phase == "intro":
		if (keyboard and event.physical_keycode in [KEY_ENTER, KEY_SPACE]) or (controller and event.button_index == JOY_BUTTON_START):
			finish_intro()
			get_viewport().set_input_as_handled()
		return
	if phase == "choice" and keyboard and event.physical_keycode in [KEY_1, KEY_2]:
		choose_village("spared" if event.physical_keycode == KEY_1 else "raided")
		get_viewport().set_input_as_handled()
		return
	if phase in ["choice", "defeat", "ending"]:
		return
	if (keyboard and event.physical_keycode == KEY_ESCAPE) or (controller and event.button_index == JOY_BUTTON_START):
		if paused:
			resume_game()
		else:
			pause_story()
		get_viewport().set_input_as_handled()
	elif (keyboard and event.physical_keycode == KEY_R) or (controller and event.button_index == JOY_BUTTON_Y):
		field_repair()

func draw_overlay() -> void:
	var overlay: Node2D = $HUD/Overlay
	if phase == "intro":
		draw_intro(overlay)
		return
	overlay.draw_rect(Rect2(0, 0, 1280, 96), Color(0.025, 0.05, 0.08, 0.96))
	overlay.draw_string(font, Vector2(30, 29), "%02d / %s" % [chapter + 1, region().title.to_upper()], HORIZONTAL_ALIGNMENT_LEFT, -1, 21, Color("ecf4f6"))
	overlay.draw_string(font, Vector2(1030, 29), "SUPPLIES %d" % supplies, HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Color("ffd575"))
	for i in range(players.size()):
		var crew = players[i]
		var at := Vector2(30 + i * 305, 68)
		var armor_label := "ARMOR %d/%d" % [crew.armor, crew.max_armor]
		if not crew.equipped_part.is_empty():
			armor_label += " · " + crew.equipped_part.to_upper()
		var label := "P%d  %s" % [i + 1, armor_label if crew.alive else "DOWN — HOLD F / A NEARBY"]
		overlay.draw_string(font, at, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, DuelTank.readable_tint(crew.tint))
	if announcement_time > 0:
		overlay.draw_rect(Rect2(24, 107, 1232, 46), Color(0.03, 0.06, 0.1, 0.9))
		overlay.draw_string(font, Vector2(40, 136), announcement, HORIZONTAL_ALIGNMENT_LEFT, 1200, 17, Color("e4d9b8"))
	overlay.draw_rect(Rect2(0, 741, 1280, 59), Color(0.025, 0.05, 0.08, 0.96))
	var objective := "Clear the road: %d enemies remaining. Cover different directions." % remaining_enemies()
	if phase == "tutorial":
		objective = ["WASD / LEFT STICK — Move off the polishing station.", "MOUSE / RIGHT STICK — Aim. CLICK / RT — Fire at two inactive tanks.", "E / B — Deploy a landmine. These first tanks cannot fire back."][mini(tutorial_step, 2)]
	elif region().section_type == "Village" and village_choice.is_empty():
		objective = "Approach the village gates. The chief is waiting to speak with the crew."
	elif region().section_type == "Escape":
		objective = "Escape east → Reinforcements arrive from the west every %.0f seconds. Stay together." % region().reinforcement_interval
	elif region().section_type == "Approach":
		objective = "Follow the dirt road and the villagers' signs to the eastern exit →"
	elif wave_cleared:
		objective = "Road clear. Bring every active crew member to the east exit →"
	elif not pending_attackers.is_empty() and not ambush_triggered:
		objective = "Advance east and clear the patrols: %d enemies remain. Watch the road behind you." % remaining_enemies()
		if region().coop_fortress:
			objective = "Advance into the courtyard. Watch each entrance when the alarm sounds."
	for crew in living_players():
		var pickup := nearest_part(crew, 85)
		if pickup != null:
			objective = "P%d · HOLD F / A to fit %s: %s One part slot." % [crew.player_index + 1, pickup.part_type, Parts.DESCRIPTIONS[pickup.part_type]]
			break
	overlay.draw_string(font, Vector2(30, 763), objective, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("f5dc9c"))
	overlay.draw_string(font, Vector2(30, 788), "ESC / START pause  •  F / A revive / equip part  •  R / Y field repair (2 supplies)  •  BACKSPACE menu", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("a0b5c1"))
	for enemy in enemies:
		if enemy.boss and enemy.alive:
			overlay.draw_rect(Rect2(390, 164, 500, 7), Color("172631"))
			overlay.draw_rect(Rect2(390, 164, 500.0 * enemy.armor / enemy.max_armor, 7), Color("ff951a"))
			overlay.draw_string(font, Vector2(390, 194), enemy.boss_title.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("ffe0a8"))
	if chapter == 0 and phase == "alarm":
		overlay.draw_rect(Rect2(0, 96, 1280, 645), Color(0.9, 0.08, 0.05, 0.035 + maxf(0, sin(scene_time * 6)) * 0.04))
	if fade_alpha > 0:
		overlay.draw_rect(Rect2(0, 0, 1280, 800), Color(0, 0, 0, fade_alpha))

func draw_intro(canvas: Node2D) -> void:
	var time := intro_time * 16.0 / intro_duration
	canvas.draw_rect(Rect2(0, 0, 1280, 800), Color("0b141e"))
	if time < 1:
		canvas.draw_rect(Rect2(0, 0, 1280, 800), Color.BLACK)
		return
	# Factory gantry, overhead lights and the same roller belt used in the level.
	for x in range(0, 1280, 80):
		canvas.draw_line(Vector2(x, 160), Vector2(x, 800), Color("162632"), 1)
	for y in range(180, 800, 80):
		canvas.draw_line(Vector2(0, y), Vector2(1280, y), Color("162632"), 1)
	canvas.draw_rect(Rect2(110, 190, 24, 395), Color("304552"))
	canvas.draw_rect(Rect2(1146, 190, 24, 395), Color("304552"))
	canvas.draw_rect(Rect2(110, 180, 1060, 20), Color("526470"))
	for x in [290, 640, 990]:
		canvas.draw_rect(Rect2(x - 53, 164, 106, 8), Color("d2d8b5"))
		canvas.draw_colored_polygon(PackedVector2Array([Vector2(x - 44, 174), Vector2(x + 44, 174), Vector2(x + 160, 630), Vector2(x - 160, 630)]), Color(0.6, 0.75, 0.72, 0.025))
	FactoryArt.conveyor(canvas, Rect2(155, 320, 970, 260), time)
	var center := Vector2(640, 440)
	var scale := Vector2.ONE * 4.5
	var tint := StorySession.COLORS[0]
	canvas.draw_set_transform(center, 0, scale)
	canvas.draw_circle(Vector2(1, 4), 24, Color(0, 0, 0, 0.3))
	var chassis_slide := -105.0 * (1 - smoothstep(1.0, 3.0, time))
	DuelTank.Art.chassis(canvas, Vector2(chassis_slide, 0))
	if time >= 3:
		var track_drop := -40.0 * (1 - smoothstep(3.0, 4.5, time))
		DuelTank.Art.tracks(canvas, Vector2(0, track_drop), -1, time * 3)
	if time >= 3.6:
		var track_drop := 40.0 * (1 - smoothstep(3.6, 5.1, time))
		DuelTank.Art.tracks(canvas, Vector2(0, track_drop), 1, time * 3)
	if time >= 5:
		var armor_drop := -75.0 * (1 - smoothstep(5.0, 7.0, time))
		DuelTank.Art.armor(canvas, tint, Vector2(0, armor_drop))
	if time >= 7.6:
		var turret_drop := -65.0 * (1 - smoothstep(7.6, 9.3, time))
		DuelTank.Art.turret(canvas, tint, Vector2(0, turret_drop), 0, false)
	if time >= 9.4:
		var barrel_slide := 75.0 * (1 - smoothstep(9.4, 10.9, time))
		DuelTank.Art.barrel(canvas, tint, Vector2(barrel_slide, 0))
	if time >= 11:
		DuelTank.draw_identification(canvas, "1")
	canvas.draw_set_transform(Vector2.ZERO)
	# Lowering chains, an assembly arm, and welding flashes make each install visible.
	if time >= 5 and time < 7:
		var y := center.y - 75 * 4.5 * (1 - smoothstep(5.0, 7.0, time))
		for x in [center.x - 58, center.x + 58]:
			canvas.draw_line(Vector2(x, 200), Vector2(x, y - 38), Color("9faeac"), 3)
	if time >= 6.8 and time < 7.6:
		var weld := center + Vector2(-65, -37)
		canvas.draw_line(Vector2(210, 215), Vector2(340, 270), Color("72848b"), 13)
		canvas.draw_line(Vector2(340, 270), weld, Color("93a8ad"), 9)
		canvas.draw_circle(weld, 9, Color("fff3b4"))
		for i in range(15):
			var point := weld + Vector2.RIGHT.rotated(i * 0.57 + time) * fmod(time * 170 + i * 7, 70)
			canvas.draw_line(point, point + (point - weld).normalized() * 5, Color("ffd16b"), 2)
	if time >= 11:
		canvas.draw_set_transform(center + Vector2(-120, 32), 0, Vector2.ONE * 2.4)
		FactoryArt.technician(canvas, Vector2.ZERO, time)
		canvas.draw_set_transform(Vector2.ZERO)
		if time >= 14:
			canvas.draw_circle(center + Vector2(-57, -36), 5, Color("7ff3c7"))
	var title := "CHASSIS INSPECTION"
	if time >= 3: title = "MOUNTING THE TRACKS"
	if time >= 5: title = "FITTING THE ARMOR"
	if time >= 7.6: title = "TURRET INSTALLATION"
	if time >= 9.4: title = "CANNON INSTALLATION"
	if time >= 11: title = "ONE LAST POLISH"
	if time >= 14: title = "ENGINE ONLINE"
	var width := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 32).x
	canvas.draw_string(font, Vector2(640 - width * 0.5, 112), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 32, Color("f4dc9c"))
	canvas.draw_string(font, Vector2(430, 694), "ASSEMBLY LINE 01  /  FINAL INSPECTION", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("afc4ce"))
	canvas.draw_string(font, Vector2(510, 764), "ENTER / START skip intro", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("8296a5"))
	if time < 1.7:
		canvas.draw_rect(Rect2(0, 0, 1280, 800), Color(0, 0, 0, 1 - smoothstep(1.0, 1.7, time)))
	if time > 15:
		canvas.draw_rect(Rect2(0, 0, 1280, 800), Color(0, 0, 0, time - 15))
