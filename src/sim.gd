extends RefCounted


signal event_raised(ev: Dictionary)
signal day_ended(summary: Dictionary)
signal ground_call(text: String)
signal activity_finished(act: Dictionary)

const WAKE: = 360.0
const SLEEP_AT: = 1290.0
const ORBIT: = 92.6
const SUNLIT: = 56.8
const DAYS_TOTAL: = 5
const GMT_DAY0: = 268

var day: = 1
var t: = WAKE
var sleeping: = false
var sleep_started: = 0.0
var finished: = false


var co2: = 2.3
var o2: = 21.2
var water: = 418.0
var urine: = 22.0
var soc: = 91.0
var cdra: = "nominal"
var cdra_fail_at: = -1.0
var ground_fix_at: = -1.0
var upa: = "nominal"
var edv_next: = -1.0


var fatigue: = 10.0
var fitness: = 100.0
var morale: = 74.0

var timeline: Array = []
var events: Array = []
var deadline: = {}
var co2_hist: Array = []
var hist_timer: = 0.0
var rng: = RandomNumberGenerator.new()
var today: = {}
var totals: = {"science": 0, "photos": 0, "ontime": 0, "planned": 0, "exercise": 0, "anomalies": 0, "violations": 0}

const SCIENCE: = [
	{"title": "Plant Habitat · lettuce harvest", "loc": "lab", "where": "Lab · Plant Habitat rack", "steps": [
		["Open the habitat, photograph the canopy", 2], ["Harvest four plants into sample bags", 5], ["Freeze samples in MELFI at -80 C", 2], ["Wipe the chamber, close and log", 2]]}, 
	{"title": "Ultrasound · eye and vein scan", "loc": "lab", "where": "Lab · Human Research Facility", "steps": [
		["Set up ultrasound, gel the probe", 2], ["Remote-guided scan with the ground team", 5], ["Downlink images, stow probe", 2]]}, 
	{"title": "Blood draw · centrifuge and freeze", "loc": "lab", "where": "Lab · HRF rack", "steps": [
		["Gather kit, label tubes by barcode", 2], ["Draw blood from a crewmate", 3], ["Spin tubes in the centrifuge", 3], ["Freeze at -80 C, update the log", 2]]}, 
	{"title": "Protein crystal growth", "loc": "lab", "where": "Lab · microgravity glovebox", "steps": [
		["Power up the glovebox, check airflow", 2], ["Activate 24 crystal wells", 5], ["Inspect wells under the microscope", 3], ["Close out, photo documentation", 2]]}, 
	{"title": "Fluid physics · capillary flow", "loc": "lab", "where": "Lab · Fluids rack", "steps": [
		["Install test cell in the chamber", 3], ["Run six fill cycles, watch the meniscus", 5], ["Drain, swap cell, second run", 4], ["Downlink video", 1]]}, 
]
const MAINT: = [
	{"title": "WHC pretreat tank change", "loc": "whc", "where": "Node 3 · toilet (WHC)", "steps": [
		["Don gloves and goggles", 1], ["Isolate the pretreat line", 2], ["Swap the tank, check seals", 4], ["Leak check, log the new tank", 2]]}, 
	{"title": "Clean ventilation screens", "loc": "lab", "where": "Lab · IMV screens", "steps": [
		["Vacuum Lab inlet screens", 3], ["Vacuum Node 1 and Node 3 screens", 4], ["Photo the screens, report dust", 1]]}, 
	{"title": "Stowage audit (IMS)", "loc": "galley", "where": "Node 1 · stowage bags", "steps": [
		["Pull bags from the zenith rack", 3], ["Barcode-scan every item", 5], ["Restow and update IMS", 3]]}, 
	{"title": "Smoke detector inspection", "loc": "lab", "where": "Lab · Node 1 detectors", "steps": [
		["Remove detector covers", 2], ["Vacuum the sensor ports", 3], ["Run the self-test with the ground", 2]]}, 
]
const PAYLOAD: = [
	{"title": "Cell culture · media change", "loc": "lab", "where": "Lab · incubator", "steps": [
		["Warm media, prep the bags", 2], ["Change media in eight wells", 5], ["Return cultures to 37 C", 2]]}, 
	{"title": "Combustion chamber · flame test", "loc": "lab", "where": "Lab · Combustion rack", "steps": [
		["Install fuel sample", 3], ["Ignite and record the spherical flame", 4], ["Vent chamber, swap sample", 3]]}, 
	{"title": "Robotic arm training", "loc": "cupola", "where": "Cupola · robotics workstation", "steps": [
		["Boot the robotics trainer", 2], ["Fly two capture approaches", 5], ["Debrief with the ground", 2]]}, 
]
const CEO_TARGETS: = ["Richat Structure, Mauritania", "Great Barrier Reef, Australia", "Aconcagua, Andes", "Great Bahama Bank", "Lake Baikal, Siberia"]

func _init() -> void :
	rng.seed = 74

func gmt_day() -> int:
	return GMT_DAY0 + day - 1

func total_minutes() -> float:
	return (day - 1) * 1440.0 + t

func orbit_phase() -> float:
	return fmod(total_minutes() + 20.0, ORBIT)

func sunlit() -> bool:
	return orbit_phase() < SUNLIT

func minutes_to_terminator() -> float:
	var p: = orbit_phase()
	return SUNLIT - p if p < SUNLIT else ORBIT - p

func step_mult() -> float:
	var m: = 1.0 + maxf(0.0, fatigue - 55.0) / 90.0
	if co2 > 3.0:
		m += 0.12
	return m



func _steps(defs: Array, slot: float) -> Array:
	var w: = 0.0
	for d in defs:
		w += float(d[1])
	var out: Array = []
	for d in defs:
		out.append({"t": d[0], "m": maxf(1.0, round(float(d[1]) / w * slot * 0.9)), "done": false})
	return out

func _act(id: String, title: String, where: String, kind: String, loc: String, start: float, dur: float, steps: Array, tag: String) -> Dictionary:
	return {"id": id, "title": title, "where": where, "kind": kind, "loc": loc, "start": start, "dur": dur, 
		"steps": _steps(steps, dur) if kind != "sleep" else [{"t": steps[0][0], "m": 0.0, "done": false}], 
		"state": "planned", "si": 0, "running": false, "left": 0.0, "tag": tag, "urgent": false, "late": 0.0}

func start_day() -> void :
	rng.seed = 7400 + day
	t = WAKE
	sleeping = false
	deadline = {}
	var sci_a: Dictionary = SCIENCE[(day - 1) % SCIENCE.size()]
	var sci_b: Dictionary = SCIENCE[(day + 1) % SCIENCE.size()]
	var mt: Dictionary = MAINT[(day - 1) % MAINT.size()]
	var pl: Dictionary = PAYLOAD[(day - 1) % PAYLOAD.size()]
	var target: String = CEO_TARGETS[(day - 1) % CEO_TARGETS.size()]
	timeline = [
		_act("wake", "Wake · morning check", "Crew quarters", "routine", "cq", 360, 10, [["Read the Daily Summary from Houston", 1]], "ROUTINE"), 
		_act("post", "Post-sleep · breakfast", "Node 1 · galley", "meal", "galley", 370, 80, [["Wash up at the hygiene station", 3], ["Breakfast, rehydrate the oatmeal", 4], ["Prep for work, check today's plan", 2]], "ROUTINE"), 
		_act("dpc", "Daily Planning Conference", "Lab · Space-to-Ground 2", "conf", "lab", 450, 15, [["Join the DPC with Houston, Huntsville, Moscow", 1]], "CONF"), 
		_act("sci1", sci_a.title, sci_a.where, "science", sci_a.loc, 465, 135, sci_a.steps, "SCIENCE"), 
		_act("ex1", "Exercise · ARED resistive", "Node 3 · ARED", "exercise", "ared", 600, 75, [["Set up ARED, set the bar load", 1], ["Squats, deadlifts, heel raises", 6], ["Wipe down, stow the bar", 1]], "EXERCISE"), 
		_act("mnt", mt.title, mt.where, "maint", mt.loc, 675, 75, mt.steps, "MAINT"), 
		_act("lunch", "Lunch", "Node 1 · galley", "meal", "galley", 750, 60, [["Lunch with the crew", 1]], "ROUTINE"), 
		_act("sci2", sci_b.title, sci_b.where, "science", sci_b.loc, 810, 105, sci_b.steps, "SCIENCE"), 
		_act("ceo", "Earth photo · " + target, "Cupola · 400 mm lens", "ceo", "cupola", 915, 25, [["Mount the 400 mm lens, set exposure", 2], ["Photograph the target on the pass", 3], ["Tag and downlink the frames", 2]], "SCIENCE"), 
		_act("ex2", "Exercise · T2 treadmill", "Node 3 · T2", "exercise", "ared", 940, 60, [["Harness on, clip the bungees", 1], ["Run 5 km at load", 6], ["Stow harness, drink water", 1]], "EXERCISE"), 
		_act("pl", pl.title, pl.where, "science", pl.loc, 1000, 70, pl.steps, "SCIENCE"), 
		_act("dpc2", "Evening planning conference", "Lab · Space-to-Ground 2", "conf", "lab", 1070, 15, [["Evening DPC, review tomorrow", 1]], "CONF"), 
		_act("dinner", "Dinner", "Node 1 · galley", "meal", "galley", 1085, 45, [["Dinner, pick from the bonus food", 1]], "ROUTINE"), 
		_act("personal", "Personal time", "Your choice", "personal", "cupola", 1130, 115, [["Spend your evening", 1]], "OFF DUTY"), 
		_act("pre", "Pre-sleep", "Crew quarters", "routine", "cq", 1245, 45, [["Hygiene, lights down in the quarters", 1]], "ROUTINE"), 
		_act("sleep", "Sleep", "Crew quarters", "sleep", "cq", SLEEP_AT, 510, [["Zip into the sleeping bag", 0]], "SLEEP"), 
	]
	for a in timeline:
		if a.id == "ceo":
			a["target"] = target
			a["window"] = [a.start + 4.0, a.start + 40.0]
	today = {"ontime": 0, "planned": 0, "science": 0, "photos": 0, "exercise": 0, "co2_max": co2, "co2_high_min": 0.0, 
		"anomalies": [], "violations": 0, "deferred": 0, "late_total": 0.0}
	events = []
	var j: = func(base: float) -> float: return base + rng.randf_range(-20.0, 20.0)
	match day:
		1:
			events.append({"at": 820.0 + rng.randf_range(0, 30), "id": "ariss", "fired": false})
		2:
			events.append({"at": j.call(640.0), "id": "cdra", "fired": false})
		3:
			events.append({"at": j.call(800.0), "id": "debris", "fired": false})
		4:
			events.append({"at": j.call(560.0), "id": "upa", "fired": false})
			events.append({"at": j.call(1010.0), "id": "ariss", "fired": false})
		5:
			events.append({"at": j.call(890.0), "id": "fire", "fired": false})
			events.append({"at": j.call(1150.0), "id": "cdra", "fired": false})
	ground_call.emit(_morning_call())

func _morning_call() -> String:
	match day:
		1: return "Houston: Good morning, Station. Welcome to your first full day. Plan is on board."
		2: return "Houston: Morning. Quiet night on the ground side. Enjoy the plant harvest."
		3: return "Houston: Good morning. Flight dynamics is watching a debris object. More on the DPC."
		4: return "Houston: Morning, crew. Water team says UPA had a rough night. Keep an eye on it."
		_: return "Houston: Last day of the week. Thanks for the hard work up there."



func current() -> Dictionary:
	for a in timeline:
		if a.state == "active":
			return a
	return {}

func next_planned() -> Dictionary:
	for a in timeline:
		if a.state == "planned":
			return a
	return {}

func upcoming(n: int) -> Array:
	var out: Array = []
	for a in timeline:
		if a.state == "planned":
			out.append(a)
			if out.size() >= n:
				break
	return out

func can_defer(a: Dictionary) -> bool:
	return not a.is_empty() and not a.urgent and a.kind in ["science", "maint"] and not a.running



func begin_next() -> void :
	if not current().is_empty():
		return
	var n: = next_planned()
	if n.is_empty():
		return
	n.state = "active"

func do_step() -> void :
	var a: = current()
	if a.is_empty() or a.running:
		return
	var s: Dictionary = a.steps[a.si]
	if a.kind == "sleep":
		_go_to_sleep(a)
		return
	a.running = true
	a.left = s.m * step_mult()

func defer_current() -> void :
	var a: = current()
	if not can_defer(a):
		return
	a.state = "deferred"
	today.deferred += 1
	ground_call.emit("Houston: Copy, " + a.title.split(" · ")[0] + " goes to the job jar.")

func choose_personal(opt: String) -> void :
	var a: = current()
	if a.is_empty() or a.kind != "personal":
		return
	a["choice"] = opt
	a.running = true
	a.left = a.steps[0].m

func resolve_event(ev: Dictionary, opt: String) -> void :
	today.anomalies.append(ev.id)
	match ev.id:
		"cdra":
			if opt == "restart":
				_insert_urgent(_act("cdra_fix", "CDRA recovery", "Lab · CDRA rack", "fix", "lab", t, 35, [["Pull up the CDRA recovery procedure", 1], ["Safe CDRA from the station laptop", 2], ["Cycle bed heater power", 3], ["Verify bed temperatures rising", 2]], "URGENT"), {"on_done": "cdra_ok"})
			elif opt == "backup":
				_insert_urgent(_act("vozdukh", "Start Vozdukh backup", "Service Module", "fix", "cq", t, 12, [["Float to the Service Module", 1], ["Activate Vozdukh with Moscow", 2]], "URGENT"), {"on_done": "cdra_backup"})
			else:
				ground_fix_at = t + 150.0
				ground_call.emit("Houston: We'll work it from the ground. Estimate two and a half hours.")
		"upa":
			if opt == "rr":
				_insert_urgent(_act("upa_rr", "UPA distillation R&R", "Node 3 · WRS rack", "fix", "whc", t, 110, [["Power down UPA, isolate fluid lines", 2], ["Remove the failed distillation assembly", 4], ["Install the spare assembly", 4], ["Leak check and restart", 2]], "URGENT"), {"on_done": "upa_ok"})
			elif opt == "edv":
				_insert_urgent(_act("edv", "Rig urine to EDV containers", "Node 3 · toilet (WHC)", "fix", "whc", t, 20, [["Reroute the WHC to an EDV", 1], ["Label and stow the full EDV", 1]], "URGENT"), {"on_done": "upa_edv"})
			else:
				ground_call.emit("Houston: Copy. Storage has a few hours of margin.")
		"debris":
			_insert_urgent(_act("shelter", "Shelter in Crew Dragon", "Node 2 · Dragon", "fix", "cq", t, 26, [["Stop work, stow loose items", 1], ["Close the Lab and Node 1 hatches", 2], ["Float to Dragon, ingress", 1], ["Power up Dragon comm, report in", 1]], "URGENT"), {"deadline_step": 3, "deadline_at": ev.shelter_by, "fail": "You were not in Dragon at closest approach. Flight rule violation."})
		"fire":
			_insert_urgent(_act("fire_resp", "Fire response · Node 1", "Node 1", "fix", "galley", t, 24, [["Don a PBA mask", 1], ["Gather at Dragon, account for crew", 2], ["Read the combustion products analyzer", 2], ["Inspect the detector: dust, false alarm", 3], ["Masks off, reset caution and warning", 2]], "URGENT"), {"deadline_step": 2, "deadline_at": t + 8.0, "fail": "Crew took too long to gather. The flight director logs it."})
		"ariss":
			if opt == "yes":
				_insert_urgent(_act("ariss_call", "School radio contact · ARISS", "Service Module · ham radio", "science", "cq", t, 22, [["Set up the ham radio, wait for signal", 1], ["Answer students' questions for 10 minutes", 3], ["Sign off, log the contact", 1]], "OUTREACH"), {})
			else:
				ground_call.emit("Houston: Copy, we'll let the school know. Another pass next week.")

func _insert_urgent(a: Dictionary, meta: Dictionary) -> void :
	a.urgent = true
	a.merge(meta)
	var cur: = current()
	if not cur.is_empty():
		if cur.running:
			cur.running = false
			cur.left = 0.0
		cur.state = "planned"
	a.state = "active"
	var idx: = timeline.find(cur) if not cur.is_empty() else _first_planned_index()
	if idx < 0:
		idx = timeline.size() - 1
	timeline.insert(idx, a)
	if meta.has("deadline_at"):
		deadline = {"at": meta.deadline_at, "act": a, "step": meta.deadline_step, "fail": meta.fail}

func _first_planned_index() -> int:
	for i in timeline.size():
		if timeline[i].state == "planned":
			return i
	return -1



func advance(dm: float) -> void :
	if finished:
		return
	while dm > 0.0:
		var s: = minf(dm, 1.0)
		dm -= s
		_tick(s)
		if finished:
			return

func _tick(s: float) -> void :
	t += s

	for ev in events:
		if not ev.fired and t >= ev.at and not sleeping:
			ev.fired = true
			_raise(ev)

	var crew_gen: = 0.04
	var a: = current()
	if not a.is_empty() and a.kind == "exercise" and a.running:
		crew_gen += 0.012
	var k: = 0.0172
	if cdra == "failed":
		k = 0.0035
	elif cdra == "backup":
		k = 0.0125
	co2 += (crew_gen - k * co2) * s
	if cdra == "failed" and ground_fix_at > 0.0 and t >= ground_fix_at:
		cdra = "nominal"
		ground_fix_at = -1.0
		ground_call.emit("Houston: CDRA is back in service from the ground. Thanks for your patience.")
	o2 += (21.2 - o2) * 0.01 * s + rng.randf_range(-0.004, 0.004)
	water -= 0.0014 * s
	if upa == "failed":
		urine = minf(100.0, urine + 0.26 * s)
		if urine >= 100.0 and not _has_active("edv_forced"):
			_insert_urgent(_act("edv_forced", "Urine storage full · swap EDV", "Node 3 · toilet (WHC)", "fix", "whc", t, 15, [["Swap in an empty EDV", 1], ["Stow the full one", 1]], "URGENT"), {"on_done": "upa_edv"})
			morale -= 6.0
			ground_call.emit("Houston: Storage is full. Sorry, crew. EDV swap is on your plan now.")
	elif upa == "edv":
		if edv_next > 0.0 and t >= edv_next:
			edv_next = t + 240.0
			_insert_urgent(_act("edv_swap", "EDV container swap", "Node 3 · toilet (WHC)", "fix", "whc", t, 12, [["Swap in an empty EDV", 1], ["Label and stow the full one", 1]], "URGENT"), {})
	elif urine > 20.0:
		urine -= 0.05 * s

	if sunlit():
		soc = minf(100.0, soc + 0.3 * s)
	else:
		soc = maxf(20.0, soc - 0.42 * s)

	if sleeping:
		var q: = 1.0 if co2 < 3.0 else 0.7
		fatigue = maxf(4.0, fatigue - 0.19 * q * s)
	else:
		fatigue = minf(100.0, fatigue + 0.068 * s)
		morale -= 0.011 * s
	if co2 > 3.0:
		today.co2_high_min += s
		morale -= 0.012 * s
	today.co2_max = maxf(today.co2_max, co2)
	morale = clampf(morale, 0.0, 100.0)
	hist_timer += s
	if hist_timer >= 5.0:
		hist_timer = 0.0
		co2_hist.append(co2)
		if co2_hist.size() > 60:
			co2_hist.pop_front()

	if not sleeping:
		_work(s)
		if current().is_empty():
			var n: = next_planned()
			if not n.is_empty() and t >= n.start:
				n.state = "active"
	else:
		if t >= 1440.0 + WAKE:
			_wake()

	if not deadline.is_empty() and t >= deadline.at:
		var da: Dictionary = deadline.act
		if da.si < deadline.step:
			today.violations += 1
			morale -= 5.0
			ground_call.emit("Flight: " + deadline.fail)
		deadline = {}
	if not sleeping and t >= 1440.0 + 60.0:
		ground_call.emit("Flight surgeon: It's 01:00 GMT. Lights out, please.")
		var sl: = current()
		for x in timeline:
			if x.id == "sleep":
				x.state = "active"
				_go_to_sleep(x)
				break

func _has_active(id: String) -> bool:
	for a in timeline:
		if a.id == id and a.state != "done":
			return true
	return false

func _work(s: float) -> void :
	var a: = current()
	if a.is_empty() or not a.running:
		return
	a.left -= s
	if a.left > 0.0:
		return
	a.running = false
	a.steps[a.si].done = true
	a.si += 1
	if a.kind == "science" and a.id != "ceo":
		today.science += 1
	if a.si >= a.steps.size():
		_finish(a)

func _finish(a: Dictionary) -> void :
	a.state = "done"
	a.late = maxf(0.0, t - (a.start + a.dur))
	if not a.urgent and a.kind != "sleep":
		today.planned += 1
		if a.late <= 15.0:
			today.ontime += 1
		today.late_total += a.late
	match a.kind:
		"exercise":
			today.exercise += 1
			fatigue += 6.0
			morale += 2.0
		"meal":
			morale += 1.5
			fatigue = maxf(0.0, fatigue - 2.0)
		"personal":
			match a.get("choice", ""):
				"cupola":
					morale += 7.0
				"call":
					morale += 8.0
				"rest":
					fatigue = maxf(0.0, fatigue - 14.0)
					morale += 4.0
		"conf":
			pass
	match a.get("on_done", ""):
		"cdra_ok":
			cdra = "nominal"
			ground_fix_at = -1.0
			ground_call.emit("Houston: We see CDRA beds heating. Nice work. ppCO2 will come down.")
		"cdra_backup":
			cdra = "backup"
			ground_fix_at = t + 180.0
			ground_call.emit("Moscow: Vozdukh is running. Houston will restore CDRA from the ground.")
		"upa_ok":
			upa = "nominal"
			ground_call.emit("Houston: UPA is processing again. Water team says thank you.")
		"upa_edv":
			if upa != "nominal":
				upa = "edv"
				edv_next = t + 240.0
	if deadline.has("act") and deadline.act == a:
		deadline = {}
	if a.id == "shelter":
		ground_call.emit("Houston: Object passed at 1.4 km. You're clear to open hatches.")
		_insert_urgent(_act("egress", "Reopen hatches", "Node 1 · Lab", "fix", "lab", t, 12, [["Egress Dragon, open the hatches", 1], ["Restart the fans, resume the plan", 1]], "URGENT"), {})
	activity_finished.emit(a)

func record_photos(n: int) -> void :
	today.photos += n

func _raise(ev: Dictionary) -> void :
	match ev.id:
		"cdra":
			cdra = "failed"
			ev.merge({"sev": "caution", "title": "CAUTION · CDRA LAB BED HEATER", 
				"body": "The Lab CO2 removal unit has stopped. ppCO2 is climbing. Above 3 mmHg the crew gets headaches and slower hands.", 
				"opts": [["restart", "Run the recovery procedure", "About 35 min of your time. Fixes it now."], 
					["backup", "Start the Russian Vozdukh", "12 min. Holds CO2 near 3.3 until the ground restores CDRA."], 
					["ground", "Let the ground work it", "No crew time. CO2 climbs for about 2.5 hours."]]})
		"upa":
			upa = "failed"
			ev.merge({"sev": "caution", "title": "CAUTION · UPA DISTILLATION", 
				"body": "The urine processor stopped. Urine storage now fills. When it's full the toilet can't be used until someone swaps a container.", 
				"opts": [["rr", "Swap in the spare assembly", "About 1 h 50 min. Fixes it for good."], 
					["edv", "Route to EDV containers", "20 min, then a 12 min container swap every 4 hours."], 
					["defer", "Keep working", "Storage lasts a few hours, then a forced swap."]]})
		"debris":
			var tca: = t + 45.0
			ev["shelter_by"] = t + 30.0
			ev.merge({"sev": "warning", "title": "WARNING · DEBRIS CONJUNCTION", 
				"body": "Flight dynamics: a debris object passes at %s GMT. Too late for an avoidance burn. Crew shelters in Crew Dragon by %s GMT." % [clock(tca), clock(t + 30.0)], 
				"opts": [["go", "Start the safe-haven procedure", "Stops your current task. About 26 min."]]})
		"fire":
			ev.merge({"sev": "warning", "title": "EMERGENCY · FIRE, NODE 1", 
				"body": "A Node 1 smoke detector tripped. Treat it as real until proven otherwise: masks on, crew together, read the air.", 
				"opts": [["go", "Start the fire response", "Gather within 8 minutes."]]})
		"ariss":
			ev.merge({"sev": "info", "title": "HOUSTON · SCHOOL CONTACT", 
				"body": "A school in Pune has a ham radio pass in a few minutes. Ten minutes of students' questions, live. It will push your plan back.", 
				"opts": [["yes", "Take the call", "About 22 min. Good for morale."], ["no", "Decline this pass", "Stay on the timeline."]]})
	totals.anomalies += 1 if ev.sev != "info" else 0
	event_raised.emit(ev)

func _go_to_sleep(a: Dictionary) -> void :
	sleeping = true
	sleep_started = t
	a.steps[0].done = true
	a.state = "done"
	for x in timeline:
		if x.state == "planned" or x.state == "active":
			if x != a and x.kind != "sleep":
				x.state = "missed"

func _wake() -> void :
	var slept: = (1440.0 + WAKE - sleep_started) / 60.0
	if slept < 7.0:
		morale -= (7.0 - slept) * 2.0
	var ex: int = today.exercise
	if ex < 2:
		fitness -= (2 - ex) * 0.9
	var summary: = make_summary(slept)
	totals.science += today.science
	totals.photos += today.photos
	totals.ontime += today.ontime
	totals.planned += today.planned
	totals.exercise += ex
	totals.violations += today.violations
	sleeping = false
	t = WAKE
	if day >= DAYS_TOTAL:
		finished = true
		summary["final"] = true
	day_ended.emit(summary)

func make_summary(slept: float) -> Dictionary:
	var scheduled: = 0
	for a in timeline:
		if not a.urgent and a.kind != "sleep":
			scheduled += 1
	var adherence: float = float(today.ontime) / float(maxi(1, scheduled))
	return {"day": day, "gmt": gmt_day(), "adherence": adherence, "ontime": today.ontime, "scheduled": scheduled, 
		"science": today.science, "photos": today.photos, "exercise": today.exercise, "co2_max": today.co2_max, 
		"co2_high_min": today.co2_high_min, "violations": today.violations, "slept": slept, 
		"fitness": fitness, "morale": morale, "fatigue": fatigue, "anomalies": today.anomalies.size(), 
		"deferred": today.deferred, "note": _note(adherence)}

func _note(adh: float) -> String:
	if today.violations > 0:
		return "Flight director: the timeline can wait. Safety calls can't. We'll talk it through on the DPC."
	if today.co2_high_min > 120:
		return "Flight surgeon: long hours above 3 mmHg today. Expect a headache and a rough night."
	if today.exercise < 2:
		return "Flight surgeon: you skipped exercise. Bone loss in orbit runs about 1% a month without it."
	if adh >= 0.85:
		return "Ops planning: you ran the timeline almost to the minute. Strong day."
	if adh >= 0.6:
		return "Ops planning: some slip, nothing we can't absorb. We'll rebalance tomorrow's plan."
	return "Ops planning: big slip today. We'll lighten tomorrow and move tasks to the job jar."

func next_day() -> void :
	day += 1
	start_day()

func clock(m: float) -> String:
	var mm: = int(floor(m)) % 1440
	return "%02d:%02d" % [mm / 60, mm % 60]



func to_save() -> Dictionary:
	return {"v": 1, "day": day, "fitness": fitness, "morale": morale, "fatigue": fatigue, "co2": co2, "water": water, 
		"urine": urine, "cdra": cdra, "upa": upa, "totals": totals}

func from_save(d: Dictionary) -> bool:
	if int(d.get("v", 0)) != 1:
		return false
	day = clampi(int(d.get("day", 1)), 1, DAYS_TOTAL)
	fitness = float(d.get("fitness", 100.0))
	morale = float(d.get("morale", 74.0))
	fatigue = float(d.get("fatigue", 10.0))
	co2 = float(d.get("co2", 2.3))
	water = float(d.get("water", 418.0))
	urine = float(d.get("urine", 22.0))
	cdra = "nominal" if str(d.get("cdra", "nominal")) != "backup" else "backup"
	upa = str(d.get("upa", "nominal"))
	if upa == "failed":
		upa = "edv"
	var tt = d.get("totals", {})
	if tt is Dictionary:
		for k in totals.keys():
			totals[k] = int(tt.get(k, 0))
	return true
