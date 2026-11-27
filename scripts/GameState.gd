extends Node

const CasinoDBLib := preload("res://scripts/casino_db.gd")
const HarvestCardsLib := preload("res://scripts/harvest_cards.gd")
const AlmanacLib := preload("res://scripts/almanac_db.gd")

## Persistent game state: coins, inventory, fish index, gear, quests.
## Saved to user://save.json via FileAccess store_var/get_var.
## Also owns the procedural audio player (see play_sound()).

var coins := 50
## Last Lucky Lily stake chosen by the player, persisted with the save.
var casino_bet := 10
var inventory := []
var index := {}
var gear := {"rod": "rod_stick", "line": "line_nylon", "bait": "", "bucket": "bucket_small",
	"boat": "boat_raft", "lantern": "lantern_none"}
var owned_boats: Array = ["boat_raft"]
var unlocked_regions := ["pond", "island"]
## Bait is a consumable bought at the shop: bait id -> casts left in the bag.
## Each cast with bait equipped uses one; without bait rare fish barely bite.
var bait_counts := {}
var total_caught := 0
## Lifetime stats for the stats screen. Merged on load so old saves gain it.
var stats := {
	"coins_earned": 0, "fish_sold": 0, "perfect_catches": 0,
	"current_streak": 0, "best_streak": 0, "daily_catches": 0,
	"biggest_fish": 0.0, "biggest_name": "", "days_fished": 0,
	"casino_wagered": 0, "casino_returned": 0, "casino_wins": 0,
	"casino_biggest_win": 0, "lines_set": 0,
}
var muted := false
## The version whose What's New screen has been read (shown once with a
## badge on the menu until opened).
var seen_version := ""
## 2x coin launch event: every coin earned is doubled until this unix
## timestamp. A brand new save (or an old save without the field) starts
## its own 12-hour window on first load, so nobody misses it.
const EVENT_SECONDS := 12 * 3600
var event_until := 0
## Coconut Isle progression: axe ownership, coconut inventory and unix
## timestamps for felled palms. Timers keep running between sessions.
var has_axe := false
var axe_level := 1
var coconuts := 0
var chopped_palms := {}
const PALM_REGROW_SEC := 1200
const PALM_IDS := ["palm_0", "palm_1", "palm_2", "palm_3"]
## True once a session is underway (the player started fishing or travelled).
## Used so returning from the Town resumes the fishing scene instead of
## showing the start screen again. Not saved - a fresh boot shows the menu.
var session_started := false

## --- Angler's Almanac (v1.10) ---------------------------------------
## Mastery stores only the highest rank already paid per species; the rank
## shown anywhere is always derived from the index catch count. The daily
## board and set lines are additive save keys (old saves merge them).
var mastery := {}
const DAILY_DEFAULTS := {"day": 0, "ids": [], "progress": {}, "claimed": [],
	"streak": 0, "last_complete_day": 0}
var daily: Dictionary = DAILY_DEFAULTS.duplicate(true)
var trotline_tier := 0
var set_lines := {}
const SET_LINE_SECONDS := 8 * 60
## Filled by _check_mastery for the catch card tag / rank-up toast.
var last_mastery_rank := 0
var last_mastery_coins := 0

var audio_player: AudioStreamPlayer
var sfx_cache := {}
## Set by touch_controls.gd every frame; town_player reads it for analog
## thumb-stick movement without needing a reference to the control node.
var touch_vector := Vector2.ZERO

## --- Settings (v1.7) -------------------------------------------------
## Persisted player preferences. Merged over the defaults on load so any
## save written before a setting existed still gains a sane value.
const DEFAULT_SETTINGS := {
	"music": 0.7,
	"sfx": 0.8,
	"fullscreen": false,
	"reduce_motion": false,
	"quality": "auto",
	"touch_ui": "auto",
}
var settings: Dictionary = DEFAULT_SETTINGS.duplicate(true)

## --- Harvest Feast (v1.9) --------------------------------------------
## Persisted event state. Merged over these defaults on load (like stats),
## so a save from before the event gains a sane empty album.
const HARVEST_DEFAULTS := {
	"tokens": 0,
	"donated": 0,
	"table_stage": 0,
	"completed": false,
	"grateful_seen": false,
	"caught_harvest": 0,
	"cards": {},
	"packs_opened": 0,
	"pity": 0,
	"boat_claimed": false,
	"last_daily_request": "",
	"free_pack_day": "",
	"boat_exclusive_year": false,
	# bookkeeping beyond the published state list
	"table_rewarded": false,
	"token_day": "",
	"tokens_today": 0,
}
const HARVEST_TABLE_STAGES := [3, 8, 15, 25]
const HARVEST_PACK_COST := 20
## One-time token payout that lands with the table-completion pack.
const HARVEST_TABLE_BONUS := 60
const HARVEST_TOKEN_DAY_CAP := 120
var harvest: Dictionary = HARVEST_DEFAULTS.duplicate(true)
## Dev override wired to the 2222 cheat so the event can be tested off-season.
var force_harvest := false
var _season_open_cache := false
var _season_check_timer := 0.0

## --- Save safety -----------------------------------------------------
## save_version lets future builds migrate old saves. Writes go to a
## temp file first and the previous save is kept as a .bak, so a crash
## mid-write can never leave an unreadable save behind (IndexedDB on the
## web build is the risky one).
const SAVE_VERSION := 1
const SAVE_MAGIC := "CCF2"
const SAVE_DEBOUNCE := 1.0
var save_version := SAVE_VERSION
var _save_pending := false
var _save_timer := 0.0
var _saved_toast_cd := 0.0

signal saved
signal coins_gained(amount: int)
signal harvest_boat_awarded
signal mastery_ranked(fish_id: String, rank: int)
signal daily_completed(streak: int)

## --- Audio director (v1.7) ------------------------------------------
## Two music players crossfade between procedurally baked loops, one per
## region + time of day. Ambience one-shots are baked on demand and share
## the SFX player.
const BUS_MUSIC := "Music"
const BUS_SFX := "SFX"
var music_players: Array[AudioStreamPlayer] = []
var music_cache := {}
var music_key := ""
var _music_slot := 0
var _music_target_db: Array[float] = [-60.0, -60.0]
var _ambience_timer := 9.0
var _amb_region := "pond"
var _amb_night := false

## --- Scene fade ------------------------------------------------------
var fade_layer: CanvasLayer
var fade_rect: ColorRect
var fade_alpha := 0.0
var fade_target := 0.0
var fade_scene := ""

var SAVE_PATH := "user://save.json"
var BACKUP_PATH := "user://save.bak"
var AUTO_SAVE := true

## Quest definitions. "kind" is the event that advances it, "target" the
## thing being counted (a number, a rarity, or a region), and "need" the
## amount required. Saved progress is merged with these on load, so new
## quests show up for old saves too.
const QUEST_DEFS := [
	{"id": "first_catch", "title": "First Catch", "desc": "Catch any fish.",
		"kind": "catch_any", "target": 1, "need": 1, "reward": 30},
	{"id": "first_rare", "title": "Rare Find", "desc": "Catch a Rare fish.",
		"kind": "catch_rarity", "target": "Rare", "need": 1, "reward": 75},
	{"id": "collector", "title": "Collector", "desc": "Catch one of each pond species.",
		"kind": "region_complete", "target": "pond", "need": 1, "reward": 150},
	{"id": "seasoned", "title": "Seasoned Angler", "desc": "Catch 5 fish.",
		"kind": "catch_any", "target": 5, "need": 5, "reward": 60},
	{"id": "market_day", "title": "Market Day", "desc": "Sell 10 fish at the Fish Market.",
		"kind": "sell_count", "target": 10, "need": 10, "reward": 120},
	{"id": "seafarer", "title": "Seafarer", "desc": "Buy a real boat at the Boat Dealer.",
		"kind": "own_boat", "target": 1, "need": 1, "reward": 200},
	# --- 15 new quests (v1.4) ---
	{"id": "bait_buyer", "title": "Bait Shopper", "desc": "Buy bait at the shop.",
		"kind": "buy_bait", "target": 1, "need": 1, "reward": 40},
	{"id": "bait_fisher", "title": "Well Prepared", "desc": "Make 3 casts with bait on the hook.",
		"kind": "use_bait", "target": 3, "need": 3, "reward": 70},
	{"id": "night_owl", "title": "Night Owl", "desc": "Catch 5 fish at night.",
		"kind": "catch_night", "target": 5, "need": 5, "reward": 110},
	{"id": "big_one", "title": "The Big One", "desc": "Catch a fish heavier than 15 kg.",
		"kind": "catch_weight", "target": 15, "need": 1, "reward": 180},
	{"id": "rare_trio", "title": "Rare Company", "desc": "Catch 3 Rare fish.",
		"kind": "catch_rarity", "target": "Rare", "need": 3, "reward": 200},
	{"id": "epic_encounter", "title": "Epic Encounter", "desc": "Catch an Epic fish.",
		"kind": "catch_rarity", "target": "Epic", "need": 1, "reward": 300},
	{"id": "legend_seeker", "title": "Legend Seeker", "desc": "Catch a Legendary fish.",
		"kind": "catch_rarity", "target": "Legendary", "need": 1, "reward": 600},
	{"id": "river_regular", "title": "River Regular", "desc": "Catch 8 fish in the River.",
		"kind": "region_catch", "target": "river", "need": 8, "reward": 120},
	{"id": "lake_life", "title": "Lake Life", "desc": "Catch 8 fish in the Lake.",
		"kind": "region_catch", "target": "lake", "need": 8, "reward": 150},
	{"id": "deep_diver", "title": "Into the Deep", "desc": "Catch 6 fish in the Deep Sea.",
		"kind": "region_catch", "target": "ocean", "need": 6, "reward": 240},
	{"id": "open_water", "title": "Open Water", "desc": "Catch 5 fish in Open Water.",
		"kind": "region_catch", "target": "open", "need": 5, "reward": 170},
	{"id": "species_10", "title": "Species Collector", "desc": "Discover 10 different species.",
		"kind": "unique_species", "target": 10, "need": 10, "reward": 220},
	{"id": "species_25", "title": "Master Angler", "desc": "Discover 25 different species.",
		"kind": "unique_species", "target": 25, "need": 25, "reward": 500},
	{"id": "coin_500", "title": "Fish Merchant", "desc": "Earn 500 coins from selling fish.",
		"kind": "sell_coins", "target": 500, "need": 500, "reward": 150},
	{"id": "sell_30", "title": "Big Haul", "desc": "Sell 30 fish in total.",
		"kind": "sell_count", "target": 30, "need": 30, "reward": 260},
	{"id": "night_angler", "title": "After Dark", "desc": "Catch 3 fish at night.",
		"kind": "catch_night", "target": 3, "need": 3, "reward": 140},
	{"id": "storm_chaser", "title": "Rain Chaser", "desc": "Catch 2 fish in rain or a storm.",
		"kind": "catch_weather", "target": "bad", "need": 2, "reward": 180},
	{"id": "perfect_angler", "title": "Dead Center", "desc": "Land 5 perfect catches.",
		"kind": "perfect_catch", "target": 5, "need": 5, "reward": 200},
	{"id": "hot_streak", "title": "On Fire", "desc": "Reach a 6-catch streak.",
		"kind": "catch_streak", "target": 6, "need": 6, "reward": 220},
	{"id": "islander", "title": "Island Angler", "desc": "Catch 5 fish at Coconut Isle.",
		"kind": "region_catch", "target": "island", "need": 5, "reward": 200},
	# --- Lucky Lily toy-coin wagers (v1.8) ---
	{"id": "lucky_lily", "title": "Lucky Lily", "desc": "Win a wager at the Lucky Lily.",
		"kind": "casino_win", "target": 1, "need": 1, "reward": 50},
	{"id": "high_roller", "title": "High Roller", "desc": "Win 300 coins at the Lucky Lily.",
		"kind": "casino_won", "target": 300, "need": 300, "reward": 200},
	# --- Harvest Feast seasonal quests (v1.9) ---
	{"id": "full_plate", "title": "A Full Plate", "desc": "Catch 6 Harvest Feast fish.",
		"kind": "harvest_catch", "target": 6, "need": 6, "reward": 40,
		"token_reward": true, "season": "harvest"},
	{"id": "potluck", "title": "Potluck", "desc": "Donate 6 fish to the Harvest Table.",
		"kind": "harvest_donate", "target": 6, "need": 6, "reward": 90,
		"token_reward": true, "season": "harvest"},
	{"id": "grand_tom", "title": "The Grand Tom", "desc": "Catch The Grand Tom by night.",
		"kind": "catch_species", "target": "grand_tom", "need": 1, "reward": 200,
		"token_reward": true, "season": "harvest"},
	# --- Angler's Almanac (v1.10) ---
	{"id": "a_line_in_water", "title": "A Line in the Water", "desc": "Set a line at any fishing spot.",
		"kind": "line_set", "target": 1, "need": 1, "reward": 60},
	{"id": "something_on_the_line", "title": "Something on the Line", "desc": "Collect a fish from a set line.",
		"kind": "line_collect", "target": 1, "need": 1, "reward": 120},
	{"id": "bronze_angler", "title": "Bronze Angler", "desc": "Reach Bronze mastery with 12 species.",
		"kind": "mastery_rank", "target": 1, "need": 12, "reward": 150},
	{"id": "silver_service", "title": "Silver Service", "desc": "Reach Silver mastery with 5 species.",
		"kind": "mastery_rank", "target": 2, "need": 5, "reward": 220},
	{"id": "gold_standard", "title": "The Gold Standard", "desc": "Reach Gold mastery with any species.",
		"kind": "mastery_rank", "target": 3, "need": 1, "reward": 300},
	{"id": "habit_formed", "title": "Habit Formed", "desc": "Reach a 3-day daily challenge streak.",
		"kind": "daily_streak", "target": 3, "need": 3, "reward": 200},
	{"id": "moonlit_tench", "title": "The Moonlit Tench", "desc": "Catch a Moonlit Tench at night.",
		"kind": "catch_species", "target": "moon_tench", "need": 1, "reward": 180},
	{"id": "gale_smelt", "title": "Storm Chaser", "desc": "Catch a Gale Smelt in a thunderstorm.",
		"kind": "catch_species", "target": "gale_smelt", "need": 1, "reward": 160},
]

var quests: Array = []

## Buy the island axe (AXE_COST), then upgrade it once to a palm axe
## (PALM_AXE_COST) that knocks an extra coconut out of every palm.
func axe_cost() -> int:
	if not has_axe:
		return ShopDB.AXE_COST
	if axe_level < 2:
		return ShopDB.PALM_AXE_COST
	return 0

func buy_axe() -> bool:
	var cost := axe_cost()
	if cost <= 0 or not can_afford(cost):
		return false
	coins -= cost
	if not has_axe:
		has_axe = true
		axe_level = 1
	else:
		axe_level = 2
	if AUTO_SAVE:
		save_game()
	return true

## Buy the next set-line tier (Willow 300 / Braided 800 / Rack 1,600).
func buy_trotline() -> bool:
	var d := ShopDB.trotline_next(trotline_tier)
	if d.is_empty():
		return false
	var cost := int(d.get("cost", 0))
	if cost <= 0 or not can_afford(cost):
		return false
	coins -= cost
	trotline_tier = int(d.get("tier", trotline_tier + 1))
	play_sound("ui")
	if AUTO_SAVE:
		save_game()
	return true

func palm_regrow_left(id: String) -> int:
	if not chopped_palms.has(id):
		return 0
	return maxi(0, int(chopped_palms.get(id, 0) - Time.get_unix_time_from_system()))

## Returns coconuts earned, or -1 when the palm is still regrowing.
func chop_palm(id: String) -> int:
	if palm_regrow_left(id) > 0:
		return -1
	var yield_count := 3 if axe_level >= 2 else 2
	coconuts += yield_count
	chopped_palms[id] = int(Time.get_unix_time_from_system()) + PALM_REGROW_SEC
	if AUTO_SAVE:
		save_game()
	return yield_count

## Build a Coconut Isle rod out of coconuts. Returns "" on success and a
## reason string when it fails, so the shops can show the right message.
func craft_rod(id: String) -> String:
	if not ShopDB.CRAFTED_RODS.has(id):
		return "missing"
	if ShopDB.owned("rods", id):
		gear["rod"] = id
		if AUTO_SAVE:
			save_game()
		return ""
	var recipe := ShopDB.crafted_recipe(id)
	var mat := int(recipe.get("coconuts", 0))
	if coconuts < mat:
		return "need_coconuts"
	coconuts -= mat
	ShopDB.set_owned("rods", id, true)
	gear["rod"] = id
	if AUTO_SAVE:
		save_game()
	return ""


## Testing cheat (typed as `2222` on the spot keys): hands over the whole
## game so every screen can be poked at immediately - every shop item and
## island rod owned and equipped, all regions open, the palm axe, plenty of
## coconuts and bait, a complete Fish Index, and every quest completed but
## unclaimed so the reward flow is still clickable.
func grant_everything() -> void:
	backup_save()
	coins = maxi(coins, 999999)
	unlocked_regions = ["pond", "river", "lake", "ocean"]
	for id in ShopDB.RODS.keys():
		ShopDB.RODS[id]["owned"] = true
	for id in ShopDB.CRAFTED_RODS.keys():
		ShopDB.CRAFTED_RODS[id]["owned"] = true
	for id in ShopDB.LINES.keys():
		ShopDB.LINES[id]["owned"] = true
	for id in ShopDB.BUCKETS.keys():
		ShopDB.BUCKETS[id]["owned"] = true
	for id in ShopDB.LANTERNS.keys():
		ShopDB.LANTERNS[id]["owned"] = true
	for id in ShopDB.BOATS.keys():
		ShopDB.BOATS[id]["owned"] = true
	for id in ShopDB.BAITS.keys():
		bait_counts[id] = maxi(bait_count(String(id)), 999)
	owned_boats = ShopDB.BOATS.keys()
	# best of everything equipped
	gear["rod"] = "rod_ancient"
	gear["line"] = "line_fluoro"
	gear["bucket"] = "bucket_cooler"
	gear["lantern"] = "lantern_storm"
	gear["bait"] = "bait_glow"
	gear["boat"] = "boat_trawler"
	# Coconut Isle: palm axe, a full coconut purse and every palm regrown
	has_axe = true
	axe_level = 2
	coconuts = maxi(coconuts, 999)
	chopped_palms = {}
	# complete Fish Index, every species recorded at its top weight. Use the
	# raw table (not all_ids) so seasonal fish are included even when the
	# event is closed.
	_init_index()
	for fid in FishDB.FISH.keys():
		var id := String(fid)
		var f := FishDB.fish_data(id)
		var wg: Array = f.get("weight_kg", [0.1, 1.0])
		var entry: Dictionary = index.get(id, {})
		entry["caught"] = true
		entry["count"] = maxi(40, int(entry.get("count", 0)))
		entry["pb_weight"] = maxf(float(wg[wg.size() - 1]), float(entry.get("pb_weight", 0.0)))
		entry["region"] = String(f.get("region", "pond"))
		index[id] = entry
	total_caught = maxi(total_caught, index.size())
	# Leave mastery empty on purpose: the first catch then pays the whole
	# Bronze -> Silver -> Gold cascade so the rank-up flow can be tested.
	mastery = {}
	trotline_tier = 3
	set_lines = {}
	# a handful of top-value fish in the bucket so selling can be tested
	var pool := FishDB.FISH.keys()
	# Force the Harvest Feast on and hand over the completed album AND the
	# Harvest Queen, so the event boat, trophy tab and seasonal screens can
	# all be tested immediately instead of after twenty packs.
	force_harvest = true
	SeasonTheme.apply("harvest")
	_season_open_cache = true
	harvest = HARVEST_DEFAULTS.duplicate(true)
	harvest["tokens"] = 999
	harvest["donated"] = 24
	harvest["table_stage"] = 4
	var hcards: Dictionary = {}
	var hids: Array = HarvestCardsLib.ALL_IDS
	for i in range(hids.size()):
		hcards[String(hids[i])] = 1
	harvest["cards"] = hcards
	harvest["completed"] = true
	harvest["boat_claimed"] = true
	harvest["caught_harvest"] = 5
	# Award the event-only hull exactly as the 20/20 album does.
	if not owned_boats.has("boat_harvest"):
		owned_boats.append("boat_harvest")
	ShopDB.set_owned("boats", "boat_harvest", true)
	gear["boat"] = "boat_harvest"
	pool.sort_custom(func(a, b: String) -> bool:
		return int(FishDB.fish_data(String(a)).get("coin", 0)) > int(FishDB.fish_data(b).get("coin", 0)))
	for i in range(mini(6, pool.size())):
		var fid := String(pool[i])
		var wg: Array = FishDB.fish_data(fid).get("weight_kg", [0.1, 1.0])
		inventory.append({"fish_id": fid, "weight": float(wg[wg.size() - 1]),
			"region": String(FishDB.fish_data(fid).get("region", "pond")),
			"caught_at": Time.get_ticks_msec(), "perfect": true})
	# every quest done and waiting to be claimed (instead of auto-claimed)
	if quests.is_empty():
		quests = _merge_quests([])
	for q in quests:
		q["progress"] = quest_need(q)
		q["done"] = true
		q["claimed"] = false
	if AUTO_SAVE:
		save_game()


## --- Testing cheat ("2222") ------------------------------------------
## The typed buffer lives here so both the fishing scene and Town can listen
## for the code. Scenes feed digits in and decide which of their own screens
## need refreshing; grant_everything() does the actual unlocking.
const CHEAT_CODE := "2222"
const CHEAT_WINDOW := 2.5
## Where the pre-cheat save is parked (only written by the first cheat, so
## real progress survives any number of cheated sessions).
const CHEAT_BACKUP_PATH := "user://save_pre_cheat.json"
var cheat_buffer := ""
var cheat_timer := 0.0


## Park a copy of the current save before the cheat overwrites it.
func backup_save() -> void:
	if FileAccess.file_exists(CHEAT_BACKUP_PATH) or not FileAccess.file_exists(SAVE_PATH):
		return
	var bytes := FileAccess.get_file_as_bytes(SAVE_PATH)
	var f := FileAccess.open(CHEAT_BACKUP_PATH, FileAccess.WRITE)
	if f:
		f.store_buffer(bytes)
		f.close()


## Feed one typed digit; true when the buffer has just spelled CHEAT_CODE.
func cheat_digit(digit: int) -> bool:
	cheat_buffer += str(clampi(digit, 0, 9))
	cheat_timer = CHEAT_WINDOW
	while cheat_buffer.length() > CHEAT_CODE.length():
		cheat_buffer = cheat_buffer.substr(1)
	if cheat_buffer != CHEAT_CODE:
		return false
	cheat_buffer = ""
	cheat_timer = 0.0
	return true


func _process(dt: float) -> void:
	_tick_save(dt)
	_tick_fade(dt)
	_tick_ambience(dt)
	_tick_music(dt)
	_tick_season(dt)
	if cheat_timer <= 0.0:
		return
	cheat_timer = maxf(0.0, cheat_timer - dt)
	if cheat_timer == 0.0:
		cheat_buffer = ""

func _tick_save(dt: float) -> void:
	if _saved_toast_cd > 0.0:
		_saved_toast_cd = maxf(0.0, _saved_toast_cd - dt)
	if not _save_pending:
		return
	_save_timer -= dt
	if _save_timer <= 0.0:
		flush_save()

func _tick_fade(dt: float) -> void:
	if fade_rect == null:
		return
	if fade_alpha < fade_target:
		fade_alpha = minf(1.0, fade_alpha + dt * 4.0)
		if fade_alpha >= 1.0 and fade_scene != "":
			var path := fade_scene
			fade_scene = ""
			fade_target = 0.0
			get_tree().call_deferred("change_scene_to_file", path)
	elif fade_alpha > fade_target:
		fade_alpha = maxf(0.0, fade_alpha - dt * 3.2)
	fade_rect.color = Color(0.04, 0.07, 0.11, fade_alpha)
	fade_rect.visible = fade_alpha > 0.001

func _build_fade() -> void:
	fade_layer = CanvasLayer.new()
	fade_layer.name = "SceneFade"
	fade_layer.layer = 100
	add_child(fade_layer)
	fade_rect = ColorRect.new()
	fade_rect.color = Color(0.04, 0.07, 0.11, 0.0)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade_rect.visible = false
	fade_layer.add_child(fade_rect)

## Region ambience: a random one-shot every few seconds (frogs, current,
## loons, gulls, spray) so each place has its own background sound.
const AMBIENCE := {
	"pond": ["frog", "lily"],
	"river": ["current", "splash"],
	"lake": ["loon", "splash"],
	"ocean": ["gull", "spray"],
	"open": ["gull", "spray"],
	"island": ["frog", "gull"],
	"town": ["bird"],
}

func set_ambience_region(region_name: String, night: bool) -> void:
	_amb_region = region_name
	_amb_night = night

func _tick_ambience(dt: float) -> void:
	if muted or audio_player == null:
		return
	_ambience_timer -= dt
	if _ambience_timer > 0.0:
		return
	_ambience_timer = randf_range(6.0, 15.0)
	var pool: Array = AMBIENCE.get(_amb_region, [])
	if pool.is_empty():
		return
	var pick := String(pool[randi() % pool.size()])
	if _amb_night and (pick == "gull" or pick == "bird"):
		pick = "frog" if _amb_region != "ocean" and _amb_region != "open" else "spray"
	play_sound("amb_" + pick)

## --- Audio director ---------------------------------------------------
func _ensure_buses() -> void:
	for bus_name in [BUS_MUSIC, BUS_SFX]:
		if AudioServer.get_bus_index(bus_name) != -1:
			continue
		AudioServer.add_bus()
		var idx := AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, bus_name)
		AudioServer.set_bus_send(idx, "Master")
	_apply_audio_settings()

func _apply_audio_settings() -> void:
	if AudioServer.get_bus_index(BUS_MUSIC) == -1:
		return
	AudioServer.set_bus_mute(0, muted)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(BUS_MUSIC),
			linear_to_db(maxf(0.0001, float(settings.get("music", 0.7)))))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(BUS_SFX),
			linear_to_db(maxf(0.0001, float(settings.get("sfx", 0.8)))))

## Pick the loop for a place + time of day. Called every frame by the
## scenes; it is a string compare unless the key actually changed.
func set_music(region_name: String, night: bool) -> void:
	# the headless test harness has no audio device; skip baking/playing
	if DisplayServer.get_name() == "headless":
		return
	var key := _music_region_key(region_name)
	key += "_night" if night else "_day"
	if key == music_key:
		return
	music_key = key
	if music_players.is_empty():
		return
	var stream: AudioStreamWAV = music_cache.get(key)
	if stream == null:
		stream = _bake_music(key)
		music_cache[key] = stream
	_crossfade_music(stream)

func _music_region_key(region_name: String) -> String:
	match region_name:
		"open": return "sea"
		"ocean": return "sea"
		"island": return "island"
		"town": return "town"
		"river": return "river"
		"lake": return "lake"
		_: return "pond"

## Manual crossfade (no tween): both players glide to their target volume
## in _tick_music, and the old one stops once it is silent. Avoiding a
## Tween here also avoids holding playback references across a quit.
func _crossfade_music(stream: AudioStreamWAV) -> void:
	var old_slot := _music_slot
	_music_slot = (_music_slot + 1) % music_players.size()
	var fresh: AudioStreamPlayer = music_players[_music_slot]
	fresh.stream = stream
	fresh.volume_db = -60.0
	fresh.play(0.0)
	_music_target_db[_music_slot] = -7.0
	_music_target_db[old_slot] = -60.0


func _tick_music(dt: float) -> void:
	for i in range(music_players.size()):
		var p: AudioStreamPlayer = music_players[i]
		if not p.playing:
			continue
		p.volume_db = move_toward(p.volume_db, _music_target_db[i], dt * 58.0)
		if _music_target_db[i] <= -59.9 and p.volume_db <= -59.9:
			p.stop()
			p.stream = null

func stop_music() -> void:
	music_key = ""
	for i in range(music_players.size()):
		music_players[i].stop()
		music_players[i].stream = null
		_music_target_db[i] = -60.0

## Short looping beds, one per region and time of day. Kept simple and
## quiet: a few stacked sines on a slow arpeggio. Baked once per key.
func _bake_music(key: String) -> AudioStreamWAV:
	var night := key.ends_with("_night")
	var base_key := key.trim_suffix("_night").trim_suffix("_day")
	var root := 220.0
	match base_key:
		"river": root = 196.0
		"lake": root = 174.6
		"sea": root = 146.8
		"island": root = 261.6
		"town": root = 246.9
	var scale := [1.0, 1.2, 1.5, 1.8, 2.0]
	if base_key == "sea":
		scale = [1.0, 1.125, 1.5, 1.687, 2.0]
	var rate := 16000
	var dur := 4.0
	var frames := int(dur * float(rate))
	var bytes := PackedByteArray()
	bytes.resize(frames * 2)
	var step := 1.0 / float(rate)
	var beat := 0.5 if not night else 0.85
	for i in range(frames):
		var t := float(i) * step
		var n := int(t / beat) % scale.size()
		var n2 := int(t / (beat * 2.0)) % scale.size()
		var f1 := root * float(scale[n])
		var f2 := root * float(scale[n2]) * 0.5
		var fade := minf(1.0, t / 0.6) * minf(1.0, (dur - t) / 0.6)
		var s := sin(TAU * f1 * t) * 0.16
		s += sin(TAU * f2 * t) * 0.12
		s += sin(TAU * root * 0.5 * t) * 0.10
		s += sin(TAU * f1 * 2.0 * t) * 0.03
		s *= (0.55 if night else 0.7) * fade
		bytes.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = frames
	wav.data = bytes
	return wav


func _ready() -> void:
	if event_until <= 0:
		event_until = int(Time.get_unix_time_from_system()) + EVENT_SECONDS
	_build_fade()
	_load_game()
	# Boot the palette for the season the save loaded into. The event check
	# also runs on a timer, so a mid-session Dec 1 rollover reverts cleanly
	# and the next screen that opens is rebuilt in the normal palette.
	_season_open_cache = harvest_season_open()
	SeasonTheme.apply("harvest" if _season_open_cache else "default")
	_ensure_buses()
	_setup_audio()
	apply_display_settings()

## Flush on focus loss, app pause (mobile) and window close so no
## progress is ever lost to the browser tab being killed.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED \
			or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		flush_save()


## Stop and release the audio streams on shutdown so the engine does not
## report leaked playback objects when the window closes.
func _exit_tree() -> void:
	for p in music_players:
		if is_instance_valid(p):
			p.stop()
			p.stream = null
	music_players.clear()
	music_cache.clear()
	if audio_player != null and is_instance_valid(audio_player):
		audio_player.stop()
		audio_player.stream = null
	sfx_cache.clear()

## --- Save API --------------------------------------------------------
## Debounced save: at most one disk write per SAVE_DEBOUNCE second, and a
## pending write is never starved by more requests.
func request_save() -> void:
	if not AUTO_SAVE:
		return
	_save_pending = true
	if _save_timer <= 0.0:
		_save_timer = SAVE_DEBOUNCE

func flush_save() -> void:
	_save_timer = 0.0
	if _save_pending:
		save_game()

func _save_data() -> Dictionary:
	return {
		"save_version": save_version,
		"settings": settings.duplicate(true),
		"coins": coins,
		"casino_bet": casino_bet,
		"seen_version": seen_version,
		"event_until": event_until,
		"inventory": inventory,
		"index": index,
		"gear": gear,
		"unlocked_regions": unlocked_regions,
		"owned_boats": owned_boats,
		"total_caught": total_caught,
		"bait_counts": bait_counts,
		"quests": quests,
		"stats": stats,
		"muted": muted,
		"has_axe": has_axe,
		"axe_level": axe_level,
		"coconuts": coconuts,
		"chopped_palms": chopped_palms,
		"owned_rods": ShopDB.owned_rod_ids(),
		"owned_gear": {
			"lines": ShopDB.owned_ids("lines"),
			"buckets": ShopDB.owned_ids("buckets"),
			"lanterns": ShopDB.owned_ids("lanterns"),
		},
		"harvest": harvest,
		"force_harvest": force_harvest,
		"mastery": mastery,
		"daily": daily,
		"trotline_tier": trotline_tier,
		"set_lines": set_lines,
	}

## Write through a temp file, park the previous save as a .bak, then swap
## the new one in. A failed rename falls back to a copy on platforms (some
## browsers) that refuse to rename user:// files.
func save_game() -> void:
	var tmp_path := SAVE_PATH + ".tmp"
	var file := FileAccess.open(tmp_path, FileAccess.WRITE)
	if file == null:
		push_warning("Could not open the save file for writing")
		return
	# A tiny checksum header means a truncated/corrupt save is rejected
	# *before* the binary Variant decoder can spew engine errors, and the
	# loader can fall back to the .bak cleanly.
	var payload := var_to_bytes(_save_data())
	var header := "%s %d %d\n" % [SAVE_MAGIC, payload.size(), hash(payload)]
	file.store_buffer(header.to_utf8_buffer())
	file.store_buffer(payload)
	file.flush()
	file.close()
	if FileAccess.file_exists(SAVE_PATH):
		if FileAccess.file_exists(BACKUP_PATH):
			DirAccess.remove_absolute(BACKUP_PATH)
		if DirAccess.rename_absolute(SAVE_PATH, BACKUP_PATH) != OK:
			# some browsers refuse renames - copy the old save aside instead
			if DirAccess.copy_absolute(SAVE_PATH, BACKUP_PATH) == OK:
				DirAccess.remove_absolute(SAVE_PATH)
	var err := DirAccess.rename_absolute(tmp_path, SAVE_PATH)
	if err != OK:
		DirAccess.copy_absolute(tmp_path, SAVE_PATH)
		DirAccess.remove_absolute(tmp_path)
	_save_pending = false
	_save_timer = 0.0
	if _saved_toast_cd <= 0.0:
		_saved_toast_cd = 6.0
		saved.emit()

func _read_save(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var header := file.get_line()
	if header.begins_with(SAVE_MAGIC + " "):
		var parts := header.split(" ")
		if parts.size() != 3:
			file.close()
			return {}
		var length := int(parts[1])
		var crc := int(parts[2])
		var payload := file.get_buffer(length)
		file.close()
		if payload.size() != length or hash(payload) != crc:
			return {}
		var data: Variant = bytes_to_var(payload)
		if typeof(data) != TYPE_DICTIONARY:
			return {}
		return data
	# legacy (v1.6 and older) raw store_var save - no header. Check the
	# binary Variant type byte first so random corruption never reaches
	# the decoder (which prints engine errors on garbage input).
	file.seek(0)
	var peek := file.get_buffer(8)
	if peek.size() < 8 or int(peek[4]) != int(TYPE_DICTIONARY):
		file.close()
		return {}
	file.seek(0)
	var legacy: Variant = file.get_var()
	file.close()
	if typeof(legacy) != TYPE_DICTIONARY:
		return {}
	return legacy

func _load_game() -> void:
	# A brand new save (or a save from before the event existed) starts its
	# own 12 hour window. An already-expired timestamp is kept as expired.
	if event_until <= 0:
		event_until = int(Time.get_unix_time_from_system()) + EVENT_SECONDS
	var data := _read_save(SAVE_PATH)
	if data.is_empty():
		# a damaged main save falls back to the previous good one
		data = _read_save(BACKUP_PATH)
	if data.is_empty():
		_apply_saved_settings({})
		_init_index()
		quests = _merge_quests([])
		save_game()
		return
	save_version = maxi(SAVE_VERSION, int(data.get("save_version", 0)))
	_apply_saved_settings(data.get("settings", {}))
	coins = int(data.get("coins", 50))
	casino_bet = _clamp_casino_bet(int(data.get("casino_bet", 10)))
	seen_version = String(data.get("seen_version", ""))
	# Old saves have no event timestamp yet - give them the full window and
	# persist the deadline together with the rest of the loaded state below.
	event_until = int(data.get("event_until", 0))
	var new_event := event_until <= 0
	if new_event:
		event_until = int(Time.get_unix_time_from_system()) + EVENT_SECONDS
	inventory = data.get("inventory", [])
	index = data.get("index", {})
	gear = data.get("gear", {"rod": "rod_stick", "line": "line_nylon", "bait": "",
		"bucket": "bucket_small", "boat": "boat_raft", "lantern": "lantern_none"})
	if not gear.has("boat"):
		gear["boat"] = "boat_raft"
	if not gear.has("lantern"):
		gear["lantern"] = "lantern_none"
	owned_boats = data.get("owned_boats", ["boat_raft"])
	unlocked_regions = data.get("unlocked_regions", ["pond", "island"])
	if not unlocked_regions.has("island"):
		unlocked_regions.append("island")
	total_caught = int(data.get("total_caught", 0))
	muted = bool(data.get("muted", false))
	has_axe = bool(data.get("has_axe", false))
	axe_level = int(data.get("axe_level", 1))
	coconuts = int(data.get("coconuts", 0))
	var saved_palms: Variant = data.get("chopped_palms", {})
	chopped_palms = saved_palms if typeof(saved_palms) == TYPE_DICTIONARY else {}
	var saved_rods: Variant = data.get("owned_rods", [])
	if typeof(saved_rods) == TYPE_ARRAY:
		ShopDB.mark_owned_rods(saved_rods)
	var saved_gear: Variant = data.get("owned_gear", {})
	if typeof(saved_gear) == TYPE_DICTIONARY:
		for cat in ["lines", "buckets", "lanterns"]:
			var ids_v: Variant = saved_gear.get(cat, [])
			if typeof(ids_v) == TYPE_ARRAY:
				ShopDB.mark_owned(cat, ids_v)
	var saved_stats: Variant = data.get("stats", {})
	if typeof(saved_stats) == TYPE_DICTIONARY:
		for k in saved_stats.keys():
			stats[k] = saved_stats[k]
	var saved_baits: Variant = data.get("bait_counts", {})
	bait_counts = saved_baits if typeof(saved_baits) == TYPE_DICTIONARY else {}
	# Harvest Feast state: merge over the defaults so a pre-v1.9 save gains
	# an empty album without losing anything.
	harvest = HARVEST_DEFAULTS.duplicate(true)
	var saved_harvest: Variant = data.get("harvest", {})
	if typeof(saved_harvest) == TYPE_DICTIONARY:
		for k in HARVEST_DEFAULTS.keys():
			if saved_harvest.has(k):
				harvest[k] = saved_harvest[k]
	force_harvest = bool(data.get("force_harvest", false))
	if typeof(harvest.get("cards", {})) != TYPE_DICTIONARY:
		harvest["cards"] = {}
	# fresh quest metadata + any missing (new) quests, keeping saved progress
	quests = _merge_quests(data.get("quests", []))
	_init_index()
	# Almanac state (v1.10). Old saves gain empty daily / line blocks. The
	# mastery block is synced to the recorded counts with NO retroactive
	# payout, exactly as a fresh install would derive it.
	trotline_tier = clampi(int(data.get("trotline_tier", 0)), 0, 3)
	var saved_lines: Variant = data.get("set_lines", {})
	set_lines = saved_lines if typeof(saved_lines) == TYPE_DICTIONARY else {}
	var saved_mastery: Variant = data.get("mastery", {})
	mastery = {}
	for fid in index.keys():
		var derived := AlmanacLib.mastery_rank(int(index[fid].get("count", 0)))
		var paid := 0
		if typeof(saved_mastery) == TYPE_DICTIONARY:
			paid = int(saved_mastery.get(fid, 0))
		mastery[fid] = clampi(maxi(derived, paid), 0, 3)
	daily = DAILY_DEFAULTS.duplicate(true)
	var saved_daily: Variant = data.get("daily", {})
	if typeof(saved_daily) == TYPE_DICTIONARY:
		for k in DAILY_DEFAULTS.keys():
			if saved_daily.has(k):
				daily[k] = saved_daily[k]
	ensure_daily()
	# Repair an album that reached 20/20 without the award (an old/hand-edited
	# save): the boat is always granted automatically, never claimable.
	if harvest_owned_count() >= HarvestCardsLib.ALL_IDS.size():
		harvest["completed"] = true
		if not bool(harvest.get("boat_claimed", false)):
			award_harvest_boat()
	if new_event:
		request_save()

## Merge saved preferences over the defaults. Anything missing (a save
## from before v1.7) silently gains the default value.
func _apply_saved_settings(saved: Variant) -> void:
	settings = DEFAULT_SETTINGS.duplicate(true)
	if typeof(saved) == TYPE_DICTIONARY:
		for k in DEFAULT_SETTINGS.keys():
			if saved.has(k):
				settings[k] = saved[k]
	settings["music"] = clampf(float(settings.get("music", 0.7)), 0.0, 1.0)
	settings["sfx"] = clampf(float(settings.get("sfx", 0.8)), 0.0, 1.0)
	settings["fullscreen"] = bool(settings.get("fullscreen", false))
	settings["reduce_motion"] = bool(settings.get("reduce_motion", false))
	var q := String(settings.get("quality", "auto"))
	if not ["auto", "low", "medium", "high"].has(q):
		q = "auto"
	settings["quality"] = q
	var t := String(settings.get("touch_ui", "auto"))
	if not ["auto", "on", "off"].has(t):
		t = "auto"
	settings["touch_ui"] = t

## Single entry point for the settings screen and F11. Persists and applies.
func set_setting(key: String, value: Variant) -> void:
	if not settings.has(key):
		return
	settings[key] = value
	_apply_audio_settings()
	if key == "fullscreen":
		apply_display_settings()
	request_save()

func reduce_motion() -> bool:
	return bool(settings.get("reduce_motion", false))

## 0 = low, 1 = medium, 2 = high. "auto" is conservative on phones and
## on mobile browsers, where the frame budget is tightest.
func quality_level() -> int:
	match String(settings.get("quality", "auto")):
		"low": return 0
		"medium": return 1
		"high": return 2
	var mobile := OS.has_feature("mobile") or OS.has_feature("web_android") \
			or OS.has_feature("web_ios")
	return 1 if mobile else 2

func touch_ui_mode() -> String:
	return String(settings.get("touch_ui", "auto"))

func apply_display_settings() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var want_full := bool(settings.get("fullscreen", false))
	var mode := DisplayServer.window_get_mode()
	var is_full := mode == DisplayServer.WINDOW_MODE_FULLSCREEN \
			or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	if want_full and not is_full:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	elif not want_full and is_full:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

func toggle_fullscreen() -> void:
	set_setting("fullscreen", not bool(settings.get("fullscreen", false)))

## Wipe progress (settings are kept) after parking the old save in the
## pre-cheat backup slot, so a reset is never completely destructive.
func reset_progress() -> void:
	backup_save()
	coins = 50
	casino_bet = 10
	inventory = []
	index = {}
	gear = {"rod": "rod_stick", "line": "line_nylon", "bait": "", "bucket": "bucket_small",
		"boat": "boat_raft", "lantern": "lantern_none"}
	owned_boats = ["boat_raft"]
	unlocked_regions = ["pond", "island"]
	bait_counts = {}
	total_caught = 0
	stats = {
		"coins_earned": 0, "fish_sold": 0, "perfect_catches": 0,
		"current_streak": 0, "best_streak": 0, "daily_catches": 0,
		"biggest_fish": 0.0, "biggest_name": "", "days_fished": 0,
		"casino_wagered": 0, "casino_returned": 0, "casino_wins": 0,
		"casino_biggest_win": 0,
	}
	has_axe = false
	axe_level = 1
	coconuts = 0
	chopped_palms = {}
	seen_version = ""
	event_until = int(Time.get_unix_time_from_system()) + EVENT_SECONDS
	ShopDB.reset_owned()
	harvest = HARVEST_DEFAULTS.duplicate(true)
	force_harvest = false
	_season_open_cache = false
	SeasonTheme.revert()
	quests = _merge_quests([])
	_init_index()
	mastery = {}
	daily = DAILY_DEFAULTS.duplicate(true)
	trotline_tier = 0
	set_lines = {}
	last_mastery_rank = 0
	last_mastery_coins = 0
	session_started = false
	save_game()

## Build the live quest list from QUEST_DEFS, carrying progress / done /
## claimed over from the saved list (old saves gain the new quests).
func _merge_quests(saved: Array) -> Array:
	var by_id := {}
	for q in saved:
		if typeof(q) == TYPE_DICTIONARY:
			by_id[String(q.get("id", ""))] = q
	var out: Array = []
	for def in QUEST_DEFS:
		var q: Dictionary = def.duplicate(true)
		var old: Dictionary = by_id.get(String(q.get("id", "")), {})
		q["progress"] = int(old.get("progress", 0))
		q["done"] = bool(old.get("done", false))
		q["claimed"] = bool(old.get("claimed", false))
		if int(q["progress"]) < quest_need(q):
			q["done"] = false
		out.append(q)
	return out

## --- Harvest Feast (v1.9) --------------------------------------------
## Season gate. The window straddles the month change (Nov 22 00:00 to
## Dec 1 23:59 local), so the test is explicit - never a bare month compare.
func harvest_season_open() -> bool:
	if force_harvest:
		return true
	return _calendar_harvest_open()

func _calendar_harvest_open() -> bool:
	var d := Time.get_date_dict_from_system()
	var m := int(d.get("month", 1))
	var day := int(d.get("day", 1))
	return (m == 11 and day >= 22) or (m == 12 and day == 1)

## Check the clock a couple of times a second, so a mid-session close
## reverts the palette and locks the pack buttons on the next screen open.
func _tick_season(dt: float) -> void:
	_season_check_timer -= dt
	if _season_check_timer > 0.0:
		return
	_season_check_timer = 2.0
	var open := harvest_season_open()
	if open == _season_open_cache:
		return
	_season_open_cache = open
	SeasonTheme.apply("harvest" if open else "default")

## Seconds until Dec 1 23:59:59 local. Built from the calendar date and the
## time of day so it never depends on the local UTC offset.
func harvest_seconds_left() -> int:
	if not harvest_season_open():
		return 0
	if force_harvest and not _calendar_harvest_open():
		return 10 * 86400
	var d := Time.get_date_dict_from_system()
	var m := int(d.get("month", 1))
	var day := int(d.get("day", 1))
	var t := Time.get_time_dict_from_system()
	var left_today := 86399 - (int(t.get("hour", 0)) * 3600 + int(t.get("minute", 0)) * 60
			+ int(t.get("second", 0)))
	if m == 12:
		return maxi(0, left_today)
	return left_today + (30 - day + 1) * 86400

func harvest_days_left() -> int:
	if not harvest_season_open():
		return 0
	return int(ceil(float(harvest_seconds_left()) / 86400.0))

func harvest_final_days() -> bool:
	return harvest_season_open() and harvest_days_left() <= 3

## "CARDS CLOSE IN 6d" / "CARDS CLOSE TONIGHT" / closed copy.
func harvest_deadline_text() -> String:
	if not harvest_season_open():
		return "PACKS CLOSED UNTIL NOV 22"
	var d := Time.get_date_dict_from_system()
	if _calendar_harvest_open() and int(d.get("month", 1)) == 12:
		return "CARDS CLOSE TONIGHT"
	return "CARDS CLOSE IN %dd" % harvest_days_left()

func harvest_time_text() -> String:
	var left := harvest_seconds_left()
	if left <= 0:
		return "CLOSED"
	if left < 86400:
		return "%d:%02d:%02d" % [left / 3600, (left / 60) % 60, left % 60]
	return "%dd %02dh" % [left / 86400, (left % 86400) / 3600]

func harvest_tokens() -> int:
	return int(harvest.get("tokens", 0))

func harvest_spend_tokens(amount: int) -> bool:
	if amount <= 0:
		return true
	if harvest_tokens() < amount:
		return false
	harvest["tokens"] = harvest_tokens() - amount
	if AUTO_SAVE:
		request_save()
	return true

## Add event tokens. Quest earnings stop at the ~120/day soft cap; table
## donations and dupe refunds pass `bypass_cap` so the Feast's pack faucet
## can never run dry and the album economy always pays out.
func add_tokens(amount: int, bypass_cap := false) -> int:
	if amount <= 0:
		return 0
	var today := Time.get_date_string_from_system()
	if String(harvest.get("token_day", "")) != today:
		harvest["token_day"] = today
		harvest["tokens_today"] = 0
	var granted := amount
	if not bypass_cap:
		var used := int(harvest.get("tokens_today", 0))
		granted = clampi(amount, 0, maxi(0, HARVEST_TOKEN_DAY_CAP - used))
		harvest["tokens_today"] = used + granted
	if granted <= 0:
		return 0
	harvest["tokens"] = harvest_tokens() + granted
	play_sound("bell")
	if AUTO_SAVE:
		request_save()
	return granted

func harvest_has_card(id: String) -> bool:
	return int((harvest.get("cards", {}) as Dictionary).get(id, 0)) > 0

func harvest_owned_count() -> int:
	var n := 0
	var cards: Dictionary = harvest.get("cards", {})
	for id in cards.keys():
		if int(cards[id]) > 0:
			n += 1
	return n

func harvest_spares_count() -> int:
	var n := 0
	var cards: Dictionary = harvest.get("cards", {})
	for id in cards.keys():
		n += maxi(0, int(cards[id]) - 1)
	return n

func harvest_cards_left() -> int:
	return maxi(0, HarvestCardsLib.ALL_IDS.size() - harvest_owned_count())

## Table growth is driven by donated fish (the saved stage is kept in sync
## so the town scene can draw the right trestle table without recomputing).
func harvest_table_stage() -> int:
	var d := int(harvest.get("donated", 0))
	var stage := 0
	for i in range(HARVEST_TABLE_STAGES.size()):
		if d >= int(HARVEST_TABLE_STAGES[i]):
			stage = i + 1
	harvest["table_stage"] = clampi(stage, 0, 4)
	return int(harvest["table_stage"])

func harvest_next_stage_donation() -> int:
	var stage := harvest_table_stage()
	if stage >= HARVEST_TABLE_STAGES.size():
		return -1
	return int(HARVEST_TABLE_STAGES[stage])

## Tokens one donation pays: 12% of the fish's coin value, clamped to 2..18,
## with a 50% bump for seasonal fish. Shared by the donate list preview and
## donate_fish so the board never promises a different number than it pays.
func harvest_donation_tokens(fish_id: String, weight: float) -> int:
	var value := coin_value(fish_id, weight)
	var tok := clampi(int(round(float(value) * 0.12)), 2, 18)
	if String(FishDB.fish_data(fish_id).get("season", "")) == "harvest":
		tok = int(round(float(tok) * 1.5))
	return maxi(1, tok)


## Donate one fish from the bucket to the town table. Pays tokens scaled to
## the fish value, grows the table and hands out the completion bonus pack.
## Donations are never capped: once the table is full they keep paying, so
## finishing the table can't leave the album with no way to buy a pack.
func donate_fish(inv_index: int) -> Dictionary:
	var out := {"ok": false, "tokens": 0, "stage": 0, "bonus_pack": false,
			"table_bonus": 0, "reason": ""}
	if not harvest_season_open():
		out["reason"] = "closed"
		return out
	if inv_index < 0 or inv_index >= inventory.size():
		out["reason"] = "empty"
		return out
	var item: Dictionary = inventory[inv_index]
	var fid := String(item.get("fish_id", ""))
	var tok := harvest_donation_tokens(fid, float(item.get("weight", 0.0)))
	inventory.remove_at(inv_index)
	harvest["donated"] = int(harvest.get("donated", 0)) + 1
	harvest["grateful_seen"] = true
	# Bypass the daily soft cap: the table is the Feast's only reliable pack
	# faucet, so maxing it must never stop donations from paying.
	var granted := add_tokens(tok, true)
	var new_stage := harvest_table_stage()
	out["tokens"] = granted
	out["stage"] = new_stage
	out["ok"] = true
	# Pay out once when the table reaches stage 4. The old check compared
	# the stage with itself, so the completion pack never fired; testing the
	# saved flag also repairs saves that maxed the table without a reward.
	if new_stage >= 4 and not bool(harvest.get("table_rewarded", false)):
		harvest["table_rewarded"] = true
		out["bonus_pack"] = true
		out["table_bonus"] = add_tokens(HARVEST_TABLE_BONUS, true)
	_check_quests("donate", "", {"coins": tok})
	play_sound("bell")
	if AUTO_SAVE:
		save_game()
	return out

func harvest_free_pack_available() -> bool:
	return harvest_season_open() and String(harvest.get("free_pack_day", "")) \
			!= Time.get_date_string_from_system()

func harvest_claim_free_pack() -> Dictionary:
	if not harvest_free_pack_available():
		return {"error": "daily_used", "cards": []}
	harvest["free_pack_day"] = Time.get_date_string_from_system()
	harvest["last_daily_request"] = harvest["free_pack_day"]
	return harvest_open_pack(0)

func harvest_buy_pack() -> Dictionary:
	return harvest_open_pack(HARVEST_PACK_COST)

## Roll 3 cards. Cards are opened immediately and never sit as an item, so
## nothing can be stranded at the Dec 1 close.
func harvest_open_pack(cost := HARVEST_PACK_COST) -> Dictionary:
	var out := {"error": "", "cards": [], "new_ids": [], "refund": 0, "new_count": 0,
		"completed": false, "awarded": false}
	if not harvest_season_open():
		out["error"] = "closed"
		return out
	if cost > 0:
		if not harvest_spend_tokens(cost):
			out["error"] = "tokens"
			return out
	var had_boat := bool(harvest.get("boat_claimed", false))
	var fresh: Array = HarvestCardsLib.new_ids(harvest.get("cards", {}))
	var picks: Array = []
	var picked := {}
	for slot in range(3):
		var cid := ""
		if slot == 0 and not fresh.is_empty():
			cid = String(fresh[randi() % fresh.size()])
		else:
			cid = _roll_harvest_card(picked)
		if cid == "":
			cid = _roll_harvest_card(picked)
		if cid == "":
			break
		picks.append(cid)
		picked[cid] = true
		fresh.erase(cid)
	harvest["packs_opened"] = int(harvest.get("packs_opened", 0)) + 1
	var had_new := false
	for cid in picks:
		var info := harvest_grant_card(String(cid))
		if bool(info.get("new", false)):
			had_new = true
			out["new_count"] = int(out["new_count"]) + 1
			out["new_ids"].append(String(cid))
		out["refund"] = int(out["refund"]) + int(info.get("refund", 0))
		out["cards"].append(HarvestCardsLib.card(String(cid)))
	# Hard pity safety net: after six new-card-less packs, the next pack is
	# forced to contain a fresh card if any remain.
	var pity := 0 if had_new else int(harvest.get("pity", 0)) + 1
	if pity >= 6 and not HarvestCardsLib.new_ids(harvest.get("cards", {})).is_empty():
		pity = 0
	harvest["pity"] = pity
	out["completed"] = bool(harvest.get("completed", false))
	out["awarded"] = (not had_boat) and bool(harvest.get("boat_claimed", false))
	if AUTO_SAVE:
		save_game()
	return out

func _roll_harvest_card(excluded: Dictionary) -> String:
	var roll := randf() * 100.0
	var rarity := "Common"
	if roll < 0.5:
		rarity = "Legendary"
	elif roll < 4.0:
		rarity = "Epic"
	elif roll < 17.0:
		rarity = "Rare"
	elif roll < 45.0:
		rarity = "Uncommon"
	var candidates: Array = []
	for id in HarvestCardsLib.ids_of_rarity(rarity):
		if not excluded.has(id):
			candidates.append(id)
	if candidates.is_empty():
		for id in HarvestCardsLib.ALL_IDS:
			if not excluded.has(id):
				candidates.append(id)
	if candidates.is_empty():
		return ""
	return String(candidates[randi() % candidates.size()])

## Register one card. Duplicates stack as SPARES and refund 5 tokens.
func harvest_grant_card(id: String) -> Dictionary:
	var out := {"id": id, "new": false, "refund": 0}
	if not HarvestCardsLib.CARDS.has(id):
		return out
	var cards: Dictionary = harvest.get("cards", {})
	var count := int(cards.get(id, 0))
	if count > 0:
		cards[id] = count + 1
		harvest["cards"] = cards
		harvest["tokens"] = harvest_tokens() + 5
		out["refund"] = 5
		play_sound("coin")
	else:
		cards[id] = 1
		harvest["cards"] = cards
		out["new"] = true
		play_sound("bell")
	if harvest_owned_count() >= HarvestCardsLib.ALL_IDS.size():
		harvest["completed"] = true
		if award_harvest_boat():
			out["awarded"] = true
	if AUTO_SAVE:
		request_save()
	return out

## The Harvest Queen is granted once, automatically at 20/20. It is stored
## as a normal owned boat id, so an unknown id in an old save just degrades
## to the raft like any other missing hull.
func award_harvest_boat() -> bool:
	if bool(harvest.get("boat_claimed", false)):
		return false
	if bool(harvest.get("boat_exclusive_year", false)):
		var year := int(Time.get_date_dict_from_system().get("year", 0))
		if year != 2025:
			return false
	harvest["boat_claimed"] = true
	if not owned_boats.has("boat_harvest"):
		owned_boats.append("boat_harvest")
	gear["boat"] = "boat_harvest"
	ShopDB.set_owned("boats", "boat_harvest", true)
	play_sound("fanfare")
	harvest_boat_awarded.emit()
	if AUTO_SAVE:
		save_game()
	return true

## Called from record_catch: count seasonal catches and grant the Grand Tom
## card on the legendary catch (the card is also in the pack pool).
func harvest_on_catch(fish_id: String) -> void:
	if not harvest_season_open():
		return
	var f := FishDB.fish_data(fish_id)
	if String(f.get("season", "")) != "harvest":
		return
	harvest["caught_harvest"] = int(harvest.get("caught_harvest", 0)) + 1
	if fish_id == "grand_tom":
		play_sound("gobble")
		harvest_grant_card("grand_tom")
	if AUTO_SAVE:
		request_save()

## Quests tagged season "harvest" only appear while the event is running.
func visible_quests() -> Array:
	if harvest_season_open():
		return quests
	var out: Array = []
	for q in quests:
		if String(q.get("season", "")) != "harvest":
			out.append(q)
	return out

## --- 2x coin event ---------------------------------------------------
func event_active() -> bool:
	return event_until > int(Time.get_unix_time_from_system())

func event_seconds_left() -> int:
	return maxi(0, event_until - int(Time.get_unix_time_from_system()))

## "11:59:32" countdown for the HUD and the What's New screen.
func event_time_text() -> String:
	var left := event_seconds_left()
	return "%d:%02d:%02d" % [left / 3600, (left / 60) % 60, left % 60]

func money_mult() -> float:
	return 2.0 if event_active() else 1.0

## Keep the saved Lucky Lily stake on one of the published rungs even if an
## old or hand-edited save contains anything else.
func _clamp_casino_bet(value: int) -> int:
	for bet in CasinoDBLib.BETS:
		if int(bet) == value:
			return value
	return int(CasinoDBLib.BETS[0])

## Settle one Lucky Lily wager. This deliberately bypasses money_mult()
## and sale_mult(): casino coins are not fish sales and the 2x coin event
## must not turn a 2x coin toss into a 4x payout. Payout includes the stake,
## so the player's net change is payout - stake and the balance can never go
## below zero. Returns the net profit (negative for a loss, zero for a push).
func casino_settle(stake: int, payout: int, _game_id: String = "") -> int:
	var wager := maxi(0, stake)
	var returned := maxi(0, payout)
	var profit := returned - wager
	coins = maxi(0, coins + profit)
	stats["casino_wagered"] = int(stats.get("casino_wagered", 0)) + wager
	stats["casino_returned"] = int(stats.get("casino_returned", 0)) + returned
	if profit > 0:
		stats["casino_wins"] = int(stats.get("casino_wins", 0)) + 1
		stats["casino_biggest_win"] = maxi(int(stats.get("casino_biggest_win", 0)), profit)
		coins_gained.emit(profit)
		play_sound("coin")
	elif profit < 0:
		play_sound("buzz")
	else:
		play_sound("ui")
	_check_quests("casino", "", {"win": profit > 0, "coins": maxi(0, profit)})
	if AUTO_SAVE:
		request_save()
	return profit

## Quest rewards pay out doubled during the event too, so the board shows
## the amount the player will actually receive.
func quest_reward(q: Dictionary) -> int:
	if bool(q.get("token_reward", false)):
		return int(q.get("reward", 0))
	return int(round(float(q.get("reward", 0)) * money_mult()))

func _init_index() -> void:
	# Every defined species gets an entry, including seasonal fish that are
	# not currently in the catch rotation.
	var ids := FishDB.FISH.keys()
	for fid in ids:
		var fid_s := String(fid)
		if not index.has(fid_s):
			index[fid_s] = {"caught": false, "count": 0, "pb_weight": 0.0, "region": ""}

func is_new_species(fish_id: String) -> bool:
	var entry: Dictionary = index.get(fish_id, {})
	return not entry.get("caught", false)

func rarity_of(fish_id: String) -> String:
	var f: Dictionary = FishDB.fish_data(fish_id)
	return String(f.get("rarity", "Common"))

func record_catch(fish_id: String, weight: float, region: String, night := false,
		weather := "", perfect := false, via_line := false) -> void:
	last_mastery_rank = 0
	last_mastery_coins = 0
	var entry: Dictionary = index.get(fish_id, {"caught": false, "count": 0, "pb_weight": 0.0, "region": region})
	if not entry.get("caught", false):
		entry["caught"] = true
		var r := rarity_of(fish_id)
		if GameTheme.get_rarity_rate(r) < 0.1:
			play_sound("rare")
		else:
			play_sound("catch")
	else:
		play_sound("catch")
	entry["count"] = int(entry.get("count", 0)) + 1
	if weight > float(entry.get("pb_weight", 0.0)):
		entry["pb_weight"] = weight
	entry["region"] = region
	index[fish_id] = entry
	_check_mastery(fish_id)
	harvest_on_catch(fish_id)
	inventory.append({"fish_id": fish_id, "weight": weight, "region": region,
		"caught_at": Time.get_ticks_msec(), "perfect": perfect})
	total_caught += 1
	# Count the first catch of each real-world day, so the Almanac's
	# "days fished" record reflects actual play instead of staying at zero.
	var catch_day := _today_key()
	if int(stats.get("last_fish_day", 0)) != catch_day:
		stats["last_fish_day"] = catch_day
		stats["days_fished"] = int(stats.get("days_fished", 0)) + 1
	# A set line is patience, not a hot hand: it never bumps the sale streak.
	if not via_line:
		stats["current_streak"] = int(stats.get("current_streak", 0)) + 1
		stats["best_streak"] = maxi(int(stats.get("best_streak", 0)), int(stats["current_streak"]))
	if perfect:
		stats["perfect_catches"] = int(stats.get("perfect_catches", 0)) + 1
	if fish_id == daily_fish_id():
		stats["daily_catches"] = int(stats.get("daily_catches", 0)) + 1
	if weight > float(stats.get("biggest_fish", 0.0)):
		stats["biggest_fish"] = weight
		stats["biggest_name"] = String(FishDB.fish_data(fish_id).get("name", fish_id))
	_check_quests("catch", fish_id, {"region": region, "weight": weight, "night": night,
			"weather": weather, "perfect": perfect, "streak": int(stats["current_streak"])})
	if AUTO_SAVE:
		request_save()

## A fish is worth its FishDB "coin" base scaled by how big the catch is
## inside the species' own weight range (85%..130% of base). Weight is
## normalized per species, so a trophy marlin pays a little extra instead
## of the old runaway formula that paid 30,000 coins for one fish.
func coin_value(fish_id: String, weight: float) -> int:
	var f := FishDB.fish_data(fish_id)
	var base := int(f.get("coin", 10))
	var wg: Array = f.get("weight_kg", [0.1, 0.5])
	var lo := float(wg[0])
	var hi := float(wg[1])
	var t := 0.5
	if hi > lo:
		t = clampf((weight - lo) / (hi - lo), 0.0, 1.0)
	return maxi(1, int(round(base * (0.85 + 0.45 * t))))

func add_coins(amount: int) -> void:
	coins += amount
	play_sound("coin")
	coins_gained.emit(amount)
	if AUTO_SAVE:
		request_save()

## --- Daily rotation -------------------------------------------------
## A real-world date key so the daily catch and hot market species change
## once a day even between sessions.
func _today_key() -> int:
	return Time.get_date_string_from_system().replace("-", "").to_int()

func _daily_pick(salt: int, count: int) -> int:
	if count <= 0:
		return 0
	return absi(hash("%d-%d" % [_today_key(), salt])) % count

## One species per real day pays double at the market.
func daily_fish_id() -> String:
	var ids := FishDB.all_ids()
	if ids.is_empty():
		return ""
	return String(ids[_daily_pick(3, ids.size())])

## Two species are in demand each day and pay +30%.
func daily_hot_ids() -> Array:
	var ids := FishDB.all_ids()
	if ids.size() < 2:
		return ids
	var a := _daily_pick(11, ids.size())
	var b := (a + 1 + _daily_pick(17, ids.size() - 1)) % ids.size()
	return [String(ids[a]), String(ids[b])]

func is_daily_catch(fish_id: String) -> bool:
	return fish_id != "" and fish_id == daily_fish_id()

func is_hot_demand(fish_id: String) -> bool:
	return daily_hot_ids().has(fish_id)

## Catch streaks pay a little more, up to +20% at ten in a row.
func streak_sale_mult() -> float:
	return 1.0 + float(mini(int(stats.get("current_streak", 0)), 10)) * 0.02

## Combined multiplier from daily catch, daily demand, perfect catch,
## streak, Gold mastery and the 2x coin event.
func sale_mult(fish_id: String, perfect := false) -> float:
	var m := streak_sale_mult()
	if is_daily_catch(fish_id):
		m *= 2.0
	if is_hot_demand(fish_id):
		m *= 1.3
	if perfect:
		m *= 1.15
	# Gold mastery: +0.5% per Gold species, capped at +15%.
	m *= mastery_sale_mult()
	return m * money_mult()

## Final value used by the market, the Tackle Shop and the catch popup.
func sale_value(fish_id: String, weight: float, mult := 1.0, perfect := false) -> int:
	return int(round(coin_value(fish_id, weight) * mult * sale_mult(fish_id, perfect)))

func reset_streak() -> void:
	stats["current_streak"] = 0
	if AUTO_SAVE:
		save_game()

## Persisted mute switch. Muted sounds are skipped entirely (no queued clip).
func set_muted(value: bool) -> void:
	muted = value
	if muted:
		for p in music_players:
			p.stop()
		music_key = ""
		if audio_player != null:
			audio_player.stop()
	_apply_audio_settings()
	if AUTO_SAVE:
		request_save()

func toggle_mute() -> bool:
	set_muted(not muted)
	return muted

## Coins knocked loose (a monster's shock, a toll...). Never goes negative.
func lose_coins(amount: int) -> void:
	coins = maxi(0, coins - amount)
	if AUTO_SAVE:
		save_game()

## Sell every fish in the bucket. `mult` applies shop-side price bonuses
## (Fish Market premium) and the owned-boat value bonus.
func sell_all(mult: float = 1.0) -> int:
	var total := 0
	var count := 0
	for item in inventory:
		var fid := String(item.get("fish_id", ""))
		var w := float(item.get("weight", 0.0))
		var perfect := bool(item.get("perfect", false))
		total += sale_value(fid, w, mult, perfect)
		count += 1
	inventory.clear()
	stats["coins_earned"] = int(stats.get("coins_earned", 0)) + total
	stats["fish_sold"] = int(stats.get("fish_sold", 0)) + count
	add_coins(total)
	_check_quests("sell", "", {"coins": total, "count": count})
	if AUTO_SAVE:
		save_game()
	return total

## Sell a single fish by inventory index. Returns the coins gained.
func sell_one(index: int, mult: float = 1.0) -> int:
	if index < 0 or index >= inventory.size():
		return 0
	var item: Dictionary = inventory[index]
	var fid := String(item.get("fish_id", ""))
	var w := float(item.get("weight", 0.0))
	var perfect := bool(item.get("perfect", false))
	var value := sale_value(fid, w, mult, perfect)
	inventory.remove_at(index)
	stats["coins_earned"] = int(stats.get("coins_earned", 0)) + value
	stats["fish_sold"] = int(stats.get("fish_sold", 0)) + 1
	add_coins(value)
	_check_quests("sell", "", {"coins": value, "count": 1})
	if AUTO_SAVE:
		save_game()
	return value

func has_boat(id: String) -> bool:
	return owned_boats.has(id)

func buy_boat(id: String) -> bool:
	var d: Dictionary = ShopDB.item("boats", id)
	if d.is_empty():
		return false
	if has_boat(id):  # already owned -> just equip
		gear["boat"] = id
		save_game()
		return true
	# Award-only grand prizes can never be bought; they only exist once the
	# album has handed them over.
	if bool(d.get("award_only", false)):
		return false
	var cost := int(d.get("cost", 0))
	if not can_afford(cost):
		return false
	owned_boats.append(id)
	gear["boat"] = id
	coins -= cost
	_check_quests("boat", "")
	save_game()
	return true

func current_boat() -> Dictionary:
	var d := ShopDB.item("boats", String(gear.get("boat", "boat_raft")))
	if d.is_empty():
		d = ShopDB.item("boats", "boat_raft")
	return d

## Best value multiplier across all owned boats (Fish Market multiplies this in).
func boat_value_mult() -> float:
	var best := 1.0
	for id in owned_boats:
		var d: Dictionary = ShopDB.item("boats", String(id))
		best = maxf(best, float(d.get("value_mult", 1.0)))
	return best

## The Deep Sea can only be fished from a real boat (anything beyond the raft).
func has_seaworthy_boat() -> bool:
	for id in owned_boats:
		if String(id) != "boat_raft":
			return true
	return false

## Buy the unlock pass for a fishing region. Ocean additionally needs a boat.
func unlock_region(name: String) -> bool:
	if unlocked_regions.has(name):
		return false
	var cost := int(FishDB.REGION_UNLOCK_COST.get(name, 0))
	if not can_afford(cost):
		return false
	if name == "ocean" and not has_seaworthy_boat():
		return false
	unlocked_regions.append(name)
	coins -= cost
	save_game()
	return true

## Turn in a completed quest for its coin reward. Returns the reward amount.
func claim_quest(qid: String) -> int:
	for q in quests:
		if String(q.get("id", "")) != qid:
			continue
		if String(q.get("season", "")) == "harvest" and not harvest_season_open():
			return 0
		if not bool(q.get("done", false)) or bool(q.get("claimed", false)):
			return 0
		q["claimed"] = true
		var reward := quest_reward(q)
		if bool(q.get("token_reward", false)):
			add_tokens(reward)
		else:
			add_coins(reward)
		save_game()
		return reward
	return 0

func quest_unclaimed_count() -> int:
	var n := 0
	for q in visible_quests():
		if bool(q.get("done", false)) and not bool(q.get("claimed", false)):
			n += 1
	return n

## Scene-to-scene travel (tunnels). The save is flushed and the screen
## fades to black, swaps scenes, then fades back in. The scene change is
## deferred to idle time so it is safe from _process and physics callbacks.
func travel(scene_path: String) -> void:
	play_sound("ui")
	if scene_path.is_empty():
		return
	session_started = true
	flush_save()
	fade_target = 1.0
	fade_scene = scene_path

func inventory_count() -> int:
	return inventory.size()

func bucket_capacity() -> int:
	var id := String(gear.get("bucket", "bucket_small"))
	return maxi(1, int(ShopDB.item("buckets", id).get("capacity", 12)))

func region_percent(region: String) -> float:
	var season := "harvest" if harvest_season_open() else ""
	var fishes := FishDB.fish_by_region(region, season)
	if fishes.size() == 0:
		return 0.0
	var caught := 0
	for f in fishes:
		var fid := String(f.get("id", ""))
		var entry: Dictionary = index.get(fid, {})
		if entry.get("caught", false):
			caught += 1
	return float(caught) / float(fishes.size())

func completion_percent() -> float:
	var season := "harvest" if harvest_season_open() else ""
	var all_ids := FishDB.all_ids(season)
	if all_ids.size() == 0:
		return 0.0
	var caught := 0
	for fid in all_ids:
		var entry: Dictionary = index.get(String(fid), {})
		if entry.get("caught", false):
			caught += 1
	return float(caught) / float(all_ids.size())

func can_afford(cost: int) -> bool:
	return coins >= cost

## The gear slot a shop category equips into ("rods" -> "rod" ...).
func gear_key(category: String) -> String:
	match category:
		"rods": return "rod"
		"lines": return "line"
		"baits": return "bait"
		"lanterns": return "lantern"
		"buckets": return "bucket"
		"boats": return "boat"
		_: return category

## Buy / equip a shop item. Bait is a consumable: a purchase adds charges
## to the bag and equips it. Already-owned gear (rods, lines, buckets)
## equips for free so items can be swapped without re-buying them.
func buy_item(category: String, id: String) -> bool:
	var d: Dictionary = ShopDB.item(category, id)
	if d.is_empty():
		return false
	# island rods are built from coconuts at the craft bench, never bought
	if category == "rods" and ShopDB.CRAFTED_RODS.has(id):
		return false
	# Seasonal lantern: bought with tokens, only while the feast runs.
	if String(d.get("season", "")) == "harvest":
		if not harvest_season_open():
			return false
		if bool(d.get("owned", false)):
			gear[gear_key(category)] = id
			save_game()
			return true
		var tcost := int(d.get("token_cost", 0))
		if tcost > 0:
			if not harvest_spend_tokens(tcost):
				return false
			ShopDB.set_owned(category, id, true)
			gear[gear_key(category)] = id
			play_sound("bell")
			save_game()
			return true
	if category == "baits":
		var bait_cost := int(d.get("cost", 0))
		if not can_afford(bait_cost):
			return false
		coins -= bait_cost
		bait_counts[id] = bait_count(id) + int(d.get("charges", 1))
		gear["bait"] = id
		_check_quests("buy_bait", "")
		save_game()
		return true
	var already := bool(d.get("owned", false))
	var cost := 0 if already else int(d.get("cost", 0))
	if not can_afford(cost):
		return false
	gear[gear_key(category)] = id
	if not already:
		ShopDB.set_owned(category, id, true)
		coins -= cost
	save_game()
	return true

## How many casts of a bait are left in the bag.
func bait_count(id: String) -> int:
	return int(bait_counts.get(id, 0))

## Equip a bought bait (only if the bag holds any).
func activate_bait(bait_id: String) -> void:
	if bait_count(bait_id) <= 0:
		return
	gear["bait"] = bait_id
	if AUTO_SAVE:
		save_game()

## Use one charge of the equipped bait for the cast that is starting.
## Returns the bait id used ("" when fishing bare - rare fish hate that).
## Deliberately debounced: a save per cast is an IndexedDB write per cast
## on the web/mobile build, which stutters the browser.
func consume_bait() -> String:
	var id := String(gear.get("bait", ""))
	if id == "":
		return ""
	if bait_count(id) <= 0:
		gear["bait"] = ""
		return ""
	bait_counts[id] = bait_count(id) - 1
	_check_quests("use_bait", "")
	if AUTO_SAVE:
		request_save()
	return id

## Unequip bait once the bag runs dry.
func update_bait(_dt: float) -> void:
	var id := String(gear.get("bait", ""))
	if id != "" and bait_count(id) <= 0:
		gear["bait"] = ""

## The amount a quest needs before it is done. Region-collection quests
## scale with how many species live in that region (new fish included).
func quest_need(q: Dictionary) -> int:
	if String(q.get("kind", "")) == "region_complete":
		var season := "harvest" if harvest_season_open() else ""
		return maxi(1, FishDB.fish_by_region(String(q.get("target", "")), season).size())
	return maxi(1, int(q.get("need", 1)))

## How many distinct species have been discovered so far.
func _species_discovered() -> int:
	var n := 0
	for fid in index.keys():
		var entry: Dictionary = index[fid]
		if bool(entry.get("caught", false)):
			n += 1
	return n

## --- Angler Almanac: mastery ---------------------------------------
func mastery_paid(fish_id: String) -> int:
	return int(mastery.get(fish_id, 0))


## The rank the recorded catch count has reached (always authoritative).
func mastery_rank(fish_id: String) -> int:
	return AlmanacLib.mastery_rank(int(index.get(fish_id, {}).get("count", 0)))


## [gold, silver, bronze] counts using the derived rank (all species).
func mastery_counts() -> Array:
	var out := [0, 0, 0]
	for fid in FishDB.FISH.keys():
		var r := mastery_rank(String(fid))
		if r >= 1 and r <= 3:
			out[3 - r] += 1
	return out


func gold_species_count() -> int:
	var n := 0
	for fid in FishDB.FISH.keys():
		if mastery_rank(String(fid)) >= 3:
			n += 1
	return n


func angler_points() -> int:
	var total := 0
	for fid in FishDB.FISH.keys():
		total += AlmanacLib.rank_points(mastery_rank(String(fid)))
	return total


func angler_title() -> String:
	return AlmanacLib.title_for(angler_points())


## [next title, points needed] or ["", 0] at Legend.
func angler_next() -> Array:
	return AlmanacLib.next_title(angler_points())


func mastery_sale_mult() -> float:
	return 1.0 + AlmanacLib.gold_bonus(gold_species_count())


func _mastery_species_at(rank: int) -> int:
	var n := 0
	for fid in FishDB.FISH.keys():
		if mastery_rank(String(fid)) >= rank:
			n += 1
	return n


## Pay every newly reached medal exactly once, oldest rank first. A save
## loaded without a mastery block is synced to its counts without paying.
func _check_mastery(fish_id: String) -> void:
	var reached := mastery_rank(fish_id)
	var paid := mastery_paid(fish_id)
	if reached <= paid:
		return
	var total := 0
	for rank in range(paid + 1, reached + 1):
		total += AlmanacLib.rank_coins(rank)
		mastery[fish_id] = rank
		last_mastery_rank = rank
		last_mastery_coins += AlmanacLib.rank_coins(rank)
		mastery_ranked.emit(fish_id, rank)
	if total > 0:
		coins += total
		coins_gained.emit(total)
		play_sound("fanfare")
	_check_quests("mastery_rank", fish_id, {"rank": reached})


## --- Angler Almanac: daily board ------------------------------------
## Local epoch day. Godot reports the timezone bias in minutes east of
## UTC (-300 for UTC-5), so add it to the epoch before flooring. The board
## only ever rolls forward, so a clock that jumps back keeps the board
## already on screen.
func day_index() -> int:
	var bias := 0
	var tz: Variant = Time.get_time_zone_from_system()
	if typeof(tz) == TYPE_DICTIONARY:
		bias = int(tz.get("bias", 0))
	return int(floor((Time.get_unix_time_from_system() + float(bias) * 60.0) / 86400.0))


func ensure_daily() -> Dictionary:
	var today := day_index()
	var board_day := int(daily.get("day", 0))
	if board_day == today:
		var ids: Array = daily.get("ids", [])
		if ids.is_empty():
			daily["ids"] = AlmanacLib.pick_daily_ids(today)
		return daily
	if board_day > today:
		return daily
	var streak := int(daily.get("streak", 0))
	var last := int(daily.get("last_complete_day", 0))
	daily = DAILY_DEFAULTS.duplicate(true)
	daily["day"] = today
	daily["ids"] = AlmanacLib.pick_daily_ids(today)
	daily["streak"] = streak
	daily["last_complete_day"] = last
	request_save()
	return daily


func daily_progress(id: String) -> int:
	var board := ensure_daily()
	var prog: Dictionary = board.get("progress", {})
	return int(prog.get(id, 0))


func daily_need(id: String) -> int:
	return maxi(1, int(AlmanacLib.daily_def(id).get("need", 1)))


func daily_done(id: String) -> bool:
	return daily_progress(id) >= daily_need(id)


func daily_claimed(id: String) -> bool:
	var board := ensure_daily()
	var claimed: Array = board.get("claimed", [])
	return claimed.has(id)


func daily_claimable_count() -> int:
	ensure_daily()
	var n := 0
	var ids: Array = daily.get("ids", [])
	var claimed: Array = daily.get("claimed", [])
	for id_v in ids:
		var id := String(id_v)
		if not claimed.has(id) and daily_done(id):
			n += 1
	return n


## Claim one finished daily. Pays the streak-scaled reward once; the third
## claim of the day also pays the completion bonus and advances the streak.
func claim_daily(challenge_id: String) -> int:
	var board := ensure_daily()
	var ids: Array = board.get("ids", [])
	if not ids.has(challenge_id):
		return 0
	var claimed: Array = board.get("claimed", [])
	if claimed.has(challenge_id):
		return 0
	var def := AlmanacLib.daily_def(challenge_id)
	if def.is_empty() or daily_progress(challenge_id) < daily_need(challenge_id):
		return 0
	var streak := int(board.get("streak", 0))
	var reward := float(def.get("reward", 0))
	var gain := int(round(reward * (1.0 + AlmanacLib.DAILY_STREAK_STEP
			* float(mini(streak, AlmanacLib.DAILY_STREAK_CAP))) * money_mult()))
	claimed.append(challenge_id)
	board["claimed"] = claimed
	if claimed.size() >= ids.size():
		gain += AlmanacLib.DAILY_BONUS
		var today := day_index()
		if int(board.get("last_complete_day", 0)) == today - 1:
			board["streak"] = streak + 1
		else:
			board["streak"] = 1
		board["last_complete_day"] = today
		daily_completed.emit(int(board["streak"]))
	coins += gain
	coins_gained.emit(gain)
	play_sound("coin")
	_check_quests("daily_streak", "", {"streak": int(board.get("streak", 0))})
	request_save()
	return gain


## Feed catch / sell events into the three challenges on the board.
func _check_dailies(kind: String, fish_id: String, data: Dictionary = {}) -> void:
	var board := ensure_daily()
	var ids: Array = board.get("ids", [])
	var claimed: Array = board.get("claimed", [])
	var prog: Dictionary = board.get("progress", {})
	var changed := false
	for id_v in ids:
		var id := String(id_v)
		if claimed.has(id):
			continue
		var def := AlmanacLib.daily_def(id)
		if def.is_empty():
			continue
		var cur := int(prog.get(id, 0))
		var need := maxi(1, int(def.get("need", 1)))
		if cur >= need:
			continue
		var inc := 0
		match String(def.get("kind", "")):
			"catch_any":
				if kind == "catch":
					inc = 1
			"catch_rarity":
				if kind == "catch" and rarity_of(fish_id) == String(def.get("target", "")):
					inc = 1
			"catch_night":
				if kind == "catch" and bool(data.get("night", false)):
					inc = 1
			"catch_weight":
				if kind == "catch" and float(data.get("weight", 0.0)) >= float(def.get("target", 0.0)):
					inc = 1
			"catch_weather":
				if kind == "catch":
					var wet := String(data.get("weather", ""))
					var target := String(def.get("target", "bad"))
					if (target == "bad" and (wet == "rain" or wet == "storm")) or target == wet:
						inc = 1
			"perfect_catch":
				if kind == "catch" and bool(data.get("perfect", false)):
					inc = 1
			"region_catch":
				if kind == "catch" and String(data.get("region", "")) == String(def.get("target", "")):
					inc = 1
			"sell_count":
				if kind == "sell":
					inc = maxi(1, int(data.get("count", 1)))
			"catch_streak":
				if kind == "catch":
					var s := maxi(cur, int(data.get("streak", 0)))
					if s > cur:
						prog[id] = s
						changed = true
					continue
		if inc > 0:
			prog[id] = cur + inc
			changed = true
	if changed:
		board["progress"] = prog
		request_save()


## --- Angler Almanac: set lines --------------------------------------
func trotline_slots() -> int:
	return ShopDB.trotline_slots(trotline_tier)


func line_slots_used() -> int:
	return set_lines.size()


func line_ready(spot: String) -> bool:
	return set_lines.has(spot) and line_seconds_left(spot) <= 0


## Seconds until ready; 0 when ready or when no line is set there.
func line_seconds_left(spot: String) -> int:
	if not set_lines.has(spot):
		return 0
	var placed := float(set_lines.get(spot, 0))
	var elapsed := maxf(0.0, Time.get_unix_time_from_system() - placed)
	return maxi(0, int(ceil(SET_LINE_SECONDS - elapsed)))


func line_ready_any() -> bool:
	for spot in set_lines.keys():
		if line_ready(String(spot)):
			return true
	return false


func line_spot_name(spot: String) -> String:
	return String(FishDB.REGION_DISPLAY.get(spot, spot.capitalize()))


## Empty string on success, otherwise a reason code the HUD turns into a hint.
func place_line(spot: String) -> String:
	if spot == "island":
		return "island"
	if spot == "" or spot.begins_with("open") or not ["pond", "river", "lake", "ocean"].has(spot):
		return "open"
	if set_lines.has(spot):
		return "already"
	if trotline_slots() <= 0:
		return "no_gear"
	if set_lines.size() >= trotline_slots():
		return "busy"
	set_lines[spot] = int(Time.get_unix_time_from_system())
	stats["lines_set"] = int(stats.get("lines_set", 0)) + 1
	play_sound("cast")
	_check_quests("line_set", "", {"spot": spot})
	request_save()
	return ""


func _line_pool(spot: String, weather: String, night: bool) -> Array:
	var season := "harvest" if harvest_season_open() else ""
	var raw := FishDB.fish_pool(spot, weather, night, season)
	var out: Array = []
	for f in raw:
		if bool(f.get("anywhere", false)) or bool(f.get("bait_only", false)):
			continue
		if String(f.get("rarity", "")) == "Legendary":
			continue
		out.append(f)
	return out


## Rarity weights 62 / 27 / 8 / 3 Common / Uncommon / Rare / Epic.
func _roll_line_fish(pool: Array) -> Dictionary:
	if pool.is_empty():
		return {}
	var roll := randf() * 100.0
	var want := "Common"
	if roll >= 97.0:
		want = "Epic"
	elif roll >= 89.0:
		want = "Rare"
	elif roll >= 62.0:
		want = "Uncommon"
	var matches: Array = []
	for f in pool:
		if String(f.get("rarity", "")) == want:
			matches.append(f)
	if matches.is_empty():
		matches = pool
	return matches[randi() % matches.size()]


## Collect a ready line. The line stays in the water when the bucket is
## full, so nothing is ever lost to a full bag.
func collect_line(spot: String, weather := "", night := false) -> Dictionary:
	if not set_lines.has(spot):
		return {"ok": false, "reason": "empty"}
	if line_seconds_left(spot) > 0:
		return {"ok": false, "reason": "waiting"}
	if inventory_count() >= bucket_capacity():
		return {"ok": false, "reason": "full"}
	var pool := _line_pool(spot, weather, night)
	if pool.is_empty():
		return {"ok": false, "reason": "empty_pool"}
	var f := _roll_line_fish(pool)
	var fid := String(f.get("id", ""))
	var wg: Array = f.get("weight_kg", [0.1, 1.0])
	var weight := randf_range(float(wg[0]), float(wg[1]))
	set_lines.erase(spot)
	record_catch(fid, weight, spot, night, weather, false, true)
	var bait_back := false
	var bait_id := String(gear.get("bait", ""))
	if bait_id != "" and randf() < 0.5:
		bait_counts[bait_id] = bait_count(bait_id) + 1
		bait_back = true
	play_sound("bell")
	_check_quests("line_collect", fid, {"region": spot, "weight": weight,
			"night": night, "weather": weather})
	request_save()
	return {"ok": true, "fish_id": fid, "weight": weight,
			"name": String(f.get("name", fid)), "bait_back": bait_back, "bait_id": bait_id}

func _check_quests(kind: String, fish_id: String, data: Dictionary = {}) -> void:
	for q in quests:
		if bool(q.get("done", false)):
			continue
		var qk := String(q.get("kind", ""))
		match qk:
			"catch_any":
				if kind == "catch":
					q["progress"] = int(q.get("progress", 0)) + 1
			"catch_rarity":
				if kind == "catch" and rarity_of(fish_id) == String(q.get("target", "")):
					q["progress"] = int(q.get("progress", 0)) + 1
			"catch_night":
				if kind == "catch" and bool(data.get("night", false)):
					q["progress"] = int(q.get("progress", 0)) + 1
			"catch_weight":
				if kind == "catch" and float(data.get("weight", 0.0)) >= float(q.get("target", 0.0)):
					q["progress"] = int(q.get("progress", 0)) + 1
			"region_catch":
				if kind == "catch" and String(data.get("region", "")) == String(q.get("target", "")):
					q["progress"] = int(q.get("progress", 0)) + 1
			"region_complete":
				if kind == "catch":
					var r := String(q.get("target", ""))
					var season := "harvest" if harvest_season_open() else ""
					q["progress"] = int(region_percent(r) * float(FishDB.fish_by_region(r, season).size()))
			"unique_species":
				if kind == "catch":
					q["progress"] = _species_discovered()
			"sell_count":
				if kind == "sell":
					q["progress"] = int(q.get("progress", 0)) + maxi(1, int(data.get("count", 1)))
			"sell_coins":
				if kind == "sell":
					q["progress"] = int(q.get("progress", 0)) + int(data.get("coins", 0))
			"buy_bait":
				if kind == "buy_bait":
					q["progress"] = int(q.get("progress", 0)) + 1
			"use_bait":
				if kind == "use_bait":
					q["progress"] = int(q.get("progress", 0)) + 1
			"own_boat":
				if kind == "boat":
					q["progress"] = 1
			"catch_weather":
				if kind == "catch":
					var wet := String(data.get("weather", ""))
					var target := String(q.get("target", "bad"))
					if (target == "bad" and (wet == "rain" or wet == "storm")) or target == wet:
						q["progress"] = int(q.get("progress", 0)) + 1
			"perfect_catch":
				if kind == "catch" and bool(data.get("perfect", false)):
					q["progress"] = int(q.get("progress", 0)) + 1
			"catch_streak":
				if kind == "catch":
					q["progress"] = maxi(int(q.get("progress", 0)), int(data.get("streak", 0)))
			"catch_species":
				if kind == "catch" and fish_id == String(q.get("target", "")):
					q["progress"] = int(q.get("progress", 0)) + 1
			"harvest_catch":
				if kind == "catch" and String(FishDB.fish_data(fish_id).get("season", "")) == "harvest":
					q["progress"] = int(q.get("progress", 0)) + 1
			"harvest_donate":
				if kind == "donate":
					q["progress"] = int(q.get("progress", 0)) + 1
			"casino_win":
				if kind == "casino" and bool(data.get("win", false)):
					q["progress"] = int(q.get("progress", 0)) + 1
			"casino_won":
				if kind == "casino":
					q["progress"] = int(q.get("progress", 0)) + maxi(0, int(data.get("coins", 0)))
			"line_set":
				if kind == "line_set":
					q["progress"] = int(q.get("progress", 0)) + 1
			"line_collect":
				if kind == "line_collect":
					q["progress"] = int(q.get("progress", 0)) + 1
			"mastery_rank":
				if kind == "mastery_rank":
					q["progress"] = _mastery_species_at(int(q.get("target", 1)))
			"daily_streak":
				if kind == "daily_streak":
					q["progress"] = maxi(int(q.get("progress", 0)), int(data.get("streak", 0)))
		if int(q.get("progress", 0)) >= quest_need(q):
			q["done"] = true
	_check_dailies(kind, fish_id, data)

## Procedural SFX are baked once into AudioStreamWAV clips (a streaming
## generator playback leaks an ObjectDB instance at exit) and cached.
func _setup_audio() -> void:
	audio_player = AudioStreamPlayer.new()
	audio_player.autoplay = false
	audio_player.bus = BUS_SFX
	add_child(audio_player)
	for i in range(2):
		var p := AudioStreamPlayer.new()
		p.autoplay = false
		p.bus = BUS_MUSIC
		p.volume_db = -60.0
		add_child(p)
		music_players.append(p)

func play_sound(sfx_name: String) -> void:
	if audio_player == null or muted:
		return
	var wav: AudioStreamWAV = sfx_cache.get(sfx_name)
	if wav == null:
		wav = _bake_sfx(sfx_name)
		if wav == null:
			return
		sfx_cache[sfx_name] = wav
	audio_player.stream = wav
	audio_player.play(0.0)

func _bake_sfx(sfx_name: String) -> AudioStreamWAV:
	var sfx := {
		"cast": [440.0, 0.12, 0.15, 0],
		"bite": [880.0, 0.18, 0.25, 0],
		"reel": [660.0, 0.06, 0.12, 1],
		"escape": [220.0, 0.40, 0.20, 0],
		"catch": [523.0, 0.25, 0.30, 0],
		"rare": [784.0, 0.45, 0.35, 0],
		"coin": [1046.0, 0.10, 0.20, 1],
		"ui": [700.0, 0.05, 0.10, 1],
		"buzz": [150.0, 0.30, 0.18, 2],
		"shock": [190.0, 0.40, 0.32, 2],
		"thunder": [58.0, 1.10, 0.34, 2],
		# ambience one-shots (played by the region ambience timer)
		"amb_frog": [110.0, 0.22, 0.16, 4],
		"amb_lily": [1500.0, 0.08, 0.07, 0],
		"amb_current": [70.0, 0.60, 0.10, 3],
		"amb_splash": [300.0, 0.20, 0.10, 3],
		"amb_loon": [420.0, 0.90, 0.16, 4],
		"amb_gull": [900.0, 0.35, 0.10, 4],
		"amb_spray": [180.0, 0.40, 0.08, 3],
		"amb_bird": [1200.0, 0.12, 0.07, 4],
		# Harvest Feast one-shots
		"leaf": [1100.0, 0.45, 0.09, 3],
		"bell": [1568.0, 0.60, 0.20, 4],
		"gobble": [380.0, 0.50, 0.16, 4],
		"fanfare": [523.0, 1.50, 0.24, 5],
	}
	var t: Array = sfx.get(sfx_name, [])
	if t.size() == 0:
		return null
	var freq := float(t[0])
	var dur := float(t[1])
	var vol := float(t[2])
	var wave := int(t[3])
	var frames := int(dur * 44100.0)
	var bytes := PackedByteArray()
	bytes.resize(frames * 2)
	var phase := 0.0
	var step := freq * 2.0 * PI / 44100.0
	var noise := 0.0
	for i in range(frames):
		var tpos := float(i) / float(frames)
		var env := 1.0 - tpos * 0.7
		var sample := 0.0
		match wave:
			0:
				sample = sin(phase)
			1:
				sample = 1.0 if sin(phase) > 0 else -1.0
			2:
				sample = 1.0 if sin(phase * 3.0) > 0 else -1.0
			3:
				# cheap noise: smooth a random walk for water textures
				noise = noise * 0.82 + randf_range(-1.0, 1.0) * 0.18
				sample = noise * 1.6
			4:
				# two-tone call (frog / loon / gull), pitch slides down
				var slide := 1.0 - tpos * 0.35
				sample = sin(phase * slide) * (0.6 + 0.4 * sin(tpos * TAU * 2.0))
			5:
				# four-note fanfare
				var notes := [1.0, 1.25, 1.5, 2.0]
				var ni := mini(3, int(tpos * 4.0))
				sample = sin(phase * float(notes[ni])) * (1.0 - tpos * 0.15) 						+ sin(phase * float(notes[ni]) * 0.5) * 0.25
		phase += step
		sample *= vol * env * 0.5
		bytes.encode_s16(i * 2, int(clampf(sample, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 44100
	wav.stereo = false
	wav.data = bytes
	return wav
