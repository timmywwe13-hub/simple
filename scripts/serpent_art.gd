class_name SerpentArt
extends RefCounted

## Dedicated art for the Volt Serpent. The generic fish renderer draws a
## straight body, which makes a sea serpent look like a fat loaf. This one
## builds a sinuous tapered ribbon along an S-curve, with a real head, a
## spined dorsal ridge, a forked tail and lightning bolts that cross the
## body instead of smearing over it.

const KNOTS := [
	[0.00, 0.05], [0.06, 0.30], [0.14, 0.62], [0.28, 0.88],
	[0.45, 1.00], [0.62, 0.94], [0.74, 0.74], [0.82, 0.62],
	[0.89, 1.04], [0.94, 1.16], [0.98, 1.02], [1.00, 0.80],
]

static func _k(t: float) -> float:
	for i in range(1, KNOTS.size()):
		var b: Array = KNOTS[i]
		if t <= float(b[0]):
			var a: Array = KNOTS[i - 1]
			var f: float = (t - float(a[0])) / maxf(0.0001, float(b[0]) - float(a[0]))
			return lerpf(float(a[1]), float(b[1]), smoothstep(0.0, 1.0, f))
	return 0.32


static func _tri(ci: CanvasItem, a: Vector2, b: Vector2, c: Vector2,
		fill: Color, outline: Color, detail: bool) -> void:
	if detail:
		var cen := (a + b + c) / 3.0
		var o := clampf((a - cen).length() * 0.10, 0.5, 2.0)
		ci.draw_colored_polygon(PackedVector2Array([
				a + (a - cen).normalized() * o,
				b + (b - cen).normalized() * o,
				c + (c - cen).normalized() * o]), outline)
	ci.draw_colored_polygon(PackedVector2Array([a, b, c]), fill)


static func _rays(ci: CanvasItem, a: Vector2, b: Vector2, tip: Vector2,
		color: Color, count: int, width: float) -> void:
	for i in range(count):
		var t := (float(i) + 1.0) / float(count + 1)
		var from := a.lerp(b, t)
		ci.draw_line(from, from.lerp(tip, 0.84), color, width)


static func _ribbon(pts: Array[Vector2], nrms: Array[Vector2], rads: Array[float],
		inner: float, outer: float, extra: float = 0.0) -> PackedVector2Array:
	var a: Array[Vector2] = []
	var b: Array[Vector2] = []
	for i in range(pts.size()):
		a.append(pts[i] + nrms[i] * (rads[i] * inner + extra))
		b.append(pts[i] + nrms[i] * (rads[i] * outer + extra))
	var poly := PackedVector2Array()
	poly.append_array(a)
	for i in range(b.size() - 1, -1, -1):
		poly.append(b[i])
	return poly


static func draw(ci: CanvasItem, rect: Rect2, fish: Dictionary,
		silhouette: bool, facing := 1.0) -> void:
	var pal: Dictionary = fish.get("palette", {})
	var body_c := Color(String(pal.get("body", "#241c42")))
	var belly_c := Color(String(pal.get("belly", "#4fd7f2")))
	var fin_c := Color(String(pal.get("fin", "#38e0ff")))
	var eye_c := Color(String(pal.get("eye", "#ffe45c")))
	var features: Array = fish.get("features", [])
	var pattern := String(fish.get("pattern", "lightning"))
	var detail: bool = not silhouette and rect.size.y >= 30.0

	if silhouette:
		body_c = Color("#31465e")
		belly_c = body_c
		fin_c = Color("#26384c")
		eye_c = Color("#101820")

	var dir: float = 1.0 if facing > 0.0 else -1.0
	var H := rect.size.y
	var thick := H * 0.46
	var L: float = minf(rect.size.x * 0.82, H * 3.7)
	var tail_len := thick * 1.70
	L = minf(L, rect.size.x * 0.86 - tail_len)
	thick = minf(thick, L / 8.5)
	tail_len = thick * 1.70
	L = maxf(L, H * 1.2)
	var amp := H * 0.10
	var cy := rect.position.y + rect.size.y * 0.52
	var total := L + tail_len + thick * 0.35
	var left := rect.position.x + (rect.size.x - total) * 0.5
	var x0: float = (left + tail_len) if facing > 0.0 else (left + L)
	var pad: float = maxf(1.0, thick * 0.06)
	var N: int = clampi(int(L / maxf(2.0, thick * 0.22)), 18, 40)

	var pts: Array[Vector2] = []
	var rads: Array[float] = []
	var tans: Array[Vector2] = []
	var nrms: Array[Vector2] = []
	for i in range(N + 1):
		var t := float(i) / float(N)
		var x := x0 + dir * t * L
		var wave := sin(t * PI * 2.0) * sin(PI * t) * amp
		pts.append(Vector2(x, cy + wave))
		rads.append(thick * 0.5 * _k(t))
	for i in range(N + 1):
		var a := pts[maxi(0, i - 1)]
		var b := pts[mini(N, i + 1)]
		var tan := (b - a).normalized()
		if tan.length() < 0.001:
			tan = Vector2(dir, 0)
		tans.append(tan)
		nrms.append(Vector2(-tan.y, tan.x) * dir)

	var outline := Color("#0f1722") if silhouette else body_c.darkened(0.62)
	var shade := body_c if silhouette else body_c.lightened(0.10)
	var belly := belly_c

	# Soft electric aura.
	if not silhouette and (features.has("glow") or pattern == "lightning"):
		var gc := fin_c.lerp(Color("#ffffff"), 0.35)
		var mid := pts[N / 2]
		var gmax: float = minf(rect.size.y * 0.46, L * 0.13)
		for i in range(5):
			ci.draw_circle(mid, gmax * (0.34 + 0.145 * float(i)),
					Color(gc.r, gc.g, gc.b, 0.042 + 0.008 * float(i)))

	# --- tail fan (behind the ribbon) ---
	var tp := pts[2]
	var tt := tans[2]
	var tn := nrms[2]
	var tr := rads[2]
	var back := tp - tt * tail_len
	var tip_a := back + tn * thick * 0.68
	var tip_b := back - tn * thick * 0.68
	var notch := tp - tt * tail_len * 0.55
	var root_a := tp + tn * tr * 2.2
	var root_b := tp - tn * tr * 2.2
	var tail_fill := fin_c if silhouette else fin_c.lightened(0.06)
	_tri(ci, root_a, tip_a, notch, tail_fill, outline, detail)
	_tri(ci, notch, tip_b, root_b, tail_fill, outline, detail)
	if detail:
		_rays(ci, root_a, root_b, tip_a, tail_fill.darkened(0.18), 3, maxf(1.0, thick * 0.05))
		_rays(ci, root_a, root_b, tip_b, tail_fill.darkened(0.18), 3, maxf(1.0, thick * 0.05))

	# --- body ribbon: outline, base, belly, back ---
	var outline_poly := _ribbon(pts, nrms, rads, -1.0, 1.0, pad)
	ci.draw_colored_polygon(outline_poly, outline)
	ci.draw_colored_polygon(_ribbon(pts, nrms, rads, -1.0, 1.0), body_c)
	if not silhouette:
		ci.draw_colored_polygon(_ribbon(pts, nrms, rads, 0.10, 0.46), body_c.lerp(belly, 0.24))
		ci.draw_colored_polygon(_ribbon(pts, nrms, rads, 0.42, 0.72), body_c.lerp(belly, 0.54))
		ci.draw_colored_polygon(_ribbon(pts, nrms, rads, 0.68, 1.0), body_c.lerp(belly, 0.84))
		ci.draw_colored_polygon(_ribbon(pts, nrms, rads, -1.0, -0.48), shade)

	# lateral line, following the curve
	if detail:
		var line := PackedVector2Array()
		for i in range(N + 1):
			line.append(pts[i] + nrms[i] * rads[i] * 0.08)
		ci.draw_polyline(line, body_c.lightened(0.24), maxf(1.0, thick * 0.025))
		# Plates / segmentation across the body.
		for i in range(4, N - 2, 4):
			ci.draw_line(pts[i] - nrms[i] * rads[i] * 0.82,
					pts[i] + nrms[i] * rads[i] * 0.82,
					body_c.darkened(0.12), maxf(1.0, thick * 0.014))

	# --- spined dorsal ridge ---
	var first := maxi(2, int(float(N) * 0.16))
	var last := mini(N - 2, int(float(N) * 0.80))
	if last > first:
		var outer: Array[Vector2] = []
		var base: Array[Vector2] = []
		for i in range(first, last + 1):
			var top := pts[i] - nrms[i] * rads[i]
			base.append(top)
			var lift := thick * (0.035 + 0.010 * sin(float(i) * 1.7))
			outer.append(top - nrms[i] * lift)
		var membrane := PackedVector2Array()
		membrane.append_array(outer)
		for i in range(base.size() - 1, -1, -1):
			membrane.append(base[i])
		ci.draw_colored_polygon(membrane,
				Color(fin_c.darkened(0.48).r, fin_c.darkened(0.48).g,
						fin_c.darkened(0.48).b, 0.85 if not silhouette else 1.0))
		if detail:
			for i in range(first, last + 1):
				ci.draw_line(base[i - first], outer[i - first],
						fin_c.darkened(0.22), maxf(1.0, thick * 0.022))
		var spines := 6
		for s in range(spines):
			var t := 0.18 + 0.58 * float(s) / float(spines - 1)
			var i := clampi(int(t * float(N)), first, last)
			var b := pts[i] - nrms[i] * rads[i] * 0.92
			var h := thick * (0.20 + 0.055 * float(s % 2))
			var tip := b - nrms[i] * h - tans[i] * thick * 0.10
			var ba := b - tans[i] * rads[i] * 0.30
			var bb := b + tans[i] * rads[i] * 0.30
			_tri(ci, ba, tip, bb, fin_c, outline, detail)

	# --- lightning across the body ---
	if detail and pattern == "lightning" and not silhouette:
		for b in range(4):
			var t := 0.24 + 0.16 * float(b)
			var i := clampi(int(t * float(N)), 1, N - 1)
			var p := pts[i]
			var n := nrms[i]
			var tan := tans[i]
			var r := rads[i]
			var bolt := PackedVector2Array([
					p + n * r * -0.72 + tan * r * -0.08,
					p + n * r * -0.26 + tan * r * 0.20,
					p + n * r * 0.10 + tan * r * -0.18,
					p + n * r * 0.64 + tan * r * 0.08])
			ci.draw_polyline(bolt, Color(0.08, 0.07, 0.12, 0.60), maxf(2.0, thick * 0.095))
			ci.draw_polyline(bolt, Color("#ffe45c"), maxf(1.0, thick * 0.058))
			ci.draw_polyline(bolt, Color(1.0, 1.0, 0.92, 0.95), maxf(1.0, thick * 0.020))
		for s in range(4):
			var t := 0.24 + 0.18 * float(s)
			var i := clampi(int(t * float(N)), 1, N - 1)
			var p := pts[i] - nrms[i] * rads[i] - nrms[i] * thick * (0.18 + 0.08 * float(s % 2))
			ci.draw_rect(Rect2(p.x - thick * 0.018, p.y - thick * 0.018,
					thick * 0.036, thick * 0.036), Color(1.0, 0.92, 0.40, 0.9))

	# --- head details ---
	var hi := N
	var hp := pts[hi]
	var ht := tans[hi]
	var hn := nrms[hi]
	var hr := rads[hi]

	# pointed snout
	var snout := hp + ht * thick * 0.12
	var htop := hp - hn * hr
	var hbot := hp + hn * hr
	ci.draw_colored_polygon(PackedVector2Array([htop, snout, hbot]), body_c)
	ci.draw_line(htop, snout, outline, maxf(1.0, thick * 0.030))
	ci.draw_line(hbot, snout, outline, maxf(1.0, thick * 0.030))

	if detail and not silhouette:
		# cheek / pectoral fin
		var ci_fin := clampi(int(float(N) * 0.80), 2, N - 2)
		var fp := pts[ci_fin] + nrms[ci_fin] * rads[ci_fin] * 0.62
		var ft := tans[ci_fin]
		var fn := nrms[ci_fin]
		var ftip := fp - ft * thick * 0.28 + fn * thick * 0.20
		var fa := fp - ft * thick * 0.08
		var fb := fp + ft * thick * 0.08
		_tri(ci, fa, ftip, fb, fin_c.lightened(0.12), outline, true)
		_rays(ci, fa, fb, ftip, fin_c.darkened(0.20), 2, maxf(1.0, thick * 0.02))

		# brow horns
		for s in range(2):
			var hi2 := clampi(int(float(N) * (0.86 + 0.04 * float(s))), 2, N - 1)
			var bb := pts[hi2] - nrms[hi2] * rads[hi2] * 0.92
			var horn := bb - nrms[hi2] * thick * 0.20 - tans[hi2] * thick * 0.06
			_tri(ci, bb - tans[hi2] * rads[hi2] * 0.28, horn,
					bb + tans[hi2] * rads[hi2] * 0.28, fin_c, outline, true)

		# crown spines behind the head
		for cs in range(3):
			var ti := clampi(int(float(N) * (0.80 + 0.035 * float(cs))), 2, N - 2)
			var cb := pts[ti] - nrms[ti] * rads[ti] * 0.95
			var ch := thick * (0.40 + 0.10 * float(cs))
			var ctip := cb - nrms[ti] * ch - tans[ti] * thick * 0.12
			_tri(ci, cb - tans[ti] * rads[ti] * 0.40, ctip,
					cb + tans[ti] * rads[ti] * 0.40, fin_c, outline, true)

		# eye
		var ei := clampi(int(float(N) * 0.935), 2, N - 1)
		var ep := pts[ei] - nrms[ei] * rads[ei] * 0.02
		var er: float = clampf(thick * 0.160, 1.5, 26.0)
		if features.has("big_eye"):
			er *= 1.15
		ci.draw_circle(ep, er + maxf(1.0, thick * 0.018), outline)
		ci.draw_circle(ep, er, Color("#f7f2e6"))
		ci.draw_circle(ep + tans[ei] * er * 0.10, er * 0.68, eye_c)
		ci.draw_rect(Rect2(ep.x + tans[ei].x * er * 0.10 - er * 0.10,
				ep.y - er * 0.58, er * 0.20, er * 1.16), Color("#101820"))
		ci.draw_line(ep - tans[ei] * er * 1.2 - nrms[ei] * er * 0.9,
				ep + tans[ei] * er * 0.9 - nrms[ei] * er * 1.1,
				body_c.darkened(0.35), maxf(1.0, thick * 0.022))
		# nostril
		var ni := clampi(int(float(N) * 0.975), 2, N - 1)
		var np := pts[ni] - nrms[ni] * rads[ni] * 0.45
		ci.draw_rect(Rect2(np.x - thick * 0.012, np.y - thick * 0.012,
				thick * 0.024, thick * 0.024), outline)

		# jaw and fangs
		var ji := clampi(int(float(N) * 0.93), 2, N - 1)
		var jp := pts[ji] + nrms[ji] * rads[ji] * 0.34
		ci.draw_line(jp, snout - nrms[ji] * thick * 0.03, outline,
				maxf(1.0, thick * 0.038))
		ci.draw_line(jp + nrms[ji] * thick * 0.04, snout + nrms[ji] * thick * 0.01,
				fin_c.lightened(0.25), maxf(1.0, thick * 0.018))
		for f in range(3):
			var base := jp + tans[ji] * thick * (0.02 + 0.080 * float(f))
			var fang := base + nrms[ji] * thick * 0.26 + tans[ji] * thick * 0.02
			_tri(ci, base - tans[ji] * thick * 0.040, fang,
					base + tans[ji] * thick * 0.040, Color("#f7f2e6"), outline, true)
		# forked tongue
		var troot := jp + tans[ji] * thick * 0.06 + nrms[ji] * thick * 0.02
		var tmid := troot + tans[ji] * thick * 0.30 + nrms[ji] * thick * 0.04
		ci.draw_line(troot, tmid, Color("#ff5a6e"), maxf(1.0, thick * 0.025))
		ci.draw_line(tmid, tmid + tans[ji] * thick * 0.07 + nrms[ji] * thick * 0.045,
				Color("#ff5a6e"), maxf(1.0, thick * 0.020))
		ci.draw_line(tmid, tmid + tans[ji] * thick * 0.07 - nrms[ji] * thick * 0.045,
				Color("#ff5a6e"), maxf(1.0, thick * 0.020))
	else:
		# Small version: a simple eye so the head still reads.
		var ei := clampi(int(float(N) * 0.90), 2, N - 1)
		var ep := pts[ei] - nrms[ei] * rads[ei] * 0.34
		ci.draw_rect(Rect2(ep.x - thick * 0.03, ep.y - thick * 0.03,
				thick * 0.06, thick * 0.06), eye_c)
