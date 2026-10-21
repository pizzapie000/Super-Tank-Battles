extends SceneTree

const Controls = preload("res://scripts/input/controller_input.gd")
var failures := 0

func _initialize() -> void:
	run.call_deferred()
	create_timer(25).timeout.connect(func(): push_error("Wii bridge launch check timed out"); quit(1))

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func run() -> void:
	var wii: Node = Controls.bridge()
	if wii.listen_port == 0:
		push_error("Wii bridge launch checks require permission to bind a local UDP socket.")
		quit(1)
		return
	check(wii.launch_bridge(true) == OK, "The game must launch the bridge app through macOS")
	var session_token: String = wii.token
	check(wii.launch_bridge(true) == OK and wii.token == session_token, "Repeated Start clicks must keep the same pending launch")
	var deadline := Time.get_ticks_msec() + 15000
	while wii.bridge_starting and Time.get_ticks_msec() < deadline:
		await process_frame
	var owned_pid: int = wii.bridge_pid
	check(owned_pid > 0 and not wii.bridge_starting, "The native app must send its actual PID in an authenticated heartbeat")
	if owned_pid > 0:
		check(owned_pid != OS.get_process_id() and wii.bridge_is_running(), "The tracked PID must belong to the live bridge app")
		check(wii.launch_bridge(true) == OK and wii.bridge_pid == owned_pid and wii.token == session_token, "Starting a connected bridge must not spawn another app")
	var reopened := false
	while Time.get_ticks_msec() < deadline:
		if wii.status == "Window reopen checks: 20/20": reopened = true
		if reopened and wii.bridge_pid == -1: break
		await process_frame
	check(reopened, "The actual bridge window must survive twenty close and reopen cycles")
	check(wii.bridge_pid == -1 and wii.status.contains("closed"), "A bridge that quits must release its PID and offer a retry")
	check(wii.launch_bridge(true) == OK and wii.token != session_token, "Retry after quitting must start a fresh session")
	deadline = Time.get_ticks_msec() + 5000
	while wii.bridge_starting and Time.get_ticks_msec() < deadline:
		await process_frame
	owned_pid = wii.bridge_pid
	check(owned_pid > 0, "The bridge must reconnect after a retry")
	# Exercise the same cleanup used when the game exits, without ending the test yet.
	wii._exit_tree()
	wii.set_process(false)
	await create_timer(0.2).timeout
	check(owned_pid <= 0 or not wii.bridge_is_running(), "Game cleanup must stop only its launched bridge")
	wii.bridge_pid = -1
	print("Wii bridge launch checks: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)
