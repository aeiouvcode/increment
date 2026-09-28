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
	assert(m.lbl_clock.text == "06:00" and m.lbl_mission.text.contains("DAY 1"))
	m.header_calls = 0
	for i in 240:
		await process_frame
	assert(m.header_calls == 0, "Held clock must not rebuild header")
	m.sim.t += 1.0
	await process_frame
	assert(m.header_calls == 1 and m.lbl_clock.text == "06:01", "Clock minute must refresh once")
	m.clock_held = false
	await process_frame
	assert(m.header_calls == 2 and not m.lbl_orbit.text.contains("CLOCK STARTS"), "Clock release must refresh orbit")
	m.clock_held = true
	await process_frame
	assert(m.header_calls == 3 and m.lbl_orbit.text.contains("CLOCK STARTS"), "Clock hold must refresh orbit")
	m.sim.day = 2
	await process_frame
	assert(m.header_calls == 4 and m.lbl_mission.text.contains("DAY 2"), "Day transition must refresh mission")
	m.sim.t = 365.0
	await process_frame
	assert(m.header_calls == 5 and m.lbl_clock.text == "06:05", "Time jump must refresh clock")
	print("header refresh PASS: 0/240 held frames; minute, release, hold, day and time jump refresh")
	quit()
