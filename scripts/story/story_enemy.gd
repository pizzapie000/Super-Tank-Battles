extends EnemyTank

const Parts = preload("res://scripts/story/upgrade_parts.gd")
var carried_part := ""
var part_level := 1
var carrier_claimed := false

func equip_carrier(part: String) -> void:
	carried_part = part
	# Marked carriers remain visible even when their base model can cloak.
	invisible_tank = false
	body_opacity = 1
	match part:
		"Loader": shot_cooldown *= 0.7
		"Armor": armor += 1; max_armor += 1
		"Bank Shot": shell_wall_hits += 1; ricochets += 1; ricochet_bonus_damage = 1
		"Engine": forward_speed *= 1.2; reverse_speed *= 1.2
	Parts.weapon_stats(self, part, part_level, true)

var armor: int = 1
var max_armor: int = 1
var dormant: bool = false
var damaged_model: bool = false
var boss: bool = false
var boss_title: String = ""
var phase_two: bool = false
var pursuer: bool = false
var visual_time: float = 0
var tactical_slot: int = 0
var tactical_role: String = "Independent"
var tactical_goal: Vector2 = Vector2.ZERO
var tactical_target: DuelTank
var tactical_timer: float = 0

func _process(delta: float) -> void:
	if is_instance_valid(arena) and not arena.paused:
		visual_time += delta
		tactical_timer = maxf(0, tactical_timer - delta)
	if not carried_part.is_empty(): self_modulate = Color.WHITE.lerp(Parts.COLORS[carried_part], (0.5 + 0.5 * sin(visual_time * 7)) * 0.6)
	super._process(delta)

func take_hit() -> void:
	take_shell_hit(1)

func take_shell_hit(damage: int) -> void:
	if not alive or (is_instance_valid(arena) and arena.stage_ready_time > 0):
		return
	armor -= damage
	if boss and not phase_two and armor <= max_armor / 2:
		phase_two = true
		shot_cooldown *= 0.65
		forward_speed *= 1.15
		arena.boss_phase(self)
	if armor <= 0:
		super.take_hit()
	else:
		arena.burst(position, tint, false)

func _draw() -> void:
	super._draw()
	if alive and not carried_part.is_empty():
		var pulse := 0.5 + 0.5 * sin(visual_time * 7)
		var color: Color = Parts.COLORS[carried_part]
		draw_circle(Vector2.ZERO, 28, Color(color, 0.1 + pulse * 0.22))
		draw_arc(Vector2.ZERO, 30, 0, TAU, 32, Color(color, 0.45 + pulse * 0.55), 3, true)
		draw_set_transform(Vector2.ZERO, -rotation)
		draw_string(ThemeDB.fallback_font, Vector2(-45, -42), carried_part.to_upper(), HORIZONTAL_ALIGNMENT_CENTER, 90, 12, color.lightened(0.3))
		draw_set_transform(Vector2.ZERO)
	if dormant:
		draw_circle(Vector2(-10, -3), 4, Color("182731"))
		draw_line(Vector2(-15, 7), Vector2(12, 7), Color("182731"), 2)
	if damaged_model:
		draw_rect(Rect2(-23, -21, 35, 10), Color("2c241d"))
		draw_polyline(PackedVector2Array([Vector2(-14, -8), Vector2(-3, -2), Vector2(-8, 5), Vector2(4, 10)]), Color("161b1d"), 2)
		for i in range(4):
			var age := fmod(visual_time * 0.65 + i * 0.25, 1)
			draw_circle(Vector2(-14 + sin(i * 4.0 + visual_time) * age * 12, -16 - age * 45), 3 + age * 10, Color(0.38, 0.38, 0.35, (1 - age) * 0.35))
		if fmod(visual_time * 3, 1) < 0.18:
			draw_line(Vector2(-17, -13), Vector2(-26, -22), Color("ffcf54"), 2)
	if armor > 1 or boss:
		draw_set_transform(Vector2.ZERO, -rotation)
		draw_rect(Rect2(-26, -34, 52, 5), Color("13202c"))
		draw_rect(Rect2(-26, -34, 52.0 * armor / max_armor, 5), Color("ffcc64"))
