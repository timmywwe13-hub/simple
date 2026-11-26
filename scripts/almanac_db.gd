class_name AlmanacDB
extends RefCounted

## Static data for the Angler Almanac (v1.10).
##
## Species mastery thresholds and medal payouts, angler rank titles, the
## daily challenge table, and the field-note tips. Everything here is pure
## data plus deterministic pickers, so the save file only ever stores the
## highest rank already paid, the current daily board, and the set lines.

const MASTERY_THRESHOLDS := [5, 15, 40]
const MASTERY_NAMES := ["NONE", "BRONZE", "SILVER", "GOLD"]
const MASTERY_COINS := [0, 25, 100, 300]
const MASTERY_POINTS := [0, 1, 2, 3]
const MASTERY_MAX_POINTS := 204          # 68 species x 3 points
const GOLD_BONUS_PER_SPECIES := 0.005
const GOLD_BONUS_CAP := 0.15             # 30 gold species
const DAILY_BONUS := 150
const DAILY_STREAK_STEP := 0.10
const DAILY_STREAK_CAP := 5

## [points, title]. The first entry is the floor.
const TITLES := [
	[0, "NOVICE"],
	[20, "APPRENTICE"],
	[50, "ANGLER"],
	[90, "VETERAN"],
	[130, "MASTER"],
	[170, "LEGEND"],
]

## Daily challenge table. `kind` matches the event kinds passed through
## _check_quests; the four region rows use region_catch with a target.
const DAILY_DEFS := [
	{"id": "catch_any_10", "kind": "catch_any", "need": 10, "reward": 100,
		"label": "CATCH 10 FISH"},
	{"id": "catch_any_18", "kind": "catch_any", "need": 18, "reward": 140,
		"label": "CATCH 18 FISH"},
	{"id": "rare_5", "kind": "catch_rarity", "target": "Uncommon", "need": 5,
		"reward": 110, "label": "CATCH 5 UNCOMMON FISH"},
	{"id": "rare_2", "kind": "catch_rarity", "target": "Rare", "need": 2,
		"reward": 160, "label": "CATCH 2 RARE FISH"},
	{"id": "night_4", "kind": "catch_night", "need": 4, "reward": 120,
		"label": "CATCH 4 FISH AT NIGHT"},
	{"id": "weather_3", "kind": "catch_weather", "target": "bad", "need": 3,
		"reward": 130, "label": "CATCH 3 FISH IN BAD WEATHER"},
	{"id": "perfect_3", "kind": "perfect_catch", "need": 3, "reward": 140,
		"label": "LAND 3 PERFECT CATCHES"},
	{"id": "region_pond", "kind": "region_catch", "target": "pond", "need": 5,
		"reward": 120, "label": "CATCH 5 POND FISH"},
	{"id": "region_river", "kind": "region_catch", "target": "river", "need": 5,
		"reward": 120, "label": "CATCH 5 RIVER FISH"},
	{"id": "region_lake", "kind": "region_catch", "target": "lake", "need": 4,
		"reward": 120, "label": "CATCH 4 LAKE FISH"},
	{"id": "region_ocean", "kind": "region_catch", "target": "ocean", "need": 3,
		"reward": 120, "label": "CATCH 3 DEEP SEA FISH"},
	{"id": "sell_12", "kind": "sell_count", "need": 12, "reward": 110,
		"label": "SELL 12 FISH"},
	{"id": "weight_5", "kind": "catch_weight", "target": 5.0, "need": 1,
		"reward": 130, "label": "CATCH A FISH OF 5 KG OR MORE"},
	{"id": "streak_6", "kind": "catch_streak", "target": 6, "need": 6,
		"reward": 150, "label": "REACH A 6-CATCH STREAK"},
]

## Field notes: three are picked per local day for the Almanac.
const FIELD_NOTES := [
	"SET LINES RUN FOR EIGHT MINUTES. CHECK THEM WHEN THE BELL RINGS.",
	"EACH GOLD SPECIES ADDS HALF A PERCENT TO EVERY SALE, UP TO 15 PERCENT.",
	"FINISH ALL THREE DAILIES FOR A 150 COIN COMPLETION BONUS.",
	"MASTERED SPECIES SHOW THEIR MEDAL ON THE CATCH CARD.",
	"THE DAILY BOARD ROLLS OVER AT LOCAL MIDNIGHT.",
	"TITLES RISE AT 20, 50, 90, 130 AND 170 ANGLER POINTS.",
	"PERFECT CATCHES ADD 15 PERCENT ON TOP OF YOUR GOLD BONUS.",
	"THE MOONLIT TENCH ONLY RISES ON THE LAKE AFTER DARK.",
	"SELL YOUR BUCKET IN ONE TRIP TO CLEAR A SELLING DAILY.",
	"THE GALE SMELT BITES ONLY WHEN THE STORM ROLLS IN.",
	"SET LINES ARE PATIENCE - THEY NEVER BUMP YOUR CATCH STREAK.",
	"CHECK THE ALMANAC FOR THE THREE CHALLENGES BEFORE YOU CAST.",
]

## --- mastery ----------------------------------------------------------
static func mastery_rank(count: int) -> int:
	if count >= int(MASTERY_THRESHOLDS[2]):
		return 3
	if count >= int(MASTERY_THRESHOLDS[1]):
		return 2
	if count >= int(MASTERY_THRESHOLDS[0]):
		return 1
	return 0


static func rank_name(rank: int) -> String:
	return String(MASTERY_NAMES[clampi(rank, 0, 3)])


static func rank_points(rank: int) -> int:
	return int(MASTERY_POINTS[clampi(rank, 0, 3)])


## Coins paid when a species first reaches `rank` (1..3).
static func rank_coins(rank: int) -> int:
	return int(MASTERY_COINS[clampi(rank, 0, 3)])


static func next_threshold(rank: int) -> int:
	if rank >= 3:
		return 0
	return int(MASTERY_THRESHOLDS[clampi(rank, 0, 2)])


## "SILVER (23 / 40 TO GOLD)" or "GOLD (MAX)" for the Index detail.
static func mastery_line(count: int) -> String:
	var rank := mastery_rank(count)
	if rank >= 3:
		return "GOLD (MAX)"
	var next := next_threshold(rank)
	return "%s (%d / %d TO %s)" % [rank_name(rank), count, next,
			rank_name(rank + 1)]


## --- angler rank ------------------------------------------------------
static func title_for(points: int) -> String:
	var title := String(TITLES[0][1])
	for row in TITLES:
		if points >= int(row[0]):
			title = String(row[1])
	return title


static func next_title(points: int) -> Array:
	for row in TITLES:
		if points < int(row[0]):
			return [String(row[1]), int(row[0])]
	return ["", 0]


static func gold_bonus(gold_species: int) -> float:
	return minf(float(gold_species) * GOLD_BONUS_PER_SPECIES, GOLD_BONUS_CAP)


## --- daily board ------------------------------------------------------
static func daily_def(id: String) -> Dictionary:
	for d in DAILY_DEFS:
		if String(d.get("id", "")) == id:
			return d
	return {}


## Deterministic three-challenge pick for a local epoch day. Salts 101-103
## mirror daily_fish_id hashing, with linear probing so a day never repeats
## a challenge.
static func pick_daily_ids(day_key: int) -> Array:
	var out: Array = []
	for salt in [101, 102, 103]:
		var idx := absi(hash("%d-%d" % [day_key, salt])) % DAILY_DEFS.size()
		var guard := 0
		while out.has(String(DAILY_DEFS[idx]["id"])) and guard < DAILY_DEFS.size():
			idx = (idx + 1) % DAILY_DEFS.size()
			guard += 1
		out.append(String(DAILY_DEFS[idx]["id"]))
	return out


## Three deterministic field notes for the day (salts 201-203).
static func pick_field_notes(day_key: int) -> Array:
	var out: Array = []
	for salt in [201, 202, 203]:
		var idx := absi(hash("%d-%d" % [day_key, salt])) % FIELD_NOTES.size()
		var guard := 0
		while out.has(String(FIELD_NOTES[idx])) and guard < FIELD_NOTES.size():
			idx = (idx + 1) % FIELD_NOTES.size()
			guard += 1
		out.append(String(FIELD_NOTES[idx]))
	return out
