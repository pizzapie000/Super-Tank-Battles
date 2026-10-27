extends SceneTree
## -- image vector|atlas checkpoint /absolute/path.png; default checks edit fallback.
const Atlas = preload("res://scripts/story/scenery_atlas.gd")
var failures := 0

func _initialize() -> void:
	run.call_deferred()
	create_timer(45).timeout.connect(func(): push_error("Scenery atlas check timed out"); quit(1))

func check(value: bool, message: String) -> void:
	if value: return
	failures += 1
	push_error(message)

func run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() >= 4 and args[0] == "image":
		if args[1] == "vector": set_meta("scenery_vector", true)
		var viewport := SubViewport.new()
		viewport.size = Vector2i(1280, 880)
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(viewport)
		var world = load("res://scenes/story/StoryWorld.tscn").instantiate()
		var region = world.get_child(int(args[2]))
		world.remove_child(region)
		world.free()
		viewport.add_child(region)
		region.position = Vector2.ZERO
		viewport.canvas_transform = Transform2D(0, Vector2.ONE * 0.8, 0, Vector2.ZERO)
		for _frame in range(6): await process_frame
		RenderingServer.force_draw(false)
		check(viewport.get_texture().get_image().save_png(args[3]) == OK, "Scenery image must save")
		viewport.queue_free()
	else:
		var world = load("res://scenes/story/StoryWorld.tscn").instantiate()
		root.add_child(world)
		var covered := 0
		for node in world.find_children("*", "", true, false):
			if node.get_script() == null: continue
			var path: String = node.get_script().resource_path
			if path.ends_with("cover_tree.gd"):
				var before: Rect2 = node.wall_rect()
				for layer in ["crown", "shadow", "trunk"]:
					var key: String = node.Atlas.tree_key(layer, node.crown_radius, node.variation, node.scorched)
					check(not node.Atlas.lookup(node, key).is_empty(), "Every authored tree layer must have a cached texture")
				node.variation += 100000
				check(node.color.a > 0 and node.Atlas.lookup(node, node.Atlas.tree_key("crown", node.crown_radius, node.variation, node.scorched)).is_empty(), "New edited tree variants must fall back to procedural artwork")
				check(node.wall_rect() == before, "Visual cache changes must preserve trunk collision")
				covered += 1
			elif path.ends_with("environment_barricade.gd"):
				var before: Rect2 = node.wall_rect()
				check(not node.Atlas.lookup(node, node.Atlas.wall_key(node.environment, node.form, node.variation, node.size)).is_empty(), "Every authored barricade must have a cached texture")
				node.variation += 100000
				check(node.Atlas.lookup(node, node.Atlas.wall_key(node.environment, node.form, node.variation, node.size)).is_empty() and node.wall_rect() == before, "Edited barricades must retain vector fallback and collision")
				covered += 1
		check(covered > 0, "Authored trees and themed barricades must be checked")
		world.queue_free()
	for _frame in range(3): await process_frame
	if args.is_empty():
		check(Atlas.consumers.is_empty() and Atlas.pages.is_empty() and Atlas.resolved.is_empty() and not Atlas.loaded, "Leaving the last cached scene must release atlas textures and consumers")
	print("SCENERY ATLAS SMOKE: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)
