@tool
extends StaticBody2D

signal breached(gate: Node2D)

@export var size := Vector2(42, 400):
	set(value):
		size = Vector2(maxf(20, value.x), maxf(80, value.y))
		refresh()
@export_range(1, 30) var max_health: int = 6
var health: int = 6
var broken: bool = false
var arena: Node2D
var hit_flash: float = 0

func _ready() -> void:
	health = max_health
	refresh()

func refresh() -> void:
	if has_node("CollisionShape2D"):
		$CollisionShape2D.shape.size = size
	queue_redraw()

func restore(battlefield: Node2D, enabled: bool) -> void:
	arena = battlefield
	health = max_health if enabled else 0
	broken = not enabled
	visible = enabled
	collision_layer = 1 if enabled else 0
	hit_flash = 0
	refresh()

func wall_rect() -> Rect2:
	return Rect2(global_position - size / 2, size)

func take_hit() -> void:
	take_shell_hit(1)

func take_shell_hit(damage: int) -> void:
	if broken or not is_instance_valid(arena) or arena.region() != get_parent() or not arena.active or arena.paused or arena.stage_ready_time > 0:
		return
	health = maxi(0, health - maxi(1, damage))
	hit_flash = 0.15
	queue_redraw()
	if health == 0:
		broken = true
		collision_layer = 0
		hide()
		breached.emit(self)

func _process(delta: float) -> void:
	if hit_flash > 0 and (not is_instance_valid(arena) or not arena.paused):
		hit_flash = maxf(0, hit_flash - delta)
		queue_redraw()

func _draw() -> void:
	var rect := Rect2(-size / 2, size)
	var metal := Color("687b84") if hit_flash <= 0 else Color("dbe3cc")
	draw_rect(rect, Color("17242e"))
	draw_rect(rect.grow(-4), metal)
	for y in range(int(-size.y / 2 + 10), int(size.y / 2 - 6), 25):
		draw_rect(Rect2(-size.x / 2 + 6, y, size.x - 12, 19), metal.darkened(0.25))
		draw_line(Vector2(-size.x / 2 + 6, y), Vector2(size.x / 2 - 6, y), Color("a9b5b6"), 2)
		for side in [-1, 1]:
			draw_line(Vector2(side * (size.x / 2 - 4), y - 3), Vector2(side * (size.x / 2 - 4), y + 9), Color("ffd575") if y % 2 == 0 else Color("29353b"), 4)
	draw_rect(Rect2(-size.x / 2, -42, size.x, 84), Color("303e45"))
	draw_line(Vector2(-size.x / 2 + 4, -35), Vector2(size.x / 2 - 4, 35), Color("ffd575"), 5)
	draw_line(Vector2(-size.x / 2 + 4, 35), Vector2(size.x / 2 - 4, -35), Color("ffd575"), 5)
	var damage := max_health - health
	for i in range(damage):
		var y := -size.y * 0.35 + i * size.y * 0.12
		draw_polyline(PackedVector2Array([Vector2(-size.x / 2 + 4, y), Vector2(4, y + 9), Vector2(-3, y + 17), Vector2(size.x / 2 - 4, y + 25)]), Color("14202b"), 2)
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(-56, -size.y / 2 - 26), "BLAST GATE", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("ffd575"))
	draw_rect(Rect2(-56, -size.y / 2 - 18, 112, 6), Color("17242e"))
	draw_rect(Rect2(-56, -size.y / 2 - 18, 112.0 * health / max_health, 6), Color("ff951a"))

func _get_configuration_warnings() -> PackedStringArray:
	if not is_zero_approx(rotation) or not scale.is_equal_approx(Vector2.ONE):
		return ["Keep Rotation at 0 and Scale at (1, 1). Resize the gate with Size."]
	return []
