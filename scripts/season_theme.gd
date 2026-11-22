class_name SeasonTheme
extends RefCounted

## Seasonal UI palette (v1.9).
##
## One token table per season. GameTheme and UILib hold the same tokens as
## `static var`, so applying a season simply reassigns those variables -
## every screen that already reads GameTheme.* / UILib.* is re-skinned with
## no call-site changes. A future winter/summer event is one more table.

const DEFAULT_TABLE := {
	"INK": "#182236",
	"CREAM": "#f6ead8",
	"PAPER": "#f3e3c6",
	"PANEL": "#1d2536",
	"PANEL_LIGHT": "#33405a",
	"WOOD": "#8a5a3b",
	"WOOD_DARK": "#5f3d28",
	"GOLD": "#f2c14e",
	"LEAF": "#68a35c",
	"PUMPKIN": "#e2703a",
	"CRANBERRY": "#9c3d54",
	"WHEAT": "#e8d5a8",
	"EMBER": "#c9532b",
	"HUSK": "#6b4a2f",
	"BUTTON_HOVER": "#55708a",
	"BUTTON_PRESS": "#2c3d4d",
	"SUBTEXT": "#a8c0cc",
	"DIM": "#0b1320",
	"FAINT": "#8d9aa6",
	"RARITY_OUTLINE": "#00000000",
	"PANEL_BORDER": "#16202a", "BUTTON_BORDER": "#16202a", "BUTTON_BORDER_PRESS": "#0e151c",
	"SKY_TOP": "#f19cbb", "SKY_MID": "#f7bdcb", "SKY_LOW": "#f9d9d6",
	"CLOUD": "#fdf2f5",
	"GRASS": "#5d8c4c", "GRASS_DARK": "#3d6438",
	"DIRT": "#3a2a2d", "DIRT_LIGHT": "#4a3636",
	"MOUNTAIN_FAR": "#7a7296", "MOUNTAIN_MID": "#565e86",
}

const HARVEST_TABLE := {
	"INK": "#2a1a12",
	"CREAM": "#f7e6c4",
	"PAPER": "#f0dcb4",
	"PANEL": "#2b1d16",
	"PANEL_LIGHT": "#5b3826",
	"WOOD": "#a3662f",
	"WOOD_DARK": "#4a2d17",
	"GOLD": "#f2b03c",
	"LEAF": "#8f9b3f",
	"PUMPKIN": "#e2703a",
	"CRANBERRY": "#9c3d54",
	"WHEAT": "#e8d5a8",
	"EMBER": "#c9532b",
	"HUSK": "#6b4a2f",
	"BUTTON_HOVER": "#7a4a2c",
	"BUTTON_PRESS": "#3d2416",
	"SUBTEXT": "#d9c39a",
	"DIM": "#1a1008",
	"FAINT": "#9a8b74",
	"RARITY_OUTLINE": "#e0b070",
	"PANEL_BORDER": "#4a2d17", "BUTTON_BORDER": "#4a2d17", "BUTTON_BORDER_PRESS": "#2a170d",
	"SKY_TOP": "#d9843f", "SKY_MID": "#e8ac62", "SKY_LOW": "#f5d49a",
	"CLOUD": "#fbe4c2",
	"GRASS": "#7f8438", "GRASS_DARK": "#5b5f28",
	"DIRT": "#4a3220", "DIRT_LIGHT": "#63452c",
	"MOUNTAIN_FAR": "#a57a5a", "MOUNTAIN_MID": "#7d5640",
}

const TABLES := {
	"default": DEFAULT_TABLE,
	"harvest": HARVEST_TABLE,
}

static var _current := "default"


## Reassign the shared palette tokens. Safe to call repeatedly.
static func apply(id: String) -> void:
	var key := id if TABLES.has(id) else "default"
	if key == _current and _applied:
		return
	var t: Dictionary = TABLES[key]
	_current = key
	_apply_to_theme(t)
	_apply_to_ui(t)
	_applied = true


static var _applied := false


static func revert() -> void:
	apply("default")


static func current_id() -> String:
	return _current


static func is_harvest() -> bool:
	return _current == "harvest"


static func color(name: String, fallback := Color.WHITE) -> Color:
	var t: Dictionary = TABLES.get(_current, DEFAULT_TABLE)
	if not t.has(name):
		return fallback
	return Color(String(t[name]))


static func _apply_to_theme(t: Dictionary) -> void:
	GameTheme.INK = Color(String(t["INK"]))
	GameTheme.CREAM = Color(String(t["CREAM"]))
	GameTheme.PAPER = Color(String(t["PAPER"]))
	GameTheme.PANEL = Color(String(t["PANEL"]))
	GameTheme.PANEL_LIGHT = Color(String(t["PANEL_LIGHT"]))
	GameTheme.WOOD = Color(String(t["WOOD"]))
	GameTheme.WOOD_DARK = Color(String(t["WOOD_DARK"]))
	GameTheme.GOLD = Color(String(t["GOLD"]))
	GameTheme.LEAF = Color(String(t["LEAF"]))
	GameTheme.PUMPKIN = Color(String(t["PUMPKIN"]))
	GameTheme.CRANBERRY = Color(String(t["CRANBERRY"]))
	GameTheme.WHEAT = Color(String(t["WHEAT"]))
	GameTheme.EMBER = Color(String(t["EMBER"]))
	GameTheme.HUSK = Color(String(t["HUSK"]))
	GameTheme.BUTTON_HOVER = Color(String(t["BUTTON_HOVER"]))
	GameTheme.BUTTON_PRESS = Color(String(t["BUTTON_PRESS"]))
	GameTheme.SUBTEXT = Color(String(t["SUBTEXT"]))
	GameTheme.DIM = Color(String(t["DIM"]))
	GameTheme.FAINT = Color(String(t["FAINT"]))
	GameTheme.RARITY_OUTLINE = Color(String(t["RARITY_OUTLINE"]))
	GameTheme.SKY_TOP = Color(String(t["SKY_TOP"]))
	GameTheme.SKY_MID = Color(String(t["SKY_MID"]))
	GameTheme.SKY_LOW = Color(String(t["SKY_LOW"]))
	GameTheme.CLOUD = Color(String(t["CLOUD"]))
	GameTheme.GRASS = Color(String(t["GRASS"]))
	GameTheme.GRASS_DARK = Color(String(t["GRASS_DARK"]))
	GameTheme.DIRT = Color(String(t["DIRT"]))
	GameTheme.DIRT_LIGHT = Color(String(t["DIRT_LIGHT"]))
	GameTheme.MOUNTAIN_FAR = Color(String(t["MOUNTAIN_FAR"]))
	GameTheme.MOUNTAIN_MID = Color(String(t["MOUNTAIN_MID"]))
	GameTheme.PANEL_BORDER = Color(String(t["PANEL_BORDER"]))
	GameTheme.BUTTON_BORDER = Color(String(t["BUTTON_BORDER"]))
	GameTheme.BUTTON_BORDER_PRESS = Color(String(t["BUTTON_BORDER_PRESS"]))


static func _apply_to_ui(t: Dictionary) -> void:
	UILib.INK = Color(String(t["INK"]))
	UILib.CREAM = Color(String(t["CREAM"]))
	UILib.PAPER = Color(String(t["PAPER"]))
	UILib.PANEL = Color(String(t["PANEL"]))
	UILib.PANEL_LIGHT = Color(String(t["PANEL_LIGHT"]))
	UILib.WOOD = Color(String(t["WOOD"]))
	UILib.WOOD_DARK = Color(String(t["WOOD_DARK"]))
	UILib.GOLD = Color(String(t["GOLD"]))
	UILib.LEAF = Color(String(t["LEAF"]))
	UILib.PUMPKIN = Color(String(t["PUMPKIN"]))
	UILib.CRANBERRY = Color(String(t["CRANBERRY"]))
	UILib.WHEAT = Color(String(t["WHEAT"]))
	UILib.EMBER = Color(String(t["EMBER"]))
	UILib.HUSK = Color(String(t["HUSK"]))
	UILib.BUTTON_HOVER = Color(String(t["BUTTON_HOVER"]))
	UILib.BUTTON_PRESS = Color(String(t["BUTTON_PRESS"]))
	UILib.SUBTEXT = Color(String(t["SUBTEXT"]))
	UILib.DIM = Color(String(t["DIM"]))
	UILib.FAINT = Color(String(t["FAINT"]))
	UILib.RARITY_OUTLINE = Color(String(t["RARITY_OUTLINE"]))
	UILib.PANEL_BORDER = Color(String(t["PANEL_BORDER"]))
	UILib.BUTTON_BORDER = Color(String(t["BUTTON_BORDER"]))
	UILib.BUTTON_BORDER_PRESS = Color(String(t["BUTTON_BORDER_PRESS"]))
