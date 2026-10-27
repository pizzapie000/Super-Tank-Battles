extends RefCounted

const MineAwareness = preload("res://scripts/enemy_mine_awareness.gd")
# A finer grid than the old maze lets AI route around moved/resized scene walls.
# Clearance includes the tank's 18px collision radius and a small safety margin.
const BOARD := Rect2(64, 152, 1152, 512)
const STEP := 32
const CLEARANCE := 20.0
var points: Dictionary = {}
var links: Dictionary = {}
var walls: Array[Rect2] = []
var bounds: Rect2 = BOARD
var graph := AStar2D.new()
var cell_ids: Dictionary = {}
var components: Dictionary = {}

class DynamicGraph extends AStar2D:
	const Awareness = preload("res://scripts/enemy_mine_awareness.gd")
	var coordinates: Array[Vector2i] = []
	var locations: Array[Vector2] = []
	var hazards: Array[Vector3] = []
	var node_safe: Dictionary = {}
	var edge_safe: Dictionary = {}
	var weighted: Array[int] = []
	var cell_step := 1.0
	func _estimate_cost(from_id: int, end_id: int) -> float:
		var delta := coordinates[from_id] - coordinates[end_id]
		return (absi(delta.x) + absi(delta.y)) * cell_step

	func _filter_neighbor(from_id: int, to_id: int) -> bool:
		if not node_safe.has(to_id): node_safe[to_id] = Awareness.point_clear(locations[to_id], hazards)
		if not node_safe[to_id]: return true
		var edge := mini(from_id, to_id) * locations.size() + maxi(from_id, to_id)
		if not edge_safe.has(edge): edge_safe[edge] = Awareness.segment_clear(locations[from_id], locations[to_id], hazards)
		return not edge_safe[edge]

var dynamic_graph := DynamicGraph.new()

func build(rectangles: Array[Rect2], region: Rect2 = BOARD) -> void:
	bounds = region
	walls = rectangles
	points.clear()
	links.clear()
	graph.clear()
	dynamic_graph.clear()
	dynamic_graph.cell_step = STEP
	dynamic_graph.coordinates.clear()
	dynamic_graph.locations.clear()
	dynamic_graph.weighted.clear()
	cell_ids.clear()
	components.clear()
	for y in range(int(ceil(bounds.size.y / STEP))):
		for x in range(int(ceil(bounds.size.x / STEP))):
			var cell := Vector2i(x, y)
			var point := bounds.position + Vector2(cell) * STEP + Vector2.ONE * STEP * 0.5
			if point_clear(point):
				points[cell] = point
				cell_ids[cell] = graph.get_point_count()
				graph.add_point(cell_ids[cell], point)
				dynamic_graph.add_point(cell_ids[cell], point)
				dynamic_graph.coordinates.append(cell)
				dynamic_graph.locations.append(point)
	for cell in points:
		var neighbors: Array[Vector2i] = []
		for direction in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next: Vector2i = cell + direction
			if points.has(next) and segment_clear(points[cell], points[next]):
				neighbors.append(next)
				graph.connect_points(cell_ids[cell], cell_ids[next], false)
				dynamic_graph.connect_points(cell_ids[cell], cell_ids[next], false)
		links[cell] = neighbors
	# Cover/flank selection only needs connectivity, not a complete route for
	# every candidate. Rebuild labels along with the graph when cover changes.
	for start in points:
		if components.has(start): continue
		var queue: Array[Vector2i] = [start]
		var head := 0
		components[start] = cell_ids[start]
		while head < queue.size():
			var cell := queue[head]
			head += 1
			for next in links[cell]:
				if components.has(next): continue
				components[next] = components[start]
				queue.append(next)

func point_clear(point: Vector2) -> bool:
	if not bounds.grow(-CLEARANCE).has_point(point):
		return false
	for wall in walls:
		if point.distance_squared_to(point.clamp(wall.position, wall.end)) <= CLEARANCE * CLEARANCE:
			return false
	return true

func segment_clear(from: Vector2, to: Vector2, clearance: float = CLEARANCE) -> bool:
	# Most steering/reconnection checks are only a few pixels long. Cull walls
	# outside the swept body's bounds before doing the exact rounded-corner test.
	var swept := Rect2(from, to - from).abs().grow(maxf(0, clearance) + 0.001)
	for wall in walls:
		if not swept.intersects(wall, true): continue
		if not segment_hits_rect(from, to, wall.grow(clearance)):
			continue
		# Tank bodies are circles: padding a rectangle with square corners can
		# trap a legal physics position inside an imaginary navigation obstacle.
		if clearance <= 0 or segment_hits_rect(from, to, wall):
			return false
		var radius_squared := clearance * clearance
		if from.distance_squared_to(from.clamp(wall.position, wall.end)) <= radius_squared or to.distance_squared_to(to.clamp(wall.position, wall.end)) <= radius_squared:
			return false
		for corner in [wall.position, Vector2(wall.end.x, wall.position.y), wall.end, Vector2(wall.position.x, wall.end.y)]:
			var closest := Geometry2D.get_closest_point_to_segment(corner, from, to)
			if closest.distance_squared_to(corner) <= radius_squared:
				return false
	return true

static func segment_hits_rect(from: Vector2, to: Vector2, rect: Rect2) -> bool:
	# Slab intersection, including a zero-length segment and parallel edges.
	var low := 0.0
	var high := 1.0
	var delta := to - from
	for axis in range(2):
		if absf(delta[axis]) < 0.0001:
			if from[axis] < rect.position[axis] or from[axis] > rect.end[axis]:
				return false
		else:
			var a: float = (rect.position[axis] - from[axis]) / delta[axis]
			var b: float = (rect.end[axis] - from[axis]) / delta[axis]
			low = maxf(low, minf(a, b))
			high = minf(high, maxf(a, b))
	return low <= high

func closest_cell(point: Vector2, hazards: Array[Vector3] = []) -> Vector2i:
	var closest := Vector2i(-1, -1)
	var best := INF
	var center := Vector2i(((point - bounds.position) / STEP - Vector2.ONE * 0.5).round())
	# The rounded grid cell is already the nearest possible point. Most tanks
	# can reconnect here without testing every cell in the surrounding square.
	if points.has(center) and MineAwareness.point_clear(points[center], hazards) and segment_clear(point, points[center], 17.9) and MineAwareness.segment_clear(point, points[center], hazards):
		return center
	# Inspect nearby cells rather than scanning the whole region. Widen the
	# search when reconnecting a tank or target surrounded by a newly laid mine.
	var reach := 5 if not hazards.is_empty() else 3
	for y in range(center.y - reach, center.y + reach + 1):
		for x in range(center.x - reach, center.x + reach + 1):
			var cell := Vector2i(x, y)
			if not points.has(cell) or not MineAwareness.point_clear(points[cell], hazards):
				continue
			var distance: float = point.distance_squared_to(points[cell])
			# Reconnect tanks touching cover using their actual collision radius.
			if distance < best and distance <= pow(reach * STEP, 2) and segment_clear(point, points[cell], 17.9) and MineAwareness.segment_clear(point, points[cell], hazards):
				closest = cell
				best = distance
	return closest

func can_reach(from: Vector2, to: Vector2) -> bool:
	var origin := closest_cell(from)
	var target := closest_cell(to)
	if components.has(origin) and components.has(target) and components[origin] == components[target]:
		return true
	# A direct, tank-width connection can also pass a gap finer than the grid.
	return point_clear(from) and point_clear(to) and segment_clear(from, to)

static func heap_push(heap: Array[Array], entry: Array) -> void:
	var index := heap.size()
	heap.append(entry)
	while index > 0:
		var parent := (index - 1) / 2
		if heap[parent][2] <= entry[2]: break
		heap[index] = heap[parent]
		index = parent
	heap[index] = entry

static func heap_pop(heap: Array[Array]) -> Array:
	var first: Array = heap[0]
	var last: Array = heap.pop_back()
	if heap.is_empty(): return first
	var index := 0
	while index * 2 + 1 < heap.size():
		var child := index * 2 + 1
		if child + 1 < heap.size() and heap[child + 1][2] < heap[child][2]:
			child += 1
		if last[2] <= heap[child][2]: break
		heap[index] = heap[child]
		index = child
	heap[index] = last
	return first

func grid_path(origin: Vector2i, target: Vector2i, hazards: Array[Vector3], traffic: Array[Vector3]) -> Array[Vector2]:
	var result: Array[Vector2] = []
	if hazards.is_empty() and traffic.is_empty():
		# The static graph is searched in native code. Dynamic mines and crowd
		# preferences use the same links with per-request costs below.
		result.assign(graph.get_point_path(cell_ids[origin], cell_ids[target]))
		return result
	# Native A* owns the queue/search. Set the same per-destination traffic
	# costs, retaining dynamic mine filtering and the Manhattan lower bound.
	for id in dynamic_graph.weighted: dynamic_graph.set_point_weight_scale(id, 1.0)
	dynamic_graph.weighted.clear()
	var pressure := {}
	for zone in traffic:
		var center := Vector2(zone.x, zone.y)
		var radius := maxf(1, zone.z)
		var reach := Vector2.ONE * (radius + 0.001)
		var low := Vector2i(((center - reach - bounds.position) / STEP - Vector2.ONE * 0.5).ceil())
		var high := Vector2i(((center + reach - bounds.position) / STEP - Vector2.ONE * 0.5).floor())
		low = low.max(Vector2i.ZERO)
		high = high.min(Vector2i(ceili(bounds.size.x / STEP) - 1, ceili(bounds.size.y / STEP) - 1))
		for y in range(low.y, high.y + 1):
			for x in range(low.x, high.x + 1):
				var cell := Vector2i(x, y)
				if not points.has(cell): continue
				var contribution := maxf(0, 1 - points[cell].distance_to(center) / radius)
				if contribution > 0:
					var id: int = cell_ids[cell]
					pressure[id] = pressure.get(id, 0.0) + contribution
	for id in pressure:
		dynamic_graph.set_point_weight_scale(id, 1 + minf(pressure[id], 3) * 3)
		dynamic_graph.weighted.append(id)
	dynamic_graph.hazards = hazards
	dynamic_graph.node_safe.clear()
	dynamic_graph.edge_safe.clear()
	dynamic_graph.neighbor_filter_enabled = not hazards.is_empty()
	result.assign(dynamic_graph.get_point_path(cell_ids[origin], cell_ids[target]))
	dynamic_graph.hazards = []
	return result

func path(from: Vector2, to: Vector2, hazards: Array[Vector3] = [], traffic: Array[Vector3] = []) -> Array[Vector2]:
	var result: Array[Vector2] = []
	if traffic.is_empty() and point_clear(from) and point_clear(to) and segment_clear(from, to) and MineAwareness.segment_clear(from, to, hazards) and MineAwareness.point_clear(to, hazards):
		result.append(to)
		return result
	var origin := closest_cell(from, hazards)
	var target := closest_cell(to, hazards)
	if not points.has(origin) or not points.has(target):
		return result
	if components[origin] != components[target]: return result
	result = grid_path(origin, target, hazards, traffic)
	if result.is_empty(): return result
	result.append(to if MineAwareness.point_clear(to, hazards) and MineAwareness.segment_clear(points[target], to, hazards) else points[target])
	# Skip redundant waypoints only when the full tank-width segment is clear.
	var anchor := from
	var simplified: Array[Vector2] = []
	# Every simplification anchor is an existing waypoint. Compute the original
	# traffic cost once, then use prefix differences for each remaining suffix.
	var prefix_costs: Array[float] = [0.0]
	if not traffic.is_empty():
		var last := anchor
		var total := 0.0
		for point in result:
			total += route_cost(last, point, traffic)
			prefix_costs.append(total)
			last = point
	var consumed := 0
	while not result.is_empty():
		var index := result.size() - 1
		while index > 0 and (not segment_clear(anchor, result[index]) or not MineAwareness.segment_clear(anchor, result[index], hazards) or (not traffic.is_empty() and route_cost(anchor, result[index], traffic) > (prefix_costs[consumed + index + 1] - prefix_costs[consumed]) * 1.05)):
			index -= 1
		anchor = result[index]
		simplified.append(anchor)
		consumed += index + 1
		result = result.slice(index + 1)
	return simplified

func congestion(at: Vector2, traffic: Array[Vector3]) -> float:
	var pressure := 0.0
	for zone in traffic:
		pressure += maxf(0, 1 - at.distance_to(Vector2(zone.x, zone.y)) / maxf(1, zone.z))
	return minf(pressure, 3) * 3

func route_cost(from: Vector2, to: Vector2, traffic: Array[Vector3]) -> float:
	var distance := from.distance_to(to)
	# A traffic circle that never reaches this segment cannot contribute at
	# any sample. Reject it once instead of repeating it at every 16px step.
	var nearby: Array[Vector3] = []
	for zone in traffic:
		var center := Vector2(zone.x, zone.y)
		var radius := maxf(1, zone.z) + 0.001
		if center.distance_squared_to(Geometry2D.get_closest_point_to_segment(center, from, to)) <= radius * radius:
			nearby.append(zone)
	if nearby.is_empty(): return distance
	var steps := maxi(1, ceili(distance / 16))
	var pressure := 0.0
	for i in range(steps):
		pressure += congestion(from.lerp(to, (i + 0.5) / steps), nearby)
	return distance * (1 + pressure / steps)
