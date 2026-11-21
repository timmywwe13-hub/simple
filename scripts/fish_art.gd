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
	var w := 0.48
	match shape:
		"minnow":
			w = pow(sin(PI * clampf(v, 0.03, 0.97)), 0.7) * 0.48
		"round":
			w = sqrt(maxf(0.0, 1.0 - pow(2.0 * v - 1.0, 2.0))) * 0.50
		"long":
			w = (1.0 - pow(absf(2.0 * v - 1.0), 4.0)) * 0.45
		"eel":
			w = sqrt(maxf(0.0, 1.0 - pow(2.0 * v - 1.0, 2.0))) * 0.30
		"flat":
			w = sqrt(maxf(0.0, 1.0 - pow(2.0 * v - 1.0, 2.0))) * 0.55
		"glow":
			w = sqrt(maxf(0.0, 1.0 - pow(2.0 * v - 1.0, 2.0))) * 0.47
		"puffer":
			w = pow(maxf(0.0, 1.0 - pow(2.0 * v - 1.0, 2.0)), 0.45) * 0.54
		"shark":
			w = (1.0 - pow(absf(2.0 * v - 1.0), 2.6)) * 0.40
		"ray":
			w = sqrt(maxf(0.0, 1.0 - pow(2.0 * v - 1.0, 2.0))) * 0.64
		"deep":
			w = pow(maxf(0.0, 1.0 - absf(2.0 * v - 1.0)), 0.7) * 0.52
		"ribbon":
			w = (1.0 - pow(absf(2.0 * v - 1.0), 2.0)) * 0.16
		"serpent":
			# slim and whippy - a monster should never look fat
			w = pow(sin(PI * clampf(v, 0.03, 0.97)), 0.5) * 0.13
		_:
			w = sqrt(maxf(0.0, 1.0 - pow(2.0 * v - 1.0, 2.0))) * 0.48
	# Most fish are fuller at the shoulders than at the tail. A little
	# asymmetry stops the silhouette reading as a symmetric loaf.
	if shape == "minnow":
		w *= 0.58 + 0.42 * smoothstep(0.0, 0.42, v)
	elif shape == "long":
		w *= 0.55 + 0.45 * smoothstep(0.0, 0.36, v)
	elif shape == "shark":
		w *= 0.60 + 0.40 * smoothstep(0.0, 0.45, v)
	elif shape == "deep":
		w *= 0.66 + 0.34 * smoothstep(0.0, 0.42, v)
	return w


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
	var features: Array = fish.get("features", [])

	# 13.6 units of vertical room: the body is 11 rows, plus the dorsal fin
	# above and the pelvic fin below. Fitting them inside the rect keeps
	# fins out of the catch-card text and the index border.
	var unit: float = maxf(1.0, rect.size.y / 13.6)
	var y0: float = rect.position.y + unit * 1.9
	# Reserve room inside the rect for the tail, the bill/whiskers and any
	# long streamers, so a fish is never drawn with its tail chopped off.
	var tail_frac := 0.30 + (0.45 if features.has("streamer") else 0.0)
	var head_frac := 0.50 if features.has("bill") else (0.20 if features.has("whiskers") else 0.10)
	var body_w: float = floor(rect.size.x / (1.0 + tail_frac + head_frac) / unit) * unit
	body_w = maxf(body_w, unit * 4.0)
	var tail_reach: float = clampf(body_w * tail_frac, unit * 1.8, unit * 5.2)
	var total_w: float = body_w + tail_reach + body_w * head_frac
	var left: float = rect.position.x + (rect.size.x - total_w) * 0.5
	var x0: float = left + (tail_reach if facing > 0.0 else body_w * head_frac)
	var cols: int = maxi(3, int(body_w / unit))
	var fish_seed := hash_str(String(fish.get("id", "x")))
	# Small ambient fish do not need scales, gills or a glint; the big
	# catch/index art gets the full treatment.
	var detail: bool = unit >= 2.2 and not silhouette
	var outline := body_c.darkened(0.58).lerp(Color("#101820"), 0.35)
	if silhouette:
		body_c = Color("#31465e")
		belly_c = body_c
		fin_c = Color("#26384c")
		eye_c = Color("#101820")
		outline = Color("#0f1722")
	var center := Vector2(x0 + body_w * 0.5, y0 + 5.5 * unit)

	# --- soft glow behind lantern / deep-sea fish ---
	if not silhouette and (shape == "glow" or pattern == "glow" or features.has("glow")):
		var gc := body_c.lerp(Color("#ffffff"), 0.6)
		for i in range(3):
			var rr: float = body_w * (0.31 + 0.20 * float(i))
			ci.draw_circle(center, rr, Color(gc.r, gc.g, gc.b, 0.065 + 0.015 * float(i)))

	# --- tail (behind the body) ---
	# Attach the tail to the actual peduncle (the body's tapered end), not
	# to the bounding box, so there is no gap between fan and body.
	var body_cx := x0 + body_w * 0.5
	var tail_top_hw: float = _half_width(shape, 2.4 / float(ROWS)) * body_w
	var tail_bot_hw: float = _half_width(shape, 8.6 / float(ROWS)) * body_w
	var root_top := Vector2(body_cx - tail_top_hw * facing, y0 + 2.4 * unit)
	var root_bot := Vector2(body_cx - tail_bot_hw * facing, y0 + 8.6 * unit)
	var p1 := root_top
	# The tail always grows away from the body.
	var p2 := Vector2(root_top.x - tail_reach * facing, y0 + 5.5 * unit)
	var p3 := root_bot
	var tail_fill := fin_c if silhouette else fin_c.lightened(0.08)
	if shape == "eel" or shape == "serpent":
		_tri(ci, p1, p2, p3, tail_fill, outline, detail)
		if detail:
			for i in range(3):
				var t := (float(i) + 1.0) / 4.0
				ci.draw_line(p1.lerp(p3, t), p1.lerp(p2, 0.82), tail_fill.darkened(0.22),
						maxf(1.0, unit * 0.12))
	else:
		# A flared, forked caudal fin: two lobes with a notch in the middle.
		var tip_top := Vector2(root_top.x - tail_reach * facing, y0 + 1.5 * unit)
		var tip_bot := Vector2(root_top.x - tail_reach * facing, y0 + 9.5 * unit)
		var notch := Vector2(root_top.x - tail_reach * 0.40 * facing, y0 + 5.5 * unit)
		_tri(ci, p1, tip_top, notch, tail_fill, outline, detail)
		_tri(ci, notch, tip_bot, p3, tail_fill, outline, detail)
		if detail:
			for i in range(2):
				var t := (float(i) + 1.0) / 3.0
				ci.draw_line(p1.lerp(notch, t), p1.lerp(tip_top, 0.86),
						tail_fill.darkened(0.22), maxf(1.0, unit * 0.12))
				ci.draw_line(p3.lerp(notch, t), p3.lerp(tip_bot, 0.86),
						tail_fill.darkened(0.22), maxf(1.0, unit * 0.12))

	# --- dorsal and pelvic fins ---
	var fin_top_x: float = x0 + body_w * (0.30 if facing > 0.0 else 0.62)
	var fin_w: float = body_w * 0.30
	var d1 := Vector2(fin_top_x, y0 - unit * 0.5)
	var d2 := Vector2(fin_top_x + fin_w * 0.5, y0 - unit * 1.8)
	var d3 := Vector2(fin_top_x + fin_w, y0 - unit * 0.2)
	_tri(ci, d1, d2, d3, fin_c.lightened(0.05), outline, detail)
	if detail:
		_fin_rays(ci, d1, d3, d2, fin_c.darkened(0.2), 3, maxf(1.0, unit * 0.12))
	var fin_bot_x: float = x0 + body_w * (0.42 if facing > 0.0 else 0.70)
	var b1 := Vector2(fin_bot_x, y0 + 10.2 * unit)
	var b2 := Vector2(fin_bot_x + fin_w * 0.5, y0 + 11.6 * unit)
	var b3 := Vector2(fin_bot_x + fin_w * 0.8, y0 + 10.4 * unit)
	_tri(ci, b1, b2, b3, fin_c.lightened(0.04), outline, detail)
	if detail:
		_fin_rays(ci, b1, b3, b2, fin_c.darkened(0.2), 2, maxf(1.0, unit * 0.12))
		# small adipose fin near the tail
		var ad_x: float = x0 + body_w * (0.60 if facing > 0.0 else 0.32)
		var ad1 := Vector2(ad_x, y0 + unit * 0.35)
		var ad2 := Vector2(ad_x + unit * 1.3, y0 - unit * 0.55)
		var ad3 := Vector2(ad_x + unit * 2.1, y0 + unit * 0.5)
		_tri(ci, ad1, ad2, ad3, fin_c.lightened(0.02), outline, true)

	# --- body rows: one merged outline, then a shaded, tapered body ---
	var spans: Array = []
	for r in range(ROWS):
		var v := (float(r) + 0.5) / float(ROWS)
		var hw: float = _half_width(shape, v) * body_w
		if hw < unit * 0.45:
			continue
		spans.append({"v": v, "hw": hw, "cx": x0 + body_w * 0.5,
				"ry": y0 + float(r) * unit})
	var outline_pad := unit * 0.48
	for s in spans:
		var hw: float = float(s["hw"])
		var cx: float = float(s["cx"])
		var ry: float = float(s["ry"])
		ci.draw_rect(Rect2(cx - hw - outline_pad, ry - unit * 0.24,
				(hw + outline_pad) * 2.0, unit * 1.48), outline)
	for s in spans:
		var v: float = float(s["v"])
		var hw: float = maxf(0.0, float(s["hw"]) - maxf(0.6, unit * 0.16))
		if hw < 0.5:
			continue
		var cx: float = float(s["cx"])
		var ry: float = float(s["ry"])
		var c := body_c
		if v < 0.34:
			c = body_c.darkened(0.13 * (1.0 - v / 0.34))
		elif v > 0.56:
			c = body_c.lerp(belly_c, smoothstep(0.56, 0.98, v))
		if detail and absf(v - 0.53) < 0.06:
			c = c.lightened(0.05)
		ci.draw_rect(Rect2(cx - hw, ry, hw * 2.0, unit * 1.06), c)
		if detail and v < 0.42:
			ci.draw_rect(Rect2(cx - hw * 0.54, ry, hw * 1.08, unit * 0.26),
					c.lightened(0.26))
		if detail and v > 0.8:
			ci.draw_rect(Rect2(cx - hw * 0.66, ry + unit * 0.74, hw * 1.32, unit * 0.26),
					c.lightened(0.13))
		if detail and absf(v - 0.48) < 0.05:
			# a fine lateral line catches the light along the flank
			ci.draw_rect(Rect2(cx - hw * 0.62, ry + unit * 0.42, hw * 1.24, unit * 0.10),
					c.lightened(0.20))

	# --- patterns, clipped to each row's body width ---
	if not silhouette and detail:
		for s in spans:
			var v: float = float(s["v"])
			var hw: float = maxf(0.0, float(s["hw"]) - unit * 0.2)
			var cx: float = float(s["cx"])
			var ry: float = float(s["ry"])
			if hw < unit * 0.5:
				continue
			match pattern:
				"stripes":
					for c in range(cols):
						if (fish_seed + c * 5) % 7 != 0:
							continue
						var sx: float = x0 + float(c) * unit
						var x1: float = maxf(sx, cx - hw * 0.78)
						var x2: float = minf(sx + unit * 0.9, cx + hw * 0.78)
						if x2 - x1 < unit * 0.3:
							continue
						ci.draw_rect(Rect2(x1, ry, x2 - x1, unit * 1.04), fin_c.darkened(0.2))
						if detail:
							ci.draw_rect(Rect2(x1, ry, x2 - x1, unit * 0.2),
									fin_c.lightened(0.18))
				"bands":
					if v > 0.16 and v < 0.34 or v > 0.58 and v < 0.78:
						ci.draw_rect(Rect2(cx - hw * 0.9, ry, hw * 1.8, unit * 1.04),
								fin_c.darkened(0.28))
				"spots":
					for c in range(cols):
						if (fish_seed + c * 13 + int(v * ROWS) * 5) % 5 != 0:
							continue
						var cf := (float(c) + 0.5) / float(cols)
						if absf(cf - 0.5) * 2.0 > _half_width(shape, v) * 1.75:
							continue
						var sx: float = x0 + float(c) * unit + unit * 0.22
						ci.draw_rect(Rect2(sx, ry + unit * 0.26, unit * 0.62, unit * 0.62),
								fin_c.darkened(0.34))
						if detail:
							ci.draw_rect(Rect2(sx + unit * 0.12, ry + unit * 0.34,
									unit * 0.25, unit * 0.25), fin_c.lightened(0.22))
				"sparkle", "glow":
					if (fish_seed + int(v * ROWS) * 3) % 4 == 0:
						var sx: float = cx - unit * 0.22
						ci.draw_rect(Rect2(sx, ry + unit * 0.1, unit * 0.44, unit * 0.44),
								Color(1, 1, 1, 0.62))
						if detail:
							ci.draw_rect(Rect2(sx - unit * 0.35, ry + unit * 0.3,
									unit * 1.1, unit * 0.18), Color(1, 1, 1, 0.28))
				"checker":
					for c in range(cols):
						if (c + int(v * ROWS)) % 2 != 0:
							continue
						var sx: float = x0 + float(c) * unit
						var x1: float = maxf(sx, cx - hw)
						var x2: float = minf(sx + unit, cx + hw)
						if x2 - x1 < unit * 0.3:
							continue
						ci.draw_rect(Rect2(x1, ry, x2 - x1, unit * 1.04),
								fin_c.darkened(0.10).lerp(body_c, 0.38))
				"speckle":
					for c in range(cols):
						if (fish_seed + c * 7 + int(v * ROWS) * 11) % 4 != 0:
							continue
						var sx: float = x0 + float(c) * unit + unit * 0.3
						if sx < cx - hw or sx + unit * 0.4 > cx + hw:
							continue
						ci.draw_rect(Rect2(sx, ry + unit * 0.3, unit * 0.4, unit * 0.4),
								fin_c.darkened(0.3))
						if detail:
							ci.draw_rect(Rect2(sx + unit * 0.08, ry + unit * 0.38,
									unit * 0.18, unit * 0.18), fin_c.lightened(0.15))
				"scales":
					var off := 0.5 if int(v * ROWS) % 2 == 0 else 0.0
					for c in range(cols):
						var sx: float = x0 + (float(c) + off) * unit + unit * 0.1
						if sx < cx - hw + unit * 0.25 or sx > cx + hw - unit * 0.25:
							continue
						var sy := ry + unit * 0.48
						var sw := unit * 0.72
						var sh := unit * 0.50
						ci.draw_colored_polygon(PackedVector2Array([
								Vector2(sx, sy - sh), Vector2(sx + sw, sy),
								Vector2(sx, sy + sh), Vector2(sx - sw, sy)]),
								body_c.lightened(0.18))
						ci.draw_line(Vector2(sx - sw, sy), Vector2(sx, sy + sh),
								body_c.darkened(0.16), maxf(1.0, unit * 0.1))
				"glow_veins":
					if (fish_seed + int(v * ROWS) * 5) % 3 == 0:
						ci.draw_rect(Rect2(cx - hw * 0.62, ry, unit * 0.4, unit * 1.04),
								Color(1, 1, 1, 0.3))
						ci.draw_rect(Rect2(cx + hw * 0.3, ry, unit * 0.4, unit * 1.04),
								Color(1, 1, 1, 0.3))
				"lightning":
					var zig := (float((int(v * ROWS) + fish_seed) % 3) - 1.0) * hw * 0.45
					if detail:
						ci.draw_rect(Rect2(cx + zig - unit * 0.7, ry, unit * 1.4, unit * 1.1),
								Color(1.0, 0.9, 0.3, 0.16))
					ci.draw_rect(Rect2(cx + zig - unit * 0.3, ry, unit * 0.6, unit * 1.04),
							Color("#ffe45c"))
					if (fish_seed + int(v * ROWS) * 3) % 5 == 0:
						ci.draw_rect(Rect2(cx - hw * 0.85, ry + unit * 0.2,
								unit * 0.35, unit * 0.35), Color(1, 1, 1, 0.68))
						ci.draw_rect(Rect2(cx + hw * 0.55, ry + unit * 0.5,
								unit * 0.3, unit * 0.3), Color(1, 1, 1, 0.52))

	# --- gill line ---
	if detail:
		var gx: float = x0 + body_w * (0.70 if facing > 0.0 else 0.30)
		var gcol := body_c.darkened(0.32)
		for i in range(3):
			var gy := y0 + (2.9 + float(i) * 2.0) * unit
			var gx2 := gx - facing * (0.9 - 0.25 * absf(float(i) - 1.0)) * unit
			ci.draw_line(Vector2(gx2, gy), Vector2(gx2 + facing * 0.7 * unit, gy + 0.45 * unit),
					gcol, maxf(1.0, unit * 0.15))

	# --- near-side pectoral fin ---
	if detail:
		var sh := Vector2(x0 + body_w * (0.64 if facing > 0.0 else 0.36), y0 + 5.9 * unit)
		var tip := sh + Vector2(-facing * unit * 3.1, unit * 2.4)
		var top := sh + Vector2(-facing * unit * 0.6, unit * 0.2)
		_tri(ci, sh, tip, top, fin_c.lightened(0.18), outline, true)
		_fin_rays(ci, sh, tip, top, fin_c.darkened(0.18), 2, maxf(1.0, unit * 0.1))

	# --- species features (whiskers, bills, sails, spikes, fangs...) ---
	_draw_features(ci, fish, x0, body_w, y0, unit, facing, fin_c, silhouette)

	# --- eye and mouth ---
	if not silhouette:
		var er: float = unit * (0.95 if features.has("big_eye") else 0.62)
		var ex: float = x0 + body_w * (0.71 if facing > 0.0 else 0.29)
		var ey := y0 + 4.5 * unit
		if detail:
			ci.draw_circle(Vector2(ex, ey), er + unit * 0.22, outline)
			ci.draw_circle(Vector2(ex, ey), er, Color("#f7f2e6"))
			ci.draw_circle(Vector2(ex + facing * er * 0.12, ey), er * 0.72, eye_c)
			ci.draw_circle(Vector2(ex + facing * er * 0.12 - er * 0.2, ey - er * 0.2),
					maxf(1.0, er * 0.20), Color(1, 1, 1, 0.9))
			ci.draw_line(Vector2(ex - er * 0.9, ey - er * 0.95),
					Vector2(ex + er * 0.5, ey - er * 1.05), body_c.darkened(0.35),
					maxf(1.0, unit * 0.12))
		else:
			ci.draw_rect(Rect2(ex - er, ey - er, er * 2.0, er * 2.0), Color("#f7f2e6"))
			ci.draw_rect(Rect2(ex - er * 0.5, ey - er * 0.5, er, er), eye_c)
		var nose_x: float = x0 + body_w * (0.94 if facing > 0.0 else 0.06)
		var mouth_y := y0 + 5.9 * unit
		ci.draw_line(Vector2(nose_x - facing * 0.9 * unit, mouth_y),
				Vector2(nose_x, mouth_y + 0.35 * unit), outline, maxf(1.0, unit * 0.16))
		if detail:
			ci.draw_rect(Rect2(nose_x - facing * 0.55 * unit, mouth_y + unit * 0.38,
					unit * 0.5, unit * 0.22), belly_c)


## Outlined triangle used for fins and the tail. At small sizes it skips
## the extra outline pass so ambient fish stay cheap.
static func _tri(ci: CanvasItem, a: Vector2, b: Vector2, c: Vector2, fill: Color,
		outline: Color, detail: bool) -> void:
	if detail:
		var cen := (a + b + c) / 3.0
		var o := clampf((a - cen).length() * 0.10, 0.5, 2.0)
		var oa := a + (a - cen).normalized() * o
		var ob := b + (b - cen).normalized() * o
		var oc := c + (c - cen).normalized() * o
		ci.draw_colored_polygon(PackedVector2Array([oa, ob, oc]), outline)
	ci.draw_colored_polygon(PackedVector2Array([a, b, c]), fill)


## Fin rays: lines fanning from the base edge toward the tip.
static func _fin_rays(ci: CanvasItem, base_a: Vector2, base_b: Vector2, tip: Vector2,
		color: Color, count: int, width: float) -> void:
	for i in range(count):
		var t := (float(i) + 1.0) / float(count + 1)
		var from := base_a.lerp(base_b, t)
		ci.draw_line(from, from.lerp(tip, 0.82), color, width)


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
				var mid := root + Vector2(-facing * body_w * 0.30, -unit * 0.5)
				ci.draw_line(root, mid, fc, maxf(1.0, unit * 0.32))
				ci.draw_line(mid, mid + Vector2(-facing * body_w * 0.28, unit * 1.1),
						fc, maxf(1.0, unit * 0.28))
				var root2 := Vector2(tail_x, y0 + 8.8 * unit)
				var mid2 := root2 + Vector2(-facing * body_w * 0.30, unit * 0.5)
				ci.draw_line(root2, mid2, fc, maxf(1.0, unit * 0.32))
				ci.draw_line(mid2, mid2 + Vector2(-facing * body_w * 0.28, -unit * 1.1),
						fc, maxf(1.0, unit * 0.28))
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