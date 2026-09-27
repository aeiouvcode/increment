extends SceneTree
func _init():
	var m = load("res://main.tscn").instantiate()
	root.add_child(m)
	await process_frame
	await process_frame
	m._begin({})
	await process_frame
	var s: Dictionary = m.sim.make_summary(8.0)
	m._on_day_end(s)
	await process_frame
	m._set_tab("plan")
	await process_frame
	await process_frame
	var labels: Array[String] = []
	for l in m.page.find_children("*", "Label", true, false):
		labels.append(l.text)
	assert(m.summary_open)
	assert("DAY COMPLETE" in labels)
	assert("Houston has your daily summary" in labels)
	assert(not "Nothing scheduled" in labels)
	assert(m.modal != null)
	print("summary card PASS: ", labels)
	m._close_modal()
	m.summary_open = false
	m.clock_held = true
	m.sim.next_day()
	m.sim.begin_next()
	await process_frame
	await process_frame
	labels.clear()
	for l in m.page.find_children("*", "Label", true, false):
		labels.append(l.text)
	assert(not "DAY COMPLETE" in labels)
	print("wake reset PASS")
	quit()
