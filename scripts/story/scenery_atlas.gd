@tool
extends RefCounted
## Generated textures replace static commands; unknown edited variants stay vector.
const MANIFEST = "res://assets/generated/scenery/atlas.json"
static var loaded := false
static var entries: Dictionary = {}
static var pages: Dictionary = {}
static var resolved: Dictionary = {}
static var consumers: Dictionary = {}

static func tree_key(layer: String, radius: float, variation: int, scorched: bool) -> String:
	if layer == "trunk": return "tree_trunk"
	if layer == "shadow": return "tree_shadow:%s" % radius
	return "tree_crown:%s:%d:%d" % [radius, variation, int(scorched)]

static func wall_key(environment: String, form: String, variation: int, size: Vector2) -> String:
	return JSON.stringify([environment, form, variation, size.x, size.y])

static func tank_key(part: String, paint: Color = Color.WHITE) -> String:
	if part in ["Hull", "Ring"]: return "tank:" + part
	return JSON.stringify(["tank", part, paint.r, paint.g, paint.b, paint.a])

static func lookup(canvas: CanvasItem, key: String) -> Dictionary:
	if Engine.is_editor_hint() or not canvas.is_inside_tree() or canvas.get_tree().has_meta("scenery_vector"):
		return {}
	if not loaded:
		loaded = true
		if FileAccess.file_exists(MANIFEST):
			var data = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
			if data is Dictionary and data.get("version") == 1: entries = data.get("entries", {})
	if not entries.has(key): return {}
	var id := canvas.get_instance_id()
	if not consumers.has(id):
		consumers[id] = true
		canvas.tree_exited.connect(release.bind(id), CONNECT_ONE_SHOT)
	if resolved.has(key): return resolved[key]
	var item: Dictionary = entries[key]
	var page: String = item.page
	if not pages.has(page): pages[page] = load("res://assets/generated/scenery/" + page)
	if pages[page] == null: return {}
	var result := {"texture": pages[page], "region": Rect2(item.region[0], item.region[1], item.region[2], item.region[3]),
		"bounds": Rect2(item.bounds[0], item.bounds[1], item.bounds[2], item.bounds[3])}
	resolved[key] = result
	return result

static func release(id: int) -> void:
	consumers.erase(id)
	if not consumers.is_empty(): return
	# Leaving the last cached scene releases texture memory while keeping normal
	# round/checkpoint changes warm when other scenery is still in the tree.
	resolved.clear()
	pages.clear()
	entries.clear()
	loaded = false

static func draw(canvas: CanvasItem, key: String) -> bool:
	var item := lookup(canvas, key)
	if item.is_empty(): return false
	canvas.draw_texture_rect_region(item.texture, item.bounds, item.region)
	return true
