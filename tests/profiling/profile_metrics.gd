extends RefCounted
## Optional timers used only by an instrumented, isolated profiling copy.

static var enabled := false
static var freeze_tank_art := false
static var suppress_enemy_idle_redraw := false
static var disable_tank_aa := false
static var render_once := false
static var entries: Dictionary = {}
static var stack: Array[Dictionary] = []
static var frame_entries: Dictionary = {}

static func begin(name: String) -> void:
	if enabled: stack.append({"name": name, "start": Time.get_ticks_usec(), "children": 0, "frame": Engine.get_process_frames()})

static func end() -> void:
	if not enabled: return
	var entry: Dictionary = stack.pop_back()
	var elapsed := Time.get_ticks_usec() - int(entry.start)
	var record: Dictionary = entries.get(entry.name, {"calls": 0, "inclusive_us": 0, "self_us": 0, "max_us": 0})
	record.calls += 1
	record.inclusive_us += elapsed
	record.self_us += maxi(0, elapsed - int(entry.children))
	record.max_us = maxi(record.max_us, elapsed)
	entries[entry.name] = record
	var frame: Dictionary = frame_entries.get(entry.frame, {})
	var per_frame: Dictionary = frame.get(entry.name, {"calls": 0, "inclusive_us": 0, "self_us": 0, "max_us": 0})
	per_frame.calls += 1
	per_frame.inclusive_us += elapsed
	per_frame.self_us += maxi(0, elapsed - int(entry.children))
	per_frame.max_us = maxi(per_frame.max_us, elapsed)
	frame[entry.name] = per_frame
	frame_entries[entry.frame] = frame
	if not stack.is_empty(): stack.back().children += elapsed

static func reset() -> void:
	entries.clear()
	stack.clear()
	frame_entries.clear()
