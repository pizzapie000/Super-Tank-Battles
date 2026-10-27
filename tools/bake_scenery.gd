extends SceneTree
## Run with a rendering driver: godot --path . --script res://tools/bake_scenery.gd
const Atlas = preload("res://scripts/story/scenery_atlas.gd")
const Art = preload("res://scripts/tank_art.gd")
const DEST := "res://assets/generated/scenery/"
const SCALE := 2.0
const PAGE := 4096
const PAD := 4

func _initialize() -> void:
	set_meta("scenery_vector", true)
	run.call_deferred()
	create_timer(180).timeout.connect(func(): push_error("Scenery baking timed out"); quit(1))

func run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Scenery baking needs a rendered Godot window, not --headless")
		quit(1)
		return
	var world = load("res://scenes/story/StoryWorld.tscn").instantiate()
	var jobs := {}
	for node in world.find_children("*", "", true, false):
		if node.get_script() == null: continue
		var path: String = node.get_script().resource_path
		if path.ends_with("cover_tree.gd"):
			var radius: float = node.crown_radius
			for layer in ["crown", "shadow", "trunk"]:
				var bounds := Rect2(-34, -24, 68, 84)
				if layer == "crown":
					var top := -45 - radius * 0.8 - 4
					bounds = Rect2(-radius * 1.05 - 4, top, radius * 2.1 + 8, maxf(-45 + radius * 0.8, -20 + radius * 0.65) + 4 - top)
				elif layer == "shadow":
					var reach := Vector2(radius + 10, (radius + 10) * 0.76)
					bounds = Rect2(Vector2(12, -12) - reach, reach * 2)
				jobs[Atlas.tree_key(layer, radius, node.variation, node.scorched)] = {"kind": "tree", "layer": layer, "radius": radius, "variation": node.variation, "scorched": node.scorched, "bounds": bounds}
		elif path.ends_with("environment_barricade.gd"):
			jobs[Atlas.wall_key(node.environment, node.form, node.variation, node.size)] = {"kind": "wall", "environment": node.environment, "form": node.form, "variation": node.variation, "size": node.size, "bounds": Rect2(Vector2(-10, -10), node.size + Vector2(20, 20))}
	world.free()
	var paints: Array[Color] = StorySession.COLORS.duplicate()
	for profile in EnemyProfiles.TYPES:
		var paint := Color(profile.color)
		if not paints.has(paint): paints.append(paint)
	for part in ["Hull", "Ring", "Armor", "Barrel", "Cap"]:
		var bounds: Rect2 = {"Hull": Rect2(-28, -26, 56, 54), "Ring": Rect2(-13, -13, 26, 26), "Armor": Rect2(-26, -17, 52, 34), "Barrel": Rect2(-10, -8, 44, 16), "Cap": Rect2(-12, -12, 26, 26)}[part]
		for paint in ([Color.WHITE] if part in ["Hull", "Ring"] else paints):
			jobs[Atlas.tank_key(part, paint)] = {"kind": "tank", "part": part, "paint": paint, "bounds": bounds}
	DirAccess.make_dir_recursive_absolute(DEST)
	var records: Array = []
	for key in jobs:
		var job: Dictionary = jobs[key]
		var bounds: Rect2 = job.bounds
		var extent := Vector2i((bounds.size * SCALE).ceil())
		if extent.x + PAD * 2 > PAGE or extent.y + PAD * 2 > PAGE: continue
		bounds.size = Vector2(extent) / SCALE
		var viewport := SubViewport.new()
		viewport.size = extent
		viewport.transparent_bg = true
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(viewport)
		var node: Node2D
		if job.kind == "tank":
			node = Node2D.new()
			node.draw.connect(draw_tank_part.bind(node, job.part, job.paint))
		else:
			node = load("res://scenes/story/props/CoverTree.tscn" if job.kind == "tree" else "res://scenes/story/props/ForestMasonry.tscn").instantiate()
		if job.kind == "tree":
			node.crown_radius = job.radius
			node.variation = job.variation
			node.scorched = job.scorched
		elif job.kind == "wall":
			node.size = job.size
			node.environment = job.environment
			node.form = job.form
			node.variation = job.variation
		viewport.add_child(node)
		viewport.canvas_transform = Transform2D(0, Vector2.ONE * SCALE, 0, -bounds.position * SCALE)
		if job.kind == "tree":
			node.get_node("Shadow").visible = job.layer == "shadow"
			node.get_node("Trunk").visible = job.layer == "trunk"
			if job.layer != "crown": node.self_modulate = Color.TRANSPARENT
		await process_frame
		RenderingServer.force_draw(false)
		var image := viewport.get_texture().get_image()
		image.convert(Image.FORMAT_RGBA8)
		# Transparent viewports return premultiplied colors. Store straight alpha
		# so ordinary CanvasItem tint/fade and shared 2D texture batching work.
		var pixels := image.get_data()
		for offset in range(0, pixels.size(), 4):
			var alpha := pixels[offset + 3]
			if alpha == 0 or alpha == 255: continue
			for channel in range(3): pixels[offset + channel] = mini(255, roundi(pixels[offset + channel] * 255.0 / alpha))
		image.set_data(extent.x, extent.y, false, Image.FORMAT_RGBA8, pixels)
		image.fix_alpha_edges()
		records.append({"key": key, "image": image, "bounds": bounds})
		viewport.free()
	records.sort_custom(func(a, b): return a.image.get_height() > b.image.get_height())
	var entries := {}
	var page := Image.create(PAGE, PAGE, false, Image.FORMAT_RGBA8)
	var page_index := 0
	var x := PAD
	var y := PAD
	var row_height := 0
	var texture_bytes := 0
	for record in records:
		var image: Image = record.image
		if x + image.get_width() + PAD > PAGE:
			x = PAD
			y += row_height + PAD * 2
			row_height = 0
		if y + image.get_height() + PAD > PAGE:
			texture_bytes += save_page(page, page_index, y + row_height + PAD)
			page_index += 1
			page = Image.create(PAGE, PAGE, false, Image.FORMAT_RGBA8)
			x = PAD
			y = PAD
			row_height = 0
		page.blit_rect(image, Rect2i(Vector2i.ZERO, image.get_size()), Vector2i(x, y))
		var bounds: Rect2 = record.bounds
		entries[record.key] = {"page": "atlas_%d.png" % page_index, "region": [x, y, image.get_width(), image.get_height()], "bounds": [bounds.position.x, bounds.position.y, bounds.size.x, bounds.size.y]}
		x += image.get_width() + PAD * 2
		row_height = maxi(row_height, image.get_height())
	texture_bytes += save_page(page, page_index, y + row_height + PAD)
	var file := FileAccess.open(DEST + "atlas.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"version": 1, "scale": SCALE, "texture_bytes": texture_bytes, "entries": entries}, "\t"))
	file.close()
	print("SCENERY ATLAS: ", entries.size(), " variants, ", page_index + 1, " pages, ", texture_bytes / 1048576.0, " MiB")
	quit()

func draw_tank_part(canvas: CanvasItem, part: String, paint: Color) -> void:
	match part:
		"Hull":
			canvas.draw_circle(Vector2(2, 3), 22, Color(0, 0, 0, 0.22))
			Art.chassis(canvas, Vector2.ZERO)
			for side in [-1, 1]: Art.track_base(canvas, Vector2.ZERO, side)
		"Ring": Art.turret_ring(canvas, Vector2.ZERO)
		"Armor": Art.armor(canvas, paint, Vector2.ZERO)
		"Barrel": Art.barrel(canvas, paint, Vector2.ZERO)
		"Cap": Art.turret_cap(canvas, paint, Vector2.ZERO)

func save_page(image: Image, index: int, used_height: int) -> int:
	var cropped := image.get_region(Rect2i(0, 0, PAGE, mini(PAGE, used_height)))
	if cropped.save_png(DEST + "atlas_%d.png" % index) != OK:
		push_error("Could not write scenery atlas")
		quit(1)
	return cropped.get_width() * cropped.get_height() * 4
