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

	# --- eye ---
	var ex: float = x0 + body_w * (0.66 if facing > 0.0 else 0.26)
	var ey := y0 + 4.2 * unit
	ci.draw_rect(Rect2(ex - unit * 0.45, ey - unit * 0.45, unit, unit), Color("#f7f2e6") if not silhouette else outline)
	ci.draw_rect(Rect2(ex - unit * 0.12, ey - unit * 0.12, unit * 0.45, unit * 0.45), eye_c if not silhouette else outline)

	# --- glow halo for lantern/deep-sea fish ---
	if (shape == "glow" or pattern == "glow") and not silhouette:
		var gc := body_c.lerp(Color("#ffffff"), 0.55)
		for i in range(3):
			var rr: float = body_w * (0.30 + 0.22 * float(i))
			ci.draw_circle(Vector2(x0 + body_w * 0.5, y0 + 5.5 * unit), rr, Color(gc.r, gc.g, gc.b, 0.10))