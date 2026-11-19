class_name GameTheme
extends RefCounted

static var INK := Color("#182236")
static var CREAM := Color("#f6ead8")
static var PAPER := Color("#f3e3c6")
static var PANEL := Color("#1d2536")
static var PANEL_LIGHT := Color("#33405a")
static var WOOD := Color("#8a5a3b")
static var WOOD_DARK := Color("#5f3d28")
static var GOLD := Color("#f2c14e")
static var LEAF := Color("#68a35c")

static var SKY_TOP := Color("#f19cbb")
static var SKY_MID := Color("#f7bdcb")
static var SKY_LOW := Color("#f9d9d6")
static var SKY_NIGHT_TOP := Color("#1a2138")
static var SKY_NIGHT_MID := Color("#2c3155")
static var SKY_NIGHT_LOW := Color("#5b4a6b")
static var SKY_DAY := SKY_MID
static var SKY_NIGHT := SKY_NIGHT_MID

static var WATER_SHALLOW := Color("#3a5a78")
static var WATER_MID := Color("#263d5c")
static var WATER_DEEP := Color("#14203b")
static var WATER_SURFACE := Color("#dfeef2")
static var WATER_DAY := WATER_SHALLOW
static var WATER_NIGHT := Color("#15243c")

static var MOUNTAIN_FAR := Color("#7a7296")
static var MOUNTAIN_MID := Color("#565e86")
static var MOUNTAIN_NEAR := Color("#3b4268")
static var PINE := Color("#2c4a4b")
static var PINE_DARK := Color("#22393b")
static var TREE := Color("#35564a")

static var GRASS := Color("#5d8c4c")
static var GRASS_DARK := Color("#3d6438")
static var DIRT := Color("#3a2a2d")
static var DIRT_LIGHT := Color("#4a3636")
static var ROCK := Color("#4b4653")

static var SHIRT := Color("#b55b3c")
static var SHIRT_DARK := Color("#8c4430")
static var PANTS := Color("#4d5d75")
static var SKIN := Color("#e5ac7d")
static var HAIR := Color("#3a2a24")
static var BOOT := Color("#2a2024")
static var ROD := Color("#5c3a26")
static var BELT := Color("#33242a")
static var BOBBER_RED := Color("#e2553f")
static var SAND := Color("#e6c998")

static var RARITY_ORDER := ["Common", "Uncommon", "Rare", "Epic", "Legendary"]
static var RARITY_COLORS := {
	"Common": Color("#9fb3bd"),
	"Uncommon": Color("#83b86d"),
	"Rare": Color("#7f9ef0"),
	"Epic": Color("#c98eea"),
	"Legendary": Color("#f2c14e"),
}
static var RARITY_CATCH_RATE := {
	"Common": 0.55,
	"Uncommon": 0.25,
	"Rare": 0.14,
	"Epic": 0.05,
	"Legendary": 0.01,
}

static func get_rarity_color(rarity: String) -> Color:
	return RARITY_COLORS.get(rarity, Color("#ffffff"))

static func get_rarity_rate(rarity: String) -> float:
	return RARITY_CATCH_RATE.get(rarity, 0.5)
