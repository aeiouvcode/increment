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
	for i in 60:
		await process_frame
	assert(draws <= 1, "Stationary gauges should not draw each frame")
	var before: = draws
	g.sim.co2 = 4.01
	await process_frame
	await process_frame
	assert(draws > before, "CO2 warning threshold must redraw")
	before = draws
	g.sim.soc = 39.0
	await process_frame
	await process_frame
	assert(draws > before, "Battery warning threshold must redraw")
	before = draws
	g.sim.urine = 90.0
	await process_frame
	await process_frame
	assert(draws > before, "Urine warning threshold must redraw")
	before = draws
	g.sim.o2 = 22.3
	await process_frame
	await process_frame
	assert(draws > before, "Oxygen value must redraw")
	before = draws
	g.size = Vector2(420, 58)
	await process_frame
	await process_frame
	assert(draws > before, "Resize must redraw")
	print("gauge redraw PASS: stationary 60 frames <=1 draw; four changes and resize redraw")
	quit()
