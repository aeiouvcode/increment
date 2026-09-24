extends Control


const Sim: = preload("res://sim.gd")
const StationView: = preload("res://station_view.gd")
const Gauges: = preload("res://gauges.gd")

const BG: = Color("ece7dd")
const CARD: = Color("f6f3ec")
const HAIR: = Color("d8d1c4")
const INK: = Color("22262a")
const MUTED: = Color("6f7376")
const TEAL: = Color("2c6a64")
const AMBER: = Color("9a6420")
const RED: = Color("a5432f")
const SPEEDS: = [1.0, 4.0, 12.0]
const SAVE_PATH: = "user://increment.json"

var sim: Sim
var view
var gauges
var font: FontFile
var font_md: FontFile
var font_sb: FontFile
var mono: FontFile
var speed_i: = 1
var paused: = false
var started: = false
var modal: Control = null
var tab: = "plan"
var sig: = ""
var page: VBoxContainer
var scroll: ScrollContainer
var lbl_mission: Label
var lbl_clock: Label
var lbl_orbit: Label
var btn_speed: Button
var btn_pause: Button
var tab_btns: = {}
var live: = {}
var camera_act: Dictionary = {}
var tab_bar: Control
var clock_held: = true

func _ready() -> void :
	font = load("res://fonts/IBMPlexSans-Regular.ttf")
	font_md = load("res://fonts/IBMPlexSans-Medium.ttf")
	font_sb = load("res://fonts/IBMPlexSans-SemiBold.ttf")
	mono = load("res://fonts/IBMPlexMono-Medium.ttf")
	var th: = Theme.new()
	th.default_font = font
	th.default_font_size = 14
	th.set_color("font_color", "Label", INK)
	theme = th
	sim = Sim.new()
	sim.event_raised.connect(_on_event)
	sim.day_ended.connect(_on_day_end)
	sim.ground_call.connect( func(s): if view: view.say(s))
	_build()
	_title()



func _build() -> void :
	var bg: = ColorRect.new()
	bg.color = BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var col: = VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.add_theme_constant_override("separation", 0)
	add_child(col)

	var head: = MarginContainer.new()
	for k in ["left", "right"]:
		head.add_theme_constant_override("margin_" + k, 16)
	head.add_theme_constant_override("margin_top", 12)
	head.add_theme_constant_override("margin_bottom", 8)
	col.add_child(head)
	var hb: = HBoxContainer.new()
	head.add_child(hb)
	var left: = VBoxContainer.new()
	left.add_theme_constant_override("separation", 0)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(left)
	var brand: = _label("Increment", font_sb, 17, INK)
	left.add_child(brand)
	lbl_mission = _label("", mono, 10, MUTED)
	left.add_child(lbl_mission)
	var right: = VBoxContainer.new()
	right.add_theme_constant_override("separation", 0)
	hb.add_child(right)
	lbl_clock = _label("", mono, 17, INK)
	lbl_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(lbl_clock)
	lbl_orbit = _label("", mono, 10, MUTED)
	lbl_orbit.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(lbl_orbit)

	view = StationView.new()
	view.sim = sim
	view.font = font
	view.mono = mono
	view.custom_minimum_size = Vector2(0, 262)
	view.camera_done.connect(_on_camera_done)
	col.add_child(view)
	gauges = Gauges.new()
	gauges.sim = sim
	gauges.font = font
	gauges.mono = mono
	gauges.custom_minimum_size = Vector2(0, 58)
	col.add_child(gauges)

	scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	var pm: = MarginContainer.new()
	pm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for k in ["left", "right"]:
		pm.add_theme_constant_override("margin_" + k, 14)
	pm.add_theme_constant_override("margin_top", 10)
	pm.add_theme_constant_override("margin_bottom", 14)
	scroll.add_child(pm)
	page = VBoxContainer.new()
	page.add_theme_constant_override("separation", 10)
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pm.add_child(page)

	var bar: = PanelContainer.new()
	tab_bar = bar
	bar.add_theme_stylebox_override("panel", _box(CARD, HAIR, 0, 0, [0, 1, 0, 0]))
	col.add_child(bar)
	var bm: = MarginContainer.new()
	for k in ["left", "right"]:
		bm.add_theme_constant_override("margin_" + k, 10)
	bm.add_theme_constant_override("margin_top", 6)
	bm.add_theme_constant_override("margin_bottom", 10)
	bar.add_child(bm)
	var bb: = HBoxContainer.new()
	bb.add_theme_constant_override("separation", 4)
	bm.add_child(bb)
	for t in [["plan", "Plan"], ["systems", "Systems"], ["crew", "Crew"]]:
		var b: = _tab_button(t[1])
		b.pressed.connect( func(): _set_tab(t[0]))
		bb.add_child(b)
		tab_btns[t[0]] = b
	var sp: = Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bb.add_child(sp)
	btn_pause = _small_button("Pause")
	btn_pause.pressed.connect( func(): paused = not paused;_refresh_bar())
	bb.add_child(btn_pause)
	btn_speed = _small_button("4×")
	btn_speed.pressed.connect( func(): speed_i = (speed_i + 1) % SPEEDS.size();_refresh_bar())
	bb.add_child(btn_speed)
	_refresh_bar()

func _label(text: String, f: Font, fs: int, c: Color) -> Label:
	var l: = Label.new()
	l.text = text
	l.add_theme_font_override("font", f)
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", c)
	return l

func _wrap_label(text: String, f: Font, fs: int, c: Color) -> Label:
	var l: = _label(text, f, fs, c)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.custom_minimum_size = Vector2(10, 0)
	return l

func _box(bgc: Color, border: Color, radius: int, pad: int, bw: = [1, 1, 1, 1]) -> StyleBoxFlat:
	var s: = StyleBoxFlat.new()
	s.bg_color = bgc
	s.border_color = border
	s.border_width_left = bw[0]
	s.border_width_top = bw[1]
	s.border_width_right = bw[2]
	s.border_width_bottom = bw[3]
	s.set_corner_radius_all(radius)
	s.content_margin_left = pad
	s.content_margin_right = pad
	s.content_margin_top = pad
	s.content_margin_bottom = pad
	s.anti_aliasing = true
	return s

func _style_button(b: Button, bgc: Color, fg: Color, border: Color, fs: = 15, h: = 46) -> void :
	b.custom_minimum_size = Vector2(0, h)
	b.add_theme_font_override("font", font_md)
	b.add_theme_font_size_override("font_size", fs)
	for st in ["font_color", "font_hover_color", "font_focus_color"]:
		b.add_theme_color_override(st, fg)
	b.add_theme_color_override("font_pressed_color", fg)
	b.add_theme_color_override("font_disabled_color", Color(fg, 0.45))
	var n: = _box(bgc, border, 11, 10)
	var p: = _box(bgc.darkened(0.12), border, 11, 10)
	var d: = _box(Color(bgc, 0.35) if bgc.a > 0.0 else bgc, Color(border, 0.4), 11, 10)
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", n)
	b.add_theme_stylebox_override("pressed", p)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_stylebox_override("disabled", d)
	b.button_down.connect( func(): _press(b, 0.97))
	b.button_up.connect( func(): _press(b, 1.0))

func _press(b: Control, s: float) -> void :
	b.pivot_offset = b.size * 0.5
	var tw: = create_tween()
	tw.tween_property(b, "scale", Vector2(s, s), 0.09).set_trans(Tween.TRANS_SPRING if s == 1.0 else Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _primary(text: String) -> Button:
	var b: = Button.new()
	b.text = text
	b.clip_text = true
	b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_style_button(b, TEAL, Color("f6f3ec"), TEAL)
	return b

func _secondary(text: String) -> Button:
	var b: = Button.new()
	b.text = text
	b.clip_text = true
	b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_style_button(b, Color(0, 0, 0, 0), INK, HAIR, 14, 42)
	return b

func _tab_button(text: String) -> Button:
	var b: = Button.new()
	b.text = text
	b.toggle_mode = false
	_style_button(b, Color(0, 0, 0, 0), MUTED, Color(0, 0, 0, 0), 14, 40)
	return b

func _small_button(text: String) -> Button:
	var b: = Button.new()
	b.text = text
	_style_button(b, Color(0, 0, 0, 0), INK, HAIR, 13, 36)
	b.custom_minimum_size = Vector2(58, 36)
	b.add_theme_font_override("font", mono)
	return b

func _refresh_bar() -> void :
	btn_speed.text = "%d×" % int(SPEEDS[speed_i])
	btn_pause.text = "Play" if paused else "Pause"
	for k in tab_btns:
		var b: Button = tab_btns[k]
		var on: bool = k == tab
		for st in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			b.add_theme_color_override(st, INK if on else MUTED)
		b.add_theme_stylebox_override("normal", _box(Color(0, 0, 0, 0), TEAL if on else Color(0, 0, 0, 0), 0, 8, [0, 0, 0, 2]))
		b.add_theme_stylebox_override("hover", b.get_theme_stylebox("normal"))

func _set_tab(t: String) -> void :
	tab = t
	_refresh_bar()
	sig = ""

func _card() -> VBoxContainer:
	var pc: = PanelContainer.new()
	pc.add_theme_stylebox_override("panel", _box(CARD, HAIR, 14, 14))
	page.add_child(pc)
	var v: = VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	pc.add_child(v)
	return v

func _clear() -> void :
	for c in page.get_children():
		c.queue_free()
	live = {}



func _process(delta: float) -> void :
	if not started:
		return
	var blocked: bool = modal != null or view.mode == "camera" or sim.finished or clock_held
	if not paused and not blocked:
		var rate: float = 120.0 if sim.sleeping else SPEEDS[speed_i]
		sim.advance(delta * rate)
	_header()
	var s: = _signature()
	if s != sig:
		sig = s
		_rebuild()
	_live()

func _header() -> void :
	lbl_mission.text = "DAY %d OF %d · GMT %03d" % [sim.day, sim.DAYS_TOTAL, sim.gmt_day()]
	lbl_clock.text = sim.clock(sim.t)
	var m: = int(ceil(sim.minutes_to_terminator()))
	lbl_orbit.text = ("DAYLIGHT · SUNSET IN %d MIN" if sim.sunlit() else "ORBITAL NIGHT · SUNRISE IN %d MIN") % m
	if clock_held:
		lbl_orbit.text = "CLOCK STARTS WHEN YOU BEGIN"

func _signature() -> String:
	var a: Dictionary = sim.current()
	var s: = tab + "|" + str(sim.sleeping) + "|" + str(sim.day) + "|" + str(sim.timeline.size())
	if not a.is_empty():
		s += "|" + a.id + str(a.si) + str(a.running)
	else:
		var n: Dictionary = sim.next_planned()
		s += "|idle" + (n.id if not n.is_empty() else "")
	if tab != "plan":
		s += "|" + sim.cdra + sim.upa + str(int(sim.t / 10.0))
	return s

func _rebuild() -> void :
	_clear()
	match tab:
		"plan": _page_plan()
		"systems": _page_systems()
		"crew": _page_crew()

func _live() -> void :
	if live.has("progress"):
		var a: Dictionary = sim.current()
		if not a.is_empty():
			var done: = 0.0
			var tot: = 0.0
			for i in a.steps.size():
				tot += a.steps[i].m
				if a.steps[i].done:
					done += a.steps[i].m
			if a.running and a.si < a.steps.size():
				done += maxf(0.0, a.steps[a.si].m - a.left / sim.step_mult())
			live.progress.value = 100.0 * done / maxf(1.0, tot)
			if live.has("button") and a.running and not (a.kind == "ceo" and a.si == 1):
				live.button.text = "Working · %d min left" % int(ceil(a.left))
			if live.has("timing"):
				live.timing.text = _timing(a)
	if live.has("idle"):
		var n: Dictionary = sim.next_planned()
		if not n.is_empty():
			live.idle.text = "Next at %s · in %d min" % [sim.clock(n.start), int(maxf(0.0, n.start - sim.t))]
	if live.has("sleep"):
		live.sleep.text = "Sleeping · %s GMT" % sim.clock(sim.t)

func _timing(a: Dictionary) -> String:
	var end: float = a.start + a.dur
	var txt: = "%s–%s" % [sim.clock(a.start), sim.clock(end)]
	if a.urgent:
		return "Unplanned · now"
	var remaining: = 0.0
	for i in range(a.si, a.steps.size()):
		remaining += a.steps[i].m * sim.step_mult()
	if a.running:
		remaining -= (a.steps[a.si].m * sim.step_mult() - a.left)
	var proj: float = sim.t + remaining
	if proj > end + 1.0:
		txt += " · %d min late" % int(proj - end)
	else:
		txt += " · on time"
	return txt



func _chip(text: String, c: Color) -> Label:
	var l: = _label(text, mono, 10, c)
	return l

func _tag_color(tag: String) -> Color:
	match tag:
		"URGENT": return RED
		"EXERCISE": return AMBER
		"SCIENCE", "OUTREACH": return TEAL
	return MUTED

func _page_plan() -> void :
	if sim.sleeping:
		var v: = _card()
		v.add_child(_chip("SLEEP", MUTED))
		v.add_child(_wrap_label("Lights out in the crew quarters", font_sb, 18, INK))
		var l: = _label("", mono, 12, MUTED)
		v.add_child(l)
		live.sleep = l
		v.add_child(_wrap_label("The station keeps running. Houston watches the systems overnight.", font, 13, MUTED))
		return
	var a: Dictionary = sim.current()
	if a.is_empty():
		var n: Dictionary = sim.next_planned()
		var v: = _card()
		v.add_child(_chip("AHEAD OF PLAN", TEAL))
		v.add_child(_wrap_label(n.title if not n.is_empty() else "Nothing scheduled", font_sb, 18, INK))
		var il: = _label("", mono, 12, MUTED)
		v.add_child(il)
		live.idle = il
		v.add_child(_wrap_label("Starting early banks time for the day's surprises.", font, 13, MUTED))
		if not n.is_empty():
			var b: = _primary("Start early")
			b.pressed.connect( func(): sim.begin_next())
			v.add_child(b)
	else:
		_activity_card(a)
	var up: Array = sim.upcoming(5)
	if up.size() > 0:
		page.add_child(_label("LATER TODAY", mono, 10, MUTED))
		var v2: = _card()
		v2.add_theme_constant_override("separation", 9)
		for x in up:
			var row: = HBoxContainer.new()
			row.add_theme_constant_override("separation", 10)
			var tl: = _label(sim.clock(x.start), mono, 12, MUTED)
			tl.custom_minimum_size = Vector2(44, 0)
			row.add_child(tl)
			var nl: = _wrap_label(x.title, font, 14, INK)
			row.add_child(nl)
			var dot: = Panel.new()
			dot.custom_minimum_size = Vector2(7, 7)
			dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			dot.add_theme_stylebox_override("panel", _box(_tag_color(x.tag), Color(0, 0, 0, 0), 4, 0, [0, 0, 0, 0]))
			row.add_child(dot)
			v2.add_child(row)

func _activity_card(a: Dictionary) -> void :
	var v: = _card()
	var top: = HBoxContainer.new()
	v.add_child(top)
	var chip: = _chip(a.tag, _tag_color(a.tag))
	chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(chip)
	var tm: = _label(_timing(a), mono, 10, MUTED)
	top.add_child(tm)
	live.timing = tm
	v.add_child(_wrap_label(a.title, font_sb, 18, INK))
	v.add_child(_label(a.where, font, 13, MUTED))
	var pb: = ProgressBar.new()
	pb.show_percentage = false
	pb.custom_minimum_size = Vector2(0, 4)
	pb.add_theme_stylebox_override("background", _box(Color("e4ded2"), Color(0, 0, 0, 0), 2, 0, [0, 0, 0, 0]))
	pb.add_theme_stylebox_override("fill", _box(RED if a.urgent else TEAL, Color(0, 0, 0, 0), 2, 0, [0, 0, 0, 0]))
	v.add_child(pb)
	live.progress = pb
	if a.kind == "personal" and not a.running:
		v.add_child(_wrap_label("Your evening. Nothing on the timeline until pre-sleep.", font, 13, MUTED))
		for o in [["cupola", "Float to the Cupola and watch Earth"], ["call", "Call home on the IP phone"], ["rest", "Read, rest, sleep a little early"]]:
			var b: = _secondary(o[1])
			b.pressed.connect( func(): sim.choose_personal(o[0]))
			v.add_child(b)
		return
	var steps: = VBoxContainer.new()
	steps.add_theme_constant_override("separation", 5)
	v.add_child(steps)
	for i in a.steps.size():
		var s: Dictionary = a.steps[i]
		var row: = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var mark: = "•" if s.done else ("›" if i == a.si else "·")
		var mc: = TEAL if s.done else (INK if i == a.si else MUTED)
		var ml: = _label(mark, mono, 13, mc)
		ml.custom_minimum_size = Vector2(12, 0)
		row.add_child(ml)
		var sl: = _wrap_label(s.t, font_md if i == a.si else font, 13, INK if i >= a.si else MUTED)
		row.add_child(sl)
		if a.kind != "sleep":
			row.add_child(_label("%d m" % int(s.m), mono, 11, MUTED))
		steps.add_child(row)
	var label: = "Do this step"
	if a.kind == "sleep":
		label = "Go to sleep"
	elif a.kind == "ceo" and a.si == 1:
		label = "Open the camera"
	elif a.si == 0:
		label = "Begin"
	var b: = _primary(label)
	if a.running:
		b.disabled = true
		b.text = "Working · %d min left" % int(ceil(a.left))
		if a.kind == "ceo" and a.si == 1:
			b.text = "On the camera"
	b.pressed.connect(_on_do)
	v.add_child(b)
	live.button = b
	if sim.can_defer(a):
		var d: = _secondary("Move to the job jar")
		d.pressed.connect( func(): sim.defer_current())
		v.add_child(d)

func _on_do() -> void :
	clock_held = false
	var a: Dictionary = sim.current()
	if a.is_empty():
		return
	if a.kind == "ceo" and a.si == 1 and not a.running:
		var w: Array = a.window
		sim.do_step()
		camera_act = a
		view.open_camera(a.target, sim.t >= w[0] and sim.t <= w[1])
		return
	sim.do_step()

func _on_camera_done(frames: int, note: String) -> void :
	sim.record_photos(frames)
	if not camera_act.is_empty() and camera_act.running:
		camera_act.left = 0.01
	camera_act = {}
	view.say("Earth observation: " + note)

func _row(v: VBoxContainer, name: String, value: String, note: String, c: Color) -> void :
	var row: = HBoxContainer.new()
	var nl: = _label(name, font, 14, INK)
	nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(nl)
	row.add_child(_label(value, mono, 14, c))
	v.add_child(row)
	if note != "":
		v.add_child(_wrap_label(note, font, 12, MUTED))

func _page_systems() -> void :
	var v: = _card()
	v.add_child(_chip("ATMOSPHERE", MUTED))
	var cc: = RED if sim.co2 > 4.0 else (AMBER if sim.co2 > 3.0 else TEAL)
	_row(v, "ppCO2", "%.2f mmHg" % sim.co2, "NASA's 1-hour limit is 3 mmHg. Headaches start around 2.8.", cc)
	_row(v, "ppO2", "%.1f kPa" % sim.o2, "", TEAL)
	var cd: = {"nominal": "Running", "failed": "Failed", "backup": "Off · Vozdukh backup on"}
	_row(v, "CO2 removal (CDRA)", cd[sim.cdra], "", TEAL if sim.cdra == "nominal" else RED)
	var v2: = _card()
	v2.add_child(_chip("WATER", MUTED))
	_row(v2, "Potable water", "%d L" % int(sim.water), "The station recycles about 98% of its water, urine included.", TEAL)
	var up: = {"nominal": "Processing", "failed": "Failed", "edv": "Bypassed to EDVs"}
	_row(v2, "Urine processor", up[sim.upa], "", TEAL if sim.upa == "nominal" else AMBER)
	_row(v2, "Urine storage", "%d%%" % int(sim.urine), "", RED if sim.urine > 85 else (AMBER if sim.urine > 60 else TEAL))
	var v3: = _card()
	v3.add_child(_chip("POWER", MUTED))
	_row(v3, "Battery charge", "%d%%" % int(sim.soc), "A 92-minute orbit: about 57 minutes of sun, 36 of night.", TEAL if sim.soc > 40 else AMBER)

func _page_crew() -> void :
	var v: = _card()
	v.add_child(_chip("YOU · FLIGHT ENGINEER", MUTED))
	_row(v, "Fatigue", "%d / 100" % int(sim.fatigue), "Above 55, every step takes longer.", RED if sim.fatigue > 75 else (AMBER if sim.fatigue > 55 else TEAL))
	_row(v, "Bone and muscle", "%.1f%%" % sim.fitness, "Two exercise sessions a day hold the line. Skipped days cost you.", TEAL if sim.fitness > 98 else AMBER)
	_row(v, "Morale", "%d / 100" % int(sim.morale), "Meals, calls home and the Cupola help. Alarms and CO2 hurt.", TEAL if sim.morale > 50 else AMBER)
	_row(v, "Exercise today", "%d of 2" % int(sim.today.get("exercise", 0)), "", TEAL)



func _sheet(accent: Color, dim_a: = 0.42) -> VBoxContainer:
	modal = Control.new()
	modal.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal.mouse_filter = Control.MOUSE_FILTER_IGNORE if dim_a <= 0.0 else Control.MOUSE_FILTER_STOP
	add_child(modal)
	var dim: = ColorRect.new()
	dim.color = Color(0.1, 0.11, 0.12, dim_a)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE if dim_a <= 0.0 else Control.MOUSE_FILTER_STOP
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal.add_child(dim)
	var pc: = PanelContainer.new()
	pc.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	pc.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var st: = _box(CARD, accent, 18, 18, [0, 3, 0, 0])
	st.corner_radius_bottom_left = 0
	st.corner_radius_bottom_right = 0
	st.content_margin_bottom = 26
	pc.add_theme_stylebox_override("panel", st)
	modal.add_child(pc)
	var v: = VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	pc.add_child(v)
	pc.modulate.a = 0.0
	var tw: = create_tween()
	tw.tween_property(pc, "modulate:a", 1.0, 0.18)
	return v

func _close_modal() -> void :
	if modal:
		modal.queue_free()
		modal = null
	sig = ""

func _on_event(ev: Dictionary) -> void :
	var c: Color = RED if ev.sev == "warning" else (AMBER if ev.sev == "caution" else TEAL)
	var v: = _sheet(c)
	v.add_child(_label(ev.title, mono, 12, c))
	v.add_child(_wrap_label(ev.body, font, 15, INK))
	v.add_child(_label("The clock holds while you decide.", font, 12, MUTED))
	for o in ev.opts:
		var b: = _primary(o[1]) if o == ev.opts[0] else _secondary(o[1])
		b.pressed.connect( func(): _close_modal();sim.resolve_event(ev, o[0]))
		v.add_child(b)
		v.add_child(_wrap_label(o[2], font, 12, MUTED))

func _on_day_end(s: Dictionary) -> void :
	_save()
	var v: = _sheet(TEAL)
	var fin: bool = s.get("final", false)
	v.add_child(_label("DAILY SUMMARY · GMT %03d" % s.gmt if not fin else "INCREMENT COMPLETE", mono, 12, TEAL))
	v.add_child(_wrap_label("Day %d, from Houston" % s.day, font_sb, 20, INK))
	var g: = GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 12)
	g.add_theme_constant_override("v_separation", 4)
	v.add_child(g)
	var rows: = [["On-time activities", "%d of %d" % [s.ontime, s.scheduled]], ["Science steps", str(s.science)], 
		["Earth photos", str(s.photos)], ["Exercise sessions", "%d of 2" % s.exercise], ["Peak ppCO2", "%.1f mmHg" % s.co2_max], 
		["Sleep", "%.1f h" % s.slept], ["Safety calls missed", str(s.violations)]]
	for r in rows:
		var nl: = _label(r[0], font, 14, MUTED)
		nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		g.add_child(nl)
		g.add_child(_label(r[1], mono, 14, INK))
	v.add_child(_wrap_label(s.note, font, 14, INK))
	if fin:
		var tot: Dictionary = sim.totals
		var pct: = 100.0 * float(tot.ontime) / maxf(1.0, float(tot.planned + 0.0001))
		v.add_child(_wrap_label("Five days: %d science steps, %d Earth photos, %d workouts, %d safety calls missed. Bone and muscle at %.1f%%." % [tot.science, tot.photos, tot.exercise, tot.violations, sim.fitness], font, 14, INK))
		var b: = _primary("Start a new increment")
		b.pressed.connect( func(): _clear_save();get_tree().reload_current_scene())
		v.add_child(b)
	else:
		var b: = _primary("Wake up · Day %d" % (s.day + 1))
		b.pressed.connect( func(): _close_modal();clock_held = true;sim.next_day();sim.begin_next();_save())
		v.add_child(b)

func _title() -> void :
	view.title_mode = true
	_title_layout(true)
	var v: = _sheet(TEAL, 0.0)
	v.add_child(_label("A STATION DAY SIMULATOR", mono, 11, TEAL))
	v.add_child(_wrap_label("Five days aboard a space station. The timeline is the job.", font_sb, 21, INK))
	v.add_child(_wrap_label("Houston plans your day to the five minutes. You work the steps, keep the air clean, exercise twice, and handle what breaks.", font, 14, MUTED))
	var saved: = _load()
	var b: = _primary("Continue · Day %d" % saved.day if saved.size() > 0 else "Begin Day 1")
	b.pressed.connect( func(): _begin(saved))
	v.add_child(b)
	if saved.size() > 0:
		var n: = _secondary("Start over")
		n.pressed.connect( func(): _clear_save();_begin({}))
		v.add_child(n)

func _title_layout(on: bool) -> void :
	# Title: the station fills the screen above the card; no dimming, no empty band.
	view.size_flags_vertical = Control.SIZE_EXPAND_FILL if on else Control.SIZE_FILL
	gauges.visible = not on
	scroll.visible = not on
	tab_bar.visible = not on

func _begin(saved: Dictionary) -> void :
	_close_modal()
	if saved.size() > 0:
		sim.from_save(saved)
	view.title_mode = false
	_title_layout(false)
	started = true
	clock_held = true
	sim.start_day()
	sim.begin_next()
	_qa()

func _qa() -> void :

	if not OS.has_feature("web"):
		return
	var q = JavaScriptBridge.eval("new URLSearchParams(location.search).get('qa') || ''", true)
	if typeof(q) != TYPE_STRING or q == "":
		return
	var target: = ""
	match q:
		"cdra": sim.day = 2;target = "sci1"
		"debris": sim.day = 3;target = "sci2"
		"camera": target = "ceo"
		"sleep": target = "sleep"
		_: return
	clock_held = false
	sim.start_day()
	for a in sim.timeline:
		if a.id == target:
			sim.t = a.start
			break
		a.state = "done"
	sim.timeline.filter( func(a): return a.id == target)[0].state = "active"
	if q == "cdra" or q == "debris":
		for ev in sim.events:
			ev.at = sim.t + 3.0
	else:
		sim.events = []
	if q == "camera":
		var c: Dictionary = sim.current()
		c.steps[0].done = true
		c.si = 1
		c.window = [sim.t - 5.0, sim.t + 60.0]
		_on_do()
	if q == "sleep":
		sim.do_step()



func _save() -> void :
	var f: = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(sim.to_save()))
		f.close()

func _load() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var f: = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return {}
	var d = JSON.parse_string(f.get_as_text())
	if d is Dictionary and int(d.get("v", 0)) == 1:
		return d
	return {}

func _clear_save() -> void :
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
