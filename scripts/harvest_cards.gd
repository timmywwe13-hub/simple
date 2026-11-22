class_name HarvestCards
extends RefCounted

## The 20-card Harvest Feast album, all art drawn in code (fish delegate to
## FishArt; the feast / places / critters cards use simple pixel icons so the
## event needs no external assets).

const CARDS := {
	# --- Fish (5) ---
	"pumpkinseed": {"id": "pumpkinseed", "name": "Pumpkinseed Sunny", "rarity": "Common",
		"group": "fish", "art": "fish"},
	"cranberry_darter": {"id": "cranberry_darter", "name": "Cranberry Darter", "rarity": "Uncommon",
		"group": "fish", "art": "fish"},
	"maple_koi": {"id": "maple_koi", "name": "Maple Leaf Koi", "rarity": "Rare",
		"group": "fish", "art": "fish"},
	"wattle_grouper": {"id": "wattle_grouper", "name": "Wattle Grouper", "rarity": "Epic",
		"group": "fish", "art": "fish"},
	"grand_tom": {"id": "grand_tom", "name": "The Grand Tom", "rarity": "Legendary",
		"group": "fish", "art": "fish"},
	# --- Feast (5) ---
	"long_table": {"id": "long_table", "name": "The Long Table", "rarity": "Common",
		"group": "feast", "art": "table"},
	"mothers_pie": {"id": "mothers_pie", "name": "Mother's Pie", "rarity": "Common",
		"group": "feast", "art": "pie"},
	"cranberry_sauce": {"id": "cranberry_sauce", "name": "Cranberry Sauce", "rarity": "Common",
		"group": "feast", "art": "sauce"},
	"stuffed_roast": {"id": "stuffed_roast", "name": "Stuffed Roast", "rarity": "Uncommon",
		"group": "feast", "art": "roast"},
	"cornucopia": {"id": "cornucopia", "name": "Cornucopia", "rarity": "Rare",
		"group": "feast", "art": "cornucopia"},
	# --- Places (5) ---
	"cottage_creek_farm": {"id": "cottage_creek_farm", "name": "Cottage Creek Farm", "rarity": "Common",
		"group": "places", "art": "barn"},
	"corn_maze": {"id": "corn_maze", "name": "The Corn Maze", "rarity": "Common",
		"group": "places", "art": "maze"},
	"smokehouse_chimney": {"id": "smokehouse_chimney", "name": "Smokehouse Chimney", "rarity": "Uncommon",
		"group": "places", "art": "chimney"},
	"pie_window": {"id": "pie_window", "name": "The Pie Window", "rarity": "Uncommon",
		"group": "places", "art": "window"},
	"first_frost": {"id": "first_frost", "name": "First Frost", "rarity": "Rare",
		"group": "places", "art": "frost"},
	# --- Critters & gear (5) ---
	"acorn_bounty": {"id": "acorn_bounty", "name": "Acorn Bounty", "rarity": "Common",
		"group": "critters", "art": "acorn"},
	"tom_turkey": {"id": "tom_turkey", "name": "Tom Turkey", "rarity": "Uncommon",
		"group": "critters", "art": "turkey"},
	"scarecrow": {"id": "scarecrow", "name": "Scarecrow", "rarity": "Uncommon",
		"group": "critters", "art": "scarecrow"},
	"harvest_lantern": {"id": "harvest_lantern", "name": "Harvest Lantern", "rarity": "Rare",
		"group": "critters", "art": "lantern"},
	"grandmothers_rod": {"id": "grandmothers_rod", "name": "Grandmother's Rod", "rarity": "Epic",
		"group": "critters", "art": "rod"},
}

## Insertion order = the 5x4 album grid order.
const ALL_IDS := [
	"pumpkinseed", "cranberry_darter", "maple_koi", "wattle_grouper", "grand_tom",
	"long_table", "mothers_pie", "cranberry_sauce", "stuffed_roast", "cornucopia",
	"cottage_creek_farm", "corn_maze", "smokehouse_chimney", "pie_window", "first_frost",
	"acorn_bounty", "tom_turkey", "scarecrow", "harvest_lantern", "grandmothers_rod",
]

const RARITY_ODDS := {
	"Common": 55.0,
	"Uncommon": 28.0,
	"Rare": 13.0,
	"Epic": 3.5,
	"Legendary": 0.5,
}


static func card(id: String) -> Dictionary:
	return CARDS.get(id, {})


static func ids_of_rarity(rarity: String) -> Array:
	var out: Array = []
	for id in ALL_IDS:
		if String(CARDS[id].get("rarity", "Common")) == rarity:
			out.append(id)
	return out


## Card ids the player has not collected yet.
static func new_ids(owned: Dictionary) -> Array:
	var out: Array = []
	for id in ALL_IDS:
		if int(owned.get(id, 0)) <= 0:
			out.append(id)
	return out


static func group_label(id: String) -> String:
	var g := String(card(id).get("group", ""))
	match g:
		"fish": return "FISH"
		"feast": return "FEAST"
		"places": return "PLACES"
		"critters": return "CRITTERS & GEAR"
		_: return ""


## Parchment card face with a walnut border, rarity ribbon and (optionally)
## a wax-stamp NEW! stamp. `r` is the full card rect.
static func draw_card(ci: CanvasItem, r: Rect2, data: Dictionary, collected := true,
		new_stamp := false, hovered := false, closed_hint := "") -> void:
	if data.is_empty():
		return
	var id := String(data.get("id", ""))
	var rarity := String(data.get("rarity", "Common"))
	var rc := GameTheme.get_rarity_color(rarity)
	var face := GameTheme.PAPER if collected else GameTheme.PAPER.darkened(0.55)
	# During a pack flip the rect can be only a few pixels wide; drawing the
	# ribbon label across it would spill outside the card. Just show the edge.
	if r.size.x < 12.0:
		ci.draw_rect(r, face)
		return
	# drop shadow + card body
	ci.draw_rect(Rect2(r.position + Vector2(2.0, 3.0), r.size), Color(0, 0, 0, 0.28))
	ci.draw_rect(r, face)
	# 1px warm outline keeps rarity colours meaningful without repainting them
	if GameTheme.RARITY_OUTLINE.a > 0.0:
		ci.draw_rect(r, GameTheme.RARITY_OUTLINE, false, 1.0)
	# walnut border
	var bw := 3.0 if hovered else 2.0
	ci.draw_rect(r, GameTheme.WOOD_DARK, false, bw)
	# rarity ribbon across the top
	var ribbon := Rect2(r.position + Vector2(1.0, 1.0), Vector2(r.size.x - 2.0, 17.0))
	ci.draw_rect(ribbon, rc if collected else rc.darkened(0.45))
	if r.size.x > 58.0:
		var label := rarity.to_upper()
		ci.draw_string(ThemeDB.fallback_font, ribbon.position + Vector2(6.0, 13.0), label,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 9, GameTheme.INK)
	# art well
	var art := Rect2(r.position + Vector2(8.0, 23.0), Vector2(r.size.x - 16.0, r.size.y - 50.0))
	ci.draw_rect(art, face.darkened(0.06) if collected else face.darkened(0.12))
	if collected:
		_draw_art(ci, art, data)
		# card name
		if r.size.x > 48.0:
			var name := String(data.get("name", id)).to_upper()
			var fs := 10
			while fs > 7 and name.length() * fs * 0.72 > r.size.x - 8.0:
				fs -= 1
			ci.draw_string(ThemeDB.fallback_font,
					r.position + Vector2(4.0, r.size.y - 7.0), name,
					HORIZONTAL_ALIGNMENT_CENTER, r.size.x - 8.0, fs, GameTheme.INK)
	else:
		if closed_hint != "":
			var fs2 := 8
			while fs2 > 6 and closed_hint.length() * fs2 * 0.72 > r.size.x - 8.0:
				fs2 -= 1
			ci.draw_string(ThemeDB.fallback_font, art.get_center() + Vector2(-r.size.x * 0.46, 3.0),
					closed_hint, HORIZONTAL_ALIGNMENT_CENTER, r.size.x - 4.0, fs2,
					GameTheme.INK)
		else:
			ci.draw_string(ThemeDB.fallback_font, art.get_center() + Vector2(-8.0, 8.0), "?",
					HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(GameTheme.INK, 0.55))
	if new_stamp and r.size.x > 62.0:
		_draw_new_stamp(ci, r.position + Vector2(r.size.x - 22.0, 24.0))
	if hovered:
		ci.draw_rect(r.grow(1.0), GameTheme.GOLD, false, 2.0)


static func _draw_new_stamp(ci: CanvasItem, center: Vector2) -> void:
	ci.draw_circle(center, 15.0, GameTheme.CRANBERRY)
	ci.draw_circle(center, 12.0, GameTheme.CRANBERRY.lightened(0.12))
	ci.draw_string(ThemeDB.fallback_font, center + Vector2(-13.0, 3.0), "NEW!",
			HORIZONTAL_ALIGNMENT_CENTER, 26.0, 8, GameTheme.CREAM)


static func _draw_art(ci: CanvasItem, r: Rect2, data: Dictionary) -> void:
	var id := String(data.get("id", ""))
	if String(data.get("group", "")) == "fish":
		var fish := FishDB.fish_data(id)
		if not fish.is_empty():
			FishArt.draw_fish(ci, r.grow(-2.0), fish, false, 1.0)
			return
	_draw_icon(ci, r, String(data.get("art", id)))


## Code-drawn icons for the non-fish cards. Every icon is anchored to the
## art well and uses only rectangles, lines and circles.
static func _draw_icon(ci: CanvasItem, r: Rect2, kind: String) -> void:
	var cx := r.get_center().x
	var by := r.position.y + r.size.y * 0.86
	var s := minf(r.size.x, r.size.y)
	var ink := GameTheme.INK
	var wood := GameTheme.WOOD
	var dark := GameTheme.WOOD_DARK
	var gold := GameTheme.GOLD
	var orange := GameTheme.PUMPKIN
	var green := GameTheme.LEAF
	match kind:
		"table":
			ci.draw_rect(Rect2(cx - s * 0.42, by - s * 0.30, s * 0.84, s * 0.10), wood)
			ci.draw_rect(Rect2(cx - s * 0.34, by - s * 0.20, s * 0.06, s * 0.20), dark)
			ci.draw_rect(Rect2(cx + s * 0.28, by - s * 0.20, s * 0.06, s * 0.20), dark)
			for i in range(3):
				ci.draw_circle(Vector2(cx - s * 0.24 + float(i) * s * 0.24, by - s * 0.36), s * 0.07, GameTheme.WHEAT)
				ci.draw_circle(Vector2(cx - s * 0.24 + float(i) * s * 0.24, by - s * 0.36), s * 0.03, orange)
		"pie":
			ci.draw_circle(Vector2(cx, by - s * 0.30), s * 0.24, dark)
			ci.draw_circle(Vector2(cx, by - s * 0.30), s * 0.20, gold)
			for i in range(4):
				ci.draw_line(Vector2(cx - s * 0.14 + float(i) * s * 0.09, by - s * 0.42),
						Vector2(cx - s * 0.10 + float(i) * s * 0.09, by - s * 0.18),
						orange, 2.0)
			for i in range(2):
				ci.draw_circle(Vector2(cx - s * 0.06 + float(i) * s * 0.12, by - s * 0.55), s * 0.035,
						Color(1, 1, 1, 0.35))
		"sauce":
			ci.draw_rect(Rect2(cx - s * 0.24, by - s * 0.30, s * 0.48, s * 0.22), GameTheme.CREAM)
			ci.draw_circle(Vector2(cx, by - s * 0.30), s * 0.22, GameTheme.CRANBERRY)
			for i in range(5):
				ci.draw_circle(Vector2(cx - s * 0.13 + float(i) * s * 0.065, by - s * 0.34), s * 0.035,
						GameTheme.CRANBERRY.darkened(0.2))
		"roast":
			ci.draw_rect(Rect2(cx - s * 0.34, by - s * 0.16, s * 0.68, s * 0.08), GameTheme.PAPER.darkened(0.2))
			ci.draw_circle(Vector2(cx, by - s * 0.34), s * 0.22, wood)
			ci.draw_circle(Vector2(cx - s * 0.05, by - s * 0.40), s * 0.14, wood.lightened(0.18))
			ci.draw_line(Vector2(cx + s * 0.12, by - s * 0.48), Vector2(cx + s * 0.18, by - s * 0.62), GameTheme.CREAM, 2.0)
		"cornucopia":
			ci.draw_arc(Vector2(cx - s * 0.10, by - s * 0.30), s * 0.24, -0.4, 2.6, 14, wood, 5.0)
			for i in range(4):
				ci.draw_circle(Vector2(cx + s * 0.10 + float(i % 2) * s * 0.08,
						by - s * 0.40 - float(i) * s * 0.06), s * 0.06,
						[orange, gold, green, GameTheme.CRANBERRY][i])
		"barn":
			ci.draw_rect(Rect2(cx - s * 0.28, by - s * 0.36, s * 0.56, s * 0.28), GameTheme.CRANBERRY)
			ci.draw_colored_polygon(PackedVector2Array([
				Vector2(cx - s * 0.34, by - s * 0.36), Vector2(cx, by - s * 0.58),
				Vector2(cx + s * 0.34, by - s * 0.36)]), dark)
			ci.draw_rect(Rect2(cx - s * 0.09, by - s * 0.22, s * 0.18, s * 0.14), dark)
			ci.draw_line(Vector2(cx - s * 0.09, by - s * 0.22), Vector2(cx + s * 0.09, by - s * 0.08), GameTheme.CREAM, 1.5)
		"maze":
			ci.draw_rect(Rect2(cx - s * 0.30, by - s * 0.52, s * 0.60, s * 0.44), green.darkened(0.25))
			ci.draw_rect(Rect2(cx - s * 0.20, by - s * 0.44, s * 0.06, s * 0.28), gold)
			ci.draw_rect(Rect2(cx - s * 0.20, by - s * 0.22, s * 0.26, s * 0.06), gold)
			ci.draw_rect(Rect2(cx + s * 0.12, by - s * 0.44, s * 0.06, s * 0.22), gold)
		"chimney":
			ci.draw_rect(Rect2(cx - s * 0.22, by - s * 0.34, s * 0.44, s * 0.26), wood.darkened(0.2))
			ci.draw_rect(Rect2(cx + s * 0.04, by - s * 0.54, s * 0.14, s * 0.22), GameTheme.HUSK)
			for i in range(3):
				ci.draw_circle(Vector2(cx + s * 0.18 + float(i) * s * 0.04,
						by - s * 0.62 - float(i) * s * 0.10), s * 0.07, Color(1, 1, 1, 0.28 - float(i) * 0.06))
		"window":
			ci.draw_rect(Rect2(cx - s * 0.28, by - s * 0.50, s * 0.56, s * 0.42), dark)
			ci.draw_rect(Rect2(cx - s * 0.22, by - s * 0.44, s * 0.44, s * 0.30), gold.darkened(0.15))
			ci.draw_line(Vector2(cx, by - s * 0.44), Vector2(cx, by - s * 0.14), dark, 2.0)
			ci.draw_circle(Vector2(cx, by - s * 0.28), s * 0.09, orange)
		"frost":
			for i in range(6):
				var a := float(i) * TAU / 6.0
				ci.draw_line(Vector2(cx, by - s * 0.30),
						Vector2(cx, by - s * 0.30) + Vector2(cos(a), sin(a)) * s * 0.26,
						Color("#cfe6f2"), 2.0)
				ci.draw_line(Vector2(cx, by - s * 0.30) + Vector2(cos(a), sin(a)) * s * 0.14,
						Vector2(cx, by - s * 0.30) + Vector2(cos(a + 0.5), sin(a + 0.5)) * s * 0.20,
						Color("#cfe6f2"), 1.5)
		"acorn":
			ci.draw_circle(Vector2(cx, by - s * 0.28), s * 0.18, wood)
			ci.draw_rect(Rect2(cx - s * 0.18, by - s * 0.44, s * 0.36, s * 0.10), dark)
			ci.draw_line(Vector2(cx, by - s * 0.44), Vector2(cx + s * 0.04, by - s * 0.54), dark, 3.0)
		"turkey":
			for i in range(5):
				var a := -PI * 0.15 - float(i) * PI * 0.17
				ci.draw_circle(Vector2(cx + s * 0.10 + cos(a) * s * 0.16,
						by - s * 0.34 + sin(a) * s * 0.16), s * 0.07,
						[orange, gold, GameTheme.CRANBERRY, gold, orange][i])
			ci.draw_circle(Vector2(cx - s * 0.06, by - s * 0.30), s * 0.14, dark)
			ci.draw_circle(Vector2(cx - s * 0.18, by - s * 0.40), s * 0.07, dark)
			ci.draw_colored_polygon(PackedVector2Array([
				Vector2(cx - s * 0.24, by - s * 0.40), Vector2(cx - s * 0.34, by - s * 0.37),
				Vector2(cx - s * 0.24, by - s * 0.34)]), gold)
			ci.draw_rect(Rect2(cx - s * 0.22, by - s * 0.34, s * 0.05, s * 0.08), GameTheme.CRANBERRY)
		"scarecrow":
			ci.draw_line(Vector2(cx, by - s * 0.56), Vector2(cx, by - s * 0.04), dark, 3.0)
			ci.draw_line(Vector2(cx - s * 0.28, by - s * 0.40), Vector2(cx + s * 0.28, by - s * 0.40), dark, 3.0)
			ci.draw_circle(Vector2(cx, by - s * 0.50), s * 0.11, GameTheme.WHEAT)
			ci.draw_rect(Rect2(cx - s * 0.24, by - s * 0.56, s * 0.48, s * 0.05), orange)
			ci.draw_rect(Rect2(cx - s * 0.16, by - s * 0.38, s * 0.32, s * 0.20), GameTheme.CRANBERRY)
			ci.draw_rect(Rect2(cx - s * 0.06, by - s * 0.51, s * 0.04, s * 0.04), ink)
			ci.draw_rect(Rect2(cx + s * 0.03, by - s * 0.51, s * 0.04, s * 0.04), ink)
		"lantern":
			ci.draw_rect(Rect2(cx - s * 0.16, by - s * 0.46, s * 0.32, s * 0.34), GameTheme.HUSK)
			ci.draw_rect(Rect2(cx - s * 0.10, by - s * 0.40, s * 0.20, s * 0.22), gold)
			ci.draw_circle(Vector2(cx, by - s * 0.30), s * 0.07, Color("#fff2cf"))
			ci.draw_line(Vector2(cx, by - s * 0.46), Vector2(cx, by - s * 0.58), dark, 2.0)
			ci.draw_line(Vector2(cx - s * 0.08, by - s * 0.58), Vector2(cx + s * 0.08, by - s * 0.58), dark, 2.0)
		"rod":
			ci.draw_line(Vector2(cx - s * 0.34, by - s * 0.06), Vector2(cx + s * 0.22, by - s * 0.58), wood, 3.0)
			ci.draw_line(Vector2(cx + s * 0.22, by - s * 0.58), Vector2(cx + s * 0.30, by - s * 0.10), GameTheme.CREAM, 1.0)
			ci.draw_circle(Vector2(cx + s * 0.30, by - s * 0.08), s * 0.05, orange)
			ci.draw_circle(Vector2(cx - s * 0.15, by - s * 0.34), s * 0.06, gold)
		_:
			ci.draw_circle(Vector2(cx, by - s * 0.30), s * 0.18, wood)


## Trophy plaque for the album's completion page / boat reveal.
static func draw_trophy(ci: CanvasItem, r: Rect2) -> void:
	ci.draw_rect(Rect2(r.position + Vector2(3.0, 4.0), r.size), Color(0, 0, 0, 0.30))
	ci.draw_rect(r, GameTheme.WOOD_DARK)
	ci.draw_rect(r.grow(-4.0), GameTheme.PANEL)
	ci.draw_rect(r.grow(-7.0), GameTheme.GOLD.darkened(0.35), false, 2.0)
	var cx := r.get_center().x
	var by := r.get_center().y + r.size.y * 0.24
	# little gilded hull
	ci.draw_colored_polygon(PackedVector2Array([
		Vector2(cx - r.size.x * 0.22, by - 8.0), Vector2(cx + r.size.x * 0.22, by - 8.0),
		Vector2(cx + r.size.x * 0.14, by + 6.0), Vector2(cx - r.size.x * 0.14, by + 6.0),
	]), GameTheme.WOOD)
	ci.draw_rect(Rect2(cx - r.size.x * 0.22, by - 10.0, r.size.x * 0.44, 4.0), GameTheme.GOLD)
	ci.draw_line(Vector2(cx, by - 12.0), Vector2(cx, by - r.size.y * 0.30), GameTheme.WOOD_DARK, 2.0)
	ci.draw_colored_polygon(PackedVector2Array([
		Vector2(cx + 2.0, by - r.size.y * 0.30), Vector2(cx + r.size.x * 0.14, by - r.size.y * 0.20),
		Vector2(cx + 2.0, by - r.size.y * 0.12)]), GameTheme.CRANBERRY)
	for i in range(5):
		var a := float(i) * TAU / 5.0 - 0.4
		ci.draw_circle(Vector2(cx + cos(a) * r.size.x * 0.16,
				by - r.size.y * 0.10 + sin(a) * r.size.y * 0.10), 3.0, GameTheme.GOLD)
	ci.draw_string(ThemeDB.fallback_font, Vector2(r.position.x, r.position.y + 22.0),
			"THE HARVEST QUEEN", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 14, GameTheme.GOLD)
	ci.draw_string(ThemeDB.fallback_font, Vector2(r.position.x, r.position.y + 38.0),
			"AUTUMN 2025", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 10, GameTheme.WHEAT)
