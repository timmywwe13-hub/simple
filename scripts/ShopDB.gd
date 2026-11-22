class_name ShopDB
extends RefCounted

## Shop / upgrade data. All static.

const GREEN_BASE_PERCENT := 40
const GREEN_STEP_PERCENT := 4

static var RODS := {
	"rod_stick": {"id": "rod_stick", "name": "Twig Rod", "cost": 0,
		"reel_speed": 1.0, "timing_window": 0.18, "desc": "A bent stick. Slow reeling, 40% green window.", "owned": true},
	"rod_wood": {"id": "rod_wood", "name": "Willow Rod", "cost": 150,
		"reel_speed": 1.4, "timing_window": 0.22, "desc": "Faster reel and a 4% wider green window.", "owned": false},
	"rod_bamboo": {"id": "rod_bamboo", "name": "Bamboo Rod", "cost": 500,
		"reel_speed": 1.9, "timing_window": 0.28, "desc": "Quick reel and an 8% wider green window.", "owned": false},
	"rod_fiber": {"id": "rod_fiber", "name": "Reed Rod", "cost": 1200,
		"reel_speed": 2.5, "timing_window": 0.36, "desc": "Very fast reel and a 12% wider green window.", "owned": false},
	"rod_carbon": {"id": "rod_carbon", "name": "Carbon Rod", "cost": 2600,
		"reel_speed": 3.2, "timing_window": 0.42, "desc": "Tournament blank: fastest reel and a 16% wider green window.", "owned": false},
}

## Island-crafted rods: exactly 25% better than the shop rod they are
## rebuilt from (Twig -> Palmwood, Willow -> Driftwood, Bamboo -> Bamboo
## Master, Reed -> Reed Master, Carbon -> Ancient). They are built from
## coconuts at Coconut Isle, so `owned` stays false until crafted.
static var CRAFTED_RODS := {
	"rod_palm": {"id": "rod_palm", "name": "Palmwood Rod", "reel_speed": 1.25,
		"timing_window": 0.225, "base_rod": "rod_stick", "cost": 4,
		"desc": "25% better than the Twig Rod.", "owned": false},
	"rod_driftwood": {"id": "rod_driftwood", "name": "Driftwood Rod", "reel_speed": 1.75,
		"timing_window": 0.275, "base_rod": "rod_wood", "cost": 6,
		"desc": "25% better than the Willow Rod.", "owned": false},
	"rod_bamboo_master": {"id": "rod_bamboo_master", "name": "Bamboo Master Rod", "reel_speed": 2.375,
		"timing_window": 0.35, "base_rod": "rod_bamboo", "cost": 8,
		"desc": "25% better than the Bamboo Rod.", "owned": false},
	"rod_fiber_master": {"id": "rod_fiber_master", "name": "Reed Master Rod", "reel_speed": 3.125,
		"timing_window": 0.45, "base_rod": "rod_fiber", "cost": 10,
		"desc": "25% better than the Reed Rod.", "owned": false},
	"rod_ancient": {"id": "rod_ancient", "name": "Ancient Rod", "reel_speed": 4.0,
		"timing_window": 0.525, "base_rod": "rod_carbon", "cost": 14,
		"desc": "25% better than the Carbon Rod.", "owned": false},
}

const AXE_COST := 100
const PALM_AXE_COST := 350

static var LINES := {
	"line_nylon": {"id": "line_nylon", "name": "Nylon Line", "cost": 0,
		"escape_chance": 0.30, "desc": "Snaps under pressure.", "owned": true},
	"line_silk": {"id": "line_silk", "name": "Silk Line", "cost": 200,
		"escape_chance": 0.20, "desc": "Holds better.", "owned": false},
	"line_braided": {"id": "line_braided", "name": "Braided Line", "cost": 600,
		"escape_chance": 0.12, "desc": "Rare fish stay on.", "owned": false},
	"line_fluoro": {"id": "line_fluoro", "name": "Fluorocarbon Line", "cost": 1400,
		"escape_chance": 0.06, "desc": "Almost nothing shakes this line.", "owned": false},
}

## Bait is a consumable bought at the shop: every purchase adds `charges`
## casts to the bag, and each cast uses one. Rare fish almost never bite
## without it - see main.gd NO_BAIT_PENALTY.
static var BAITS := {
	"bait_worm": {"id": "bait_worm", "name": "Worm Bait", "cost": 30,
		"charges": 5, "duration_sec": 60, "rarity_boost": ["Common", "Uncommon"],
		"desc": "5 casts that draw common and uncommon fish."},
	"bait_minnow": {"id": "bait_minnow", "name": "Minnow Bait", "cost": 90,
		"charges": 4, "duration_sec": 90, "rarity_boost": ["Uncommon", "Rare"],
		"desc": "4 casts that draw rare fish. Rare fish need bait!"},
	"bait_glow": {"id": "bait_glow", "name": "Glow Bait", "cost": 220,
		"charges": 3, "duration_sec": 120, "rarity_boost": ["Rare", "Epic", "Legendary"],
		"desc": "3 casts of the deep: epic and legendary fish."},
	"bait_moon": {"id": "bait_moon", "name": "Moon Bait", "cost": 150,
		"charges": 4, "duration_sec": 120, "rarity_boost": ["Uncommon", "Rare", "Epic"],
		"time_boost": "night",
		"desc": "4 night casts that draw the moonfin hunters."},
	"bait_storm": {"id": "bait_storm", "name": "Storm Bait", "cost": 240,
		"charges": 3, "duration_sec": 120, "rarity_boost": ["Rare", "Epic", "Legendary"],
		"weather_boost": ["rain", "storm"],
		"desc": "3 foul-weather casts. Bad weather fish love it."},
}

static var BUCKETS := {
	"bucket_small": {"id": "bucket_small", "name": "Small Pail", "cost": 0,
		"capacity": 12, "owned": true, "desc": "Holds 12 fish."},
	"bucket_med": {"id": "bucket_med", "name": "Medium Creel", "cost": 250,
		"capacity": 24, "owned": false, "desc": "Holds 24 fish."},
	"bucket_large": {"id": "bucket_large", "name": "Large Creel", "cost": 700,
		"capacity": 48, "owned": false, "desc": "Holds 48 fish."},
	"bucket_cooler": {"id": "bucket_cooler", "name": "Deck Cooler", "cost": 1500,
		"capacity": 72, "owned": false, "desc": "Holds 72 fish and keeps them fresh."},
}

## Lanterns make night fishing easier: lower night_bite means faster bites,
## higher night_rare means rarer night fish are more likely.
static var LANTERNS := {
	"lantern_none": {"id": "lantern_none", "name": "No Lantern", "cost": 0,
		"night_bite": 1.0, "night_rare": 1.0, "owned": true,
		"desc": "Fishing blind after dark."},
	"lantern_oil": {"id": "lantern_oil", "name": "Oil Lamp", "cost": 260,
		"night_bite": 0.90, "night_rare": 1.25, "owned": false,
		"desc": "A warm flame. Night bites come 10% faster."},
	"lantern_storm": {"id": "lantern_storm", "name": "Storm Lantern", "cost": 750,
		"night_bite": 0.80, "night_rare": 1.55, "owned": false,
		"desc": "Sealed against the wind. Night rare fish love it."},
	"lantern_harvest": {"id": "lantern_harvest", "name": "Harvest Lantern", "cost": 0,
		"token_cost": 40, "season": "harvest", "night_bite": 0.85, "night_rare": 1.45,
		"owned": false, "desc": "A warm harvest glow. Bought with 40 Feast tokens."},
}

static var BOATS := {
	"boat_raft": {"id": "boat_raft", "name": "Old Raft", "cost": 0,
		"speed": 90.0, "value_mult": 1.00, "desc": "A patched raft. It floats... mostly.", "owned": true},
	"boat_rowboat": {"id": "boat_rowboat", "name": "Pine Rowboat", "cost": 400,
		"speed": 130.0, "value_mult": 1.05, "desc": "Sturdy oars. Fish fetch 5% more.", "owned": false},
	"boat_skiff": {"id": "boat_skiff", "name": "Lake Skiff", "cost": 900,
		"speed": 170.0, "value_mult": 1.10, "desc": "Light and quick on open water.", "owned": false},
	"boat_trawler": {"id": "boat_trawler", "name": "Sea Trawler", "cost": 2200,
		"speed": 215.0, "value_mult": 1.20, "desc": "Deep-sea ready. Fish fetch 20% more.", "owned": false},
	# Award-only grand prize: exactly the Trawler's stats, granted once at
	# 20/20 cards. buy_boat() refuses award_only hulls.
	"boat_harvest": {"id": "boat_harvest", "name": "The Harvest Queen", "cost": 0,
		"speed": 215.0, "value_mult": 1.20, "award_only": true,
		"desc": "Gilded autumn hull. Awarded for completing the Harvest album.", "owned": false},
}

## Rod tier from the hidden timing_window marker: 0 = Twig, 4 = Carbon.
## Crafted rod timings map through these same thresholds.
static func rod_tier(rod_id: String) -> int:
	var tw := float(item("rods", rod_id).get("timing_window", 0.18))
	if tw >= 0.40:
		return 4
	if tw >= 0.34:
		return 3
	if tw >= 0.26:
		return 2
	if tw >= 0.20:
		return 1
	return 0


## Total width of the timing green as a percentage of the bar. Every shop
## rod adds 4 points; crafted rods sit one tier above their base rod.
static func rod_green_percent(rod_id: String) -> int:
	return GREEN_BASE_PERCENT + GREEN_STEP_PERCENT * rod_tier(rod_id)


static func category(category: String) -> Dictionary:
	return _db(category)

static func item(category: String, id: String) -> Dictionary:
	if category == "rods":
		if RODS.has(id):
			return RODS[id]
		return CRAFTED_RODS.get(id, {})
	return _db(category).get(id, {})

static func crafted_recipe(id: String) -> Dictionary:
	var d: Dictionary = CRAFTED_RODS.get(id, {})
	if d.is_empty():
		return {}
	return {"coconuts": int(d.get("cost", 4)), "base_rod": String(d.get("base_rod", "")),
		"name": String(d.get("name", id))}

static func owned(category: String, id: String) -> bool:
	if category == "rods" and CRAFTED_RODS.has(id):
		return bool(CRAFTED_RODS[id].get("owned", false))
	return bool(_db(category).get(id, {}).get("owned", false))

static func set_owned(category: String, id: String, value: bool) -> void:
	var d: Dictionary = _db(category).get(id, {})
	if d.is_empty() and category == "rods":
		d = CRAFTED_RODS.get(id, {})
	if d:
		d["owned"] = value

## Owned rod ids of both lists, so bought and crafted rods survive a
## save/load (the static tables reset every launch).
static func owned_rod_ids() -> Array:
	var out: Array = []
	for id in RODS.keys():
		if bool(RODS[id].get("owned", false)):
			out.append(String(id))
	for id in CRAFTED_RODS.keys():
		if bool(CRAFTED_RODS[id].get("owned", false)):
			out.append(String(id))
	return out

static func mark_owned_rods(ids: Array) -> void:
	for id_v in ids:
		var id := String(id_v)
		if RODS.has(id):
			RODS[id]["owned"] = true
		elif CRAFTED_RODS.has(id):
			CRAFTED_RODS[id]["owned"] = true

## Owned ids of a non-rod category, so bought lines / buckets / lanterns
## (including the token-bought Harvest Lantern) survive a restart.
static func owned_ids(category: String) -> Array:
	var out: Array = []
	var db := _db(category)
	for id in db.keys():
		if bool(db[id].get("owned", false)):
			out.append(String(id))
	return out

static func mark_owned(category: String, ids: Array) -> void:
	var db := _db(category)
	for id_v in ids:
		var id := String(id_v)
		if db.has(id):
			db[id]["owned"] = true

static func reset_owned() -> void:
	for db in [RODS, CRAFTED_RODS, LINES, BUCKETS, LANTERNS, BOATS]:
		for id in db.keys():
			db[id]["owned"] = false
	RODS["rod_stick"]["owned"] = true
	LINES["line_nylon"]["owned"] = true
	BUCKETS["bucket_small"]["owned"] = true
	LANTERNS["lantern_none"]["owned"] = true
	BOATS["boat_raft"]["owned"] = true

static func _db(category: String) -> Dictionary:
	match category:
		"rods": return RODS
		"lines": return LINES
		"baits": return BAITS
		"lanterns": return LANTERNS
		"buckets": return BUCKETS
		"boats": return BOATS
		_: return {}
