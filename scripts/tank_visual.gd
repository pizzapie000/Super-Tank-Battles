extends Node2D
## Retained vector layers: transforms animate the gun without rebuilding its art.
const Art = preload("res://scripts/tank_art.gd")
const Atlas = preload("res://scripts/story/scenery_atlas.gd")
var paint := Color.WHITE
var phase := 0.0
var hull: Node2D
var treads: Node2D
var armor: Node2D
var turret: Node2D
var barrel: Node2D
var cap: Node2D

func _ready() -> void:
	hull = layer(self, "Hull", draw_hull)
	treads = layer(self, "Treads", draw_treads)
	armor = layer(self, "Armor", draw_armor)
	turret = Node2D.new()
	turret.name = "Turret"
	add_child(turret)
	layer(turret, "Ring", draw_ring)
	barrel = layer(turret, "Barrel", draw_barrel)
	cap = layer(turret, "Cap", draw_cap)

func layer(parent: Node, label: String, callback: Callable) -> Node2D:
	var canvas := Node2D.new()
	canvas.name = label
	parent.add_child(canvas)
	canvas.draw.connect(callback.bind(canvas))
	return canvas

func sync(tank) -> void:
	visible = tank.alive and tank.body_opacity > 0.01
	# self_modulate affects only the parent's own commands; mirror its carrier
	# flash onto these child layers so the whole tank still flashes together.
	modulate = tank.self_modulate
	turret.rotation = tank.turret_angle - tank.rotation if tank.separate_turret else 0.0
	barrel.position.x = -tank.recoil
	if paint != tank.tint:
		paint = tank.tint
		for canvas in [armor, barrel, cap]: canvas.queue_redraw()
	if phase != tank.tread_phase:
		phase = tank.tread_phase
		treads.queue_redraw()

func draw_hull(canvas: CanvasItem) -> void:
	if Atlas.draw(canvas, Atlas.tank_key("Hull")): return
	canvas.draw_circle(Vector2(2, 3), 22, Color(0, 0, 0, 0.22))
	Art.chassis(canvas, Vector2.ZERO)
	for side in [-1, 1]: Art.track_base(canvas, Vector2.ZERO, side)

func draw_treads(canvas: CanvasItem) -> void:
	for side in [-1, 1]: Art.track_treads(canvas, Vector2.ZERO, side, phase)

func draw_armor(canvas: CanvasItem) -> void:
	if Atlas.draw(canvas, Atlas.tank_key("Armor", paint)): return
	Art.armor(canvas, paint, Vector2.ZERO)

func draw_ring(canvas: CanvasItem) -> void:
	if Atlas.draw(canvas, Atlas.tank_key("Ring")): return
	Art.turret_ring(canvas, Vector2.ZERO)

func draw_barrel(canvas: CanvasItem) -> void:
	if Atlas.draw(canvas, Atlas.tank_key("Barrel", paint)): return
	Art.barrel(canvas, paint, Vector2.ZERO)

func draw_cap(canvas: CanvasItem) -> void:
	if Atlas.draw(canvas, Atlas.tank_key("Cap", paint)): return
	Art.turret_cap(canvas, paint, Vector2.ZERO)
