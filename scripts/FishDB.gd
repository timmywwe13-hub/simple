class_name FishDB
extends RefCounted

## All fish data + regional fish tables. All static.

static var REGIONS := ["pond", "river", "lake", "ocean"]
static var REGION_DISPLAY := {
	"pond": "Pond",
	"river": "River",
	"lake": "Lake",
	"ocean": "Deep Sea",
	"open": "Open Water",
}
static var REGION_UNLOCK_COST := {
	"pond": 0,
	"river": 120,
	"lake": 400,
	"ocean": 900,
}

static var FISH := {
	"minnow": {
		"id": "minnow", "name": "Minnow", "rarity": "Common", "region": "pond",
		"shape": "minnow", "pattern": "plain",
		"palette": {"body": "#8fb7c4", "belly": "#cfe8f2", "fin": "#5f7a8a", "eye": "#141d27"},
		"weight_kg": [0.02, 0.06], "coin": 4, "catch_rate": 1.0,
		"desc": "A tiny, shy fish of the shallows.",
	},
	"sunfish": {
		"id": "sunfish", "name": "Sunfish", "rarity": "Common", "region": "pond",
		"shape": "round", "pattern": "bands",
		"palette": {"body": "#e8a85c", "belly": "#f5d7a0", "fin": "#c16a3d", "eye": "#141d27"},
		"weight_kg": [0.1, 0.3], "coin": 9, "catch_rate": 0.9,
		"desc": "Round and golden, likes warm ponds.",
	},
	"trout": {
		"id": "trout", "name": "River Trout", "rarity": "Uncommon", "region": "river",
		"shape": "long", "pattern": "spots",
		"palette": {"body": "#7aa07a", "belly": "#cfe3c9", "fin": "#4d6b4d", "eye": "#141d27"},
		"weight_kg": [0.4, 1.2], "coin": 26, "catch_rate": 0.7,
		"desc": "Speckled silver of the running water.",
	},
	"perch": {
		"id": "perch", "name": "Perch", "rarity": "Uncommon", "region": "river",
		"shape": "minnow", "pattern": "stripes",
		"palette": {"body": "#d96c5c", "belly": "#f2bca6", "fin": "#a33e2e", "eye": "#141d27"},
		"weight_kg": [0.2, 0.6], "coin": 18, "catch_rate": 0.75,
		"desc": "Striped bandit of the river bend.",
	},
	"bass": {
		"id": "bass", "name": "Largemouth Bass", "rarity": "Rare", "region": "lake",
		"shape": "long", "pattern": "plain",
		"palette": {"body": "#3e6b54", "belly": "#9fd4ad", "fin": "#2a4a3c", "eye": "#141d27"},
		"weight_kg": [1.0, 3.5], "coin": 65, "catch_rate": 0.45,
		"desc": "A strong fighter from the deep lake.",
	},
	"catfish": {
		"id": "catfish", "name": "Whisker Catfish", "rarity": "Rare", "region": "lake",
		"shape": "eel", "pattern": "plain",
		"palette": {"body": "#5c5450", "belly": "#a8a098", "fin": "#3b3532", "eye": "#141d27"},
		"weight_kg": [1.5, 5.0], "coin": 75, "catch_rate": 0.4,
		"desc": "Bottom-dweller with long whiskers.",
	},
	"salmon": {
		"id": "salmon", "name": "Salmon", "rarity": "Epic", "region": "river",
		"shape": "long", "pattern": "plain",
		"palette": {"body": "#d95f45", "belly": "#f2b191", "fin": "#a33d27", "eye": "#141d27"},
		"weight_kg": [2.5, 6.0], "coin": 110, "catch_rate": 0.22,
		"desc": "Brilliant red, runs the river in autumn.",
	},
	"arowana": {
		"id": "arowana", "name": "Golden Arowana", "rarity": "Epic", "region": "lake",
		"shape": "eel", "pattern": "sparkle",
		"palette": {"body": "#f2d36a", "belly": "#fbeecf", "fin": "#d9a52e", "eye": "#141d27"},
		"weight_kg": [3.0, 7.0], "coin": 140, "catch_rate": 0.2,
		"desc": "Shimmering dragon-fish of still waters.",
	},
	"lanternfish": {
		"id": "lanternfish", "name": "Lanternfish", "rarity": "Legendary", "region": "ocean",
		"shape": "glow", "pattern": "glow",
		"palette": {"body": "#2c3e50", "belly": "#4a7a8f", "fin": "#1a222c", "eye": "#ffe08a"},
		"weight_kg": [0.3, 0.8], "coin": 260, "catch_rate": 0.08,
		"desc": "Glowing light from the midnight zone.",
	},
	"marlin": {
		"id": "marlin", "name": "Marlin", "rarity": "Legendary", "region": "ocean",
		"shape": "long", "pattern": "plain",
		"palette": {"body": "#1f4e5c", "belly": "#7fc7d9", "fin": "#0f2a36", "eye": "#141d27"},
		"weight_kg": [40.0, 120.0], "coin": 650, "catch_rate": 0.05,
		"desc": "King of the deep sea. A true trophy.",
	},
	# --- Open Water: reached by sailing past the edge of a spot in a boat ---
	"mackerel": {
		"id": "mackerel", "name": "Mackerel", "rarity": "Common", "region": "open",
		"shape": "minnow", "pattern": "stripes",
		"palette": {"body": "#4f8fb0", "belly": "#cfe8f2", "fin": "#2f627a", "eye": "#141d27"},
		"weight_kg": [0.5, 2.0], "coin": 30, "catch_rate": 1.0,
		"desc": "Fast silver streak of the open water.",
	},
	"flyingfish": {
		"id": "flyingfish", "name": "Flying Fish", "rarity": "Common", "region": "open",
		"shape": "minnow", "pattern": "plain",
		"palette": {"body": "#7fb6d9", "belly": "#d8eefb", "fin": "#4f86b0", "eye": "#141d27"},
		"weight_kg": [0.2, 0.8], "coin": 26, "catch_rate": 0.9,
		"desc": "Glides over the waves to escape trouble.",
	},
	"mola": {
		"id": "mola", "name": "Ocean Sunfish", "rarity": "Uncommon", "region": "open",
		"shape": "round", "pattern": "bands",
		"palette": {"body": "#93a9b8", "belly": "#dfe9ee", "fin": "#5d7280", "eye": "#141d27"},
		"weight_kg": [20.0, 80.0], "coin": 110, "catch_rate": 0.6,
		"desc": "A giant drifting sunbather.",
	},
	"mahi": {
		"id": "mahi", "name": "Mahi Mahi", "rarity": "Uncommon", "region": "open",
		"shape": "long", "pattern": "sparkle",
		"palette": {"body": "#3fae8f", "belly": "#f2d36a", "fin": "#2a7a63", "eye": "#141d27"},
		"weight_kg": [3.0, 12.0], "coin": 95, "catch_rate": 0.55,
		"desc": "Neon colors of the warm current.",
	},
	"bluefin": {
		"id": "bluefin", "name": "Bluefin Tuna", "rarity": "Rare", "region": "open",
		"shape": "long", "pattern": "plain",
		"palette": {"body": "#2c4c6e", "belly": "#a8c8e0", "fin": "#16293e", "eye": "#141d27"},
		"weight_kg": [40.0, 150.0], "coin": 280, "catch_rate": 0.3,
		"desc": "A torpedo of muscle and silver.",
	},
	"swordfish": {
		"id": "swordfish", "name": "Swordfish", "rarity": "Rare", "region": "open",
		"shape": "long", "pattern": "plain",
		"palette": {"body": "#35566e", "belly": "#b8d2e2", "fin": "#1c3140", "eye": "#141d27"},
		"weight_kg": [50.0, 200.0], "coin": 320, "catch_rate": 0.25,
		"desc": "Its bill parts the waves like a blade.",
	},
	"coelacanth": {
		"id": "coelacanth", "name": "Coelacanth", "rarity": "Legendary", "region": "open",
		"shape": "eel", "pattern": "sparkle",
		"palette": {"body": "#3a4a7a", "belly": "#7a8ac0", "fin": "#222c4c", "eye": "#ffe08a"},
		"weight_kg": [40.0, 90.0], "coin": 800, "catch_rate": 0.04,
		"desc": "A living fossil from another age.",
	},
}

static func fish_data(fish_id: String) -> Dictionary:
	return FISH.get(fish_id, {})

static func fish_by_region(region: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for fid in FISH.keys():
		var f: Dictionary = FISH[fid]
		if f.get("region") == region:
			out.append(f)
	return out

static func all_ids() -> Array:
	return FISH.keys()
