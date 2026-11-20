extends Node

## Persistent game state: coins, inventory, fish index, gear, quests.
## Saved to user://save.json via FileAccess store_var/get_var.
## Also owns the procedural audio player (see play_sound()).

var coins := 50
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
}
var muted := false
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

var audio_player: AudioStreamPlayer
var sfx_cache := {}

var SAVE_PATH := "user://save.json"
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
	{"id": "storm_chaser", "title": "Storm Chaser", "desc": "Catch 2 fish in rain or a storm.",
		"kind": "catch_weather", "target": "bad", "need": 2, "reward": 180},
	{"id": "perfect_angler", "title": "Dead Center", "desc": "Land 5 perfect catches.",
		"kind": "perfect_catch", "target": 5, "need": 5, "reward": 200},
	{"id": "hot_streak", "title": "On Fire", "desc": "Reach a 6-catch streak.",
		"kind": "catch_streak", "target": 6, "need": 6, "reward": 220},
	{"id": "islander", "title": "Island Angler", "desc": "Catch 5 fish at Coconut Isle.",
		"kind": "region_catch", "target": "island", "need": 5, "reward": 200},
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
	# complete Fish Index, every species recorded at its top weight
	_init_index()
	for fid in FishDB.all_ids():
		var id := String(fid)
		var f := FishDB.fish_data(id)
		var wg: Array = f.get("weight_kg", [0.1, 1.0])
		var entry: Dictionary = index.get(id, {})
		entry["caught"] = true
		entry["count"] = maxi(1, int(entry.get("count", 0)))
		entry["pb_weight"] = maxf(float(wg[wg.size() - 1]), float(entry.get("pb_weight", 0.0)))
		entry["region"] = String(f.get("region", "pond"))
		index[id] = entry
	total_caught = maxi(total_caught, index.size())
	# a handful of top-value fish in the bucket so selling can be tested
	var pool := FishDB.all_ids()
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
var cheat_buffer := ""
var cheat_timer := 0.0


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
	if cheat_timer <= 0.0:
		return
	cheat_timer = maxf(0.0, cheat_timer - dt)
	if cheat_timer == 0.0:
		cheat_buffer = ""


func _ready() -> void:
	_load_game()
	_setup_audio()

func save_game() -> void:
	var data := {
		"coins": coins,
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
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_var(data)
		file.close()

func _load_game() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		_init_index()
		quests = _merge_quests([])
		save_game()
		return
	var data: Dictionary = file.get_var()
	file.close()
	if typeof(data) != TYPE_DICTIONARY:
		_init_index()
		quests = _merge_quests([])
		save_game()
		return
	coins = int(data.get("coins", 50))
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
	var saved_stats: Variant = data.get("stats", {})
	if typeof(saved_stats) == TYPE_DICTIONARY:
		for k in saved_stats.keys():
			stats[k] = saved_stats[k]
	var saved_baits: Variant = data.get("bait_counts", {})
	bait_counts = saved_baits if typeof(saved_baits) == TYPE_DICTIONARY else {}
	# fresh quest metadata + any missing (new) quests, keeping saved progress
	quests = _merge_quests(data.get("quests", []))
	_init_index()

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

func _init_index() -> void:
	var ids := FishDB.all_ids()
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
		weather := "", perfect := false) -> void:
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
	inventory.append({"fish_id": fish_id, "weight": weight, "region": region,
		"caught_at": Time.get_ticks_msec(), "perfect": perfect})
	total_caught += 1
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
		save_game()

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
	if AUTO_SAVE:
		save_game()

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

## Combined multiplier from daily catch, daily demand, perfect catch and streak.
func sale_mult(fish_id: String, perfect := false) -> float:
	var m := streak_sale_mult()
	if is_daily_catch(fish_id):
		m *= 2.0
	if is_hot_demand(fish_id):
		m *= 1.3
	if perfect:
		m *= 1.15
	return m

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
	if muted and audio_player != null:
		audio_player.stop()
	if AUTO_SAVE:
		save_game()

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
	_check_quests("sell", "", {"coins": total})
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
	_check_quests("sell", "", {"coins": value})
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
	return ShopDB.item("boats", String(gear.get("boat", "boat_raft")))

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
		if not bool(q.get("done", false)) or bool(q.get("claimed", false)):
			return 0
		q["claimed"] = true
		var reward := int(q.get("reward", 0))
		add_coins(reward)
		save_game()
		return reward
	return 0

func quest_unclaimed_count() -> int:
	var n := 0
	for q in quests:
		if bool(q.get("done", false)) and not bool(q.get("claimed", false)):
			n += 1
	return n

## Scene-to-scene travel (tunnels). The save is flushed and the scene swap
## is deferred to idle time so it is safe from _process and physics
## callbacks (an immediate swap frees this scene mid-callback).
func travel(scene_path: String) -> void:
	play_sound("ui")
	if scene_path.is_empty():
		return
	session_started = true
	save_game()
	get_tree().call_deferred("change_scene_to_file", scene_path)

func inventory_count() -> int:
	return inventory.size()

func bucket_capacity() -> int:
	var id := String(gear.get("bucket", "bucket_small"))
	return maxi(1, int(ShopDB.item("buckets", id).get("capacity", 12)))

func region_percent(region: String) -> float:
	var fishes := FishDB.fish_by_region(region)
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
	var all_ids := FishDB.all_ids()
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
		save_game()
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
		return maxi(1, FishDB.fish_by_region(String(q.get("target", ""))).size())
	return maxi(1, int(q.get("need", 1)))

## How many distinct species have been discovered so far.
func _species_discovered() -> int:
	var n := 0
	for fid in index.keys():
		var entry: Dictionary = index[fid]
		if bool(entry.get("caught", false)):
			n += 1
	return n

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
					q["progress"] = int(region_percent(r) * float(FishDB.fish_by_region(r).size()))
			"unique_species":
				if kind == "catch":
					q["progress"] = _species_discovered()
			"sell_count":
				if kind == "sell":
					q["progress"] = int(q.get("progress", 0)) + 1
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
		if int(q.get("progress", 0)) >= quest_need(q):
			q["done"] = true

## Procedural SFX are baked once into AudioStreamWAV clips (a streaming
## generator playback leaks an ObjectDB instance at exit) and cached.
func _setup_audio() -> void:
	audio_player = AudioStreamPlayer.new()
	audio_player.autoplay = false
	add_child(audio_player)

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
	for i in range(frames):
		var tpos := float(i) / float(frames)
		var env := 1.0 - tpos * 0.7
		var sample := 0.0
		if wave == 0:
			sample = sin(phase)
		elif wave == 1:
			sample = 1.0 if sin(phase) > 0 else -1.0
		else:
			sample = 1.0 if sin(phase * 3.0) > 0 else -1.0
		phase += step
		sample *= vol * env * 0.5
		bytes.encode_s16(i * 2, int(clampf(sample, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 44100
	wav.stereo = false
	wav.data = bytes
	return wav
