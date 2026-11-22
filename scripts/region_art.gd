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


static func get_art(key: String, season := "") -> Dictionary:
	if season == "harvest":
		return stylize(key)
	return TABLE.get(key, TABLE["pond"])


## Autumn palette override for every region. Only the day/night colours,
## canopies, banks, water and mountain ramps change - fish art, hit targets
## and the water's shape stay exactly as they are.
static func stylize(key: String) -> Dictionary:
	var out: Dictionary = TABLE.get(key, TABLE["pond"]).duplicate(true)
	var o: Dictionary = HARVEST_OVERRIDES.get(key, HARVEST_OVERRIDES["pond"])
	for k in o.keys():
		out[k] = Color(String(o[k]))
	out["season"] = "harvest"
	return out


const HARVEST_OVERRIDES := {
	"pond": {
		"sky_top": "#d9843f", "sky_mid": "#e8ac62", "sky_low": "#f5d49a",
		"night_top": "#2a1a14", "night_mid": "#3d2719", "night_low": "#6a4526",
		"sun": "#fff0c4", "cloud": "#fbe4c2",
		"w_shallow": "#6d5a38", "w_mid": "#4a3524", "w_deep": "#281a12",
		"w_surface": "#ffe6b8",
		"mtn_far": "#a57a58", "mtn_mid": "#7d5640", "mtn_near": "#523a2c",
		"tree": "#b5622a", "tree_dark": "#7c3f1e",
		"bank": "#b58a4a", "bank_dark": "#6d4a24", "bank_light": "#d8b26a",
		"bank_soil": "#5a3a22", "bank_soil_light": "#74502f",
	},
	"river": {
		"sky_top": "#b07a4a", "sky_mid": "#d6a066", "sky_low": "#eed0a0",
		"night_top": "#231813", "night_mid": "#38261a", "night_low": "#5e4228",
		"sun": "#ffe8b0", "cloud": "#f6dcb4",
		"w_shallow": "#6b563a", "w_mid": "#493424", "w_deep": "#271a12",
		"w_surface": "#ffdfae",
		"mtn_far": "#a07858", "mtn_mid": "#79543e", "mtn_near": "#50392a",
		"tree": "#c06a2c", "tree_dark": "#83441f",
		"bank": "#b49258", "bank_dark": "#6f5630", "bank_light": "#d8bc7e",
		"bank_soil": "#57402a", "bank_soil_light": "#6f5236",
	},
	"lake": {
		"sky_top": "#c47a3e", "sky_mid": "#e0a25c", "sky_low": "#f2cf96",
		"night_top": "#281a14", "night_mid": "#3d2819", "night_low": "#684326",
		"sun": "#ffedb8", "cloud": "#f8e0ba",
		"w_shallow": "#6a5638", "w_mid": "#473322", "w_deep": "#251810",
		"w_surface": "#ffe4b4",
		"mtn_far": "#9c7452", "mtn_mid": "#74503a", "mtn_near": "#4d3626",
		"tree": "#a95c28", "tree_dark": "#743c1c",
		"bank": "#b08644", "bank_dark": "#694820", "bank_light": "#d4ac62",
		"bank_soil": "#563a22", "bank_soil_light": "#6e4e2e",
	},
	"ocean": {
		"sky_top": "#d47a3a", "sky_mid": "#efae5e", "sky_low": "#f8d79c",
		"night_top": "#261812", "night_mid": "#3a2418", "night_low": "#5d3c24",
		"sun": "#ffdf9a", "cloud": "#ffe2b8",
		"w_shallow": "#6a5a3c", "w_mid": "#463222", "w_deep": "#231710",
		"w_surface": "#ffe2ae",
		"mtn_far": "#96684e", "mtn_mid": "#704c36", "mtn_near": "#4a3224",
		"tree": "#8a5a2a", "tree_dark": "#5f3c1e",
		"bank": "#a3865a", "bank_dark": "#65513a", "bank_light": "#c9aa76",
		"bank_soil": "#564434", "bank_soil_light": "#6d5842",
	},
	"open": {
		"sky_top": "#bd7a46", "sky_mid": "#daa060", "sky_low": "#f0cc94",
		"night_top": "#241812", "night_mid": "#38251a", "night_low": "#5a3e26",
		"sun": "#ffedb8", "cloud": "#f7ddb8",
		"w_shallow": "#64543a", "w_mid": "#443222", "w_deep": "#221710",
		"w_surface": "#ffe2b0",
		"mtn_far": "#9a7050", "mtn_mid": "#72503a", "mtn_near": "#4c3526",
		"tree": "#9a5c2c", "tree_dark": "#6b3f20",
		"bank": "#a2824e", "bank_dark": "#624824", "bank_light": "#c8a666",
		"bank_soil": "#543c26", "bank_soil_light": "#6a5032",
	},
	"island": {
		"sky_top": "#dc8a42", "sky_mid": "#eda95e", "sky_low": "#f7d69c",
		"night_top": "#2a1b14", "night_mid": "#402a1a", "night_low": "#6a4626",
		"sun": "#ffefbe", "cloud": "#fbe6c2",
		"w_shallow": "#6f5a38", "w_mid": "#4b3522", "w_deep": "#281a10",
		"w_surface": "#ffe9c0",
		"mtn_far": "#9c7450", "mtn_mid": "#77523a", "mtn_near": "#503826",
		"tree": "#a8642a", "tree_dark": "#75441e",
		"bank": "#d8b276", "bank_dark": "#a9854e", "bank_light": "#ecd09a",
		"bank_soil": "#8f6a3e", "bank_soil_light": "#a98252",
	},
}


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
