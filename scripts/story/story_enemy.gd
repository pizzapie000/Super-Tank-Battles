extends EnemyTank

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
	queue_redraw()

func take_hit() -> void:
	take_shell_hit(1)

func take_shell_hit(damage: int) -> void:
	if not alive:
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
