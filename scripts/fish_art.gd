class_name FishArt
extends RefCounted

## Procedural "pixel-ish" fish drawing, shared by the world view (water
## shadows), the fish index grid, the catch popup and the detail panel.
## All shapes come from FishDB data (palette / shape / pattern) so adding a
## new fish needs no new art.

const ROWS := 11

static func hash_str(s: String) -> int:
	var h := 0
	for i in s.length():
		h = (h * 31 + s.unicode_at(i)) & 0xFFFFFF
	return h

static func _half_width(shape: String, v: float) -> float:
	match shape:
		"minnow":
			return pow(sin(PI * clampf(v, 0.03, 0.97)), 0.7) * 0.48
		"round":
			return sqrt(maxf(0.0, 1.0 - pow(2.0 * v - 1.0, 2.0))) * 0.50
		"long":
			return (1.0 - pow(absf(2.0 * v - 1.0), 4.0)) * 0.45
		"eel":
			return sqrt(maxf(0.0, 1.0 - pow(2.0 * v - 1.0, 2.0))) * 0.30
		"flat":
			return sqrt(maxf(0.0, 1.0 - pow(2.0 * v - 1.0, 2.0))) * 0.55
		"glow":
			return sqrt(maxf(0.0, 1.0 - pow(2.0 * v - 1.0, 2.0))) * 0.47
		"puffer":
			return pow(maxf(0.0, 1.0 - pow(2.0 * v - 1.0, 2.0)), 0.45) * 0.54
		"shark":
			return (1.0 - pow(absf(2.0 * v - 1.0), 2.6)) * 0.40
		"ray":
			return sqrt(maxf(0.0, 1.0 - pow(2.0 * v - 1.0, 2.0))) * 0.64
		"deep":
			return pow(maxf(0.0, 1.0 - absf(2.0 * v - 1.0)), 0.7) * 0.52
		"ribbon":
			return (1.0 - pow(absf(2.0 * v - 1.0), 2.0)) * 0.16
		_:
			return sqrt(maxf(0.0, 1.0 - pow(2.0 * v - 1.0, 2.0))) * 0.48

static func draw_fish(ci: CanvasItem, rect: Rect2, fish: Dictionary,
		silhouette: bool = false, facing := 1.0) -> void:
	if fish.is_empty():
		return
	var shape: String = String(fish.get("shape", "minnow"))
	var pattern: String = String(fish.get("pattern", "plain"))
	var pal: Dictionary = fish.get("palette", {})
	var body_c := Color(String(pal.get("body", "#c8d2d8")))
	var belly_c := Color(String(pal.get("belly", "#e8eef2")))
	var fin_c := Color(String(pal.get("fin", "#9fb0bb")))
	var eye_c := Color(String(pal.get("eye", "#1b2430")))
	if silhouette:
		body_c = Color("#243244")
		belly_c = Color("#243244")
		fin_c = Color("#243244")

	var unit: float = rect.size.y / float(ROWS)
	var body_w: float = floor(rect.size.x / unit) * unit
	var x0: float = rect.position.x + (rect.size.x - body_w) * 0.5
	var y0: float = rect.position.y
	var cols: int = maxi(3, int(body_w / unit))
	var fish_seed := hash_str(String(fish.get("id", "x")))
	var outline := Color("#141d27")

	# --- tail (drawn first, sits behind the body) ---
	var back_x: float = x0 if facing > 0.0 else x0 + body_w
	var tail_reach: float = clampf(body_w * 0.30, unit * 1.5, unit * 4.0)
	var p1 := Vector2(back_x, y0 + 2.2 * unit)
	var p2 := Vector2(back_x + tail_reach * facing, y0 + 5.5 * unit)
	var p3 := Vector2(back_x, y0 + 8.8 * unit)
	var p4 := Vector2(back_x + tail_reach * 0.45 * facing, y0 + 5.5 * unit)
	var tc := fin_c if not silhouette else outline
	if shape == "eel" or shape == "long":
		# pointed tail
		ci.draw_colored_polygon(PackedVector2Array([p1, p2, p3]), tc)
	else:
		ci.draw_colored_polygon(PackedVector2Array([p1, p2, p4]), tc)
		ci.draw_colored_polygon(PackedVector2Array([p4, p2, p3]), tc)

	# --- dorsal + pelvic fins ---
	var fin_top_x: float = x0 + body_w * (0.30 if facing > 0.0 else 0.62)
	var fin_w: float = body_w * 0.30
	var d1 := Vector2(fin_top_x, y0 - unit * 0.9)
	var d2 := Vector2(fin_top_x + fin_w * 0.55, y0 + unit * 1.6)
	var d3 := Vector2(fin_top_x + fin_w, y0 + unit * 0.4)
	ci.draw_colored_polygon(PackedVector2Array([d1, d2, d3]), tc)
	var fin_bot_x: float = x0 + body_w * (0.42 if facing > 0.0 else 0.70)
	var b1 := Vector2(fin_bot_x, y0 + 10.2 * unit)
	var b2 := Vector2(fin_bot_x + fin_w * 0.45, y0 + 9.0 * unit)
	var b3 := Vector2(fin_bot_x + fin_w * 0.7, y0 + 10.6 * unit)
	ci.draw_colored_polygon(PackedVector2Array([b1, b2, b3]), tc)

	# --- body, one chunky pixel row at a time ---
	for r in range(ROWS):
		var v := (float(r) + 0.5) / float(ROWS)
		var hw: float = _half_width(shape, v) * body_w
		if hw < unit * 0.45:
			continue
		var cx: float = x0 + body_w * 0.5
		var ry := y0 + float(r) * unit
		# soft outline pass
		ci.draw_rect(Rect2(cx - hw - unit, ry - unit * 0.35, hw * 2.0 + unit * 2.0, unit * 1.7), outline)
		var c := body_c
		if v > 0.62:
			c = body_c.lerp(belly_c, (v - 0.62) / 0.38)
		ci.draw_rect(Rect2(cx - hw, ry, hw * 2.0, unit), c)

	# --- patterns ---
	for r in range(ROWS):
		var v := (float(r) + 0.5) / float(ROWS)
		var hw: float = _half_width(shape, v) * body_w
		if hw < unit * 0.45:
			continue
		var cx: float = x0 + body_w * 0.5
		var ry := y0 + float(r) * unit
		match pattern:
			"stripes":
				var phase := float((fish_seed + r * 7) % 3)
				if phase == 0.0 or phase == 1.0:
					ci.draw_rect(Rect2(cx - hw * 0.7, ry, hw * 1.4, unit), fin_c.darkened(0.15))
			"bands":
				var b := float(r)
				if b > 2.0 and b < 3.6 or b > 7.0 and b < 8.6:
					ci.draw_rect(Rect2(cx - hw * 0.85, ry, hw * 1.7, unit), fin_c.darkened(0.25))
			"spots":
				for c in range(cols):
					var cf := (float(c) + 0.5) / float(cols)
					if absf(cf - 0.5) * 2.0 > _half_width(shape, v) * 2.0:
						continue
					if (fish_seed + c * 13 + r * 5) % 5 == 0:
						var sx: float = x0 + float(c) * unit + unit * 0.25
						ci.draw_rect(Rect2(sx, ry + unit * 0.25, unit * 0.5, unit * 0.5), fin_c.darkened(0.35))
			"sparkle", "glow":
				if (fish_seed + r * 3) % 4 == 0:
					var sx: float = cx - unit * 0.25
					ci.draw_rect(Rect2(sx, ry, unit * 0.5, unit * 0.5), Color(1, 1, 1, 0.55))
			"checker":
				for c in range(cols):
					if (c + r) % 2 != 0:
						continue
					var sx: float = x0 + float(c) * unit
					var cx1: float = maxf(sx, cx - hw)
					var cx2: float = minf(sx + unit, cx + hw)
					if cx2 - cx1 < unit * 0.3:
						continue
					ci.draw_rect(Rect2(cx1, ry, cx2 - cx1, unit), fin_c.darkened(0.18))
			"speckle":
				for c in range(cols):
					if (fish_seed + c * 7 + r * 11) % 4 != 0:
						continue
					var sx: float = x0 + float(c) * unit + unit * 0.3
					if sx < cx - hw or sx + unit * 0.4 > cx + hw:
						continue
					ci.draw_rect(Rect2(sx, ry + unit * 0.3, unit * 0.4, unit * 0.4), fin_c.darkened(0.3))
			"scales":
				for c in range(cols):
					if (c + (r % 2)) % 2 != 0:
						continue
					var sx: float = x0 + float(c) * unit
					var cx1: float = maxf(sx, cx - hw)
					var cx2: float = minf(sx + unit, cx + hw)
					if cx2 - cx1 < unit * 0.3:
						continue
					ci.draw_rect(Rect2(cx1, ry, cx2 - cx1, unit * 0.85), body_c.lightened(0.14))
			"glow_veins":
				if (fish_seed + r * 5) % 3 == 0:
					ci.draw_rect(Rect2(cx - hw * 0.6, ry, unit * 0.45, unit), Color(1, 1, 1, 0.32))
					ci.draw_rect(Rect2(cx + hw * 0.35, ry, unit * 0.45, unit), Color(1, 1, 1, 0.32))

	# --- species features (whiskers, bills, sails, spikes, fangs, lanterns...) ---
	_draw_features(ci, fish, x0, body_w, y0, unit, facing, fin_c, silhouette)

	# --- eye ---
	var features: Array = fish.get("features", [])
	var er: float = unit * (0.85 if features.has("big_eye") else 0.5)
	var ex: float = x0 + body_w * (0.66 if facing > 0.0 else 0.26)
	var ey := y0 + 4.2 * unit
	ci.draw_rect(Rect2(ex - er, ey - er, er * 2.0, er * 2.0), Color("#f7f2e6") if not silhouette else outline)
	var pr := er * 0.45
	ci.draw_rect(Rect2(ex - pr, ey - pr, pr * 2.0, pr * 2.0), eye_c if not silhouette else outline)

	# --- glow halo for lantern/deep-sea fish ---
	if (shape == "glow" or pattern == "glow") and not silhouette:
		var gc := body_c.lerp(Color("#ffffff"), 0.55)
		for i in range(3):
			var rr: float = body_w * (0.30 + 0.22 * float(i))
			ci.draw_circle(Vector2(x0 + body_w * 0.5, y0 + 5.5 * unit), rr, Color(gc.r, gc.g, gc.b, 0.10))


## Extra silhouettes that make a species read as itself: whiskers, bills,
## horns, sails, spikes, fangs, lanterns, wings, crests, streamers and the
## hammerhead's T-bar. Everything is drawn from the fish's own fin color so
## night silhouettes stay one flat shape.
static func _draw_features(ci: CanvasItem, fish: Dictionary, x0: float, body_w: float,
		y0: float, unit: float, facing: float, fin_c: Color, silhouette: bool) -> void:
	var features: Array = fish.get("features", [])
	if features.is_empty():
		return
	var fc := Color("#141d27") if silhouette else fin_c
	var pale := Color("#141d27") if silhouette else fin_c.lightened(0.5)
	var head_x: float = x0 + body_w * (0.86 if facing > 0.0 else 0.14)
	var tail_x: float = x0 + body_w * (0.06 if facing > 0.0 else 0.94)
	for feat in features:
		match String(feat):
			"whiskers":
				var root := Vector2(head_x, y0 + 7.4 * unit)
				for i in range(3):
					var tip := root + Vector2(facing * body_w * (0.20 + 0.08 * float(i)),
							(0.4 + float(i) * 1.3) * unit)
					ci.draw_line(root, tip, fc, maxf(1.0, unit * 0.22))
			"bill":
				var top := Vector2(head_x, y0 + 4.6 * unit)
				var bot := Vector2(head_x, y0 + 6.4 * unit)
				var tip := Vector2(head_x + facing * body_w * 0.55, y0 + 5.2 * unit)
				ci.draw_colored_polygon(PackedVector2Array([top, tip, bot]), fc)
			"horn":
				var base := Vector2(head_x - facing * body_w * 0.14, y0 + 2.2 * unit)
				ci.draw_colored_polygon(PackedVector2Array([Vector2(base.x - unit, base.y),
						Vector2(base.x + unit, base.y),
						Vector2(head_x + facing * body_w * 0.08, y0 - unit * 1.8)]), fc)
			"sail":
				var a := Vector2(x0 + body_w * (0.26 if facing > 0.0 else 0.74), y0 + unit)
				var b := Vector2(x0 + body_w * (0.34 if facing > 0.0 else 0.66), y0 - unit * 3.2)
				var c := Vector2(x0 + body_w * (0.72 if facing > 0.0 else 0.28), y0 - unit * 2.6)
				var d := Vector2(x0 + body_w * (0.80 if facing > 0.0 else 0.20), y0 + unit)
				ci.draw_colored_polygon(PackedVector2Array([a, b, c, d]), fc)
				for i in range(4):
					var rx := a.lerp(d, (float(i) + 1.0) / 5.0)
					ci.draw_line(rx, Vector2(rx.x, rx.y - unit * (1.9 + 0.5 * float(i))),
							fc.darkened(0.25), maxf(1.0, unit * 0.2))
			"spikes":
				for i in range(5):
					var sx: float = x0 + body_w * (0.18 + float(i) * 0.16)
					var fy: float = y0 + unit * (1.6 + 1.1 * sin(float(i) * 1.3))
					ci.draw_colored_polygon(PackedVector2Array([Vector2(sx - unit * 0.7, fy),
							Vector2(sx + unit * 0.7, fy), Vector2(sx, fy - unit * 1.5)]), fc)
					var by: float = y0 + unit * (9.6 - 1.0 * sin(float(i) * 1.1))
					ci.draw_colored_polygon(PackedVector2Array([Vector2(sx - unit * 0.7, by),
							Vector2(sx + unit * 0.7, by), Vector2(sx, by + unit * 1.5)]), fc)
			"fangs":
				var mouth := Vector2(head_x, y0 + 6.6 * unit)
				for i in range(2):
					var fx: float = mouth.x + facing * float(i) * unit * 1.3
					ci.draw_colored_polygon(PackedVector2Array([Vector2(fx - unit * 0.5, mouth.y),
							Vector2(fx + unit * 0.5, mouth.y), Vector2(fx, mouth.y + unit * 1.5)]), pale)
			"lantern":
				var base := Vector2(head_x - facing * body_w * 0.04, y0 + 2.6 * unit)
				var tip := Vector2(head_x + facing * body_w * 0.34, y0 - unit * 1.2)
				ci.draw_line(base, tip, fc, maxf(1.0, unit * 0.3))
				if not silhouette:
					var glow := Color("#bfe9ff")
					ci.draw_circle(tip, unit * 1.1, Color(glow.r, glow.g, glow.b, 0.35))
					ci.draw_circle(tip, unit * 0.55, glow)
			"wings":
				var shoulder := Vector2(x0 + body_w * (0.52 if facing > 0.0 else 0.48), y0 + 4.0 * unit)
				var tip1 := Vector2(x0 + body_w * (0.02 if facing > 0.0 else 0.98), y0 + 9.6 * unit)
				var tip2 := Vector2(x0 + body_w * (0.98 if facing > 0.0 else 0.02), y0 + 8.6 * unit)
				ci.draw_colored_polygon(PackedVector2Array([shoulder, tip1, tip2]), fc)
				var top1 := Vector2(x0 + body_w * (0.06 if facing > 0.0 else 0.94), y0 + unit * 0.6)
				var top2 := Vector2(x0 + body_w * (0.94 if facing > 0.0 else 0.06), y0 + unit * 0.6)
				ci.draw_colored_polygon(PackedVector2Array([
						Vector2(shoulder.x, y0 + 2.0 * unit), top1, top2]), fc)
			"streamer":
				var root := Vector2(tail_x, y0 + 2.0 * unit)
				ci.draw_line(root, root + Vector2(-facing * body_w * 0.85, -unit * 0.8),
						fc, maxf(1.0, unit * 0.35))
				var root2 := Vector2(tail_x, y0 + 8.6 * unit)
				ci.draw_line(root2, root2 + Vector2(-facing * body_w * 0.85, unit * 0.8),
						fc, maxf(1.0, unit * 0.35))
			"crest":
				for i in range(4):
					var sx: float = head_x - facing * body_w * (0.02 + float(i) * 0.07)
					var h := unit * (1.4 + 0.7 * float(i))
					ci.draw_colored_polygon(PackedVector2Array([Vector2(sx - unit * 0.6, y0 + unit * 1.4),
							Vector2(sx + unit * 0.6, y0 + unit * 1.4),
							Vector2(sx, y0 + unit * 1.4 - h)]), fc)
			"hammer":
				ci.draw_rect(Rect2(head_x - unit * 0.9, y0 - unit * 0.6,
						unit * 1.8, unit * 8.2), fc)
				for sgn in [-1.0, 1.0]:
					var hy: float = y0 + unit * (1.2 if sgn < 0.0 else 7.2)
					ci.draw_circle(Vector2(head_x + facing * unit * 1.3, hy), unit * 0.9, pale)