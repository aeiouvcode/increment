extends SceneTree
func _init():
	var m = load("res://main.tscn").instantiate()
	root.add_child(m)
	await process_frame
	await process_frame
	m._begin({})
	for i in 30: await process_frame
	m._on_do()
	for i in 30: await process_frame
	print("started ", m.started, " t ", m.sim.t, " cur ", m.sim.current().get("id", "-"), " running ", m.sim.current().get("running", false))
	var ev = {"id": "cdra", "fired": true}
	m.sim._raise(ev)
	await process_frame
	print("modal ", m.modal != null)
	quit()
