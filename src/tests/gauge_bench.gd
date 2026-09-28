extends SceneTree
const Sim = preload("res://sim.gd")
const Gauges = preload("res://gauges.gd")
var draws: = 0
func _init() -> void:
	call_deferred("run")
func run() -> void:
	var g: = Gauges.new()
	g.sim = Sim.new()
	g.mono = load("res://fonts/IBMPlexMono-Medium.ttf")
	g.size = Vector2(390, 58)
	g.draw.connect(func(): draws += 1)
	root.add_child(g)
	await process_frame
	draws = 0
	var started: = Time.get_ticks_usec()
	for i in 240:
		if OS.get_environment("GAUGE_DYNAMIC") == "1":
			g.sim.co2 += 0.001
			g.sim.o2 += 0.0001
		await process_frame
	var elapsed: = Time.get_ticks_usec() - started
	print("GAUGE_BENCH dynamic=", OS.get_environment("GAUGE_DYNAMIC"), " frames=240 draws=", draws, " elapsed_us=", elapsed)
	quit()
