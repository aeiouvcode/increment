extends SceneTree
const Main = preload("res://tests/probe_main.gd")
func _init() -> void:
	call_deferred("run")
func run() -> void:
	var m = Main.new()
	root.add_child(m)
	await process_frame
	m._begin({})
	await process_frame
	m.header_calls = 0
	var started: = Time.get_ticks_usec()
	for i in 240:
		await process_frame
	print("HEADER_PROBE held=", m.clock_held, " frames=240 calls=", m.header_calls, " elapsed_us=", Time.get_ticks_usec() - started, " label=", m.lbl_clock.text)
	quit()
