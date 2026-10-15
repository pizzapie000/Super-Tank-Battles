extends RefCounted

# A finer grid than the old maze lets AI route around moved/resized scene walls.
# Clearance includes the tank's 18px collision radius and a small safety margin.
const BOARD := Rect2(64, 152, 1152, 512)
const STEP := 32
const CLEARANCE := 20.0
var points: Dictionary = {}
var links: Dictionary = {}
var walls: Array[Rect2] = []
var bounds: Rect2 = BOARD

func build(rectangles: Array[Rect2], region: Rect2 = BOARD) -> void:
	bounds = region
	walls = rectangles
	points.clear()
	links.clear()
	for y in range(int(ceil(bounds.size.y / STEP))):
		for x in range(int(ceil(bounds.size.x / STEP))):
			var cell := Vector2i(x, y)
			var point := bounds.position + Vector2(cell) * STEP + Vector2.ONE * STEP * 0.5
			if point_clear(point):
				points[cell] = point
	for cell in points:
		var neighbors: Array[Vector2i] = []
		for direction in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next: Vector2i = cell + direction
			if points.has(next) and segment_clear(points[cell], points[next]):
				neighbors.append(next)
		links[cell] = neighbors

func point_clear(point: Vector2) -> bool:
	if not bounds.grow(-CLEARANCE).has_point(point):
		return false
	for wall in walls:
		if wall.grow(CLEARANCE).has_point(point):
			return false
	return true

func segment_clear(from: Vector2, to: Vector2, clearance: float = CLEARANCE) -> bool:
	for wall in walls:
		var rect := wall.grow(clearance)
		# Slab intersection, including a zero-length segment and parallel edges.
		var low := 0.0
		var high := 1.0
		var delta := to - from
		for axis in range(2):
			if absf(delta[axis]) < 0.0001:
				if from[axis] < rect.position[axis] or from[axis] > rect.end[axis]:
					low = 2.0
					break
			else:
				var a: float = (rect.position[axis] - from[axis]) / delta[axis]
				var b: float = (rect.end[axis] - from[axis]) / delta[axis]
				low = maxf(low, minf(a, b))
				high = minf(high, maxf(a, b))
		if low <= high:
			return false
	return true

func closest_cell(point: Vector2) -> Vector2i:
	var closest := Vector2i(-1, -1)
	var best := INF
	var center := Vector2i(((point - bounds.position) / STEP - Vector2.ONE * 0.5).round())
	# The reconnect radius is three cells: inspect that neighborhood rather than
	# scanning the whole region for each member of a larger enemy squad.
	for y in range(center.y - 3, center.y + 4):
		for x in range(center.x - 3, center.x + 4):
			var cell := Vector2i(x, y)
			if not points.has(cell):
				continue
			var distance: float = point.distance_squared_to(points[cell])
			# Reconnect tanks touching cover using their actual collision radius.
			if distance < best and distance <= 96.0 * 96.0 and segment_clear(point, points[cell], 17.9):
				closest = cell
				best = distance
	return closest

func path(from: Vector2, to: Vector2) -> Array[Vector2]:
	var result: Array[Vector2] = []
	if point_clear(from) and point_clear(to) and segment_clear(from, to):
		result.append(to)
		return result
	var origin := closest_cell(from)
	var target := closest_cell(to)
	if not points.has(origin) or not points.has(target):
		return result
	var frontier: Array[Vector2i] = [origin]
	var previous: Dictionary = {origin: origin}
	var head := 0
	while head < frontier.size():
		var cell := frontier[head]
		head += 1
		if cell == target:
			break
		for next in links[cell]:
			if not previous.has(next):
				previous[next] = cell
				frontier.append(next)
	if not previous.has(target):
		return result
	var cursor := target
	result.append(to)
	while cursor != origin:
		result.push_front(points[cursor])
		cursor = previous[cursor]
	result.push_front(points[origin])
	# Skip redundant waypoints only when the full tank-width segment is clear.
	var anchor := from
	var simplified: Array[Vector2] = []
	while not result.is_empty():
		var index := result.size() - 1
		while index > 0 and not segment_clear(anchor, result[index]):
			index -= 1
		anchor = result[index]
		simplified.append(anchor)
		result = result.slice(index + 1)
	return simplified
