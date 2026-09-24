extends Control


var sim
var font: Font
var mono: Font
const INK: = Color("22262a")
const MUTED: = Color("6f7376")
const TEAL: = Color("2c6a64")
const AMBER: = Color("b7792b")
const RED: = Color("a5432f")
const HAIR: = Color("d8d1c4")

func _process(_d: float) -> void :
	queue_redraw()

func _draw() -> void :
	if sim == null:
		return
	draw_line(Vector2(0, 0), Vector2(size.x, 0), HAIR, 1.0)
	draw_line(Vector2(0, size.y - 1), Vector2(size.x, size.y - 1), HAIR, 1.0)
	var cells: = [
		["ppCO2", "%.1f" % sim.co2, "mmHg", clampf(sim.co2 / 6.0, 0, 1), RED if sim.co2 > 4.0 else (AMBER if sim.co2 > 3.0 else TEAL)], 
		["ppO2", "%.1f" % sim.o2, "kPa", clampf((sim.o2 - 18.0) / 6.0, 0, 1), TEAL], 
		["URINE", "%d" % int(sim.urine), "%", clampf(sim.urine / 100.0, 0, 1), RED if sim.urine > 85 else (AMBER if sim.urine > 60 else TEAL)], 
		["BATTERY", "%d" % int(sim.soc), "%", clampf(sim.soc / 100.0, 0, 1), TEAL if sim.soc > 40 else AMBER], 
	]
	var w: = size.x / 4.0
	for i in cells.size():
		var c = cells[i]
		var x: = i * w + 14.0
		if i > 0:
			draw_line(Vector2(i * w, 10), Vector2(i * w, size.y - 10), HAIR, 1.0)
		draw_string(mono, Vector2(x, 19), c[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 9, MUTED)
		draw_string(mono, Vector2(x, 39), c[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, INK if c[4] == TEAL else c[4])
		var vw: = mono.get_string_size(c[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		draw_string(mono, Vector2(x + vw + 3, 39), c[2], HORIZONTAL_ALIGNMENT_LEFT, -1, 9, MUTED)
		var bw: = w - 28.0
		draw_rect(Rect2(x, 46, bw, 2), Color("e0d9cc"))
		draw_rect(Rect2(x, 46, bw * c[3], 2), c[4])
