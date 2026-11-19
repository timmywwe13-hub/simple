extends Node

## Persistent game state: coins, inventory, fish index, gear, quests.
## Saved to user://save.json via FileAccess store_var/get_var.
## Also owns the procedural audio player (see play_sound()).

var coins := 50
var inventory := []
var index := {}
var gear := {"rod": "rod_stick", "line": "line_nylon", "bait": "", "bucket": "bucket_small",
	"boat": "boat_raft"}
var owned_boats: Array = ["boat_raft"]
var unlocked_regions := ["pond"]
var active_bait_end := 0.0
var total_caught := 0
## True once a session is underway (the player started fishing or travelled).
## Used so returning from the Town resumes the fishing scene instead of
## showing the start screen again. Not saved - a fresh boot shows the menu.
var session_started := false

var audio_player: AudioStreamPlayer
var sfx_cache := {}

var SAVE_PATH := "user://save.json"
var AUTO_SAVE := true

var quests := [
	{"id": "first_catch", "title": "First Catch", "desc": "Catch any fish.", "done": false, "claimed": false,
	 "kind": "catch_any", "target": 1, "progress": 0, "reward": 30},
	{"id": "first_rare", "title": "Rare Find", "desc": "Catch a Rare fish.", "done": false, "claimed": false,
	 "kind": "catch_rarity", "target": "Rare", "progress": 0, "reward": 75},
	{"id": "collector", "title": "Collector", "desc": "Catch one of each pond species.", "done": false, "claimed": false,
	 "kind": "region_complete", "target": "pond", "progress": 0, "reward": 150},
	{"id": "seasoned", "title": "Seasoned Angler", "desc": "Catch 5 fish.", "done": false, "claimed": false,
	 "kind": "catch_any", "target": 5, "progress": 0, "reward": 60},
	{"id": "market_day", "title": "Market Day", "desc": "Sell 10 fish at the Fish Market.", "done": false, "claimed": false,
	 "kind": "sell_count", "target": 10, "progress": 0, "reward": 120},
	{"id": "seafarer", "title": "Seafarer", "desc": "Buy a real boat at the Boat Dealer.", "done": false, "claimed": false,
	 "kind": "own_boat", "target": 1, "progress": 0, "reward": 200},
]

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
		"quests": quests,
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_var(data)
		file.close()

func _load_game() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		_init_index()
		save_game()
		return
	var data: Dictionary = file.get_var()
	file.close()
	if typeof(data) != TYPE_DICTIONARY:
		_init_index()
		save_game()
		return
	coins = int(data.get("coins", 50))
	inventory = data.get("inventory", [])
	index = data.get("index", {})
	gear = data.get("gear", {"rod": "rod_stick", "line": "line_nylon", "bait": "",
		"bucket": "bucket_small", "boat": "boat_raft"})
	if not gear.has("boat"):
		gear["boat"] = "boat_raft"
	owned_boats = data.get("owned_boats", ["boat_raft"])
	unlocked_regions = data.get("unlocked_regions", ["pond"])
	total_caught = int(data.get("total_caught", 0))
	quests = data.get("quests", quests)
	_init_index()

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

func record_catch(fish_id: String, weight: float, region: String) -> void:
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
	inventory.append({"fish_id": fish_id, "weight": weight, "region": region, "caught_at": Time.get_ticks_msec()})
	total_caught += 1
	_check_quests("catch", fish_id)
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

## Sell every fish in the bucket. `mult` applies shop-side price bonuses
## (Fish Market premium) and the owned-boat value bonus.
func sell_all(mult: float = 1.0) -> int:
	var total := 0
	for item in inventory:
		var fid := String(item.get("fish_id", ""))
		var w := float(item.get("weight", 0.0))
		total += int(round(coin_value(fid, w) * mult))
	inventory.clear()
	add_coins(total)
	_check_quests("sell", "")
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
	var value := int(round(coin_value(fid, w) * mult))
	inventory.remove_at(index)
	add_coins(value)
	_check_quests("sell", "")
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
	match id:
		"bucket_small": return 12
		"bucket_med": return 24
		"bucket_large": return 48
		_: return 12

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

func buy_item(category: String, id: String) -> bool:
	var cost := _cost(category, id)
	if not can_afford(cost):
		return false
	if category == "rods":
		gear["rod"] = id
	elif category == "lines":
		gear["line"] = id
	elif category == "baits":
		gear["bait"] = id
	elif category == "buckets":
		gear["bucket"] = id
	ShopDB.set_owned(category, id, true)
	coins -= cost
	save_game()
	return true

func _cost(category: String, id: String) -> int:
	var d: Dictionary = ShopDB.item(category, id)
	return int(d.get("cost", 0))

func update_bait(_dt: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if active_bait_end > 0 and now > active_bait_end:
		gear["bait"] = ""
		active_bait_end = 0.0

func activate_bait(bait_id: String) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var d: Dictionary = ShopDB.item("baits", bait_id)
	active_bait_end = now + float(d.get("duration_sec", 60))
	gear["bait"] = bait_id

func _check_quests(kind: String, fish_id: String) -> void:
	for q in quests:
		if bool(q.get("done", false)):
			continue
		var qk := String(q.get("kind", ""))
		if qk == "catch_any" and kind == "catch":
			q["progress"] = int(q.get("progress", 0)) + 1
		elif qk == "catch_rarity" and kind == "catch":
			if rarity_of(fish_id) == String(q.get("target", "")):
				q["progress"] = int(q.get("progress", 0)) + 1
		elif qk == "region_complete" and kind == "catch":
			var r := String(q.get("target", ""))
			q["progress"] = int(region_percent(r) * float(FishDB.fish_by_region(r).size()))
		elif qk == "sell_count" and kind == "sell":
			q["progress"] = int(q.get("progress", 0)) + 1
		elif qk == "own_boat" and kind == "boat":
			q["progress"] = 1
		if int(q.get("progress", 0)) >= int(q.get("target", 1)):
			q["done"] = true

## Procedural SFX are baked once into AudioStreamWAV clips (a streaming
## generator playback leaks an ObjectDB instance at exit) and cached.
func _setup_audio() -> void:
	audio_player = AudioStreamPlayer.new()
	audio_player.autoplay = false
	add_child(audio_player)

func play_sound(sfx_name: String) -> void:
	if audio_player == null:
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
