extends SceneTree

# Preserve the engine and bundled-library notices alongside each exported app.
func _initialize() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() != 1:
		push_error("Expected a notice output path")
		quit(1)
		return
	var output := FileAccess.open(arguments[0], FileAccess.WRITE)
	if output == null:
		push_error("Could not create engine notices")
		quit(1)
		return
	output.store_string(JSON.stringify({"engine": Engine.get_license_text(), "copyrights": Engine.get_copyright_info(), "licenses": Engine.get_license_info()}, "\t"))
	output.close()
	quit()
