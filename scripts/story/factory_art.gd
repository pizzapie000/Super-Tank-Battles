@tool
extends RefCounted

static func conveyor(canvas: CanvasItem, rect: Rect2, time: float) -> void:
	var p := rect.position
	var s := rect.size
	canvas.draw_rect(Rect2(p + Vector2(5, 9), s), Color(0, 0, 0, 0.35))
	canvas.draw_rect(rect, Color("14232c"))
	canvas.draw_rect(rect.grow(-5), Color("75848a"))
	var deck := Rect2(p + Vector2(18, 23), s - Vector2(36, 46))
	canvas.draw_rect(deck, Color("23323b"))
	# Moving interlocked steel slats and end drums.
	var pitch := 22.0
	var phase := fmod(time * 26, pitch)
	for i in range(int(deck.size.x / pitch) + 1):
		var x := deck.position.x + fmod(i * pitch + phase, deck.size.x - 2)
		var width := minf(16, deck.end.x - x)
		canvas.draw_rect(Rect2(x, deck.position.y + 3, width, deck.size.y - 6), Color("45565e"))
		canvas.draw_line(Vector2(x + 1, deck.position.y + 4), Vector2(x + 1, deck.end.y - 4), Color("849ba2"), 1.5)
	for x in [deck.position.x - 7, deck.end.x + 7]:
		canvas.draw_rect(Rect2(x - 5, p.y + 18, 10, s.y - 36), Color("33464f"))
		canvas.draw_line(Vector2(x - 2, p.y + 21), Vector2(x - 2, p.y + s.y - 21), Color("d1d9d8"), 3)
	for y in [p.y + 8, p.y + s.y - 16]:
		canvas.draw_rect(Rect2(p.x + 10, y, s.x - 20, 8), Color("18242b"))
		for x in range(15, int(s.x) - 15, 32):
			canvas.draw_line(Vector2(p.x + x, y + 1), Vector2(p.x + x + 12, y + 6), Color("ebbd51"), 5)
		for x in [p.x + 6, p.x + s.x - 7]:
			canvas.draw_circle(Vector2(x, y + 4), 2.5, Color("d9e1dd"))
	# Bolted corner mounts and a motor/control housing at the lower edge.
	for x in [p.x + 7, p.x + s.x - 21]:
		for y in [p.y + 3, p.y + s.y - 13]:
			canvas.draw_rect(Rect2(x, y, 14, 10), Color("b2c1c3"))
			canvas.draw_circle(Vector2(x + 7, y + 5), 2, Color("34444d"))
	canvas.draw_rect(Rect2(p.x + s.x * 0.72, p.y + s.y - 1, 50, 16), Color("35505c"))
	for x in range(5):
		canvas.draw_line(Vector2(p.x + s.x * 0.72 + 5 + x * 7, p.y + s.y + 1), Vector2(p.x + s.x * 0.72 + 5 + x * 7, p.y + s.y + 12), Color("829ea8"), 2)
	canvas.draw_circle(Vector2(p.x + 31, p.y + s.y - 12), 3, Color("7ef4c0"))
	# Direction marks stay readable over the moving deck.
	for x in [0.3, 0.6]:
		var at := deck.position + Vector2(deck.size.x * x, deck.size.y * 0.5)
		canvas.draw_polyline(PackedVector2Array([at + Vector2(-7, -7), at + Vector2(3, 0), at + Vector2(-7, 7)]), Color(0.7, 0.85, 0.86, 0.25), 2)

static func technician(canvas: CanvasItem, at: Vector2, time: float, fleeing: bool = false, startled: bool = false) -> void:
	canvas.draw_circle(at + Vector2(2, 15), 11, Color(0, 0, 0, 0.25))
	var stride := sin(time * 21) * 8 if fleeing else 0.0
	for x in [-4, 4]:
		var foot := at + Vector2(x + stride * signf(x), 23 - absf(stride) * 0.25)
		canvas.draw_line(at + Vector2(x, 10), foot, Color("1c2e39"), 5)
		canvas.draw_rect(Rect2(foot - Vector2(3, 3), Vector2(7, 5)), Color("111f29"))
	canvas.draw_rect(Rect2(at - Vector2(7, 7), Vector2(14, 20)), Color("83afbc"))
	canvas.draw_rect(Rect2(at + Vector2(-5, 2), Vector2(10, 8)), Color("355267"))
	canvas.draw_circle(at - Vector2(0, 15), 7, Color("e2bc91"))
	canvas.draw_arc(at - Vector2(0, 16), 7, PI, TAU, 16, Color("f0cf66"), 4)
	canvas.draw_line(at + Vector2(-8, -16), at + Vector2(8, -16), Color("e3b24c"), 2)
	if fleeing or startled:
		canvas.draw_line(at + Vector2(-6, -3), at + Vector2(-17, -17 + stride * 0.4), Color("e2bc91"), 4)
		canvas.draw_line(at + Vector2(6, -3), at + Vector2(16, -19 - stride * 0.4), Color("e2bc91"), 4)
		for x in [-3, 3]:
			canvas.draw_circle(at + Vector2(x, -16), 1.6, Color("fff4d7"))
			canvas.draw_circle(at + Vector2(x - 0.5, -16), 0.8, Color("25313a"))
		canvas.draw_circle(at + Vector2(0, -11), 2, Color("4f392f"))
		canvas.draw_circle(at + Vector2(0, -36), 8, Color("ffdf85"))
		canvas.draw_line(at + Vector2(0, -41), at + Vector2(0, -36), Color("3d3e32"), 2)
		canvas.draw_circle(at + Vector2(0, -32), 1, Color("3d3e32"))
	else:
		var hand := at + Vector2(20, -6 + sin(time * 6) * 4)
		canvas.draw_line(at + Vector2(6, -3), hand, Color("e2bc91"), 4)
		canvas.draw_rect(Rect2(hand - Vector2(3, 2), Vector2(7, 5)), Color("eef2dc"))
