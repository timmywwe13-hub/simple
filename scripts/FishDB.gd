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
		"features": ["whiskers"],
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
		"features": ["whiskers"],
		"weight_kg": [3.0, 7.0], "coin": 140, "catch_rate": 0.2,
		"desc": "Shimmering dragon-fish of still waters.",
	},
	"lanternfish": {
		"id": "lanternfish", "name": "Lanternfish", "rarity": "Legendary", "region": "ocean",
		"shape": "glow", "pattern": "glow",
		"palette": {"body": "#2c3e50", "belly": "#4a7a8f", "fin": "#1a222c", "eye": "#ffe08a"},
		"features": ["lantern", "big_eye"],
		"weight_kg": [0.3, 0.8], "coin": 260, "catch_rate": 0.08,
		"desc": "Glowing light from the midnight zone.",
	},
	"marlin": {
		"id": "marlin", "name": "Marlin", "rarity": "Legendary", "region": "ocean",
		"shape": "long", "pattern": "plain",
		"palette": {"body": "#1f4e5c", "belly": "#7fc7d9", "fin": "#0f2a36", "eye": "#141d27"},
		"features": ["bill"],
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
		"features": ["bill"],
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
	# --- 20 new species: pond, river, lake, deep sea and open water ---
	"bluegill": {
		"id": "bluegill", "name": "Bluegill", "rarity": "Common", "region": "pond",
		"shape": "round", "pattern": "checker",
		"palette": {"body": "#4f9c8e", "belly": "#f2b06a", "fin": "#2f6e62", "eye": "#141d27"},
		"weight_kg": [0.2, 0.7], "coin": 12, "catch_rate": 0.85,
		"desc": "A scrappy pond favorite with jade flanks.",
	},
	"koi": {
		"id": "koi", "name": "Golden Koi", "rarity": "Uncommon", "region": "pond",
		"shape": "long", "pattern": "sparkle",
		"palette": {"body": "#f2b64b", "belly": "#fdf0d0", "fin": "#e2853a", "eye": "#141d27"},
		"features": ["whiskers"],
		"weight_kg": [1.0, 4.0], "coin": 55, "catch_rate": 0.5,
		"desc": "A living jewel, treasured for a thousand years.",
	},
	"carp": {
		"id": "carp", "name": "Dusky Carp", "rarity": "Uncommon", "region": "pond",
		"shape": "long", "pattern": "bands",
		"palette": {"body": "#8a6b3f", "belly": "#d9bd8a", "fin": "#5c4526", "eye": "#141d27"},
		"features": ["whiskers"],
		"weight_kg": [2.0, 8.0], "coin": 60, "catch_rate": 0.48,
		"desc": "Old, broad, and wise to every trick.",
	},
	"puddle_puffer": {
		"id": "puddle_puffer", "name": "Puddle Puffer", "rarity": "Rare", "region": "pond",
		"shape": "puffer", "pattern": "spots",
		"palette": {"body": "#e8c94f", "belly": "#fdf3c2", "fin": "#b8932c", "eye": "#141d27"},
		"features": ["spikes", "big_eye"],
		"weight_kg": [0.4, 1.2], "coin": 90, "catch_rate": 0.3,
		"desc": "Inflates to twice its size when startled.",
	},
	"darter": {
		"id": "darter", "name": "Rainbow Darter", "rarity": "Common", "region": "river",
		"shape": "minnow", "pattern": "stripes",
		"palette": {"body": "#4fa8a0", "belly": "#f2a6b8", "fin": "#e2763a", "eye": "#141d27"},
		"weight_kg": [0.05, 0.15], "coin": 14, "catch_rate": 0.9,
		"desc": "A darting jewel of the riffles.",
	},
	"emerald_eel": {
		"id": "emerald_eel", "name": "Emerald Eel", "rarity": "Uncommon", "region": "river",
		"shape": "eel", "pattern": "glow_veins",
		"palette": {"body": "#2f8a5c", "belly": "#8fd9a8", "fin": "#1c5c3c", "eye": "#ffe08a"},
		"weight_kg": [1.0, 3.0], "coin": 70, "catch_rate": 0.45,
		"desc": "Slides through stone gaps at dusk.",
	},
	"pike": {
		"id": "pike", "name": "Northern Pike", "rarity": "Rare", "region": "river",
		"shape": "long", "pattern": "plain",
		"palette": {"body": "#5c7a3f", "belly": "#cfe0a0", "fin": "#3d5426", "eye": "#141d27"},
		"features": ["fangs"],
		"weight_kg": [3.0, 12.0], "coin": 150, "catch_rate": 0.28,
		"desc": "An ambush predator with a toothy grin.",
	},
	"crimson_gar": {
		"id": "crimson_gar", "name": "Crimson Gar", "rarity": "Rare", "region": "river",
		"shape": "shark", "pattern": "checker",
		"palette": {"body": "#b0403a", "belly": "#e89a86", "fin": "#7c2721", "eye": "#141d27"},
		"features": ["bill"],
		"weight_kg": [2.0, 9.0], "coin": 160, "catch_rate": 0.25,
		"desc": "Armored in red, patient as a floating log.",
	},
	"kelp_grouper": {
		"id": "kelp_grouper", "name": "Kelp Grouper", "rarity": "Uncommon", "region": "lake",
		"shape": "round", "pattern": "bands",
		"palette": {"body": "#4f6b45", "belly": "#b8c98f", "fin": "#33472c", "eye": "#141d27"},
		"weight_kg": [2.0, 7.0], "coin": 85, "catch_rate": 0.5,
		"desc": "Lurks in the kelp beds, all mouth and patience.",
	},
	"tiger_muskie": {
		"id": "tiger_muskie", "name": "Tiger Muskie", "rarity": "Rare", "region": "lake",
		"shape": "long", "pattern": "stripes",
		"palette": {"body": "#7a7a3f", "belly": "#e8d98f", "fin": "#4f4f26", "eye": "#141d27"},
		"features": ["fangs"],
		"weight_kg": [5.0, 18.0], "coin": 200, "catch_rate": 0.25,
		"desc": "The striped phantom of the weedy bays.",
	},
	"sturgeon": {
		"id": "sturgeon", "name": "Lake Sturgeon", "rarity": "Rare", "region": "lake",
		"shape": "long", "pattern": "scales",
		"palette": {"body": "#5a6672", "belly": "#c2ccd6", "fin": "#39424c", "eye": "#141d27"},
		"features": ["spikes", "whiskers"],
		"weight_kg": [20.0, 90.0], "coin": 320, "catch_rate": 0.2,
		"desc": "An armored relic older than the lake itself.",
	},
	"opaline_cichlid": {
		"id": "opaline_cichlid", "name": "Opaline Cichlid", "rarity": "Epic", "region": "lake",
		"shape": "round", "pattern": "sparkle",
		"palette": {"body": "#d98fc2", "belly": "#8fe0d4", "fin": "#9a5cb8", "eye": "#141d27"},
		"features": ["crest", "big_eye"],
		"weight_kg": [0.8, 2.2], "coin": 240, "catch_rate": 0.12,
		"desc": "Shimmers like a cut opal in the shallows.",
	},
	"hammerhead": {
		"id": "hammerhead", "name": "Hammerhead Shark", "rarity": "Rare", "region": "ocean",
		"shape": "shark", "pattern": "plain",
		"palette": {"body": "#4a6b7c", "belly": "#c2d8e2", "fin": "#2c4551", "eye": "#141d27"},
		"features": ["hammer", "spikes"],
		"weight_kg": [60.0, 200.0], "coin": 420, "catch_rate": 0.16,
		"desc": "Its strange head sweeps the deep for prey.",
	},
	"manta": {
		"id": "manta", "name": "Manta Ray", "rarity": "Rare", "region": "ocean",
		"shape": "ray", "pattern": "plain",
		"palette": {"body": "#2c4c66", "belly": "#dfeaf2", "fin": "#1a2f42", "eye": "#141d27"},
		"features": ["wings"],
		"weight_kg": [80.0, 300.0], "coin": 450, "catch_rate": 0.15,
		"desc": "A gliding giant that flies through the blue.",
	},
	"deep_angler": {
		"id": "deep_angler", "name": "Deep Sea Angler", "rarity": "Epic", "region": "ocean",
		"shape": "deep", "pattern": "glow",
		"palette": {"body": "#2a2438", "belly": "#4c3f62", "fin": "#171224", "eye": "#ffe08a"},
		"features": ["lantern", "fangs"],
		"weight_kg": [2.0, 9.0], "coin": 380, "catch_rate": 0.1,
		"desc": "It carries its own lantern into the dark.",
	},
	"viperfish": {
		"id": "viperfish", "name": "Viperfish", "rarity": "Epic", "region": "ocean",
		"shape": "shark", "pattern": "glow_veins",
		"palette": {"body": "#39424f", "belly": "#7c8fa8", "fin": "#222a36", "eye": "#ffe08a"},
		"features": ["fangs", "big_eye"],
		"weight_kg": [1.0, 3.5], "coin": 360, "catch_rate": 0.1,
		"desc": "Needle fangs in the midnight zone.",
	},
	"goblin_shark": {
		"id": "goblin_shark", "name": "Goblin Shark", "rarity": "Epic", "region": "ocean",
		"shape": "shark", "pattern": "speckle",
		"palette": {"body": "#b07c86", "belly": "#e8c6c9", "fin": "#7c4f5c", "eye": "#141d27"},
		"features": ["bill", "fangs"],
		"weight_kg": [40.0, 120.0], "coin": 520, "catch_rate": 0.08,
		"desc": "A living fossil with a phantom snout.",
	},
	"oarfish": {
		"id": "oarfish", "name": "Giant Oarfish", "rarity": "Legendary", "region": "ocean",
		"shape": "ribbon", "pattern": "sparkle",
		"palette": {"body": "#c9ccd6", "belly": "#f2f3f8", "fin": "#c23c4c", "eye": "#141d27"},
		"features": ["crest", "streamer"],
		"weight_kg": [30.0, 150.0], "coin": 900, "catch_rate": 0.035,
		"desc": "The sea serpent itself, draped in silver.",
	},
	"wahoo": {
		"id": "wahoo", "name": "Wahoo", "rarity": "Uncommon", "region": "open",
		"shape": "shark", "pattern": "stripes",
		"palette": {"body": "#3f8aa8", "belly": "#cfe8f2", "fin": "#2a5f78", "eye": "#141d27"},
		"weight_kg": [8.0, 30.0], "coin": 180, "catch_rate": 0.5,
		"desc": "A striped torpedo that hunts at full speed.",
	},
	"sailfish": {
		"id": "sailfish", "name": "Sailfish", "rarity": "Legendary", "region": "open",
		"shape": "long", "pattern": "plain",
		"palette": {"body": "#2c4c8a", "belly": "#a8c8e8", "fin": "#1c3160", "eye": "#141d27"},
		"features": ["sail", "bill"],
		"weight_kg": [30.0, 90.0], "coin": 950, "catch_rate": 0.035,
		"desc": "Its sail rises like a banner over the waves.",
	},
	# --- The monster: roams every water, and it bites back when you pull it in ---
	"volt_serpent": {
		"id": "volt_serpent", "name": "Volt Serpent", "rarity": "Legendary", "region": "open",
		"anywhere": true, "monster": true,
		"shape": "serpent", "pattern": "lightning",
		"palette": {"body": "#241c42", "belly": "#4fd7f2", "fin": "#38e0ff", "eye": "#ffe45c"},
		"features": ["big_eye", "fangs", "spikes", "glow"],
		"weight_kg": [12.0, 45.0], "coin": 1200, "catch_rate": 0.09,
		"desc": "A living lightning bolt. It bites back - and it is fast.",
	},
	# --- Weather fish: they only bite in their own weather (see fish_pool) ---
	"rain_dace": {
		"id": "rain_dace", "name": "Rain Dace", "rarity": "Common", "region": "pond",
		"weather": "rain",
		"shape": "minnow", "pattern": "sparkle",
		"palette": {"body": "#6f9fc9", "belly": "#d2e8f6", "fin": "#4a76a8", "eye": "#141d27"},
		"weight_kg": [0.1, 0.4], "coin": 22, "catch_rate": 0.5,
		"desc": "Dances at the surface when the rain falls.",
	},
	"rainbow_trout": {
		"id": "rainbow_trout", "name": "Rainbow Trout", "rarity": "Uncommon", "region": "river",
		"weather": "rain",
		"shape": "long", "pattern": "sparkle",
		"palette": {"body": "#7fb0c9", "belly": "#f2c6d8", "fin": "#5f86b0", "eye": "#141d27"},
		"weight_kg": [0.5, 2.2], "coin": 65, "catch_rate": 0.45,
		"desc": "Its colors shine brightest under the rain.",
	},
	"thunder_pike": {
		"id": "thunder_pike", "name": "Thunder Pike", "rarity": "Epic", "region": "lake",
		"weather": "storm",
		"shape": "long", "pattern": "lightning",
		"palette": {"body": "#3c4a66", "belly": "#a8c8e0", "fin": "#25324a", "eye": "#ffe08a"},
		"features": ["fangs", "spikes"],
		"weight_kg": [4.0, 15.0], "coin": 340, "catch_rate": 0.35,
		"desc": "Only hunts while the thunder rolls.",
	},
	"storm_herring": {
		"id": "storm_herring", "name": "Storm Herring", "rarity": "Rare", "region": "open",
		"weather": "storm",
		"shape": "minnow", "pattern": "glow_veins",
		"palette": {"body": "#4a6b8a", "belly": "#bfe4f2", "fin": "#2f4a66", "eye": "#141d27"},
		"weight_kg": [1.0, 4.0], "coin": 190, "catch_rate": 0.4,
		"desc": "Rides the storm swell in silver shoals.",
	},
	# --- Day / night specialists: they only bite at their own hour ---
	"sunrise_bream": {
		"id": "sunrise_bream", "name": "Sunrise Bream", "rarity": "Uncommon", "region": "pond",
		"time": "day",
		"shape": "round", "pattern": "bands",
		"palette": {"body": "#e89a63", "belly": "#f7d9a8", "fin": "#c56a4a", "eye": "#141d27"},
		"features": ["crest"],
		"weight_kg": [0.2, 0.8], "coin": 34, "catch_rate": 0.5,
		"desc": "Glows pink at first light, then hides for the day.",
	},
	"dawn_gar": {
		"id": "dawn_gar", "name": "Dawn Gar", "rarity": "Rare", "region": "lake",
		"time": "day",
		"shape": "long", "pattern": "speckle",
		"palette": {"body": "#7d9a72", "belly": "#e0ecc8", "fin": "#4d6b4d", "eye": "#d9b04c"},
		"features": ["fangs"],
		"weight_kg": [2.0, 8.0], "coin": 140, "catch_rate": 0.3,
		"desc": "Patrols the reeds while the sun is up.",
	},
	"moonfin_eel": {
		"id": "moonfin_eel", "name": "Moonfin Eel", "rarity": "Rare", "region": "river",
		"time": "night",
		"shape": "eel", "pattern": "glow_veins",
		"palette": {"body": "#273b58", "belly": "#9fc8d8", "fin": "#1c2c46", "eye": "#e6f4ff"},
		"features": ["lantern"],
		"weight_kg": [0.8, 3.5], "coin": 120, "catch_rate": 0.35,
		"desc": "A silver ribbon that only rises after moonrise.",
	},
	"ghost_carp": {
		"id": "ghost_carp", "name": "Ghost Carp", "rarity": "Epic", "region": "lake",
		"time": "night",
		"shape": "round", "pattern": "scales",
		"palette": {"body": "#c8d8e8", "belly": "#f2f7ff", "fin": "#8fa8c0", "eye": "#dfe9f5"},
		"features": ["glow", "streamer"],
		"weight_kg": [3.0, 12.0], "coin": 320, "catch_rate": 0.18,
		"desc": "A pale shape under the moon - blink and it is gone.",
	},
	"mist_herring": {
		"id": "mist_herring", "name": "Mist Herring", "rarity": "Rare", "region": "ocean",
		"weather": "rain",
		"shape": "minnow", "pattern": "sparkle",
		"palette": {"body": "#8fb0c8", "belly": "#e8f4ff", "fin": "#5f86a8", "eye": "#141d27"},
		"features": ["streamer"],
		"weight_kg": [0.4, 1.8], "coin": 160, "catch_rate": 0.4,
		"desc": "Schools in the grey rain-mist above the reef.",
	},
	"thunderhead_grouper": {
		"id": "thunderhead_grouper", "name": "Thunderhead Grouper", "rarity": "Epic", "region": "ocean",
		"weather": "storm",
		"shape": "round", "pattern": "lightning",
		"palette": {"body": "#37425f", "belly": "#b8cce0", "fin": "#232c44", "eye": "#ffe08a"},
		"features": ["spikes", "fangs"],
		"weight_kg": [8.0, 30.0], "coin": 380, "catch_rate": 0.3,
		"desc": "Hides under the storm and hits like a wave.",
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

## Everything that can bite at a spot: the region's own table plus the
## roaming monsters (fish flagged "anywhere"), filtered by the weather and
## the hour. A fish with a "weather" tag only bites in that weather; one
## with a "time" tag only bites by day or by night.
static func fish_pool(region: String, weather := "", night := false) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for f in fish_by_region(region):
		out.append(f)
	for fid in FISH.keys():
		var roaming: Dictionary = FISH[fid]
		if bool(roaming.get("anywhere", false)) and not out.has(roaming):
			out.append(roaming)
	var filtered: Array[Dictionary] = []
	for f in out:
		var need := String(f.get("weather", ""))
		if need != "" and need != weather:
			continue
		var need_time := String(f.get("time", ""))
		if need_time == "night" and not night:
			continue
		if need_time == "day" and night:
			continue
		filtered.append(f)
	return filtered
