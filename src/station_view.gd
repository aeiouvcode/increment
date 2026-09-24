extends Control


const C_WALL: = Color("e3ddd1")
const C_WALL_B: = Color("d9d2c4")
const C_CEIL: = Color("efebe3")
const C_DECK: = Color("cfc7b8")
const C_INK: = Color("2a2e31")
const C_LINE: = Color(0.16, 0.18, 0.19, 0.55)
const C_FAINT: = Color(0.16, 0.18, 0.19, 0.18)
const C_TEAL: = Color("2c6a64")
const C_RAIL: = Color("c4a55a")
const C_SPACE: = Color("0f1519")
const BACK: = 0.62
const MID: = 0.8
const LOC_X: = {"cq": 150.0, "galley": 360.0, "lab": 600.0, "ared": 830.0, "whc": 985.0, "cupola": 1150.0}
const MODULES: = [[0.0, "NODE 2"], [250.0, "NODE 1"], [470.0, "LAB"], [720.0, "NODE 3"], [1060.0, "CUPOLA"]]
const W: = 1290.0

const Sim: = preload("res://sim.gd")
var sim: Sim
var font: Font
var mono: Font
var cam_x: = 450.0
var astro: = Vector2(600, 0)
var astro_target: = 600.0
var tt: = 0.0
var items: Array = []
var caption: = ""
var caption_t: = 0.0
var earth: ImageTexture
var lights: PackedVector2Array
var mode: = "station"
var cam: = {}
var flash: = 0.0
var title_mode: = false
var mate: = Vector2(360, 0)
var mate_target: = 360.0
var mate_timer: = 4.0
const MATE_SPOTS: = [150.0, 360.0, 560.0, 640.0, 830.0, 985.0]

signal camera_done(frames: int, note: String)

func _ready() -> void :
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	_make_earth()
	var r: = RandomNumberGenerator.new()
	r.seed = 9
	var kinds: = ["pouch", "pen", "drop", "washer", "pouch", "drop", "pen", "drop", "washer", "pouch", "pen", "drop", "card", "card"]
	for i in kinds.size():
		items.append({"k": kinds[i], "p": Vector2(r.randf_range(80, W - 80), r.randf_range(-60, 60)), 
			"v": Vector2(r.randf_range(-6, 6), r.randf_range(-3, 3)), "a": r.randf() * TAU, "w": r.randf_range(-0.5, 0.5), 
			"z": r.randf_range(0.15, 0.95) if i % 3 == 0 else r.randf_range(0.6, 0.95)})

func _make_earth() -> void :
	var n: = FastNoiseLite.new()
	n.seed = 21
	n.frequency = 0.012
	n.fractal_octaves = 5
	var c: = FastNoiseLite.new()
	c.seed = 5
	c.frequency = 0.02
	c.fractal_octaves = 4
	var img: = Image.create(512, 256, false, Image.FORMAT_RGBA8)
	var r: = RandomNumberGenerator.new()
	r.seed = 3
	lights = PackedVector2Array()
	for y in 256:
		for x in 512:

			var ang: = float(x) / 512.0 * TAU
			var px: = cos(ang) * 81.5
			var pz: = sin(ang) * 81.5
			var h: = n.get_noise_3d(px, float(y), pz)
			var col: Color
			if h < 0.04:
				col = Color("2d5a78").lerp(Color("3f7593"), clampf((h + 0.5) * 1.4, 0.0, 1.0))
				if h > 0.0:
					col = col.lerp(Color("5f9aa3"), (h / 0.04) * 0.6)
			else:
				var dry: = clampf(n.get_noise_3d(px * 0.5 + 40.0, float(y) * 0.5, pz * 0.5) * 2.0 + 0.5, 0.0, 1.0)
				col = Color("5d7651").lerp(Color("b59f76"), dry)
				col = col.darkened(clampf((h - 0.04) * 1.2, 0.0, 0.35))
				if r.randf() < 0.004:
					lights.append(Vector2(x, y))
			var cl: = c.get_noise_3d(px * 1.3, float(y) * 1.6, pz * 1.3)
			if cl > -0.02:
				col = col.lerp(Color("f4f3ee"), clampf((cl + 0.02) * 2.6, 0.0, 0.94))
			img.set_pixel(x, y, col)
	img.generate_mipmaps()
	earth = ImageTexture.create_from_image(img)

func say(text: String, secs: = 7.0) -> void :
	caption = text
	caption_t = secs

func _process(delta: float) -> void :
	tt += delta
	caption_t = maxf(0.0, caption_t - delta)
	flash = maxf(0.0, flash - delta * 3.0)
	if sim:
		var a: Dictionary = sim.current()
		var loc: = "cupola" if title_mode else ("cq" if sim.sleeping else (a.get("loc", "lab") if not a.is_empty() else "lab"))
		astro_target = LOC_X.get(loc, 600.0)
		if not a.is_empty() and a.kind == "exercise":
			astro_target = LOC_X.ared
	var wander: = sin(tt * 0.23) * 26.0 + sin(tt * 0.61 + 1.3) * 9.0
	astro.x = lerpf(astro.x, astro_target + wander, 1.0 - exp( - delta * 1.1))
	mate_timer -= delta
	if mate_timer <= 0.0:
		mate_timer = randf_range(7.0, 14.0)
		mate_target = MATE_SPOTS[randi() % MATE_SPOTS.size()]
	mate.x = lerpf(mate.x, mate_target + sin(tt * 0.31 + 2.0) * 20.0, 1.0 - exp( - delta * 0.5))
	var want: = clampf(astro.x - size.x * 0.5 + sin(tt * 0.13) * 14.0, -40.0, W - size.x + 40.0)
	cam_x = lerpf(cam_x, want, 1.0 - exp( - delta * 1.4))
	for it in items:
		it.p += it.v * delta
		it.a += it.w * delta
		if it.p.x < 40 or it.p.x > W - 40:
			it.v.x = - it.v.x
		if absf(it.p.y) > 70:
			it.v.y = - it.v.y
	if mode == "camera":
		_camera_tick(delta)
	queue_redraw()



func _proj(x: float, y: float, z: float) -> Vector2:

	var s: = lerpf(1.0, BACK, z)
	var c: = size * 0.5
	var sx: = c.x + (x - cam_x - c.x) * s
	var sy: = c.y + y * c.y * s
	return Vector2(sx, sy)

func _draw() -> void :
	if mode == "camera":
		_draw_camera()
		return
	var h: = size.y
	var c: = size * 0.5
	var bt: = c.y - c.y * BACK
	var bb: = c.y + c.y * BACK
	var dim: = 0.0
	if sim and not sim.sunlit():
		dim = 0.06
	if sim and sim.sleeping:
		dim = 0.28

	draw_rect(Rect2(0, 0, size.x, h), C_WALL)
	draw_colored_polygon(PackedVector2Array([Vector2(-2000, 0), Vector2(3000, 0), Vector2(3000, bt), Vector2(-2000, bt)]), C_CEIL)
	draw_colored_polygon(PackedVector2Array([Vector2(-2000, bb), Vector2(3000, bb), Vector2(3000, h), Vector2(-2000, h)]), C_DECK)

	var x0: = floorf(cam_x / 130.0) * 130.0 - 260.0
	var lx: = x0
	while lx < cam_x + size.x + 400:
		var a: = _proj(lx + 20, -1, 0.0)
		var b: = _proj(lx + 90, -1, 0.0)
		var a2: = _proj(lx + 20, -1, 0.7)
		var b2: = _proj(lx + 90, -1, 0.7)
		a.y = 0;b.y = 0
		draw_colored_polygon(PackedVector2Array([a, b, b2, a2]), Color(1, 1, 0.98, 0.9))
		draw_polyline(PackedVector2Array([a, a2, b2, b]), C_FAINT, 1.0, true)

		var d1: = _proj(lx, 1, 0.0)
		var d2: = _proj(lx, 1, 1.0)
		draw_line(d1, d2, C_FAINT, 1.0, true)
		var c1: = _proj(lx, -1, 0.0)
		var c2: = _proj(lx, -1, 1.0)
		draw_line(c1, c2, C_FAINT, 1.0, true)
		lx += 130.0

	draw_line(Vector2(-10, bt), Vector2(size.x + 10, bt), C_LINE, 1.0, true)
	draw_line(Vector2(-10, bb), Vector2(size.x + 10, bb), C_LINE, 1.0, true)
	_draw_racks()
	_draw_modules()
	_draw_props()
	_draw_air()
	_draw_person(mate, Color("9a5b3f"), Color("5d6a70"), 0.86, 1.7, false)

	for it in items:
		if it.z > MID:
			_draw_item(it)
	_draw_astronaut()
	for it in items:
		if it.z <= MID:
			_draw_item(it)

	var ry: = h - 16.0
	var rx: = fmod( - cam_x * 1.25, 180.0) - 180.0
	while rx < size.x + 180:
		draw_line(Vector2(rx + 20, ry), Vector2(rx + 120, ry), C_RAIL, 5.0, true)
		draw_line(Vector2(rx + 22, ry), Vector2(rx + 22, h), C_RAIL.darkened(0.2), 3.0, true)
		draw_line(Vector2(rx + 118, ry), Vector2(rx + 118, h), C_RAIL.darkened(0.2), 3.0, true)
		rx += 180.0
	if dim > 0.0:
		draw_rect(Rect2(0, 0, size.x, h), Color(0.08, 0.1, 0.13, dim))
	_draw_inset()
	if caption_t > 0.0 and caption != "":
		_draw_caption()

func _draw_racks() -> void :

	var rx: = floorf((cam_x - 300.0) / 80.0) * 80.0
	while rx < cam_x + size.x + 400.0:
		var skip: = false
		for m in MODULES:
			if absf(rx - m[0]) < 45.0:
				skip = true
		if rx > 1080.0:
			skip = true
		if not skip:
			var tl: = _proj(rx + 4, -0.92, 1.0)
			var br: = _proj(rx + 76, 0.92, 1.0)
			var r: = Rect2(tl, br - tl)
			draw_rect(r, C_WALL_B)
			draw_rect(r, C_LINE, false, 1.0, true)
			var seed_i: = int(rx / 80.0)
			var pattern: = posmod(seed_i * 7 + 3, 5)
			var w: = r.size.x
			var hh: = r.size.y
			match pattern:
				0, 1:
					for j in 3:
						for i in 2:
							var lr: = Rect2(r.position + Vector2(4 + i * (w - 8) * 0.5, 6 + j * (hh - 12) / 3.0), Vector2((w - 12) * 0.5, (hh - 12) / 3.0 - 4))
							draw_rect(lr, C_FAINT, false, 1.0, true)
							draw_circle(lr.position + Vector2(lr.size.x - 5, lr.size.y * 0.5), 1.4, C_LINE)
				2:
					var lap: = Rect2(r.position + Vector2(8, hh * 0.28), Vector2(w - 16, hh * 0.26))
					draw_rect(lap, Color("2d3337"))
					var glow: = 0.5 + 0.5 * sin(tt * 0.7 + seed_i)
					draw_rect(lap.grow(-2), Color("3b5f63").lerp(Color("4d7a75"), glow * 0.4))
					var scroll_i: = int(tt * 1.5)
					for q in 4:
						var ln: = (0.3 + 0.18 * float(posmod((q + scroll_i) * 3 + seed_i, 4)))
						draw_line(lap.position + Vector2(5, 6 + q * 5), lap.position + Vector2(5 + (lap.size.x - 12) * ln, 6 + q * 5), Color(0.9, 0.95, 0.9, 0.5), 1.0)
					draw_line(lap.position + Vector2(lap.size.x * 0.5, lap.size.y), r.position + Vector2(w * 0.3, hh), C_LINE, 1.0, true)
				3:
					for q in 5:
						var yy: = r.position.y + 8 + q * (hh - 16) / 4.0
						draw_line(Vector2(r.position.x + 6, yy), Vector2(r.end.x - 6, yy), C_FAINT, 1.0)
					draw_rect(Rect2(r.position + Vector2(w * 0.2, hh * 0.6), Vector2(w * 0.6, hh * 0.22)), Color("c9c1b1"))
				4:
					var bag: = Rect2(r.position + Vector2(6, 8), Vector2(w - 12, hh * 0.5))
					draw_rect(bag, Color("d6ccb6"))
					draw_rect(bag, C_FAINT, false, 1.0, true)
					draw_line(bag.position + Vector2(4, bag.size.y * 0.5), bag.end - Vector2(4, bag.size.y * 0.5), C_FAINT, 1.0)

					var sag: = sin(tt * 0.9 + seed_i) * 3.0
					draw_polyline(PackedVector2Array([Vector2(r.position.x, r.position.y + hh * 0.7), Vector2(r.position.x + w * 0.5, r.position.y + hh * 0.74 + sag), Vector2(r.end.x, r.position.y + hh * 0.75)]), Color("5f6b6e"), 1.5, true)

			for li in 3:
				var ph: = sin(tt * (0.8 + 0.37 * float(posmod(seed_i * 5 + li, 7))) + float(seed_i + li))
				var lc: = Color("3f8d84") if li != 1 else Color("d69a45")
				lc.a = 0.25 + 0.75 * clampf(ph * 3.0, 0.0, 1.0)
				draw_circle(Vector2(r.end.x - 7.0, r.position.y + 7.0 + li * 5.0), 1.6, lc)

			var hr: = _proj(rx + 12, 0.8, 1.0)
			var hr2: = _proj(rx + 44, 0.8, 1.0)
			draw_line(hr, hr2, C_RAIL, 2.5, true)
		rx += 80.0

func _draw_modules() -> void :
	for m in MODULES:
		var x: float = m[0]

		var t1: = _proj(x - 14, -1, 1.0)
		var t2: = _proj(x + 14, 1, 1.0)
		draw_rect(Rect2(t1, t2 - t1), Color("d2cabb"))
		for yy in [-1.0, 1.0]:
			var p1: = _proj(x - 14, yy, 0.0)
			var p2: = _proj(x + 14, yy, 0.0)
			var p3: = _proj(x + 14, yy, 1.0)
			var p4: = _proj(x - 14, yy, 1.0)
			draw_colored_polygon(PackedVector2Array([p1, p2, p3, p4]), Color(0.72, 0.68, 0.61, 0.5))
		draw_line(_proj(x - 14, -1, 1.0), _proj(x - 14, 1, 1.0), C_LINE, 1.0, true)
		draw_line(_proj(x + 14, -1, 1.0), _proj(x + 14, 1, 1.0), C_LINE, 1.0, true)
		var lp: = _proj(x + 22, -0.86, 1.0)
		draw_string(mono, lp, m[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.16, 0.18, 0.19, 0.6))

func _draw_props() -> void :

	var q1: = _proj(LOC_X.cq - 40, -0.7, 1.0)
	var q2: = _proj(LOC_X.cq + 40, 0.7, 1.0)
	var qr: = Rect2(q1, q2 - q1)
	draw_rect(qr, Color("d8cfbf"))
	draw_rect(qr, C_LINE, false, 1.0, true)
	if not (sim and sim.sleeping):
		var bag: = Rect2(qr.position + Vector2(qr.size.x * 0.3, 8), Vector2(qr.size.x * 0.4, qr.size.y - 16))
		draw_rect(bag, Color("7a8a8f"))
		draw_line(bag.position + Vector2(bag.size.x * 0.5, 6), bag.position + Vector2(bag.size.x * 0.5, bag.size.y - 6), Color(1, 1, 1, 0.35), 1.0)

	var g: = _proj(LOC_X.galley - 30, -0.2, 1.0)
	var g2: = _proj(LOC_X.galley + 30, 0.3, 1.0)
	draw_rect(Rect2(g, g2 - g), Color("b9b3a6"))
	draw_rect(Rect2(g + Vector2(4, 4), Vector2((g2 - g).x - 8, 8)), Color("8f8a80"))
	for i in 4:
		var pp: = _proj(LOC_X.galley - 26 + i * 16, 0.45, 1.0)
		draw_rect(Rect2(pp, Vector2(8, 13)), Color("e9e6df"))
		draw_rect(Rect2(pp, Vector2(8, 13)), C_FAINT, false, 1.0)

	var af: = _proj(LOC_X.ared - 34, 1.0, 0.55)
	var at: = _proj(LOC_X.ared - 34, -0.35, 0.55)
	var af2: = _proj(LOC_X.ared + 34, 1.0, 0.55)
	var at2: = _proj(LOC_X.ared + 34, -0.35, 0.55)
	draw_line(af, at, Color("6d7477"), 4.0, true)
	draw_line(af2, at2, Color("6d7477"), 4.0, true)
	var bar_y: = -0.1
	if sim and not sim.current().is_empty() and sim.current().kind == "exercise" and sim.current().running:
		bar_y = -0.1 + 0.22 * (0.5 + 0.5 * sin(tt * 2.6))
	draw_line(_proj(LOC_X.ared - 44, bar_y, 0.55), _proj(LOC_X.ared + 44, bar_y, 0.55), C_INK, 3.0, true)

	var w1: = _proj(LOC_X.whc - 26, -0.5, 1.0)
	var w2: = _proj(LOC_X.whc + 26, 0.6, 1.0)
	draw_rect(Rect2(w1, w2 - w1), Color("cdd3d2"))
	draw_rect(Rect2(w1, w2 - w1), C_LINE, false, 1.0, true)
	var hose: = PackedVector2Array()
	for i in 12:
		var f: = float(i) / 11.0
		hose.append(_proj(LOC_X.whc + 10 + sin(f * 3.0 + tt * 0.4) * 6.0, 0.1 + f * 0.6, 0.9))
	draw_polyline(hose, Color("e6c36a"), 2.0, true)

	var cc: = _proj(LOC_X.cupola, -0.02, 1.0)
	var cr: = minf((size.y * 0.5) * BACK * 0.78, size.x * 0.34)
	_draw_window(cc, cr, C_WALL_B, 1.0)
	if sim and sim.sunlit():
		var beam: = PackedVector2Array([cc + Vector2( - cr * 0.7, cr * 0.3), cc + Vector2(cr * 0.7, cr * 0.3), _proj(LOC_X.cupola + 140, 1.0, 0.0), _proj(LOC_X.cupola - 60, 1.0, 0.0)])
		draw_colored_polygon(beam, Color(1.0, 0.93, 0.78, 0.18))

func _draw_window(c: Vector2, r: float, frame: Color, zoom: float) -> void :

	draw_circle(c, r, C_SPACE)
	var lit: bool = true if sim == null else sim.sunlit()
	var off: = 0.0 if sim == null else float(sim.total_minutes()) * 0.0105
	off += tt * 0.0004

	var R: = r * 3.2
	var ec: = c + Vector2(0, R - r * 0.25)
	var pts: = PackedVector2Array()
	var uvs: = PackedVector2Array()
	var n: = 48
	for i in 64:
		var ang: = TAU * float(i) / 64.0
		var p: = c + Vector2(cos(ang), sin(ang)) * r
		var dx: = p.x - ec.x
		var ly: = ec.y - sqrt(maxf(0.0, R * R - dx * dx))
		if p.y < ly:
			p.y = ly
		pts.append(p)
	for p in pts:
		var d: = (p - c) / (r * 2.0)
		uvs.append(Vector2(d.x * 0.35 * zoom + off, 0.5 + d.y * 0.35 * zoom))
	var tint: = Color(1, 1, 1, 1) if lit else Color(0.16, 0.19, 0.25, 1)
	draw_colored_polygon(pts, tint, uvs, earth)
	if not lit:
		for lp in lights:
			var u: = (lp.x / 512.0) - fposmod(off, 1.0)
			u = fposmod(u, 1.0)
			var dx: = (u - 0.5) / (0.35 * zoom) * r * 2.0 * 0.5
			var dy: = (lp.y / 256.0 - 0.5) / (0.35 * zoom) * r * 2.0 * 0.5
			var pp: = c + Vector2(dx, dy + r * 0.35)
			if pp.distance_to(c) < r - 2 and pp.distance_to(ec) < R:
				draw_circle(pp, 0.9, Color(1.0, 0.8, 0.45, 0.85))

	var limb: = PackedVector2Array()
	for i in n + 1:
		var ang2: = - PI * 0.5 - 0.75 + 1.5 * float(i) / float(n)
		var lpnt: = ec + Vector2(cos(ang2), sin(ang2)) * (R + 1.5)
		if lpnt.distance_to(c) < r - 1.0:
			limb.append(lpnt)
	var glow: = Color(0.55, 0.78, 0.95, 0.9) if lit else Color(0.3, 0.45, 0.7, 0.35)
	if limb.size() > 1:
		draw_polyline(limb, Color(glow.r, glow.g, glow.b, glow.a * 0.35), 5.0, true)
		draw_polyline(limb, glow, 1.6, true)

	draw_arc(c, r + 3.0, 0, TAU, 72, Color("bfb7a8"), 6.0, true)
	draw_arc(c, r + 6.5, 0, TAU, 72, C_LINE, 1.0, true)
	draw_arc(c, r - 0.5, 0, TAU, 72, Color(0, 0, 0, 0.35), 1.0, true)

	draw_arc(c, r * 0.78, -2.5, -1.9, 16, Color(1, 1, 1, 0.12), 2.0, true)

func _draw_inset() -> void :

	var cup: = _proj(LOC_X.cupola, 0, 1.0)
	if cup.x < size.x + 60 and cup.x > -60:
		return
	var c: = Vector2(size.x - 40, 40)
	draw_circle(c, 31, Color("bfb7a8"))
	_draw_window(c, 26, Color("bfb7a8"), 0.6)
	draw_arc(c, 31, 0, TAU, 48, C_LINE, 1.0, true)

func _draw_air() -> void :

	for k in 7:
		var ph: = fmod(tt * 0.12 + float(k) * 0.143, 1.0)
		var x: = cam_x - 60.0 + ph * (size.x + 200.0)
		var yy: = -0.72 + 0.12 * sin(float(k) * 2.1)
		var a: = _proj(x, yy, 0.45)
		var b: = _proj(x + 46.0, yy + 0.02, 0.45)
		var alpha: = 0.18 * sin(ph * PI)
		draw_line(a, b, Color(1, 1, 1, alpha), 1.2, true)

func _draw_person(pos: Vector2, polo: Color, shorts: Color, z: float, seed_f: float, reaching: bool) -> void :
	var y: = -0.02 + sin(tt * 0.7 + seed_f) * 0.07
	z = clampf(z + sin(tt * 0.11 + seed_f) * 0.07, 0.0, 0.95)
	var p: = _proj(pos.x, y, z)
	var sc: = lerpf(1.0, BACK, z) * 1.45
	var rot: = sin(tt * 0.33 + seed_f) * 0.16 + (mate_target - pos.x) * 0.0005
	draw_set_transform(p, rot, Vector2( - sc, sc))
	var skin: = Color("a8704f")
	var hair: = Color("1f1a17")
	_limb(Vector2(-2, 11), Vector2(8, 20), Vector2(3, 30), skin.darkened(0.15), 4.2)
	_limb(Vector2(-1, -15), Vector2(-9, -11 + sin(tt + seed_f) * 2.0), Vector2(-12, -18), skin.darkened(0.15), 3.4)
	draw_colored_polygon(PackedVector2Array([Vector2(-7, -18), Vector2(6, -18), Vector2(7, -4), Vector2(6, 5), Vector2(-6, 5), Vector2(-8, -4)]), polo)
	draw_colored_polygon(PackedVector2Array([Vector2(-6, 4), Vector2(6, 4), Vector2(7, 12), Vector2(-7, 12)]), shorts)
	_limb(Vector2(2, 11), Vector2(11, 19 + sin(tt * 0.8 + seed_f) * 1.5), Vector2(6, 29), skin, 4.6)
	draw_circle(Vector2(6, 29), 2.8, Color("e9e6df"))
	draw_circle(Vector2(0.5, -26), 6.4, skin)
	draw_arc(Vector2(0.5, -27), 6.6, PI * 0.95, TAU + 0.15, 18, hair, 3.6, true)
	var arm: = 0.5 + 0.5 * sin(tt * 1.1 + seed_f)
	_limb(Vector2(1, -15), Vector2(8, -12).lerp(Vector2(11, -17), arm), Vector2(13, -20).lerp(Vector2(18, -22), arm), skin, 3.8)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_item(it: Dictionary) -> void :
	var p: = _proj(it.p.x, it.p.y / 135.0, it.z)
	var s: = lerpf(1.0, BACK, it.z)
	draw_set_transform(p, it.a, Vector2(s, s))
	match it.k:
		"pouch":
			draw_rect(Rect2(-5, -7, 10, 14), Color("dcdcd6"))
			draw_rect(Rect2(-5, -7, 10, 14), C_LINE, false, 1.0)
			draw_rect(Rect2(-5, -7, 10, 4), Color("9aa6a8"))
		"pen":
			draw_line(Vector2(-8, 0), Vector2(8, 0), Color("39424a"), 2.0, true)
			draw_line(Vector2(6, 0), Vector2(9, 0), Color("c4a55a"), 2.0, true)
		"drop":
			var wob: = 1.0 + 0.08 * sin(tt * 3.0 + it.a * 5.0)
			draw_set_transform(p, 0.0, Vector2(s * wob, s / wob))
			draw_circle(Vector2.ZERO, 4.0, Color(0.7, 0.85, 0.9, 0.55))
			draw_circle(Vector2(-1.2, -1.4), 1.2, Color(1, 1, 1, 0.8))
		"washer":
			draw_arc(Vector2.ZERO, 3.5, 0, TAU, 16, Color("7c8285"), 2.0, true)
		"card":
			draw_rect(Rect2(-7, -5, 14, 10), Color("f4f1ea"))
			draw_rect(Rect2(-7, -5, 14, 10), C_LINE, false, 1.0)
			draw_line(Vector2(-4, -1), Vector2(4, -1), C_FAINT, 1.0)
			draw_line(Vector2(-4, 2), Vector2(2, 2), C_FAINT, 1.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_astronaut() -> void :
	var a: Dictionary = {} if sim == null else sim.current()
	var kind: String = "idle" if a.is_empty() else a.kind
	var working: bool = not a.is_empty() and a.running
	var sleeping: bool = sim != null and sim.sleeping
	var bob: = sin(tt * 0.9) * 0.05
	var y: = -0.05 + bob
	var rot: = sin(tt * 0.45) * 0.14 + sin(tt * 0.17) * 0.08 + (astro_target - astro.x) * 0.0009
	if kind == "exercise" and working:
		y = 0.05 + 0.08 * sin(tt * 2.6)
		rot = 0.0
	if sleeping:
		y = -0.02
		rot = 0.0
	var az: = 0.72
	if not sleeping and not (kind == "exercise" and working):
		az += sin(tt * 0.09 + 0.6) * 0.06
	var p: = _proj(astro.x, y, az)
	var sc: = lerpf(1.0, BACK, az) * 1.55
	draw_set_transform(p, rot, Vector2(sc, sc))
	var skin: = Color("c48d69")
	var hair: = Color("33272188")
	hair = Color("332721")
	if sleeping:
		draw_rect(Rect2(-9, -20, 18, 50), Color("6f8288"))
		draw_circle(Vector2(0, -24), 6.5, skin)
		draw_arc(Vector2(0, -25), 6.5, PI, TAU, 16, hair, 3.0, true)
		draw_line(Vector2(-6, -8), Vector2(6, -8), Color(1, 1, 1, 0.3), 1.0)
		var zz: = fmod(tt, 3.0) / 3.0
		draw_string(font, Vector2(9, -30 - zz * 16), "z", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.16, 0.18, 0.19, 0.6 * (1.0 - zz)))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	var polo: = C_TEAL
	var shorts: = Color("8b8471")
	var reach: = 0.0
	if working and kind in ["science", "maint", "fix", "ceo", "conf"]:
		reach = 0.5 + 0.5 * sin(tt * 3.2)

	var knee_b: = Vector2(8, 20)
	var foot_b: = Vector2(3, 30)
	if kind == "exercise" and working:
		knee_b = Vector2(7, 19 + 3 * sin(tt * 2.6))
	_limb(Vector2(-2, 11), knee_b, foot_b, skin.darkened(0.15), 4.2)
	draw_circle(foot_b, 2.6, Color("e9e6df").darkened(0.1))

	var drift: = sin(tt * 0.8) * 2.5
	_limb(Vector2(-1, -15), Vector2(-9, -11 + drift), Vector2(-12, -18 + drift * 1.4), skin.darkened(0.15), 3.4)

	draw_colored_polygon(PackedVector2Array([Vector2(-7, -18), Vector2(6, -18), Vector2(7, -4), Vector2(6, 5), Vector2(-6, 5), Vector2(-8, -4)]), polo)
	draw_line(Vector2(-2, -18), Vector2(0, -12), Color(1, 1, 1, 0.35), 1.0)
	draw_colored_polygon(PackedVector2Array([Vector2(-6, 4), Vector2(6, 4), Vector2(7, 12), Vector2(-7, 12)]), shorts)

	_limb(Vector2(2, 11), Vector2(11, 19), Vector2(6, 29), skin, 4.6)
	draw_circle(Vector2(6, 29), 2.8, Color("e9e6df"))

	draw_line(Vector2(0, -18), Vector2(0, -21), skin, 3.0)
	draw_circle(Vector2(0.5, -26), 6.4, skin)
	draw_arc(Vector2(0.5, -27), 6.6, PI * 0.95, TAU + 0.15, 18, hair, 3.6, true)
	draw_circle(Vector2(4.2, -26), 0.9, C_INK)

	var elbow: = Vector2(8, -12).lerp(Vector2(11, -16), reach)
	var hand: = Vector2(13, -20).lerp(Vector2(19, -18), reach)
	_limb(Vector2(1, -15), elbow, hand, skin, 3.8)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _limb(a: Vector2, b: Vector2, c: Vector2, col: Color, w: float) -> void :
	draw_line(a, b, col, w, true)
	draw_line(b, c, col, w * 0.92, true)
	draw_circle(a, w * 0.5, col)
	draw_circle(b, w * 0.5, col)
	draw_circle(c, w * 0.46, col)

func _draw_caption() -> void :
	var alpha: = clampf(caption_t, 0.0, 1.0)
	var pad: = 12.0
	var box_w: = size.x - 24.0
	var lines: = _wrap(caption, box_w - pad * 2, 12)
	var bh: = 14.0 + lines.size() * 16.0
	var r: = Rect2(12, size.y - bh - 12, box_w, bh)
	draw_rect(r, Color(0.97, 0.96, 0.93, 0.94 * alpha))
	draw_rect(r, Color(0.16, 0.18, 0.19, 0.25 * alpha), false, 1.0)
	draw_rect(Rect2(r.position, Vector2(3, r.size.y)), Color(C_TEAL.r, C_TEAL.g, C_TEAL.b, alpha))
	for i in lines.size():
		draw_string(font, r.position + Vector2(pad, 19 + i * 16), lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.13, 0.15, 0.16, alpha))

func _wrap(text: String, width: float, fs: int) -> Array:
	var out: Array = []
	var line: = ""
	for w in text.split(" "):
		var test: = w if line == "" else line + " " + w
		if font.get_string_size(test, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > width and line != "":
			out.append(line)
			line = w
		else:
			line = test
	if line != "":
		out.append(line)
	return out



func open_camera(target: String, in_window: bool) -> void :
	mode = "camera"
	cam = {"target": target, "ok": in_window, "pass": 0, "shots": 0, "hits": 0, "good": 0, "x": -0.25, "y": 0.0, "t": 0.0, 
		"result": "", "result_t": 0.0, "done_t": -1.0, "last": ""}
	if not in_window:
		cam.result = "The target already passed. No frames this orbit."
		cam.done_t = 2.6
	_new_pass()

func _new_pass() -> void :
	cam.x = -0.3
	cam.y = [0.12, -0.18, 0.05][int(cam.pass) % 3]

func shoot() -> void :
	if mode != "camera" or not cam.ok or cam.done_t >= 0.0:
		return
	flash = 1.0
	cam.shots += 1
	var d: float = Vector2(cam.x, cam.y).length()
	if d < 0.09:
		cam.good += 1
		cam.hits += 1
		cam.last = "Sharp, centered frame."
	elif d < 0.2:
		cam.hits += 1
		cam.last = "Usable, a little off center."
	else:
		cam.last = "Missed. Target out of frame."
	cam.result_t = 1.4
	if cam.shots >= 3:
		cam.done_t = 1.4

func _camera_tick(delta: float) -> void :
	cam.t += delta
	cam.result_t = maxf(0.0, cam.result_t - delta)
	if cam.done_t >= 0.0:
		cam.done_t -= delta
		if cam.done_t < 0.0:
			mode = "station"
			var note: = "No frames this orbit." if not cam.ok else "%d of 3 frames usable, %d sharp." % [cam.hits, cam.good]
			camera_done.emit(int(cam.hits), note)
		return
	cam.x += delta * 0.11
	if cam.x > 0.32:
		cam.pass += 1
		if cam.pass >= 3:
			cam.done_t = 0.8
			cam.last = "Pass complete."
			cam.result_t = 1.0
		else:
			_new_pass()

func _gui_input(e: InputEvent) -> void :
	if mode == "camera" and ((e is InputEventMouseButton and e.pressed) or (e is InputEventScreenTouch and e.pressed)):
		shoot()
		accept_event()

func _draw_camera() -> void :
	draw_rect(Rect2(Vector2.ZERO, size), Color("171c1f"))
	var c: = size * 0.5 + Vector2(0, -6)
	var r: = minf(size.x, size.y) * 0.42

	var pts: = PackedVector2Array()
	var uvs: = PackedVector2Array()
	var off: = float(cam.get("t", 0.0)) * 0.012
	for i in 48:
		var ang: = TAU * float(i) / 48.0
		var p: = c + Vector2(cos(ang), sin(ang)) * r
		pts.append(p)
		var d: = (p - c) / (r * 2.0)
		uvs.append(Vector2(0.4 + d.x * 0.09 + off, 0.45 + d.y * 0.09))
	draw_colored_polygon(pts, Color(1, 1, 1, 1), uvs, earth)

	if cam.get("ok", false) and cam.get("done_t", -1.0) < 0.0:
		var tp: Vector2 = c + Vector2(cam.x, cam.y) * r * 2.0
		if tp.distance_to(c) < r:
			for k in 4:
				draw_arc(tp, 5.0 + k * 5.0, 0, TAU, 32, Color(0.35, 0.25, 0.16, 0.55 - k * 0.1), 2.5, true)
			draw_circle(tp, 3.0, Color(0.42, 0.32, 0.22, 0.8))

	var rc: = Color(1, 1, 1, 0.8)
	var q: = 20.0
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			var corner: = c + Vector2(sx * q, sy * q)
			draw_line(corner, corner - Vector2(sx * 7, 0), rc, 1.5)
			draw_line(corner, corner - Vector2(0, sy * 7), rc, 1.5)
	draw_line(c - Vector2(r, 0), c - Vector2(r - 12, 0), rc, 1.0)
	draw_line(c + Vector2(r, 0), c + Vector2(r - 12, 0), rc, 1.0)

	draw_arc(c, r + 30, 0, TAU, 72, Color("171c1f"), 60.0, true)
	draw_arc(c, r + 1, 0, TAU, 72, Color(1, 1, 1, 0.25), 1.0, true)
	var shots_left: = 3 - int(cam.get("shots", 0))
	draw_string(mono, Vector2(14, 22), "400 mm · f/8 · 1/1000", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1, 1, 1, 0.6))
	var ft: = "FRAMES %d" % shots_left
	draw_string(mono, Vector2(size.x - 14 - mono.get_string_size(ft, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x, 22), ft, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1, 1, 1, 0.8))
	draw_string(font, Vector2(14, 40), str(cam.get("target", "")), HORIZONTAL_ALIGNMENT_LEFT, size.x - 28, 12, Color(1, 1, 1, 0.85))
	var msg: String = cam.get("result", "") if cam.get("result", "") != "" else (cam.get("last", "") if cam.get("result_t", 0.0) > 0.0 else "Tap when the target sits in the brackets")
	var mw: = font.get_string_size(msg, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	draw_string(font, Vector2(size.x - 14 - mw, size.y - 16), msg, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, 0.75))
	if flash > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, flash * 0.6))
