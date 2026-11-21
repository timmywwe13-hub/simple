class_name RegionArt
extends RefCounted

## Per-region art direction (v1.7).
##
## Every place in the game has its own palette, horizon, water behaviour,
## bank material, tree style, set pieces and ambient particles. main.gd
## reads this table instead of GameTheme directly, so switching spots
## changes the whole look of the world - not just the menu text.
##
## The table holds only *day* colours; night is blended in by the scene
## with the separate night_* ramp. RegionArt.mix() crossfades two entries
## colour by colour, which is what makes a spot change feel like travel.

const KEYS := ["pond", "river", "lake", "ocean", "open", "island"]

const TABLE := {
	"pond": {
		"name": "THE POND",
		"tagline": "STILL GREEN WATER, LILIES AND WILLOWS",
		"glyph": "pond",
		"waterline": 0.60,
		"wave": "ripples",
		"bank_style": "grass",
		"trees": "willow",
		"props": ["lily", "reeds", "willow", "ducks", "dragonflies"],
		"ambient": ["dragonfly", "firefly"],
		"mist": false,
		"spray": false,
		"sky_top": Color("#f19cbb"),
		"sky_mid": Color("#f7bdcb"),
		"sky_low": Color("#f9d9d6"),
		"night_top": Color("#1a2138"),
		"night_mid": Color("#2c3155"),
		"night_low": Color("#5b4a6b"),
		"sun": Color("#fff2cf"),
		"cloud": Color("#fdf2f5"),
		"w_shallow": Color("#4d8a72"),
		"w_mid": Color("#2f6360"),
		"w_deep": Color("#183a3c"),
		"w_surface": Color("#e6f6ea"),
		"mtn_far": Color("#8e7fa6"),
		"mtn_mid": Color("#6b6b94"),
		"mtn_near": Color("#46536f"),
		"tree": Color("#4f8a5c"),
		"tree_dark": Color("#325c40"),
		"bank": Color("#6b9a52"),
		"bank_dark": Color("#416b39"),
		"bank_light": Color("#8cbf6b"),
		"bank_soil": Color("#5a4436"),
		"bank_soil_light": Color("#6f5343"),
	},
	"river": {
		"name": "THE RIVER",
		"tagline": "FAST CURRENT, SHARP ROCKS, COLD BLUE LIGHT",
		"glyph": "river",
		"waterline": 0.58,
		"wave": "current",
		"bank_style": "gravel",
		"trees": "birch",
		"props": ["birch", "reeds", "bridge", "rocks", "whitewater"],
		"ambient": ["spray", "firefly"],
		"mist": false,
		"spray": true,
		"sky_top": Color("#93aec6"),
		"sky_mid": Color("#b9cdda"),
		"sky_low": Color("#dde6e6"),
		"night_top": Color("#151d2e"),
		"night_mid": Color("#263044"),
		"night_low": Color("#4c5667"),
		"sun": Color("#f4f7ff"),
		"cloud": Color("#eef4f8"),
		"w_shallow": Color("#4a7f92"),
		"w_mid": Color("#2c5a74"),
		"w_deep": Color("#143048"),
		"w_surface": Color("#e4f1f6"),
		"mtn_far": Color("#8090a6"),
		"mtn_mid": Color("#5f7690"),
		"mtn_near": Color("#3f566e"),
		"tree": Color("#6f9a5e"),
		"tree_dark": Color("#4c6f45"),
		"bank": Color("#8e8878"),
		"bank_dark": Color("#67614f"),
		"bank_light": Color("#b8b19c"),
		"bank_soil": Color("#4a4640"),
		"bank_soil_light": Color("#5d5952"),
	},
	"lake": {
		"name": "THE LAKE",
		"tagline": "WIDE BLUE WATER, PINE SHORE, LONG GLASSY RIPPLES",
		"glyph": "lake",
		"waterline": 0.55,
		"wave": "glassy",
		"bank_style": "grass",
		"trees": "pine",
		"props": ["dock", "rowboat", "island_cabin", "mist", "loons"],
		"ambient": ["mist", "firefly"],
		"mist": true,
		"spray": false,
		"sky_top": Color("#6fa8dc"),
		"sky_mid": Color("#a9cbe8"),
		"sky_low": Color("#d8e9f2"),
		"night_top": Color("#131b30"),
		"night_mid": Color("#24304d"),
		"night_low": Color("#46506e"),
		"sun": Color("#fff6d8"),
		"cloud": Color("#f4f9fc"),
		"w_shallow": Color("#3a7c9c"),
		"w_mid": Color("#245a7c"),
		"w_deep": Color("#103250"),
		"w_surface": Color("#d3ecf4"),
		"mtn_far": Color("#6f8ba0"),
		"mtn_mid": Color("#4f6d84"),
		"mtn_near": Color("#34506a"),
		"tree": Color("#2f5a4e"),
		"tree_dark": Color("#1f3d39"),
		"bank": Color("#5d8c4c"),
		"bank_dark": Color("#3d6438"),
		"bank_light": Color("#7fb265"),
		"bank_soil": Color("#4a3a30"),
		"bank_soil_light": Color("#5d493c"),
	},
	"ocean": {
		"name": "THE DEEP SEA",
		"tagline": "GOLDEN HOUR SWELL, STONE QUAY AND A LIGHTHOUSE",
		"glyph": "ocean",
		"waterline": 0.50,
		"wave": "swell",
		"bank_style": "stone",
		"trees": "none",
		"props": ["quay", "lighthouse", "gulls", "sailboat", "spray"],
		"ambient": ["gull", "spray"],
		"mist": false,
		"spray": true,
		"sky_top": Color("#e8895a"),
		"sky_mid": Color("#f6c07a"),
		"sky_low": Color("#fbe3b0"),
		"night_top": Color("#1a1b33"),
		"night_mid": Color("#2c2b4d"),
		"night_low": Color("#54405e"),
		"sun": Color("#ffd98a"),
		"cloud": Color("#ffe8c8"),
		"w_shallow": Color("#4a8a92"),
		"w_mid": Color("#2a6480"),
		"w_deep": Color("#123a56"),
		"w_surface": Color("#ffe9c4"),
		"mtn_far": Color("#8f6f88"),
		"mtn_mid": Color("#6a5576"),
		"mtn_near": Color("#45405e"),
		"tree": Color("#4a6a58"),
		"tree_dark": Color("#33503f"),
		"bank": Color("#8c8a86"),
		"bank_dark": Color("#5f5d5b"),
		"bank_light": Color("#b5b1a8"),
		"bank_soil": Color("#55524f"),
		"bank_soil_light": Color("#6b6763"),
	},
	"open": {
		"name": "OPEN WATER",
		"tagline": "NOTHING BUT SWELL AND HORIZON",
		"glyph": "open",
		"waterline": 0.48,
		"wave": "swell",
		"bank_style": "none",
		"trees": "none",
		"props": ["islands", "sailboat", "gulls"],
		"ambient": ["gull", "spray"],
		"mist": false,
		"spray": true,
		"sky_top": Color("#79a9cf"),
		"sky_mid": Color("#a9c8df"),
		"sky_low": Color("#d6e3ea"),
		"night_top": Color("#131c31"),
		"night_mid": Color("#22304c"),
		"night_low": Color("#414b6a"),
		"sun": Color("#fff2cf"),
		"cloud": Color("#f2f8fc"),
		"w_shallow": Color("#356f90"),
		"w_mid": Color("#1e5074"),
		"w_deep": Color("#0b2b46"),
		"w_surface": Color("#dfeef2"),
		"mtn_far": Color("#6f8ba0"),
		"mtn_mid": Color("#4f6d84"),
		"mtn_near": Color("#34506a"),
		"tree": Color("#3a6a58"),
		"tree_dark": Color("#284e42"),
		"bank": Color("#5a8c60"),
		"bank_dark": Color("#3a6444"),
		"bank_light": Color("#7fb265"),
		"bank_soil": Color("#4a3a30"),
		"bank_soil_light": Color("#5d493c"),
	},
	"island": {
		"name": "COCONUT ISLE",
		"tagline": "WARM LAGOON, PALMS AND A LITTLE JETTY",
		"glyph": "island",
		"waterline": 0.60,
		"wave": "ripples",
		"bank_style": "sand",
		"trees": "palm",
		"props": ["palms", "jetty", "gulls", "dragonflies"],
		"ambient": ["gull", "firefly"],
		"mist": false,
		"spray": false,
		"sky_top": Color("#6fc3d8"),
		"sky_mid": Color("#a9e0e6"),
		"sky_low": Color("#f6e7c4"),
		"night_top": Color("#14203a"),
		"night_mid": Color("#243455"),
		"night_low": Color("#4c4a6e"),
		"sun": Color("#fff6d0"),
		"cloud": Color("#f4fbfb"),
		"w_shallow": Color("#3fb8ab"),
		"w_mid": Color("#1f8f96"),
		"w_deep": Color("#0d5a78"),
		"w_surface": Color("#e8fff4"),
		"mtn_far": Color("#5f9a8a"),
		"mtn_mid": Color("#3f7f78"),
		"mtn_near": Color("#2c635e"),
		"tree": Color("#3f8754"),
		"tree_dark": Color("#2c6340"),
		"bank": Color("#e6c998"),
		"bank_dark": Color("#c9a874"),
		"bank_light": Color("#f0d9a8"),
		"bank_soil": Color("#b38f62"),
		"bank_soil_light": Color("#cfa878"),
	},
}


static func get_art(key: String) -> Dictionary:
	return TABLE.get(key, TABLE["pond"])


static func display(key: String) -> String:
	return String(get_art(key).get("name", key.to_upper()))


static func tagline(key: String) -> String:
	return String(get_art(key).get("tagline", ""))


## Blend two region palettes. Colours lerp, numbers lerp, discrete fields
## (props, wave, trees) flip at the halfway point so the crossfade always
## reads as one coherent place at a time.
static func mix(a: Dictionary, b: Dictionary, t: float) -> Dictionary:
	var out: Dictionary = b.duplicate(true)
	for k in a.keys():
		var va: Variant = a[k]
		var vb: Variant = b.get(k, va)
		if typeof(va) == TYPE_COLOR and typeof(vb) == TYPE_COLOR:
			out[k] = (va as Color).lerp(vb as Color, t)
		elif (typeof(va) == TYPE_FLOAT or typeof(va) == TYPE_INT) \
				and (typeof(vb) == TYPE_FLOAT or typeof(vb) == TYPE_INT):
			out[k] = lerpf(float(va), float(vb), t)
		else:
			out[k] = va if t < 0.5 else vb
	return out


## Small pixel glyph used by the HUD and the arrival banner so each place
## has a recognisable mark next to its name.
static func draw_glyph(ci: CanvasItem, kind: String, center: Vector2, s: float, color: Color) -> void:
	var dark := color.darkened(0.35)
	match kind:
		"pond":
			ci.draw_circle(center + Vector2(0.0, s * 0.12), s * 0.42, color)
			ci.draw_line(center + Vector2(0.0, s * 0.12), center + Vector2(s * 0.28, -s * 0.22), dark, maxf(1.0, s * 0.1))
			ci.draw_circle(center + Vector2(-s * 0.1, -s * 0.22), s * 0.08, Color("#fbe3b0"))
		"river":
			for i in range(3):
				var y := center.y - s * 0.3 + float(i) * s * 0.3
				ci.draw_line(Vector2(center.x - s * 0.45, y), Vector2(center.x + s * 0.45, y + s * 0.1), color if i % 2 == 0 else dark, maxf(1.0, s * 0.13))
		"lake":
			ci.draw_line(Vector2(center.x - s * 0.45, center.y), Vector2(center.x + s * 0.45, center.y), color, maxf(1.0, s * 0.14))
			ci.draw_line(Vector2(center.x - s * 0.32, center.y + s * 0.2), Vector2(center.x + s * 0.32, center.y + s * 0.2), dark, maxf(1.0, s * 0.1))
			ci.draw_line(Vector2(center.x - s * 0.25, center.y - s * 0.2), Vector2(center.x + s * 0.25, center.y - s * 0.2), color, maxf(1.0, s * 0.07))
		"ocean":
			ci.draw_line(Vector2(center.x - s * 0.4, center.y + s * 0.35), Vector2(center.x - s * 0.4, center.y - s * 0.25), color, maxf(1.0, s * 0.14))
			ci.draw_line(Vector2(center.x - s * 0.4, center.y - s * 0.25), Vector2(center.x + s * 0.05, center.y - s * 0.25), color, maxf(1.0, s * 0.14))
			ci.draw_rect(Rect2(center.x - s * 0.48, center.y - s * 0.45, s * 0.2, s * 0.2), Color("#f2c14e"))
		"open":
			ci.draw_line(Vector2(center.x + s * 0.05, center.y - s * 0.4), Vector2(center.x + s * 0.05, center.y + s * 0.3), dark, maxf(1.0, s * 0.1))
			ci.draw_colored_polygon(PackedVector2Array([Vector2(center.x + s * 0.08, center.y - s * 0.35), Vector2(center.x + s * 0.4, center.y + s * 0.18), Vector2(center.x + s * 0.08, center.y + s * 0.18)]), color)
			ci.draw_line(Vector2(center.x - s * 0.45, center.y + s * 0.3), Vector2(center.x + s * 0.45, center.y + s * 0.3), dark, maxf(1.0, s * 0.1))
		"island":
			ci.draw_line(Vector2(center.x, center.y + s * 0.35), Vector2(center.x + s * 0.08, center.y - s * 0.25), dark, maxf(1.0, s * 0.14))
			ci.draw_line(Vector2(center.x + s * 0.08, center.y - s * 0.25), Vector2(center.x - s * 0.4, center.y - s * 0.1), color, maxf(1.0, s * 0.1))
			ci.draw_line(Vector2(center.x + s * 0.08, center.y - s * 0.25), Vector2(center.x + s * 0.42, center.y - s * 0.34), color, maxf(1.0, s * 0.1))
			ci.draw_line(Vector2(center.x + s * 0.08, center.y - s * 0.25), Vector2(center.x + s * 0.35, center.y + s * 0.02), color, maxf(1.0, s * 0.1))
			ci.draw_line(Vector2(center.x - s * 0.4, center.y + s * 0.35), Vector2(center.x + s * 0.45, center.y + s * 0.35), Color("#f0d9a8"), maxf(1.0, s * 0.16))
		_:
			ci.draw_circle(center, s * 0.35, color)
