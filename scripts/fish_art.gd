class_name FishArt
extends RefCounted

## Procedural "pixel-ish" fish drawing, shared by the world view (water
## shadows), the fish index, the catch popup and the detail panel.
##
## The body is built from vertical columns along the length of the fish, so
## a slim serpent really is long and slim instead of reading as a tall loaf.
## Every shape is defined by a profile (0 at the tail, 1 through the middle)
## and an aspect (body height / body length). Fins are anchored to the actual
## top and bottom of the body at their own x position.

const ROWS := 11
const SerpentArtScript := preload("res://scripts/serpent_art.gd")

## Body height as a fraction of body length. A round sunfish is almost as
## tall as it is long; a Volt Serpent is a long ribbon with a lot of teeth.
const SHAPE_ASPECT := {
	"minnow": 0.32,
	"round": 0.72,
	"long": 0.42,
	"eel": 0.26,
	"flat": 0.62,
	"glow": 0.64,
	"puffer": 0.82,
	"shark": 0.36,
	"ray": 0.54,
	"deep": 0.60,
	"ribbon": 0.20,
	"serpent": 0.26,
}

static func hash_str(s: String) -> int:
	var h := 0
	for i in s.length():
		h = (h * 31 + s.unicode_at(i)) & 0xFFFFFF
	return h


## Normalised half-height profile: 1.0 at the fattest point, 0 at the ends.
static func _half_width(shape: String, v: float) -> float:
	var x := clampf(v, 0.0, 1.0)
	var w := 0.5
	match shape:
		"minnow":
			w = pow(sin(PI * x), 0.7)
		"round":
			w = sqrt(maxf(0.0, 1.0 - pow(2.0 * x - 1.0, 2.0)))
		"long":
			w = 1.0 - pow(absf(2.0 * x - 1.0), 4.0)
		"eel":
			w = sqrt(maxf(0.0, 1.0 - pow(2.0 * x - 1.0, 2.0)))
		"flat":
			w = sqrt(maxf(0.0, 1.0 - pow(2.0 * x - 1.0, 2.0)))
		"glow":
			w = sqrt(maxf(0.0, 1.0 - pow(2.0 * x - 1.0, 2.0)))
		"puffer":
			w = pow(maxf(0.0, 1.0 - pow(2.0 * x - 1.0, 2.0)), 0.45)
		"shark":
			w = 1.0 - pow(absf(2.0 * x - 1.0), 2.6)
		"ray":
			w = sqrt(maxf(0.0, 1.0 - pow(2.0 * x - 1.0, 2.0)))
		"deep":
			w = pow(maxf(0.0, 1.0 - absf(2.0 * x - 1.0)), 0.7)
		"ribbon":
			w = 1.0 - pow(absf(2.0 * x - 1.0), 2.0)
		"serpent":
			w = pow(sin(PI * x), 0.8)
		_:
			w = sqrt(maxf(0.0, 1.0 - pow(2.0 * x - 1.0, 2.0)))
	# Fuller shoulders, slimmer tail.
	if shape in ["minnow", "long", "shark", "deep", "eel", "serpent", "ribbon"]:
		w *= 0.58 + 0.42 * smoothstep(0.0, 0.35, x)
	return clampf(w, 0.0, 1.0)


## Profile used for drawing. It keeps a rounded nose (instead of a needle
## point) and a small peduncle at the tail so the caudal fan has something
## to attach to.
static func _profile(shape: String, u: float) -> float:
	var v := clampf(u, 0.0, 1.0)
	var p := _half_width(shape, v)
	var blunt := 0.16
	if shape == "eel" or shape == "ribbon":
		blunt = 0.22
	elif shape != "serpent":
		blunt = 0.30
	p = maxf(p, blunt * smoothstep(0.82, 1.0, v))
	if shape == "serpent":
		p *= 1.0 - 0.20 * smoothstep(0.88, 1.0, v)
	var ped := 0.16 if shape == "round" or shape == "puffer" else 0.055
	p = maxf(p, ped * (1.0 - smoothstep(0.02, 0.10, v)))
	return clampf(p, 0.0, 1.0)


static func _hh(shape: String, u: float, body_h: float) -> float:
	return _profile(shape, u) * body_h * 0.5


static func _bx(x0: float, body_len: float, facing: float, u: float) -> float:
	return x0 + (u if facing > 0.0 else -u) * body_len


static func draw_fish(ci: CanvasItem, rect: Rect2, fish: Dictionary,
		silhouette: bool = false, facing := 1.0) -> void:
	if fish.is_empty():
		return
	var shape: String = String(fish.get("shape", "minnow"))
	if shape == "serpent":
		SerpentArtScript.draw(ci, rect, fish, silhouette, facing)
		return
	var pattern: String = String(fish.get("pattern", "plain"))
	var pal: Dictionary = fish.get("palette", {})
	var body_c := Color(String(pal.get("body", "#c8d2d8")))
	var belly_c := Color(String(pal.get("belly", "#e8eef2")))
	var fin_c := Color(String(pal.get("fin", "#9fb0bb")))
	var eye_c := Color(String(pal.get("eye", "#1b2430")))
	var features: Array = fish.get("features", [])

	var aspect: float = float(SHAPE_ASPECT.get(shape, 0.44))
	var tail_frac := 0.26
	if features.has("streamer"):
		tail_frac += 0.22
	if shape in ["eel", "ribbon"]:
		tail_frac += 0.04
	var head_frac := 0.46 if features.has("bill") else (0.16 if features.has("whiskers") else 0.06)
	var len_by_w := (rect.size.x * 0.94) / (1.0 + tail_frac + head_frac)
	var len_by_h := (rect.size.y * 0.70) / aspect
	var body_len: float = minf(len_by_w, len_by_h)
	var unit: float = clampf(rect.size.y / 14.0, 1.0, 20.0)
	var cols: int = clampi(int(body_len / unit), 8, 36)
	var step: float = body_len / float(cols)
	body_len = step * float(cols)
	var body_h: float = body_len * aspect
	var tail_reach: float = body_len * tail_frac
	var head_reach: float = body_len * head_frac
	var total_w: float = body_len + tail_reach + head_reach
	var left: float = rect.position.x + (rect.size.x - total_w) * 0.5
	var x0: float = left + (tail_reach if facing > 0.0 else head_reach + body_len)
	var cy: float = rect.position.y + rect.size.y * 0.54
	var fish_seed := hash_str(String(fish.get("id", "x")))
	var detail: bool = not silhouette and rect.size.y >= 32.0

	var outline := body_c.darkened(0.58).lerp(Color("#101820"), 0.35)
	if silhouette:
		body_c = Color("#31465e")
		belly_c = body_c
		fin_c = Color("#26384c")
		eye_c = Color("#101820")
		outline = Color("#0f1722")

	# --- soft glow behind lantern / deep-sea / electric fish ---
	if not silhouette and (shape == "glow" or pattern == "glow" or features.has("glow")):
		var gc := fin_c.lerp(Color("#ffffff"), 0.45)
		var gcx := _bx(x0, body_len, facing, 0.55)
		for i in range(4):
			ci.draw_circle(Vector2(gcx, cy), body_len * (0.26 + 0.13 * float(i)),
					Color(gc.r, gc.g, gc.b, 0.055 + 0.012 * float(i)))

	# --- caudal fin (behind the body) ---
	var tail_x := _bx(x0, body_len, facing, 0.0) + facing * body_len * 0.02
	var root_h: float = maxf(_hh(shape, 0.03, body_h), unit * 0.7)
	var root_top := Vector2(tail_x, cy - root_h)
	var root_bot := Vector2(tail_x, cy + root_h)
	var tip_x: float = tail_x - tail_reach * facing
	var tail_fill := fin_c if silhouette else fin_c.lightened(0.08)
	if shape == "eel" or shape == "ribbon":
		var tip := Vector2(tip_x, cy)
		_tri(ci, root_top, tip, root_bot, tail_fill, outline, detail)
		if detail:
			ci.draw_line(root_top.lerp(tip, 0.7), tip, tail_fill.darkened(0.22),
					maxf(1.0, unit * 0.12))
			ci.draw_line(root_bot.lerp(tip, 0.7), tip, tail_fill.darkened(0.22),
					maxf(1.0, unit * 0.12))
	else:
		var tip_top := Vector2(tip_x, cy - body_h * 0.32)
		var tip_bot := Vector2(tip_x, cy + body_h * 0.32)
		var notch := Vector2(tip_x + tail_reach * 0.38 * facing, cy)
		_tri(ci, root_top, tip_top, notch, tail_fill, outline, detail)
		_tri(ci, notch, tip_bot, root_bot, tail_fill, outline, detail)
		if detail:
			for i in range(3):
				var t := (float(i) + 1.0) / 4.0
				ci.draw_line(root_top.lerp(notch, t), root_top.lerp(tip_top, 0.88),
						tail_fill.darkened(0.22), maxf(1.0, unit * 0.12))
				ci.draw_line(root_bot.lerp(notch, t), root_bot.lerp(tip_bot, 0.88),
						tail_fill.darkened(0.22), maxf(1.0, unit * 0.12))

	# --- dorsal fin ---
	if shape == "eel" or shape == "serpent" or shape == "ribbon":
		# A low, continuous ridge along the back. The spikes feature adds the
		# sharp spines that make a serpent read as a monster.
		var top_pts := PackedVector2Array()
		var base_pts := PackedVector2Array()
		var ridge_h := body_h * (0.10 if shape == "ribbon" else 0.055)
		for i in range(7):
			var u := 0.10 + 0.80 * float(i) / 6.0
			var x := _bx(x0, body_len, facing, u)
			var top_y := cy - _hh(shape, u, body_h) + unit * 0.3
			top_pts.append(Vector2(x, top_y - ridge_h * (0.55 + 0.45 * sin(float(i) * 1.6))))
			base_pts.append(Vector2(x, top_y + unit * 0.5))
		var ridge := PackedVector2Array()
		ridge.append_array(top_pts)
		for i in range(base_pts.size() - 1, -1, -1):
			ridge.append(base_pts[i])
		ci.draw_colored_polygon(ridge, fin_c.lightened(0.05))
		if detail:
			for i in range(1, top_pts.size() - 1):
				ci.draw_line(base_pts[i], top_pts[i], fin_c.darkened(0.20),
						maxf(1.0, unit * 0.10))
	else:
		var du0 := 0.30
		var du1 := 0.62
		var da := Vector2(_bx(x0, body_len, facing, du0),
				cy - _hh(shape, du0, body_h) + unit * 0.25)
		var db := Vector2(_bx(x0, body_len, facing, du1),
				cy - _hh(shape, du1, body_h) + unit * 0.25)
		var dmid: float = (du0 + du1) * 0.5
		var peak := Vector2(_bx(x0, body_len, facing, dmid),
				cy - _hh(shape, dmid, body_h) - body_h * 0.20)
		peak.y = maxf(peak.y, rect.position.y + unit * 0.6)
		_tri(ci, da, peak, db, fin_c.lightened(0.05), outline, detail)
		if detail:
			_fin_rays(ci, da, db, peak, fin_c.darkened(0.20), 4, maxf(1.0, unit * 0.11))

	# --- pelvic / anal fin ---
	var pu := 0.58
	var pa := Vector2(_bx(x0, body_len, facing, pu),
			cy + _hh(shape, pu, body_h) - unit * 0.25)
	var pb := Vector2(_bx(x0, body_len, facing, pu + 0.10),
			cy + _hh(shape, pu + 0.10, body_h) - unit * 0.25)
	var ptip := Vector2(_bx(x0, body_len, facing, pu + 0.035),
			cy + _hh(shape, pu + 0.035, body_h) + body_h * 0.10)
	_tri(ci, pa, ptip, pb, fin_c.lightened(0.04), outline, detail)
	if detail:
		_fin_rays(ci, pa, pb, ptip, fin_c.darkened(0.20), 2, maxf(1.0, unit * 0.10))

	# --- body: one outline pass, then shaded columns ---
	var pad := unit * 0.42
	for c in range(cols):
		var u := (float(c) + 0.5) / float(cols)
		var hw := _hh(shape, u, body_h)
		if hw < unit * 0.30:
			continue
		var xc := _bx(x0, body_len, facing, u)
		ci.draw_rect(Rect2(xc - step * 0.55 - pad, cy - hw - pad,
				step * 1.1 + pad * 2.0, hw * 2.0 + pad * 2.0), outline)
	for c in range(cols):
		var u := (float(c) + 0.5) / float(cols)
		var hw := _hh(shape, u, body_h)
		if hw < unit * 0.30:
			continue
		var xc := _bx(x0, body_len, facing, u)
		var rx := xc - step * 0.55
		var base_c := body_c
		if u < 0.30:
			base_c = body_c.darkened(0.10 * (1.0 - u / 0.30))
		ci.draw_rect(Rect2(rx, cy - hw, step * 1.1, hw * 2.0), base_c)
		# Warm belly, cool back.
		ci.draw_rect(Rect2(rx, cy + hw * 0.12, step * 1.1, hw * 0.36),
				base_c.lerp(belly_c, 0.32))
		ci.draw_rect(Rect2(rx, cy + hw * 0.42, step * 1.1, hw * 0.34),
				base_c.lerp(belly_c, 0.58))
		ci.draw_rect(Rect2(rx, cy + hw * 0.68, step * 1.1, hw * 0.32),
				base_c.lerp(belly_c, 0.84))
		if detail:
			ci.draw_rect(Rect2(rx, cy - hw, step * 1.1, maxf(1.0, hw * 0.30)),
					base_c.lightened(0.13))
			ci.draw_rect(Rect2(rx, cy - hw * 0.10, step * 1.1, maxf(1.0, unit * 0.12)),
					base_c.lightened(0.22))
			if (shape == "eel" or shape == "serpent") and c % 2 == 0:
				ci.draw_rect(Rect2(rx, cy + hw * 0.58, step * 0.9,
						maxf(1.0, unit * 0.10)), belly_c.darkened(0.22))

	# --- patterns, clipped to each column's body height ---
	if detail and not silhouette:
		match pattern:
			"stripes":
				for c in range(cols):
					if (fish_seed + c * 5) % 7 != 0:
						continue
					var u := (float(c) + 0.5) / float(cols)
					var hw := _hh(shape, u, body_h)
					var xc := _bx(x0, body_len, facing, u)
					ci.draw_rect(Rect2(xc - step * 0.40, cy - hw * 0.94,
							step * 0.80, hw * 1.88), fin_c.darkened(0.22))
					ci.draw_rect(Rect2(xc - step * 0.40, cy - hw * 0.94,
							step * 0.80, maxf(1.0, unit * 0.14)), fin_c.lightened(0.16))
			"bands":
				for c in range(cols):
					var u := (float(c) + 0.5) / float(cols)
					if not ((u > 0.22 and u < 0.34) or (u > 0.55 and u < 0.68)):
						continue
					var hw := _hh(shape, u, body_h)
					var xc := _bx(x0, body_len, facing, u)
					ci.draw_rect(Rect2(xc - step * 0.55, cy - hw * 0.94,
							step * 1.1, hw * 1.88), fin_c.darkened(0.28))
			"spots":
				var spot_rows := 3 if body_h > unit * 5.0 else 2
				for c in range(cols):
					var u := (float(c) + 0.5) / float(cols)
					if (fish_seed + c * 13) % 3 != 0:
						continue
					var hw := _hh(shape, u, body_h)
					var xc := _bx(x0, body_len, facing, u)
					for r in range(spot_rows):
						var fy: float = (float(r) + 0.5) / float(spot_rows)
						var y: float = cy + (fy * 2.0 - 1.0) * hw * 0.74
						var sz: float = minf(unit * 0.62, hw * 0.32)
						ci.draw_rect(Rect2(xc - sz * 0.5, y - sz * 0.5, sz, sz),
								fin_c.darkened(0.30))
						ci.draw_rect(Rect2(xc - sz * 0.2, y - sz * 0.3, sz * 0.4, sz * 0.4),
								fin_c.lightened(0.20))
			"sparkle", "glow":
				for c in range(cols):
					var u := (float(c) + 0.5) / float(cols)
					if (fish_seed + c * 7) % 4 != 0:
						continue
					var hw := _hh(shape, u, body_h)
					var xc := _bx(x0, body_len, facing, u)
					var y := cy - hw * 0.45 + float((fish_seed + c) % 5) * hw * 0.12
					var sz := maxf(1.0, unit * 0.38)
					ci.draw_rect(Rect2(xc - sz * 0.5, y - sz * 0.5, sz, sz),
							Color(1, 1, 1, 0.70))
					ci.draw_rect(Rect2(xc - sz * 1.6, y - sz * 0.12, sz * 3.2, sz * 0.24),
							Color(1, 1, 1, 0.28))
			"checker":
				var rows := 3
				for c in range(cols):
					var u := (float(c) + 0.5) / float(cols)
					var hw := _hh(shape, u, body_h)
					var xc := _bx(x0, body_len, facing, u)
					for r in range(rows):
						if (c + r) % 2 != 0:
							continue
						var fy: float = (float(r) + 0.5) / float(rows)
						var y: float = cy + (fy * 2.0 - 1.0) * hw * 0.62
						var hh_block: float = hw * 0.60
						ci.draw_rect(Rect2(xc - step * 0.46, y - hh_block * 0.46,
								step * 0.92, hh_block * 0.92),
								fin_c.darkened(0.10).lerp(body_c, 0.40))
			"speckle":
				for c in range(cols):
					var u := (float(c) + 0.5) / float(cols)
					if (fish_seed + c * 11) % 3 != 0:
						continue
					var hw := _hh(shape, u, body_h)
					var xc := _bx(x0, body_len, facing, u)
					for r in range(3):
						var fy: float = (float(r) + 0.5) / 3.0
						var y: float = cy + (fy * 2.0 - 1.0) * hw * 0.68
						ci.draw_rect(Rect2(xc - unit * 0.18, y, unit * 0.36, unit * 0.36),
								fin_c.darkened(0.28))
			"scales":
				for c in range(cols):
					var u := (float(c) + 0.5) / float(cols)
					var hw := _hh(shape, u, body_h)
					var xc := _bx(x0, body_len, facing, u)
					for r in range(-1, 2):
						var y: float = cy + float(r) * hw * 0.34
						if absf(y - cy) > hw * 0.72:
							continue
						var sw := step * 0.46
						var sh := hw * 0.16
						ci.draw_colored_polygon(PackedVector2Array([
								Vector2(xc, y - sh), Vector2(xc + sw, y),
								Vector2(xc, y + sh), Vector2(xc - sw, y)]),
								body_c.lightened(0.18))
						ci.draw_line(Vector2(xc - sw, y), Vector2(xc, y + sh),
								body_c.darkened(0.16), maxf(1.0, unit * 0.08))
			"glow_veins":
				for c in range(cols):
					var u := (float(c) + 0.5) / float(cols)
					if c % 3 != 0:
						continue
					var hw := _hh(shape, u, body_h)
					var xc := _bx(x0, body_len, facing, u)
					ci.draw_rect(Rect2(xc - unit * 0.18, cy - hw * 0.76,
							unit * 0.36, hw * 1.52), Color(1, 1, 1, 0.30))
			"lightning":
				# Three sharp bolts cross the body from back to belly. They are
				# deliberately thin: a wide glow reads as a yellow rope, not
				# electricity.
				for b in range(3):
					var ub := 0.30 + 0.18 * float(b)
					var xb := _bx(x0, body_len, facing, ub)
					var hb := _hh(shape, ub, body_h)
					var bolt := PackedVector2Array([
							Vector2(xb - hb * 0.10, cy - hb * 0.72),
							Vector2(xb + hb * 0.16, cy - hb * 0.28),
							Vector2(xb - hb * 0.14, cy + hb * 0.10),
							Vector2(xb + hb * 0.10, cy + hb * 0.62)])
					ci.draw_polyline(bolt, Color(1.0, 0.9, 0.32, 0.15), maxf(2.0, unit * 1.8))
					ci.draw_polyline(bolt, Color("#ffe45c"), maxf(1.0, unit * 0.50))
					ci.draw_polyline(bolt, Color(1.0, 1.0, 0.92, 0.92), maxf(1.0, unit * 0.16))
				# A few loose sparks above the spine.
				for i in range(4):
					var u3 := 0.22 + 0.18 * float(i)
					var sx := _bx(x0, body_len, facing, u3)
					var sy := cy - _hh(shape, u3, body_h) - unit * (0.9 + 0.30 * float(i % 2))
					ci.draw_rect(Rect2(sx - unit * 0.16, sy - unit * 0.16, unit * 0.32, unit * 0.32),
							Color(1.0, 0.92, 0.40, 0.9))

	# --- gills ---
	if detail:
		var gu := 0.74
		var gx := _bx(x0, body_len, facing, gu)
		var gh := _hh(shape, gu, body_h)
		for i in range(3):
			var off := (float(i) - 1.0) * unit * 0.34
			var arc := PackedVector2Array([
					Vector2(gx - facing * unit * 0.35 + off, cy - gh * 0.62),
					Vector2(gx + facing * unit * 0.16 + off, cy),
					Vector2(gx - facing * unit * 0.35 + off, cy + gh * 0.62)])
			ci.draw_polyline(arc, body_c.darkened(0.34), maxf(1.0, unit * 0.12))

	# --- near-side pectoral fin ---
	var sh := Vector2(_bx(x0, body_len, facing, 0.66),
			cy + _hh(shape, 0.66, body_h) * 0.25)
	var pfin_tip := sh + Vector2(-facing * body_len * 0.10, body_h * 0.11)
	var pfin_top := sh + Vector2(-facing * body_len * 0.01, -body_h * 0.03)
	_tri(ci, sh, pfin_tip, pfin_top, fin_c.lightened(0.18), outline, detail)
	if detail:
		_fin_rays(ci, sh, pfin_tip, pfin_top, fin_c.darkened(0.18), 2, maxf(1.0, unit * 0.09))

	# --- species features (whiskers, bills, sails, spikes, fangs...) ---
	_draw_features(ci, fish, x0, body_len, cy, body_h, unit, facing, fin_c, silhouette)

	# --- eye and mouth ---
	if not silhouette:
		var eu := 0.82
		var ex := _bx(x0, body_len, facing, eu)
		var eh := _hh(shape, eu, body_h)
		var er: float = clampf(minf(eh * 0.26, unit * 0.95), unit * 0.50, body_h * 0.078)
		if features.has("big_eye"):
			er *= 1.20
		var ey: float = cy - eh * 0.16
		ci.draw_circle(Vector2(ex, ey), er + maxf(1.0, unit * 0.18), outline)
		ci.draw_circle(Vector2(ex, ey), er, Color("#f7f2e6"))
		ci.draw_circle(Vector2(ex + facing * er * 0.12, ey), er * 0.70, eye_c)
		if shape == "serpent" or shape == "eel":
			ci.draw_rect(Rect2(ex + facing * er * 0.12 - er * 0.11, ey - er * 0.60,
					er * 0.22, er * 1.20), Color("#101820"))
		else:
			ci.draw_circle(Vector2(ex + facing * er * 0.12 - er * 0.20, ey - er * 0.20),
					maxf(1.0, er * 0.20), Color(1, 1, 1, 0.9))
		ci.draw_line(Vector2(ex - er * 1.1, ey - er * 1.05),
				Vector2(ex + facing * er * 0.6, ey - er * 1.25),
				body_c.darkened(0.35), maxf(1.0, unit * 0.12))
		var mu := 0.955
		var mx := _bx(x0, body_len, facing, mu)
		var mh := _hh(shape, mu, body_h)
		var my: float = cy + mh * 0.30
		if shape == "serpent" or shape == "eel":
			var jaw_a := Vector2(_bx(x0, body_len, facing, 0.84),
					cy + _hh(shape, 0.84, body_h) * 0.58)
			ci.draw_line(jaw_a, Vector2(mx, my), body_c.darkened(0.45),
					maxf(1.0, unit * 0.12))
		ci.draw_line(Vector2(mx - facing * unit * 1.1, my),
				Vector2(mx + facing * unit * 0.15, my + unit * 0.22),
				outline, maxf(1.0, unit * 0.16))
		if detail:
			ci.draw_line(Vector2(mx - facing * unit * 0.9, my - unit * 0.05),
					Vector2(mx - facing * unit * 0.2, my - unit * 0.55),
					body_c.darkened(0.28), maxf(1.0, unit * 0.10))


## Outlined triangle used for fins and the tail.
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
static func _draw_features(ci: CanvasItem, fish: Dictionary, x0: float, body_len: float,
		cy: float, body_h: float, unit: float, facing: float, fin_c: Color,
		silhouette: bool) -> void:
	var features: Array = fish.get("features", [])
	if features.is_empty():
		return
	var shape: String = String(fish.get("shape", "minnow"))
	var fc := Color("#141d27") if silhouette else fin_c
	var pale := Color("#141d27") if silhouette else fin_c.lightened(0.5)
	var head_x := _bx(x0, body_len, facing, 0.88)
	var nose_x := _bx(x0, body_len, facing, 1.0)
	var tail_x := _bx(x0, body_len, facing, 0.03)
	for feat in features:
		match String(feat):
			"whiskers":
				var root := Vector2(_bx(x0, body_len, facing, 0.91),
						cy + _hh(shape, 0.91, body_h) * 0.10)
				for i in range(3):
					var tip := root + Vector2(facing * body_len * (0.12 + 0.04 * float(i)),
							(body_h * 0.16) * (float(i) - 1.1))
					ci.draw_line(root, tip, fc, maxf(1.0, unit * 0.20))
			"bill":
				var base := Vector2(head_x, cy)
				var top := Vector2(base.x, cy - body_h * 0.065)
				var bot := Vector2(base.x, cy + body_h * 0.065)
				var tip := Vector2(base.x + facing * body_len * 0.40, cy)
				ci.draw_colored_polygon(PackedVector2Array([top, tip, bot]), fc)
				ci.draw_line(top.lerp(tip, 0.15), tip, pale, maxf(1.0, unit * 0.12))
			"horn":
				var base := Vector2(_bx(x0, body_len, facing, 0.82),
						cy - _hh(shape, 0.82, body_h) * 0.7)
				ci.draw_colored_polygon(PackedVector2Array([
						Vector2(base.x - unit, base.y), Vector2(base.x + unit, base.y),
						Vector2(base.x + facing * unit * 0.5, cy - body_h * 0.62)]), fc)
			"sail":
				var a := Vector2(_bx(x0, body_len, facing, 0.22),
						cy - _hh(shape, 0.22, body_h) + unit * 0.3)
				var b := Vector2(_bx(x0, body_len, facing, 0.48), cy - body_h * 0.78)
				var c := Vector2(_bx(x0, body_len, facing, 0.78),
						cy - _hh(shape, 0.78, body_h) + unit * 0.3)
				ci.draw_colored_polygon(PackedVector2Array([a, b, c]), fc)
				for i in range(4):
					var from := a.lerp(c, (float(i) + 1.0) / 5.0)
					ci.draw_line(from, from.lerp(b, 0.55), fc.darkened(0.25),
							maxf(1.0, unit * 0.18))
			"spikes":
				var count := 7 if shape == "serpent" else 4
				for i in range(count):
					var u := 0.16 + 0.68 * float(i) / float(count - 1)
					var x := _bx(x0, body_len, facing, u)
					var h := _hh(shape, u, body_h)
					var base_y := cy - h + unit * 0.55
					var spike_h := body_h * (0.10 + 0.025 * float(i % 2))
					if shape == "serpent":
						spike_h *= 1.15
					ci.draw_colored_polygon(PackedVector2Array([
							Vector2(x - unit * 1.05, base_y), Vector2(x + unit * 1.05, base_y),
							Vector2(x - facing * unit * 0.45, base_y - spike_h)]), fc)
					if shape != "serpent" and shape != "eel":
						var by := cy + h - unit * 0.55
						ci.draw_colored_polygon(PackedVector2Array([
								Vector2(x - unit * 0.8, by), Vector2(x + unit * 0.8, by),
								Vector2(x + facing * unit * 0.3, by + spike_h * 0.62)]), fc)
			"fangs":
				var mu := 0.945
				var mouth := Vector2(_bx(x0, body_len, facing, mu),
						cy + _hh(shape, mu, body_h) * 0.34)
				for i in range(2):
					var fx: float = mouth.x - facing * (unit * 0.25 + float(i) * unit * 1.15)
					var fang_h := body_h * (0.13 if shape == "serpent" else 0.10)
					ci.draw_colored_polygon(PackedVector2Array([
							Vector2(fx - unit * 0.45, mouth.y),
							Vector2(fx + unit * 0.45, mouth.y),
							Vector2(fx + facing * unit * 0.10, mouth.y + fang_h)]), pale)
				ci.draw_line(Vector2(mouth.x - facing * unit * 1.8, mouth.y),
						Vector2(mouth.x + facing * unit * 0.2, mouth.y),
						fc.darkened(0.25), maxf(1.0, unit * 0.14))
			"lantern":
				var base := Vector2(_bx(x0, body_len, facing, 0.84),
						cy - _hh(shape, 0.84, body_h) * 0.55)
				var tip := base + Vector2(facing * body_len * 0.18, -body_h * 0.34)
				ci.draw_line(base, tip, fc, maxf(1.0, unit * 0.28))
				if not silhouette:
					var glow := Color("#bfe9ff")
					ci.draw_circle(tip, unit * 1.15, Color(glow.r, glow.g, glow.b, 0.35))
					ci.draw_circle(tip, unit * 0.58, glow)
			"wings":
				var shoulder := Vector2(_bx(x0, body_len, facing, 0.55), cy)
				var tip1 := Vector2(_bx(x0, body_len, facing, 0.02), cy + body_h * 0.52)
				var tip2 := Vector2(_bx(x0, body_len, facing, 0.98), cy + body_h * 0.46)
				ci.draw_colored_polygon(PackedVector2Array([shoulder, tip1, tip2]), fc)
				var top1 := Vector2(_bx(x0, body_len, facing, 0.08), cy - body_h * 0.30)
				var top2 := Vector2(_bx(x0, body_len, facing, 0.94), cy - body_h * 0.24)
				ci.draw_colored_polygon(PackedVector2Array([
						Vector2(shoulder.x, cy - body_h * 0.10), top1, top2]), fc)
			"streamer":
				for sgn in [-1.0, 1.0]:
					var root := Vector2(tail_x, cy + float(sgn) * _hh(shape, 0.03, body_h) * 0.8)
					var mid := root + Vector2(-facing * body_len * 0.24,
							float(sgn) * body_h * 0.12 - body_h * 0.08)
					ci.draw_line(root, mid, fc, maxf(1.0, unit * 0.30))
					ci.draw_line(mid, mid + Vector2(-facing * body_len * 0.22,
							-body_h * 0.20), fc, maxf(1.0, unit * 0.22))
			"crest":
				for i in range(4):
					var u := 0.78 + 0.055 * float(i)
					var x := _bx(x0, body_len, facing, u)
					var top := cy - _hh(shape, u, body_h) + unit * 0.2
					ci.draw_colored_polygon(PackedVector2Array([
							Vector2(x - unit * 0.6, top), Vector2(x + unit * 0.6, top),
							Vector2(x, top - body_h * (0.13 + 0.03 * float(i)))]), fc)
			"hammer":
				var x := _bx(x0, body_len, facing, 0.88)
				ci.draw_rect(Rect2(x - unit * 0.7, cy - body_h * 0.34,
						unit * 1.4, body_h * 0.68), fc)
				for sgn in [-1.0, 1.0]:
					var hy: float = cy + float(sgn) * body_h * 0.34
					ci.draw_circle(Vector2(x + facing * unit * 1.2, hy), unit * 0.85, pale)
