extends SceneTree
var Sim = preload("res://sim.gd")
var pend: = []
var sums: = []
func _init():
	var s = Sim.new()
	s.event_raised.connect( func(ev): pend.append(ev))
	s.day_ended.connect( func(x): sums.append(x))
	s.start_day()
	var guard: = 0
	while not s.finished and guard < 200000:
		guard += 1
		if pend.size() > 0:
			var ev = pend.pop_front()
			s.resolve_event(ev, ev.opts[0][0])
		if sums.size() > 0 and not s.finished and s.sleeping == false and s.t == s.WAKE and sums.size() >= s.day:
			s.next_day()
		var a = s.current()
		if a.is_empty():
			s.begin_next()
		elif not a.running:
			if a.kind == "personal": s.choose_personal("call")
			elif a.kind == "ceo" and a.si == 1:
				s.do_step();s.record_photos(2)
			else: s.do_step()
		s.advance(0.5)
	for x in sums:
		print("day ", x.day, " ontime ", x.ontime, "/", x.scheduled, " sci ", x.science, " ex ", x.exercise, " co2max %.2f" % x.co2_max, " viol ", x.violations, " slept %.1f" % x.slept, " fat %d mor %d" % [x.fatigue, x.morale])
	print("finished ", s.finished, " guard ", guard)
	quit()
