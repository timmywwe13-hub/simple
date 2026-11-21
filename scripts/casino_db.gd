class_name CasinoDB
extends RefCounted

## Pure toy-coin gambling maths for the Lucky Lily riverboat. There is no
## real money, no chip store and no connection to fish sales here: every
## game is a fixed, published payout table with a real house edge.
##
## Multipliers are inclusive of the returned stake, so 2X means "you get
## twice your stake back" (a net win of one stake). A 1X result is a push.

const BETS := [10, 25, 50, 100, 250, 500]

const GAMES := [
	{
		"id": "coin",
		"name": "SKIPPER'S COIN",
		"blurb": "CALL THE COIN",
		"odds": "HEADS OR TAILS - 48% CHANCE - PAYS 2X - HOUSE EDGE 4%",
	},
	{
		"id": "shells",
		"name": "PEARL SHELLS",
		"blurb": "PICK A SHELL",
		"odds": "1 OF 3 SHELLS - 30% CHANCE - PAYS 3X - HOUSE EDGE 10%",
	},
	{
		"id": "reel",
		"name": "LUCKY CATCH",
		"blurb": "SPIN THE REEL",
		"odds": "5% JACKPOT 5X - 8.3% 2X - 25% PUSH - 16.7% HALF - 41.7% MISS - HOUSE EDGE 8.3%",
	},
]

## Twelve equally likely reel stops. Duplicated labels are the weighting:
## five misses, two half-stake returns, three pushes, one 2X and one 5X.
const REEL_STOPS := [
	{"label": "MISS", "mult": 0.0},
	{"label": "HALF", "mult": 0.5},
	{"label": "PUSH", "mult": 1.0},
	{"label": "MISS", "mult": 0.0},
	{"label": "2X", "mult": 2.0},
	{"label": "MISS", "mult": 0.0},
	{"label": "PUSH", "mult": 1.0},
	{"label": "HALF", "mult": 0.5},
	{"label": "MISS", "mult": 0.0},
	{"label": "PUSH", "mult": 1.0},
	{"label": "JACKPOT", "mult": 5.0},
	{"label": "MISS", "mult": 0.0},
]


static func game(game_id: String) -> Dictionary:
	for entry in GAMES:
		if String(entry.get("id", "")) == game_id:
			return entry
	return GAMES[0]


static func reel_stops() -> Array:
	return REEL_STOPS.duplicate(true)


## Resolve one wager. `roll` is an optional [0, 1) value for tests; leave it
## negative to use the real RNG. Returns the multiplier including the stake,
## the rounded payout, whether the round made a net profit, a flavour detail
## and the reel index (-1 for games that are not the reel).
static func resolve(game_id: String, stake: int, choice: String, roll := -1.0) -> Dictionary:
	var wager := maxi(1, int(stake))
	var r := randf() if roll < 0.0 else clampf(float(roll), 0.0, 0.999999)
	var mult := 0.0
	var detail := ""
	var index := -1
	var landed := ""
	match game_id:
		"coin":
			var picked := "TAILS" if choice.to_upper().begins_with("TAIL") else "HEADS"
			var won := r < 0.48
			landed = picked if won else ("HEADS" if picked == "TAILS" else "TAILS")
			mult = 2.0 if won else 0.0
			detail = "THE COIN LANDS ON %s" % landed
		"shells":
			var picked := clampi(int(choice), 1, 3)
			var won := r < 0.30
			if won:
				landed = str(picked)
			else:
				# Pick a shell that was not the player's, deterministically
				# from the same roll so a fixed seed replays the same round.
				var shift := 1 + int(r * 10.0) % 2
				landed = str(((picked - 1 + shift) % 3) + 1)
			mult = 3.0 if won else 0.0
			detail = ("SHELL %s HIDES THE PEARL" % landed) if won else ("SHELL %s IS EMPTY" % landed)
		"reel":
			index = clampi(int(r * float(REEL_STOPS.size())), 0, REEL_STOPS.size() - 1)
			var stop: Dictionary = REEL_STOPS[index]
			mult = float(stop.get("mult", 0.0))
			landed = String(stop.get("label", "MISS"))
			detail = "THE REEL STOPS ON %s" % landed
		_:
			detail = "THE LILY DOES NOT KNOW THAT GAME"
	var payout := int(round(float(wager) * mult))
	return {
		"win": payout > wager,
		"multiplier": mult,
		"payout": payout,
		"stake": wager,
		"detail": detail,
		"index": index,
		"landed": landed,
	}
