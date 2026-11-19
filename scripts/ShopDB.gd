class_name ShopDB
extends RefCounted

## Shop / upgrade data. All static.

static var RODS := {
	"rod_stick": {"id": "rod_stick", "name": "Twig Rod", "cost": 0,
		"reel_speed": 1.0, "timing_window": 0.18, "desc": "A bent stick. Slow reeling.", "owned": true},
	"rod_wood": {"id": "rod_wood", "name": "Willow Rod", "cost": 150,
		"reel_speed": 1.4, "timing_window": 0.22, "desc": "Smoother flex, wider window.", "owned": false},
	"rod_bamboo": {"id": "rod_bamboo", "name": "Bamboo Rod", "cost": 500,
		"reel_speed": 1.9, "timing_window": 0.28, "desc": "Quick and responsive.", "owned": false},
	"rod_fiber": {"id": "rod_fiber", "name": "Reed Rod", "cost": 1200,
		"reel_speed": 2.5, "timing_window": 0.36, "desc": "Nearly effortless reeling.", "owned": false},
}

static var LINES := {
	"line_nylon": {"id": "line_nylon", "name": "Nylon Line", "cost": 0,
		"escape_chance": 0.30, "desc": "Snaps under pressure.", "owned": true},
	"line_silk": {"id": "line_silk", "name": "Silk Line", "cost": 200,
		"escape_chance": 0.20, "desc": "Holds better.", "owned": false},
	"line_braided": {"id": "line_braided", "name": "Braided Line", "cost": 600,
		"escape_chance": 0.12, "desc": "Rare fish stay on.", "owned": false},
}

static var BAITS := {
	"bait_worm": {"id": "bait_worm", "name": "Worm Bait", "cost": 30,
		"duration_sec": 60, "rarity_boost": ["Common", "Uncommon"], "desc": "Attracts common fish for 60s."},
	"bait_minnow": {"id": "bait_minnow", "name": "Minnow Bait", "cost": 90,
		"duration_sec": 90, "rarity_boost": ["Uncommon", "Rare"], "desc": "Draws rarer fish for 90s."},
	"bait_glow": {"id": "bait_glow", "name": "Glow Bait", "cost": 220,
		"duration_sec": 120, "rarity_boost": ["Rare", "Epic", "Legendary"], "desc": "Night-only lure for deep fish."},
}

static var BUCKETS := {
	"bucket_small": {"id": "bucket_small", "name": "Small Pail", "cost": 0,
		"capacity": 12, "owned": true, "desc": "Holds 12 fish."},
	"bucket_med": {"id": "bucket_med", "name": "Medium Creel", "cost": 250,
		"capacity": 24, "owned": false, "desc": "Holds 24 fish."},
	"bucket_large": {"id": "bucket_large", "name": "Large Creel", "cost": 700,
		"capacity": 48, "owned": false, "desc": "Holds 48 fish."},
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
}

static func category(category: String) -> Dictionary:
	return _db(category)

static func item(category: String, id: String) -> Dictionary:
	var db: Dictionary = _db(category)
	return db.get(id, {})

static func owned(category: String, id: String) -> bool:
	return _db(category).get(id, {}).get("owned", false)

static func set_owned(category: String, id: String, value: bool) -> void:
	var d: Dictionary = _db(category).get(id, {})
	if d:
		d["owned"] = value

static func _db(category: String) -> Dictionary:
	match category:
		"rods": return RODS
		"lines": return LINES
		"baits": return BAITS
		"buckets": return BUCKETS
		"boats": return BOATS
		_: return {}
