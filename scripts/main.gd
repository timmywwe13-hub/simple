extends Node2D

const PixFont := preload("res://scripts/pixel_font.gd")
const ChangelogLib := preload("res://scripts/changelog.gd")
const TouchControls := preload("res://scripts/touch_controls.gd")
const RegionArt := preload("res://scripts/region_art.gd")
const AlmanacLib := preload("res://scripts/almanac_db.gd")

const STATE_MENU := 0
const STATE_WORLD := 1
const STATE_CAST := 2
const STATE_BITE := 3
const STATE_REEL := 4
const STATE_CAUGHT := 5
const STATE_INDEX := 6
const STATE_SHOP := 7
const STATE_STATS := 8
const STATE_PAUSED := 9
const STATE_UPDATES := 10
const STATE_SETTINGS := 11
const STATE_HARVEST := 12
const STATE_ALMANAC := 13

const WATER_RATIO := 0.60
## Height of the start screen card (eight menu buttons now).
const MENU_PANEL_H := 524.0
## How long a spot change crossfades its whole palette.
const ART_FADE := 0.8

## Fishing minigame balance, tuned for human reaction times: a generous
## hook window, a readable sweep on the timing bar, and a forgiving
## tug-of-war. The timing green picks one spot per fish and starts at 40%
## of the bar (every rod adds 4% width). Each hooked fish randomly gets
## either the timing minigame or the tug-of-war 50/50, regardless of
## species or rarity. The tug green starts at 44% and drifts slowly so the
## player has to follow it; rods and lines widen that band too.
const BITE_WINDOW := 2.2
const TIMING_SWEEP := 0.5
const TUG_BUILD := 0.55
const TUG_DECAY := 0.45
const TUG_BAND := 0.22
const TUG_GREEN_SPEED := 0.20
const TUG_HOLD := 1.2
const TUG_PEG := 0.8

## Forgiveness around the timing window. The press is judged against the
## marker exactly as it was last drawn, and this hair of grace covers
## input latency - clicking the green no longer randomly reads as a miss.
const TIMING_GRACE := 0.03

## Tug-of-war: a quick tap works like a short pump, so clicking in the
## green lands fish just like holding the button does.
const TUG_TAP_PUMP := 0.07
const TUG_TAP_PROGRESS := 0.45

## The Volt Serpent monster bites back when you pull it in: 5% of the
## time it shocks you (you lose a few coins and it escapes), otherwise
## it's yours to keep and sell.
const MONSTER_SHOCK_CHANCE := 0.05
const MONSTER_SHOCK_COST := 20

## Rare fish are harder to come by without bait bought at the shop: their
## bite odds are cut hard when fishing bare, and the matching bait instead
## boosts them (BAIT_BOOST). Bait is a consumable - one charge per cast.
const NO_BAIT_PENALTY := {"Rare": 0.45, "Epic": 0.30, "Legendary": 0.20}
const BAIT_BOOST := 2.2

var state := STATE_MENU
var region := "pond"

## --- Region art (v1.7) -----------------------------------------------
## `art` is the *resolved* palette the drawing code uses. On a spot
## change `art_from` freezes the old palette and it lerps into
## `art_target` over ART_FADE seconds, so the world changes as a whole.
var art: Dictionary = RegionArt.get_art("pond")
var art_from: Dictionary = {}
var art_target: Dictionary = {}
var art_t := 1.0
var water_wipe := 0.0
var art_waterline := WATER_RATIO
## Arrival banner (region name + flavour line + glyph).
var arrival_name := ""
var arrival_sub := ""
var arrival_glyph := "pond"
var arrival_t := 0.0
## Start-menu keyboard/gamepad selection.
var menu_sel := 0
## Fish Index 2.0 selection.
var index_selected := -1
var index_shown_ids: Array[String] = []
var index_detail: Control
var index_detail_scroll: ScrollContainer
var index_detail_content: Control
var index_detail_art: Control
var index_detail_name: Label
var index_detail_desc: Label
var index_detail_where: Label
var index_detail_stats: Label
var index_detail_region: Label
var index_detail_mastery: Label
var index_gold_label: Label
var index_detail_rarity: Label
var index_detail_fish: Dictionary = {}
var index_detail_caught := false
## Juice (v1.7).
var splashes: Array[Dictionary] = []
var ambient_particles: Array[Dictionary] = []
var ambient_spawn := 1.0
var coin_fly: Array[Dictionary] = []
var catch_card_t := 0.0
var saved_toast_t := 0.0
var settings_panel: Control
var pause_card: Control
var settings_content: Control
var settings_from_pause := false
var settings_sliders := {}
## Cached reticle target for touch taps (updated every world frame).
var aim_reticle := Vector2.ZERO

var cast_target := Vector2.ZERO
var bobber_pos := Vector2.ZERO
var bobber_home := Vector2.ZERO
var cast_travel := 0.0
var bite_timer := 0.0
var bite_delay := 0.0
var hooked := false
var bite_reaction_left := 0.0
var reel_active := false
var reel_pos := 0.5
var reel_dir := 1.0
var reel_hold := false
var reel_tension := 0.5
var tug_center := 0.5
var tug_dir := 1.0
var tug_ok_time := 0.0
var tug_peg_time := 0.0
var catch_fish_id := ""
var catch_weight := 0.0
var catch_new := false
var catch_rarity := ""
var catch_coins := 0
var catch_perfect := false
## True when this fish's reel uses the tug-of-war instead of the timing bar.
## Rolled 50/50 after the hook lands, so either fish can use either mode.
var tug_fight := false
## Bait used for the current cast ("" = fishing bare, caught via
## GameState.consume_bait() when the cast starts).
var cast_bait := ""
var shake := 0.0
var flash := 0.0
var msg_timer := 0.0
var msg_text := ""
var day_time := 0.63
var is_night := false

## Weather: "clear", "rain" or "storm". It rolls in on its own timer and
## decides which fish bite (see FishDB.fish_pool) and how fast they do.
var weather := "clear"
var weather_next := "clear"
var weather_timer := 45.0
var lightning_timer := 6.0
var lightning_flash := 0.0
var lightning_x := 480.0
## Red screen tint after a monster shock (decays like `flash`).
var hurt_flash := 0.0

var view_size := Vector2(960.0, 540.0)
var water_line := 324.0
var bank_w := 403.0
var bank_top := 314.0
var fisher_x := 351.0
var rod_tip := Vector2(425.0, 236.0)
var mouse_pos := Vector2.ZERO
var menu_buttons: Array = []
var tunnel: Tunnel
var walk_phase := 0.0
var walking := false
var fisher_speed := 150.0
## Smooth walking: velocity eases up/down, facing follows it, and the
## boots leave little dust puffs on the bank.
var walk_vel := 0.0
var walk_ratio := 0.0
var fisher_facing := 1.0
var last_step := 0
var dust: Array[Dictionary] = []
var ambient_fish: Array[Dictionary] = []
var key_prev := {}
var hover_button := -1
## True when the Fish Index was opened from the fishing scene (I key or
## the touch INDEX button) so BACK returns to the water, not the menu.
var index_from_world := false

## Gear toggles: R takes the fishing rod out / puts it away, B boards the
## equipped boat from the shore (or lands it again near the shore).
var rod_out := true
var in_boat := false
var boat_pos := Vector2.ZERO
## True while sailing the open-water section past the edge of a spot.
var open_water := false
## The open sea is one connected route with three distinct zones. Sailing
## east at the edge moves one zone deeper; sailing west moves back toward
## shore. Zone 0 is the original Open Water.
const OPEN_ZONES := [
	{"id": "open", "name": "OPEN WATER", "tagline": "NOTHING BUT SWELL AND HORIZON",
		"fish_zone": ""},
	{"id": "open_kelp", "name": "KELP SHELF", "tagline": "GOLDEN WEEDS AND SHALLOW REEFS",
		"fish_zone": "kelp"},
	{"id": "open_trench", "name": "MIDNIGHT TRENCH", "tagline": "COLD DARK WATER AND OLD WRECKS",
		"fish_zone": "trench"},
]
var open_zone := 0
var season_art_state := ""
var harvest_award_t := 0.0
## The spot we sailed away from, restored when we sail back west.
var open_water_from := "pond"
## Coconut Isle is a separate shore with palms, island fish and crafting.
var is_island := false
var axe_out := false
var palms: Array[Dictionary] = []
const PALM_COUNT := 4

## On-screen touch controls (phones/tablets); null-safe everywhere.
var touch_controls: TouchControls

var ui_layer: CanvasLayer
var index_panel: Control
var shop_panel: Control
var index_list: ItemList
var index_comp_label: Label
var index_filter_btn: Button
var index_uncaught_btn: Button
var index_filter_region := ""
var index_only_uncaught := false
var shop_content: VBoxContainer
var shop_scroll: ScrollContainer
## Scroll offset kept across shop rebuilds so buying near the bottom of
## the list no longer snaps the panel back to the top.
var shop_scroll_pos := 0
var shop_from_pause := false
var stats_panel: Control
var stats_label: Label
## The Angler's Almanac full-screen reference (v1.10).
var almanac_panel: Control
var almanac_scroll: ScrollContainer
var almanac_body: VBoxContainer
var almanac_rank_label: Label
var almanac_next_label: Label
var almanac_bar: ProgressBar
var almanac_gold_label: Label
var almanac_grid: GridContainer
var almanac_grid_labels := {}
var almanac_board_box: VBoxContainer
var almanac_records_label: Label
var almanac_notes_label: Label
var almanac_from_pause := false
var almanac_from_world := false
var stats_mute_btn: Button
var pause_panel: Control
var pause_mute_btn: Button
var paused_from := STATE_WORLD
var updates_panel: Control
var updates_body: VBoxContainer
var updates_from_pause := false
var settings_fs_btn: Button
var settings_motion_btn: Button
var settings_touch_btn: Button
var settings_quality_btn: Button
var settings_reset_btn: Button
var settings_reset_confirm := false


func _ready() -> void:
	ui_layer = CanvasLayer.new()
	ui_layer.name = "UI"
	add_child(ui_layer)
	get_viewport().size_changed.connect(_relayout)
	_relayout()
	touch_controls = TouchControls.new()
	add_child(touch_controls)
	touch_controls.setup("fishing")
	GameState.saved.connect(_on_saved)
	GameState.coins_gained.connect(_on_coins_gained)
	GameState.harvest_boat_awarded.connect(_on_harvest_boat_awarded)
	get_tree().auto_accept_quit = false
	_init_art()
	_spawn_tunnel()
	_build_index()
	_build_shop()
	_build_stats()
	_build_pause()
	_build_updates()
	_build_settings()
	_build_almanac()
	GameState.mastery_ranked.connect(_on_mastery_ranked)
	_build_ambient_fish()
	weather_next = _roll_weather()
	if GameState.session_started:
		_on_start()
	else:
		show_menu()


## Start from this region's palette (no crossfade on boot) and remember
## the horizon ratio the rest of the layout math depends on.
func _season_id() -> String:
	return "harvest" if GameState.harvest_season_open() else ""


func _init_art() -> void:
	season_art_state = _season_id()
	art_target = RegionArt.get_art(region, season_art_state)
	art = art_target.duplicate(true)
	art_from = art_target.duplicate(true)
	art_t = 1.0
	art_waterline = float(art.get("waterline", WATER_RATIO))


## Kick off a full-palette crossfade plus the water wipe. Everything that
## follows - sky, water, mountains, bank, props - reads the blended art.
func _set_region(key: String) -> void:
	if key == region and art_t >= 1.0:
		return
	region = key
	art_from = art.duplicate(true)
	art_target = RegionArt.get_art(key, _season_id())
	art_t = 0.0
	water_wipe = 1.0
	arrival_name = String(art_target.get("name", key.to_upper()))
	arrival_sub = String(art_target.get("tagline", ""))
	arrival_glyph = String(art_target.get("glyph", "pond"))
	arrival_t = 4.5
	_build_ambient_fish()
	_setup_palms()


func _update_art(dt: float) -> void:
	if art_t < 1.0:
		art_t = minf(1.0, art_t + dt / ART_FADE)
		var e := smoothstep(0.0, 1.0, art_t)
		art = RegionArt.mix(art_from, art_target, e)
		var ratio := float(art.get("waterline", art_waterline))
		if absf(ratio - art_waterline) > 0.0005:
			art_waterline = ratio
			_relayout_water()
	if water_wipe > 0.0:
		water_wipe = maxf(0.0, water_wipe - dt * 1.35)
	if arrival_t > 0.0:
		arrival_t = maxf(0.0, arrival_t - dt)


func _relayout_water() -> void:
	water_line = floor(view_size.y * art_waterline)
	bank_w = view_size.x * 0.42
	bank_top = water_line - 10.0
	fisher_x = clampf(fisher_x, 30.0, bank_w - 40.0)
	rod_tip = Vector2(fisher_x + 74.0, floor(bank_top - 78.0))
	if tunnel:
		tunnel.position = Vector2(30.0, bank_top + 1.5)
	_build_ambient_fish()
	if is_island:
		_setup_palms()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		GameState.flush_save()
		get_tree().quit()
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		GameState.flush_save()
		if state == STATE_WORLD or state == STATE_CAST or state == STATE_BITE \
				or state == STATE_REEL:
			_open_pause()


func _relayout() -> void:
	view_size = get_viewport_rect().size
	_layout_settings_content()
	_layout_pause_card()
	water_line = floor(view_size.y * art_waterline)
	bank_w = view_size.x * 0.42
	bank_top = water_line - 10.0
	fisher_x = bank_w - 52.0
	rod_tip = Vector2(fisher_x + 74.0, floor(bank_top - 78.0))
	if tunnel:
		tunnel.position = Vector2(30.0, bank_top + 1.5)
	if touch_controls:
		touch_controls.relayout()
	# The waterline moves with the window, so rebuild the ambient fish -
	# they used to keep their old height and drift into the sky whenever
	# the viewport grew (browser canvas settling, window resize).
	_build_ambient_fish()
	if is_island:
		_setup_palms()


## Tunnel to the Town scene at the left end of the bank. The fisher has no
## physics body, so main.gd polls proximity_check() while walking.
func _spawn_tunnel() -> void:
	tunnel = Tunnel.new()
	tunnel.name = "Tunnel"
	tunnel.sign = "TOWN"
	tunnel.position = Vector2(30.0, bank_top + 1.5)
	add_child(tunnel)


func _open_zone_data() -> Dictionary:
	return OPEN_ZONES[clampi(open_zone, 0, OPEN_ZONES.size() - 1)]


func _open_zone_fish_tag() -> String:
	return String(_open_zone_data().get("fish_zone", ""))


## The pool for the current water. Open-water zones share the base "open"
## region and add their own zone-tagged fish on top.
func _fish_pool_here() -> Array[Dictionary]:
	if open_water:
		return FishDB.fish_pool("open", weather, is_night, _season_id(), _open_zone_fish_tag())
	return FishDB.fish_pool(region, weather, is_night, _season_id())


func _build_ambient_fish() -> void:
	ambient_fish.clear()
	var pool := _fish_pool_here()
	if pool.size() == 0:
		pool = FishDB.fish_pool("pond", weather, is_night, _season_id())
	var count := 7
	var q := GameState.quality_level()
	if q == 0:
		count = 4
	elif q == 1:
		count = 6
	for i in range(count):
		var data: Dictionary = pool[i % pool.size()]
		var depth_t := float(i) / float(count)
		ambient_fish.append({
			"fish": data,
			"x": randf_range(0.0, view_size.x),
			"speed": randf_range(18.0, 46.0),
			"dir": 1.0 if randf() > 0.5 else -1.0,
			"phase": randf_range(0.0, 6.28),
			"amp": randf_range(4.0, 14.0),
			"y": water_line + 64.0 + depth_t * (view_size.y - water_line) * 0.5,
			"scale": randf_range(11.0, 18.0),
			"flip": randf_range(0.4, 1.4),
		})


var key_edges := {}

## Touch button ids polled alongside the keyboard keys in _key_edge().
const TOUCH_KEY_TAPS := {KEY_R: "rod", KEY_B: "boat", KEY_I: "index", KEY_G: "axe",
		KEY_P: "line", KEY_1: "spot1", KEY_2: "spot2", KEY_3: "spot3", KEY_4: "spot4"}

## Testing cheat: typing 2222 on the number-row keys unlocks the whole game
## (see GameState.grant_everything). The digits double as the spot keys, so
## the spot that was open when the code started is restored afterwards.
var cheat_region := "pond"
var cheat_fired := false


func _key_tick() -> void:
	key_edges = {}
	cheat_fired = false
	for code in [KEY_1, KEY_2, KEY_3, KEY_4, KEY_B, KEY_R, KEY_I, KEY_G, KEY_E, KEY_P,
			KEY_F11, KEY_0, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9]:
		var now := Input.is_physical_key_pressed(code)
		var was: bool = bool(key_prev.get(code, false))
		key_prev[code] = now
		key_edges[code] = now and not was
	_track_cheat_code()


## Collect typed digits into GameState's shared buffer; the code in it fires
## the unlock. Kept to the physical keyboard so touch spot buttons never
## trip it.
func _track_cheat_code() -> void:
	for code in [KEY_0, KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9]:
		if not bool(key_edges.get(code, false)):
			continue
		# first digit of the code: remember the spot to come back to
		if GameState.cheat_buffer == "":
			cheat_region = region
		if GameState.cheat_digit(code - KEY_0):
			_run_cheat()


func _run_cheat() -> void:
	GameState.grant_everything()
	cheat_fired = true
	# the code is typed on the spot keys - put the spot back where it was
	if not is_island and not open_water:
		_set_region(cheat_region)
		_build_ambient_fish()
		_setup_palms()
	if state == STATE_SHOP:
		_refresh_shop()
	elif state == STATE_INDEX:
		_refresh_index()
	elif state == STATE_STATS:
		_refresh_stats()
	fx_flash(1.0)
	GameState.play_sound("rare")
	msg("CHEAT ACCEPTED - EVERYTHING UNLOCKED")
	print("CHEAT ACCEPTED - everything unlocked")


func _process(dt: float) -> void:
	_key_tick()
	# A season opening/closing mid-session crossfades the world palette in
	# the same way a region change does.
	if _season_id() != season_art_state:
		season_art_state = _season_id()
		art_from = art.duplicate(true)
		art_target = RegionArt.get_art(region, season_art_state)
		art_t = 0.0
		water_wipe = 1.0
		_build_ambient_fish()
	_update_art(dt)
	mouse_pos = get_viewport().get_mouse_position()
	if _key_edge(KEY_F11):
		GameState.toggle_fullscreen()
	if touch_controls != null:
		touch_controls.sync_settings()
	GameState.set_music(_music_region(), is_night)
	GameState.set_ambience_region(_music_region(), is_night)
	if saved_toast_t > 0.0:
		saved_toast_t = maxf(0.0, saved_toast_t - dt)
	if catch_card_t < 1.0:
		catch_card_t = minf(1.0, catch_card_t + dt * 4.2)
	if harvest_award_t > 0.0:
		harvest_award_t = maxf(0.0, harvest_award_t - dt)
	_update_splashes(dt)
	_update_coin_fly(dt)
	_update_ambient_particles(dt)

	if state == STATE_PAUSED:
		if Input.is_action_just_pressed("ui_cancel"):
			_resume_game()
		if touch_controls != null:
			touch_controls.set_context("hidden")
		queue_redraw()
		return

	if state == STATE_HARVEST:
		# The Harvest board is a Control overlay with its own input and
		# close handling; the world underneath just keeps breathing.
		if touch_controls != null:
			touch_controls.set_context("hidden")
		queue_redraw()
		return

	day_time = fposmod(day_time + dt * 0.02, 1.0)
	var was_night := is_night
	# Harvest dusk arrives ~2 in-game hours earlier and sunrise is later.
	var dusk_shift := 0.083 if GameState.harvest_season_open() else 0.0
	is_night = day_time > 0.75 - dusk_shift or day_time < 0.25 + dusk_shift
	if was_night != is_night:
		_build_ambient_fish()
	_update_weather(dt)

	if shake > 0.0:
		shake = maxf(0.0, shake - dt * 3.5)
	if flash > 0.0:
		flash = maxf(0.0, flash - dt * 2.5)
	if hurt_flash > 0.0:
		hurt_flash = maxf(0.0, hurt_flash - dt * 2.2)
	if msg_timer > 0.0:
		msg_timer = maxf(0.0, msg_timer - dt)
		if msg_timer == 0.0:
			msg_text = ""

	GameState.update_bait(dt)
	_update_dust(dt)

	match state:
		STATE_MENU:
			_update_menu()
		STATE_WORLD:
			_update_world(dt)
		STATE_CAST:
			_update_cast(dt)
		STATE_BITE:
			_update_bite(dt)
		STATE_REEL:
			_update_reel(dt)
		STATE_INDEX:
			_update_index_selection()
		STATE_CAUGHT:
			if _pressed():
				_on_catch_continue()

	if Input.is_action_just_pressed("ui_cancel"):
		if state == STATE_WORLD or state == STATE_CAST or state == STATE_BITE or state == STATE_REEL:
			_open_pause()
		else:
			_on_back()
	elif _touch_tap("menu"):
		if state == STATE_WORLD or state == STATE_CAST or state == STATE_BITE or state == STATE_REEL:
			_open_pause()
		else:
			_on_back()

	if touch_controls != null:
		touch_controls.set_context(_touch_context())
		touch_controls.set_action_label(_touch_action_label())

	_update_ambient(dt)
	queue_redraw()


func _music_region() -> String:
	if is_island:
		return "island"
	if open_water:
		return "open"
	return region


func _on_harvest_boat_awarded() -> void:
	# The board owns its own award reveal; only show the in-world card when
	# the legendary catch completes the album outside the feast board.
	if state == STATE_HARVEST:
		return
	harvest_award_t = 8.0
	fx_flash(1.0)
	msg("THE HARVEST QUEEN JOINS YOUR FLEET!")


func _on_saved() -> void:
	saved_toast_t = 1.8


## Gold coins flying from the sale to the HUD coin counter.
func _on_coins_gained(amount: int) -> void:
	if amount <= 0:
		return
	var n := clampi(3 + int(log(float(amount) + 1.0)), 3, 9)
	for i in range(n):
		var start := view_size * 0.5 + Vector2(randf_range(-70.0, 70.0), randf_range(10.0, 80.0))
		coin_fly.append({
			"from": start,
			"pos": start,
			"t": 0.0,
			"delay": float(i) * 0.05,
			"sweep": randf_range(-120.0, 120.0),
		})


func _update_coin_fly(dt: float) -> void:
	var target := Vector2(view_size.x - 34.0, 28.0)
	for i in range(coin_fly.size() - 1, -1, -1):
		var c: Dictionary = coin_fly[i]
		if float(c["delay"]) > 0.0:
			c["delay"] = float(c["delay"]) - dt
			continue
		c["t"] = minf(1.0, float(c["t"]) + dt * 1.8)
		var t: float = float(c["t"])
		var p: Vector2 = (c["from"] as Vector2).lerp(target, t)
		p.y -= sin(t * PI) * 90.0
		p.x += float(c["sweep"]) * sin(t * PI)
		c["pos"] = p
		if t >= 1.0:
			coin_fly.remove_at(i)


## Splash rings + droplets at the bobber (cast landing, hook, catch).
func _spawn_splash(pos: Vector2, strength := 1.0) -> void:
	if GameState.reduce_motion() and strength < 0.7:
		return
	splashes.append({"pos": pos, "life": 0.0, "max": 0.9, "strength": strength})
	if splashes.size() > 12:
		splashes.remove_at(0)


func _update_splashes(dt: float) -> void:
	for i in range(splashes.size() - 1, -1, -1):
		var s: Dictionary = splashes[i]
		s["life"] = float(s["life"]) + dt
		if float(s["life"]) >= float(s["max"]):
			splashes.remove_at(i)


## Region-appropriate ambient particles: fireflies / lily bugs / gulls /
## spray / mist. Capped hard and disabled at the low quality tier.
func _update_ambient_particles(dt: float) -> void:
	for i in range(ambient_particles.size() - 1, -1, -1):
		var p: Dictionary = ambient_particles[i]
		if GameState.reduce_motion() and String(p.get("kind", "")) == "leaf":
			ambient_particles.remove_at(i)
			continue
		p["life"] = float(p["life"]) - dt
		p["pos"] = (p["pos"] as Vector2) + (p["vel"] as Vector2) * dt
		if float(p["life"]) <= 0.0:
			ambient_particles.remove_at(i)
	if state == STATE_MENU or state == STATE_INDEX or state == STATE_SETTINGS \
			or state == STATE_STATS or state == STATE_UPDATES or state == STATE_SHOP:
		return
	var q := GameState.quality_level()
	if q == 0:
		return
	ambient_spawn -= dt
	if ambient_spawn > 0.0:
		return
	ambient_spawn = randf_range(0.35, 1.1) if q >= 2 else randf_range(0.8, 2.0)
	var kinds: Array = art.get("ambient", []).duplicate()
	if GameState.harvest_season_open() and not GameState.reduce_motion():
		kinds.append("leaf")
		kinds.append("leaf")
	if kinds.is_empty():
		return
	var kind := String(kinds[randi() % kinds.size()])
	if kind == "spray" and q < 2:
		return
	if kind == "firefly" and not is_night:
		kind = "dragonfly"
	if kind == "mist" and not bool(art.get("mist", false)):
		kind = "firefly" if is_night else "dragonfly"
	if kind == "spray" and not bool(art.get("spray", false)):
		kind = "dragonfly"
	_spawn_particle(kind)
	if ambient_particles.size() > (14 if q >= 2 else 7):
		ambient_particles.remove_at(0)


func _spawn_particle(kind: String) -> void:
	var pos := Vector2.ZERO
	var vel := Vector2.ZERO
	var life := 3.0
	match kind:
		"firefly":
			pos = Vector2(randf_range(0.0, view_size.x), randf_range(water_line * 0.55, water_line - 10.0))
			vel = Vector2(randf_range(-12.0, 12.0), randf_range(-9.0, 9.0))
			life = randf_range(3.0, 6.0)
		"dragonfly":
			pos = Vector2(randf_range(0.0, view_size.x), randf_range(water_line * 0.5, water_line - 8.0))
			vel = Vector2(randf_range(20.0, 46.0), randf_range(-8.0, 8.0))
			life = randf_range(2.5, 4.5)
		"gull":
			var from_left := randf() > 0.5
			pos = Vector2(-20.0 if from_left else view_size.x + 20.0,
					randf_range(40.0, water_line * 0.7))
			vel = Vector2(randf_range(30.0, 55.0) * (1.0 if from_left else -1.0),
					randf_range(-6.0, 6.0))
			life = 9.0
		"mist":
			pos = Vector2(randf_range(0.0, view_size.x), water_line - randf_range(2.0, 18.0))
			vel = Vector2(randf_range(4.0, 12.0), randf_range(-2.0, 2.0))
			life = randf_range(4.0, 7.0)
		"spray":
			pos = Vector2(randf_range(bank_w + 20.0, view_size.x - 20.0), water_line + randf_range(4.0, 30.0))
			vel = Vector2(randf_range(-8.0, 8.0), randf_range(-22.0, -6.0))
			life = randf_range(0.5, 1.1)
		"leaf":
			pos = Vector2(randf_range(-20.0, view_size.x + 20.0), randf_range(-30.0, water_line * 0.7))
			vel = Vector2(randf_range(14.0, 42.0), randf_range(16.0, 40.0))
			life = randf_range(5.0, 10.0)
		_:
			return
	ambient_particles.append({"kind": kind, "pos": pos, "vel": vel, "life": life,
			"max": life, "seed": randf_range(0.0, TAU)})


func _key_edge(code: int) -> bool:
	if touch_controls != null and TOUCH_KEY_TAPS.has(code) \
			and touch_controls.consume_tap(String(TOUCH_KEY_TAPS[code])):
		return true
	return bool(key_edges.get(code, false))


## Left/right axis from keyboard *and* the analog thumb-stick.
func _move_x() -> float:
	var v := Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	if touch_controls != null:
		v = clampf(v + touch_controls.stick.x, -1.0, 1.0)
	return v


func _pressed() -> bool:
	if _touch_tap("action") or Input.is_action_just_pressed("ui_accept"):
		return true
	return Input.is_action_just_pressed("click") and not _click_blocked()


## True while a virtual touch button sits under the mouse/touch position,
## so its emulated click never counts as a cast / hook / reel press.
func _click_blocked() -> bool:
	return touch_controls != null and touch_controls.blocks_click(mouse_pos)


func _touch_tap(id: String) -> bool:
	return touch_controls != null and touch_controls.consume_tap(id)


func _touch_context() -> String:
	match state:
		STATE_WORLD:
			return "world"
		STATE_CAST, STATE_BITE:
			return "fishing"
		STATE_REEL:
			return "reel"
		STATE_PAUSED, STATE_UPDATES, STATE_SETTINGS:
			return "hidden"
		_:
			return "hidden"


func _touch_action_label() -> String:
	if is_island and axe_out and state == STATE_WORLD:
		return "CHOP"
	match state:
		STATE_BITE:
			return "HOOK"
		STATE_REEL:
			return "HOLD" if _is_tug_fight() else "REEL"
		_:
			return "CAST"


func _night_factor() -> float:
	return clampf(absf(day_time - 0.5) * 2.0, 0.0, 1.0)


func _weather_label() -> String:
	return _weather_name(weather)

func _weather_name(w: String) -> String:
	match w:
		"rain": return "RAIN"
		"storm": return "THUNDERSTORM"
		_: return "CLEAR"

func _roll_weather() -> String:
	var roll := randf()
	if roll > 0.78:
		return "storm"
	if roll > 0.45:
		return "rain"
	return "clear"


## Weather rolls in and out on a timer: the next front is picked ahead of
## time so the HUD can forecast it. Storms bring lightning (flash + thunder)
## and both rains change which fish are biting.
func _update_weather(dt: float) -> void:
	weather_timer -= dt
	if weather_timer <= 0.0:
		var next := weather_next
		weather_next = _roll_weather()
		weather_timer = randf_range(35.0, 80.0)
		if next != weather:
			weather = next
			GameState.play_sound("ui")
			match weather:
				"rain":
					msg("RAIN ROLLS IN - DIFFERENT FISH ARE BITING")
				"storm":
					msg("THUNDERSTORM! STORM FISH ARE ON THE MOVE")
				_:
					msg("THE SKY CLEARS - NEXT: %s" % _weather_name(weather_next))
			_build_ambient_fish()
	if weather == "storm":
		lightning_timer -= dt
		if lightning_timer <= 0.0:
			lightning_timer = randf_range(5.0, 12.0)
			if not GameState.reduce_motion():
				lightning_flash = 1.0
			lightning_x = randf_range(view_size.x * 0.15, view_size.x * 0.85)
			GameState.play_sound("thunder")
	if lightning_flash > 0.0:
		lightning_flash = maxf(0.0, lightning_flash - dt * 2.6)


## Storm gloom, slanted rain streaks, splashes on the water and the
## lightning bolt + flash. Drawn over the world, under the HUD.
func _draw_weather(t: float) -> void:
	var strength := 0.0
	match weather:
		"rain": strength = 0.55
		"storm": strength = 1.0
	if strength <= 0.0 and lightning_flash <= 0.0:
		return
	var full := Rect2(-60.0, -60.0, view_size.x + 120.0, view_size.y + 120.0)
	if strength > 0.0:
		draw_rect(full, Color(0.12, 0.16, 0.28, 0.24 * strength))
		var drops := int(70.0 * strength)
		var wind := 0.35 + strength * 0.35
		for i in range(drops):
			var sx := fposmod(float(i) * 149.0 + t * (60.0 + float(i % 5) * 12.0),
					view_size.x + 160.0) - 80.0
			var sy := fposmod(float(i) * 271.0 + t * (620.0 + float(i % 7) * 70.0),
					view_size.y + 120.0) - 60.0
			var drop_len := 15.0 + strength * 17.0 + float(i % 3) * 6.0
			draw_line(Vector2(sx, sy), Vector2(sx - drop_len * wind, sy + drop_len),
					Color(0.72, 0.83, 1.0, 0.16 + strength * 0.24), 2.0)
		for i in range(int(18.0 * strength)):
			var rx := fposmod(float(i) * 97.0 + t * 40.0, view_size.x)
			var ry := water_line + fposmod(float(i) * 53.0 + t * 18.0,
					maxf(1.0, view_size.y - water_line))
			draw_line(Vector2(rx, ry), Vector2(rx + 8.0, ry),
					Color(0.8, 0.9, 1.0, 0.14 + strength * 0.16), 2.0)
	if lightning_flash > 0.0:
		draw_rect(full, Color(0.85, 0.9, 1.0, lightning_flash * 0.42))
		if lightning_flash > 0.55:
			# jagged bolt; its shape is fixed per strike, so it only fades
			var pts := PackedVector2Array()
			var bx := lightning_x
			var by := -10.0
			pts.append(Vector2(bx, by))
			var step := (water_line + 20.0) / 7.0
			for i in range(7):
				by += step
				bx += sin(float(i) * 2.7 + lightning_x * 0.11) * 30.0
				pts.append(Vector2(bx, by))
			var bolt := Color(1.0, 1.0, 0.88, (lightning_flash - 0.55) * 1.8)
			for i in range(pts.size() - 1):
				draw_line(pts[i], pts[i + 1], Color(1.0, 1.0, 1.0, bolt.a * 0.45), 7.0)
				draw_line(pts[i], pts[i + 1], bolt, 3.0)


func _update_menu() -> void:
	menu_buttons = _menu_button_rects()
	var up := Input.is_action_just_pressed("move_up") or Input.is_action_just_pressed("ui_up")
	var down := Input.is_action_just_pressed("move_down") or Input.is_action_just_pressed("ui_down")
	if up or down:
		menu_sel = (menu_sel + (-1 if up else 1) + menu_buttons.size()) % menu_buttons.size()
		GameState.play_sound("ui")
	hover_button = -1
	for i in range(menu_buttons.size()):
		var b := menu_buttons[i]["rect"] as Rect2
		if b.has_point(mouse_pos):
			hover_button = i
			menu_sel = i
	if hover_button < 0:
		hover_button = clampi(menu_sel, 0, menu_buttons.size() - 1)
	if not _pressed():
		return
	var pick := menu_sel
	if _clicked_on_menu():
		pick = _menu_button_at(mouse_pos)
		if pick < 0:
			return
	elif not Input.is_action_just_pressed("ui_accept"):
		return
	if pick < 0 or pick >= menu_buttons.size():
		return
	GameState.play_sound("ui")
	match String(menu_buttons[pick]["id"]):
		"start": _on_start()
		"index": _on_index()
		"shop": _on_shop()
		"harvest": _on_harvest_board()
		"stats": _on_stats()
		"settings": _on_settings()
		"updates": _on_updates()
		"almanac": _on_almanac()


func _clicked_on_menu() -> bool:
	return Input.is_action_just_pressed("click") and not _click_blocked()


func _menu_button_at(pos: Vector2) -> int:
	for i in range(menu_buttons.size()):
		if (menu_buttons[i]["rect"] as Rect2).has_point(pos):
			return i
	return -1


func _update_world(dt: float) -> void:
	if _key_edge(KEY_R):
		rod_out = not rod_out
		if rod_out:
			axe_out = false
		GameState.play_sound("ui")
		msg("ROD READY - SPACE OR CLICK TO CAST" if rod_out else "ROD PUT AWAY - PRESS R TO TAKE IT OUT")
	if _key_edge(KEY_B):
		_toggle_boat()
	if _key_edge(KEY_P):
		_set_line_action()
	if in_boat:
		_update_boat(dt)
	else:
		_update_walk(dt)
	if is_island:
		if _key_edge(KEY_G):
			if GameState.has_axe:
				axe_out = not axe_out
				rod_out = not axe_out
				GameState.play_sound("ui")
				msg("AXE READY - E OR CLICK CHOPS A NEARBY PALM" if axe_out else "ROD READY - SPACE TO CAST")
			else:
				GameState.play_sound("buzz")
				msg("BUY AN AXE IN THE SHOP TO CHOP PALMS")
		if _key_edge(KEY_E):
			_chop_nearest_palm()
	var move_right := Input.get_action_strength("move_right") > 0.1
	var move_left := Input.get_action_strength("move_left") > 0.1
	# sailing east from the Deep Sea reaches Coconut Isle; every other shore
	# opens into the three-zone open-water route
	if not is_island and in_boat and not open_water and boat_pos.x >= view_size.x - 20.0 and move_right:
		if region == "ocean":
			_enter_island()
		else:
			_enter_open_water()
	elif open_water and move_right and boat_pos.x >= view_size.x - 20.0:
		if open_zone < OPEN_ZONES.size() - 1:
			_change_open_zone(1)
	elif open_water and move_left and boat_pos.x <= 20.0:
		if open_zone > 0:
			_change_open_zone(-1)
		else:
			_exit_open_water()
	if _key_edge(KEY_I):
		_on_index(true)
		# opening the index ends this frame's world update, so a click made
		# with the same press can never start a cast behind the panel
		return
	# gamepad shoulder buttons cycle spots (touch/keyboard still use 1-4)
	var spot_delta := 0
	if Input.is_action_just_pressed("spot_next"):
		spot_delta = 1
	elif Input.is_action_just_pressed("spot_prev"):
		spot_delta = -1
	if spot_delta != 0 and not open_water and not is_island:
		_cycle_spot(spot_delta)
	for i in range(4):
		if not _key_edge(KEY_1 + i):
			continue
		# the cheat code is typed on the spot keys - ignore its digits
		if cheat_fired:
			continue
		if open_water or is_island:
			msg("RETURN TO SHORE TO CHANGE SPOTS")
			GameState.play_sound("buzz")
			continue
		var target: String = ["pond", "river", "lake", "ocean"][i]
		if target == "ocean" and not GameState.has_seaworthy_boat():
			msg("THE DEEP SEA NEEDS A REAL BOAT - VISIT THE BOAT DEALER")
			GameState.play_sound("buzz")
		elif GameState.unlocked_regions.has(target):
			_set_region(target)
			GameState.play_sound("ui")
			msg("%s - %s" % [RegionArt.display(region), RegionArt.tagline(region)])
		else:
			msg("Locked: %s costs %d coins." % [FishDB.REGION_DISPLAY.get(target, target),
					int(FishDB.REGION_UNLOCK_COST.get(target, 0))])
			GameState.play_sound("buzz")

	var cast_min_x := 40.0 if open_water else bank_w + 40.0
	cast_target = Vector2(clampf(mouse_pos.x, cast_min_x, view_size.x - 24.0), water_line)
	# Read the press once: the touch ACTION tap is consumed when polled, so
	# polling it twice in a frame would eat a cast.
	var pressed := _pressed()
	if pressed and axe_out:
		_chop_nearest_palm()
		return
	if pressed:
		if not rod_out:
			msg("TAKE OUT YOUR ROD FIRST - PRESS R")
			GameState.play_sound("buzz")
		elif GameState.inventory_count() >= GameState.bucket_capacity():
			msg("BUCKET FULL - SELL FISH IN THE SHOP")
			GameState.play_sound("buzz")
		else:
			_cast_start()


## P (or the touch LINE button) sets, checks or collects the line at the
## current bank. Open water and Coconut Isle have no bank to drive a post
## into, and a full bucket leaves the fish waiting on the hook.
func _set_line_action() -> void:
	if open_water or region.begins_with("open_"):
		msg("SET LINES NEED A BANK - POND, RIVER, LAKE OR DEEP SEA")
		GameState.play_sound("buzz")
		return
	if is_island:
		msg("LINES CANNOT BE SET ON COCONUT ISLE")
		GameState.play_sound("buzz")
		return
	if in_boat:
		msg("STEP OFF THE BOAT TO SET A LINE")
		GameState.play_sound("buzz")
		return
	if GameState.set_lines.has(region):
		if not GameState.line_ready(region):
			var left := GameState.line_seconds_left(region)
			msg("LINE IN THE WATER - %d:%02d TO GO" % [left / 60, left % 60])
			GameState.play_sound("ui")
			return
		var res := GameState.collect_line(region, weather, is_night)
		if not bool(res.get("ok", false)):
			match String(res.get("reason", "")):
				"full": msg("BUCKET FULL - THE LINE WILL WAIT")
				"empty_pool": msg("NOTHING IS BITING HERE RIGHT NOW")
				_: msg("THE LINE IS NOT READY YET")
			GameState.play_sound("buzz")
			return
		var tail := " - BAIT SAVED" if bool(res.get("bait_back", false)) else ""
		msg("%s ON THE LINE! %.2f KG%s" % [String(res.get("name", "FISH")).to_upper(),
				float(res.get("weight", 0.0)), tail])
		fx_flash(0.55)
		return
	match GameState.place_line(region):
		"":
			msg("LINE SET - CHECK BACK IN 8 MINUTES")
		"no_gear":
			msg("BUY A SET LINE IN THE TACKLE SHOP")
			GameState.play_sound("buzz")
		"busy":
			msg("ALL SET LINES ARE IN THE WATER - COLLECT ONE FIRST")
			GameState.play_sound("buzz")
		"already":
			msg("A LINE IS ALREADY SET HERE")
			GameState.play_sound("buzz")
		_:
			msg("SET LINES NEED A BANK - POND, RIVER, LAKE OR DEEP SEA")
			GameState.play_sound("buzz")

## Gamepad / keyboard spot cycling. Skips locked regions and warns instead
## of teleporting into a spot the player has not bought yet.
func _cycle_spot(delta: int) -> void:
	var order := ["pond", "river", "lake", "ocean"]
	var at := order.find(region)
	for step in range(1, order.size() + 1):
		var key: String = order[(at + step * delta + order.size() * 4) % order.size()]
		if not GameState.unlocked_regions.has(key):
			continue
		if key == "ocean" and not GameState.has_seaworthy_boat():
			continue
		_set_region(key)
		GameState.play_sound("ui")
		msg("%s - %s" % [RegionArt.display(region), RegionArt.tagline(region)])
		return
	msg("NO OTHER SPOTS UNLOCKED YET - VISIT THE SHOP")
	GameState.play_sound("buzz")


## Coconut Isle sits off the Deep Sea coast. Sail east from the Deep Sea
## to land there; walk west off the beach to sail home. The island keeps
## its own fish pool, palm trees and the coconut rod crafting.
func _enter_island() -> void:
	_set_region("island")
	is_island = true
	open_water = false
	open_zone = 0
	in_boat = false
	axe_out = false
	rod_out = true
	fisher_x = bank_w - 52.0
	rod_tip = Vector2(fisher_x + 74.0, floor(bank_top - 78.0))
	if tunnel:
		tunnel.visible = false
	_setup_palms()
	_build_ambient_fish()
	GameState.play_sound("rare")
	msg("COCONUT ISLE - E CHOPS PALMS - SHOP MAKES ISLAND RODS")
	fx_flash(0.8)


func _exit_island() -> void:
	is_island = false
	_set_region("ocean")
	open_water = false
	open_zone = 0
	in_boat = true
	axe_out = false
	rod_out = true
	boat_pos = Vector2(view_size.x - 110.0, _boat_surface_y())
	if tunnel:
		tunnel.visible = true
	_build_ambient_fish()
	GameState.play_sound("cast")
	msg("BACK ON THE DEEP SEA - SAIL WEST TO THE SHORE")
	fx_flash(0.8)


func _setup_palms() -> void:
	palms.clear()
	if not is_island:
		return
	var base := bank_top - 2.0
	# Spread the palms along the walkable stretch of beach so every one
	# can be reached even when the window is narrow.
	var span := maxf(40.0, bank_w - 120.0)
	var count := mini(PALM_COUNT, GameState.PALM_IDS.size())
	for i in range(count):
		var t := 0.0 if count <= 1 else float(i) / float(count - 1)
		palms.append({"id": String(GameState.PALM_IDS[i]),
			"x": 64.0 + span * t, "y": base})


func _nearest_palm_index() -> int:
	var best := -1
	var dist := 100.0
	for i in range(palms.size()):
		var d := absf(fisher_x - float(palms[i]["x"]))
		if d < dist:
			dist = d
			best = i
	return best


func _chop_nearest_palm() -> void:
	if not is_island or in_boat:
		return
	if not GameState.has_axe:
		msg("BUY AN AXE IN THE SHOP TO CHOP PALMS (ESC)")
		GameState.play_sound("buzz")
		return
	var idx := _nearest_palm_index()
	if idx < 0:
		msg("WALK CLOSER TO A PALM TREE")
		GameState.play_sound("buzz")
		return
	# the axe swings in hand even if the rod was out
	axe_out = true
	rod_out = false
	var palm: Dictionary = palms[idx]
	var earned := GameState.chop_palm(String(palm["id"]))
	if earned < 0:
		msg("PALM REGROWING - %s LEFT" % _clock_text(GameState.palm_regrow_left(String(palm["id"]))))
		GameState.play_sound("buzz")
		return
	GameState.play_sound("catch")
	msg("TIMBER! +%d COCONUTS - COCONUTS: %d" % [earned, GameState.coconuts])


static func _clock_text(seconds: int) -> String:
	return "%02d:%02d" % [maxi(0, seconds) / 60, maxi(0, seconds) % 60]


## On-foot movement along the bank, plus the tunnel to the Town scene.
## Input eases into a velocity instead of snapping, so starting and stopping
## reads as a walk rather than a teleport. The step counter kicks up a tiny
## dust puff on each footfall.
func _update_walk(dt: float) -> void:
	var walk := clampf(_move_x(), -1.0, 1.0)
	var target := walk * fisher_speed
	var rate := 1050.0 if absf(walk) > 0.05 else 1400.0
	walk_vel = move_toward(walk_vel, target, rate * dt)
	walk_ratio = clampf(absf(walk_vel) / fisher_speed, 0.0, 1.0)
	walking = walk_ratio > 0.035
	if walking and absf(walk_vel) > 10.0:
		fisher_facing = 1.0 if walk_vel > 0.0 else -1.0

	if walking:
		var next_x := fisher_x + walk_vel * dt
		var clamped_x := clampf(next_x, 30.0, bank_w - 40.0)
		if not is_equal_approx(clamped_x, next_x):
			# wedged against the edge of the bank: stop the gait cleanly
			walk_vel = 0.0
			walk_ratio = 0.0
			walking = false
		fisher_x = clamped_x
		if walking:
			walk_phase = fposmod(walk_phase + dt * (4.5 + 7.5 * walk_ratio), TAU)
			var step_index := int(floor(walk_phase / PI))
			if step_index != last_step:
				last_step = step_index
				if walk_ratio > 0.3:
					_spawn_dust(Vector2(fisher_x + (6.0 if step_index % 2 == 0 else -6.0),
							bank_top - 1.0))
	else:
		walk_phase = move_toward(walk_phase, 0.0, dt * 14.0)
	# walking off the west end of Coconut Isle sails you home
	if is_island and fisher_x <= 32.0 and walk < -0.5:
		_exit_island()
		return
	rod_tip = Vector2(fisher_x + 74.0, floor(bank_top - 78.0))
	if tunnel and tunnel.visible and not tunnel.triggered \
			and tunnel.proximity_check(Vector2(fisher_x, bank_top + 1.5)):
		tunnel.triggered = true
		GameState.travel(tunnel.target_scene)


## Small dust puff under the foot that just landed. Stored in world space
## so it stays behind as the fisher walks on.
func _spawn_dust(pos: Vector2) -> void:
	if GameState.reduce_motion():
		return
	dust.append({
		"pos": pos + Vector2(randf_range(-3.0, 3.0), -1.0),
		"vel": Vector2(-signf(walk_vel) * randf_range(6.0, 15.0), randf_range(-13.0, -5.0)),
		"life": randf_range(0.26, 0.4),
		"max_life": 0.4,
		"size": randf_range(2.0, 3.0),
	})
	if dust.size() > 24:
		dust.remove_at(0)


func _update_dust(dt: float) -> void:
	for i in range(dust.size() - 1, -1, -1):
		var d: Dictionary = dust[i]
		d["life"] = float(d["life"]) - dt
		if float(d["life"]) <= 0.0:
			dust.remove_at(i)
			continue
		d["pos"] = Vector2(d["pos"]) + Vector2(d["vel"]) * dt
		d["vel"] = Vector2(d["vel"]) * 0.9


## Sailing: A/D (or left/right) row the equipped boat along the water.
## The hull floats ON the surface - see _boat_surface_y - so the boat
## rides the waterline instead of drifting through the middle of the
## water. Speed comes from the boat's ShopDB stat, so better boats move
## faster.
func _update_boat(dt: float) -> void:
	var dir := _move_x()
	walking = absf(dir) > 0.1
	boat_pos.y = _boat_surface_y()
	if walking:
		var speed := float(GameState.current_boat().get("speed", 90.0))
		var min_x := 18.0 if open_water else bank_w + 52.0
		boat_pos.x = clampf(boat_pos.x + dir * speed * dt, min_x, view_size.x - 18.0)
		walk_phase = fposmod(walk_phase + dt * 6.0, TAU)
	else:
		walk_phase = move_toward(walk_phase, 0.0, dt * 12.0)
	rod_tip = Vector2(boat_pos.x + 62.0, boat_pos.y - 80.0)


## Where boats float: the hull is drawn straddling this line so it sits on
## top of the water rather than in the middle of it.
func _boat_surface_y() -> float:
	return water_line - 6.0


## B on the shore boards the boat; B again near the shore puts it back.
func _toggle_boat() -> void:
	GameState.play_sound("ui")
	if in_boat:
		if is_island:
			msg("WALK WEST TO THE END OF THE BEACH TO SAIL HOME")
			GameState.play_sound("buzz")
			return
		if open_water:
			msg("NO SHORE IN SIGHT - SAIL WEST TO RETURN")
			GameState.play_sound("buzz")
			return
		if boat_pos.x > bank_w + 120.0:
			msg("SAIL CLOSER TO SHORE TO LAND")
			GameState.play_sound("buzz")
			return
		in_boat = false
		fisher_x = clampf(boat_pos.x - 74.0, 30.0, bank_w - 40.0)
		rod_tip = Vector2(fisher_x + 74.0, floor(bank_top - 78.0))
		msg("BACK ON SHORE")
	else:
		if is_island:
			msg("BOARD ONLY IN THE OPEN SEA - WALK WEST TO LEAVE")
			GameState.play_sound("buzz")
			return
		in_boat = true
		boat_pos = Vector2(clampf(fisher_x + 96.0, bank_w + 52.0, view_size.x - 60.0), _boat_surface_y())
		msg("SET SAIL - A/D TO SAIL - B NEAR SHORE TO LAND")


## Sailing past the east edge of a fishing spot loads the open-water
## section: a wide body of open sea with its own fish for the index.
func _enter_open_water() -> void:
	open_water = true
	open_zone = 0
	open_water_from = region
	_set_region("open")
	boat_pos = Vector2(90.0, _boat_surface_y())
	if tunnel:
		tunnel.visible = false
	_build_ambient_fish()
	GameState.play_sound("cast")
	msg("OPEN WATER - SAIL EAST FOR THE KELP SHELF - UNCHARTED FISH LURK BELOW")
	fx_flash(0.8)


## Sail east/west at the edge of an open-water zone. The route is Open Water
## -> Kelp Shelf -> Midnight Trench, so the boat gets a real voyage instead
## of a single static screen.
func _change_open_zone(delta: int) -> void:
	open_zone = clampi(open_zone + delta, 0, OPEN_ZONES.size() - 1)
	var z := _open_zone_data()
	_set_region(String(z.get("id", "open")))
	boat_pos = Vector2(90.0 if delta > 0 else view_size.x - 90.0, _boat_surface_y())
	_build_ambient_fish()
	GameState.play_sound("cast")
	msg("%s - %s" % [String(z.get("name", "OPEN WATER")), String(z.get("tagline", ""))])
	fx_flash(0.8)


## Sail back west to return to the regular fishing spot.
func _exit_open_water() -> void:
	open_water = false
	open_zone = 0
	_set_region(open_water_from)
	boat_pos = Vector2(view_size.x - 110.0, boat_pos.y)
	if tunnel:
		tunnel.visible = true
	_build_ambient_fish()
	GameState.play_sound("cast")
	msg("BACK AT THE %s" % String(FishDB.REGION_DISPLAY.get(region, region)).to_upper())
	fx_flash(0.8)


func _cast_start() -> void:
	var used_bait := GameState.consume_bait()
	if region == "island" and used_bait == "":
		msg("BAIT UP FIRST - ISLAND FISH ONLY EAT BAIT (SHOP: ESC)")
		GameState.play_sound("buzz")
		return
	# casting plants the feet: clear any leftover walk animation
	walking = false
	walk_vel = 0.0
	walk_phase = 0.0
	state = STATE_CAST
	cast_travel = 0.0
	bobber_home = cast_target
	bobber_pos = rod_tip
	# each cast uses one charge of the equipped bait (bought at the shop)
	cast_bait = used_bait
	_spawn_splash(cast_target, 0.7)
	GameState.play_sound("cast")


func _update_cast(dt: float) -> void:
	cast_travel = clampf(cast_travel + dt * 2.2, 0.0, 1.0)
	var t := cast_travel
	bobber_pos = rod_tip.lerp(bobber_home, t)
	bobber_pos.y -= sin(t * PI) * 110.0
	if cast_travel >= 1.0:
		state = STATE_BITE
		_spawn_splash(bobber_home, 1.0)
		bite_timer = 0.0
		bite_delay = randf_range(1.8, 6.5)
		if is_night:
			bite_delay *= 0.8
		if weather == "rain":
			bite_delay *= 0.85
		elif weather == "storm":
			bite_delay *= 0.7
		if cast_bait != "":
			bite_delay *= 0.7
		if is_night:
			bite_delay *= float(_lantern().get("night_bite", 1.0))


func _update_bite(dt: float) -> void:
	bite_timer += dt
	var bob := sin(Time.get_ticks_msec() / 1000.0 * 4.0) * 3.0
	bobber_pos = bobber_home + Vector2(0.0, bob)
	if bite_timer >= bite_delay and not hooked:
		_trigger_bite()
	if hooked:
		bite_reaction_left -= dt
		bobber_pos = bobber_home + Vector2(0.0, sin(Time.get_ticks_msec() / 1000.0 * 14.0) * 6.0)
		if bite_reaction_left <= 0.0:
			_hook_fail()
		elif _pressed():
			_hook_success()


func _trigger_bite() -> void:
	hooked = true
	bite_reaction_left = BITE_WINDOW
	GameState.play_sound("bite")
	msg("BITE! PRESS SPACE OR CLICK TO HOOK")


## Timing minigame target. The green is chosen once when the fish is
## hooked and stays put for that fish; better rods make it wider.
var timing_center := 0.5

func _hook_success() -> void:
	hooked = false
	_spawn_splash(bobber_home, 0.8)
	_select_catch()
	state = STATE_REEL
	reel_active = true
	# Start the timing marker at the left edge so a half-bar green is still
	# a real timing test instead of an instant click at the centre.
	reel_pos = 0.0
	reel_dir = 1.0
	reel_hold = false
	reel_tension = 0.5
	tug_center = 0.5
	tug_dir = 1.0 if randf() < 0.5 else -1.0
	tug_ok_time = 0.0
	tug_peg_time = 0.0
	timing_center = _first_timing_center()
	tug_fight = _roll_fight_mode()
	if tug_fight:
		msg("TUG-OF-WAR - HOLD TO REEL, FOLLOW THE GREEN")
	else:
		msg("TIMING CAST - PRESS IN THE GREEN")


func _hook_fail() -> void:
	hooked = false
	state = STATE_WORLD
	GameState.reset_streak()
	GameState.play_sound("escape")
	msg("THE FISH GOT AWAY...")
	fx_shake(0.6)


## 50/50 pick between the timing bar and the tug-of-war for this fish.
func _roll_fight_mode() -> bool:
	return randf() < 0.5


func _is_tug_fight() -> bool:
	return tug_fight


func _lantern() -> Dictionary:
	return ShopDB.item("lanterns", String(GameState.gear.get("lantern", "lantern_none")))


func _select_catch() -> void:
	var pool := _fish_pool_here()
	if pool.size() == 0:
		pool = FishDB.fish_pool("pond", weather, is_night, _season_id())
	var weights := []
	var total := 0.0
	var boost: Array = []
	var bait_data: Dictionary = {}
	if cast_bait != "":
		bait_data = ShopDB.item("baits", cast_bait)
		boost = bait_data.get("rarity_boost", [])
	var night_rare := float(_lantern().get("night_rare", 1.0))
	# The Harvest Queen's signature perk: open-water rare+ fish are more
	# willing to bite. Other hulls keep the base weighting.
	var queen_rare := 1.0
	if open_water:
		queen_rare = float(GameState.current_boat().get("open_rare_bonus", 1.0))
	for f in pool:
		var w := float(f.get("catch_rate", 1.0))
		var r := String(f.get("rarity", "Common"))
		if open_water and queen_rare > 1.0 and (r == "Rare" or r == "Epic" or r == "Legendary"):
			w *= queen_rare
		if bool(f.get("anywhere", false)):
			# roaming monsters bite no matter what bait is on the hook
			pass
		elif cast_bait != "":
			if boost.has(r):
				w *= BAIT_BOOST
			if String(bait_data.get("time_boost", "")) == ("night" if is_night else "day"):
				w *= 1.25
			if (bait_data.get("weather_boost", []) as Array).has(weather):
				w *= 1.3
		else:
			# fishing bare: rare fish almost never show up - buy bait!
			w *= float(NO_BAIT_PENALTY.get(r, 1.0))
		if is_night and r == "Legendary":
			w *= 1.5
		if is_night and GameTheme.get_rarity_rate(r) < 0.25:
			w *= night_rare
		if weather == "storm" and GameTheme.get_rarity_rate(r) < 0.25:
			w *= 1.3
		if String(f.get("weather", "")) != "" or String(f.get("time", "")) != "":
			# weather/time specialists are hungry in their own window
			w *= 1.5
		weights.append(w)
		total += w
	var rnd := randf() * total
	var acc := 0.0
	var chosen: Dictionary = pool[0]
	for i in range(pool.size()):
		acc += float(weights[i])
		if rnd <= acc:
			chosen = pool[i]
			break
	catch_fish_id = String(chosen.get("id", ""))
	catch_rarity = String(chosen.get("rarity", "Common"))
	var wg: Array = chosen.get("weight_kg", [0.1, 0.5])
	catch_weight = randf_range(float(wg[0]), float(wg[1]))
	catch_new = GameState.is_new_species(catch_fish_id)
	catch_perfect = false
	catch_coins = GameState.sale_value(catch_fish_id, catch_weight)


func _update_reel(dt: float) -> void:
	var target := rod_tip
	bobber_pos = bobber_pos.lerp(target, clampf(dt * 0.9, 0.0, 1.0))
	if _is_tug_fight():
		_update_tug(dt)
	else:
		_update_timing(dt)


func _update_timing(dt: float) -> void:
	var prev_pos := reel_pos
	# The sweep speed is the same on every rod, so the wider green is a
	# real 4% improvement instead of being cancelled by a faster marker.
	reel_pos += reel_dir * dt * TIMING_SWEEP
	if reel_pos > 1.0:
		reel_pos = 1.0
		reel_dir = -1.0
	elif reel_pos < 0.0:
		reel_pos = 0.0
		reel_dir = 1.0
	if _pressed():
		_finish_timing(prev_pos)


## The click is judged against the whole stretch the marker swept since
## the previous frame, plus TIMING_GRACE - a press that arrives a frame
## late still counts if the marker was in the green a moment ago.
func _finish_timing(prev_pos: float = -1.0) -> void:
	var good := _green_half()
	var lo := timing_center - good - TIMING_GRACE
	var hi := timing_center + good + TIMING_GRACE
	var ok := reel_pos >= lo and reel_pos <= hi
	if not ok and prev_pos >= 0.0:
		var swept_lo := minf(prev_pos, reel_pos) - TIMING_GRACE
		var swept_hi := maxf(prev_pos, reel_pos) + TIMING_GRACE
		ok = swept_hi >= lo and swept_lo <= hi
	var perfect := ok and absf(reel_pos - timing_center) < good * 0.35
	_complete_catch(ok, perfect)


## Which rod this is: 0 = Twig, 4 = Carbon/Ancient. Crafted island rods
## sit one tier above their base shop rod.
func _rod_id() -> String:
	return String(GameState.gear.get("rod", "rod_stick"))


func _rod_tier_rank() -> int:
	return ShopDB.rod_tier(_rod_id())


## Reel power for the tug-of-war; the timing sweep stays constant so the
## wider green is the actual upgrade.
func _rod_reel_speed() -> float:
	return maxf(0.6, float(ShopDB.item("rods", _rod_id()).get("reel_speed", 1.0)))


## Half-width of the timing green. 40% of the bar on the Twig Rod, plus
## 4 percentage points for every rod tier: 40 / 44 / 48 / 52 / 56%.
func _green_half() -> float:
	return float(ShopDB.rod_green_percent(_rod_id())) / 200.0


## Pick the green's position once per fish. It does not move again while
## that fish is being reeled in.
func _first_timing_center() -> float:
	return _random_timing_center(0.5)


func _random_timing_center(previous: float) -> float:
	var half := _green_half()
	var lo := half + 0.01
	var hi := 1.0 - half - 0.01
	if hi <= lo:
		return 0.5
	var best := previous
	for i in range(8):
		best = randf_range(lo, hi)
		if absf(best - previous) >= 0.10:
			break
	return best


## 1.0 for common fish, a touch tighter for the rare ones.
func _fight_scale() -> float:
	match catch_rarity:
		"Legendary": return 0.82
		"Epic": return 0.88
		"Rare": return 0.94
		_: return 1.0


## Tug-of-war minigame: holding reels in and raises tension, releasing
## lets it fall. Keep the marker in the green band long enough to land the
## fish. The line only snaps after it has been fully slack or fully
## strained for TUG_PEG seconds straight, so one clumsy pause is
## survivable - the old build failed within half a second no matter what.
func _update_tug(dt: float) -> void:
	var band := _tug_band()
	# The green drifts slowly across the bar. Follow it with the tension
	# marker; it reverses at the edges instead of wrapping.
	tug_center += tug_dir * TUG_GREEN_SPEED * dt
	var center_lo := band + 0.03
	var center_hi := 1.0 - band - 0.03
	if center_hi <= center_lo:
		tug_center = 0.5
	elif tug_center < center_lo:
		tug_center = center_lo
		tug_dir = 1.0
	elif tug_center > center_hi:
		tug_center = center_hi
		tug_dir = -1.0
	# A click is a short pump rather than one frame of holding, so tapping
	# in the green reels the fish in just like holding the button does.
	var tapped := _pressed()
	reel_hold = _reel_held() or tapped
	var held_dt := dt + (TUG_TAP_PUMP if tapped else 0.0)
	if reel_hold:
		reel_tension += held_dt * TUG_BUILD * (2.0 - _fight_scale())
	else:
		reel_tension -= dt * TUG_DECAY
	reel_tension = clampf(reel_tension, 0.0, 1.0)
	if reel_tension <= 0.001 or reel_tension >= 0.999:
		tug_peg_time += dt
		if tug_peg_time >= TUG_PEG:
			_complete_catch(false)
			return
	else:
		tug_peg_time = 0.0
	if absf(reel_tension - tug_center) < band:
		# Better rods pull the fish in a little faster once you are in the
		# green; the wider band above is the bigger part of the upgrade.
		var reel_power := 1.0 + (_rod_reel_speed() - 1.0) * 0.15
		tug_ok_time += dt * reel_power
		if tapped:
			tug_ok_time += TUG_TAP_PROGRESS
	else:
		# a short misstep only slows the landing, it does not reset it
		tug_ok_time = maxf(0.0, tug_ok_time - dt * 0.5)
	if tug_ok_time >= TUG_HOLD:
		var perfect := absf(reel_tension - tug_center) < band * 0.3
		_complete_catch(true, perfect)


func _reel_held() -> bool:
	if Input.is_key_pressed(KEY_SPACE) or Input.is_action_pressed("ui_accept"):
		return true
	if touch_controls != null and touch_controls.action_held:
		return true
	return Input.is_action_pressed("click") and not _click_blocked()


## Safe tension band. It starts at 44% of the bar, gains 2 half-width
## points (4% total width) per rod tier, and better lines widen it a little
## more. This is the width of the moving green on the tug bar.
func _tug_band() -> float:
	var line := ShopDB.item("lines", String(GameState.gear.get("line", "line_nylon")))
	var line_bonus := (0.3 - float(line.get("escape_chance", 0.3))) * 0.2
	return clampf(TUG_BAND + float(_rod_tier_rank()) * 0.02 + line_bonus, TUG_BAND, 0.45)


func _complete_catch(success: bool, perfect := false) -> void:
	reel_active = false
	if success:
		var f := FishDB.fish_data(catch_fish_id)
		if bool(f.get("monster", false)) and randf() < MONSTER_SHOCK_CHANCE:
			_monster_shock(f)
			return
		# The fish goes into the bucket; selling it in the Tackle Shop or the
		# Fish Market is what pays - no coins at catch time (that used to pay
		# every fish twice and wreck the economy).
		GameState.record_catch(catch_fish_id, catch_weight, "open" if open_water else region,
				is_night, weather, perfect)
		catch_perfect = perfect
		catch_coins = GameState.sale_value(catch_fish_id, catch_weight, 1.0, perfect)
		state = STATE_CAUGHT
		catch_card_t = 0.0
		_spawn_splash(bobber_home, 1.0)
		if perfect:
			fx_flash(0.45)
		if catch_new and GameTheme.get_rarity_rate(catch_rarity) < 0.1:
			fx_flash(1.0)
			fx_shake(0.8)
			GameState.play_sound("rare")
		else:
			GameState.play_sound("catch")
	else:
		state = STATE_WORLD
		var had_streak := int(GameState.stats.get("current_streak", 0))
		GameState.reset_streak()
		GameState.play_sound("escape")
		msg("THE FISH GOT AWAY... STREAK LOST" if had_streak > 0 else "THE FISH GOT AWAY...")
		fx_shake(0.6)


## The Volt Serpent's bad side: it bites the hand that reels it in, costs
## the fisher MONSTER_SHOCK_COST coins and escapes. The other 95% of the
## time it goes straight into the bucket and can be sold like any fish.
func _monster_shock(f: Dictionary) -> void:
	var lost := mini(MONSTER_SHOCK_COST, GameState.coins)
	GameState.lose_coins(MONSTER_SHOCK_COST)
	GameState.reset_streak()
	state = STATE_WORLD
	hooked = false
	catch_fish_id = ""
	bobber_pos = rod_tip
	GameState.play_sound("shock")
	fx_shake(1.0)
	fx_flash(0.6)
	fx_hurt(1.0)
	# a bolt snaps out of the water where the serpent broke free
	if not GameState.reduce_motion():
		lightning_flash = 1.0
	lightning_x = clampf(bobber_pos.x, 40.0, view_size.x - 40.0)
	msg("%s SHOCKS YOU! -%d COINS - IT GOT AWAY" % [
			String(f.get("name", "MONSTER")).to_upper(), lost])


func _update_ambient(dt: float) -> void:
	for f in ambient_fish:
		f["x"] += float(f["speed"]) * float(f["dir"]) * dt
		f["phase"] += dt * 2.0
		if float(f["x"]) > view_size.x + 60.0:
			f["x"] = -60.0
		elif float(f["x"]) < -60.0:
			f["x"] = view_size.x + 60.0


func fish_name(fid: String) -> String:
	var f := FishDB.fish_data(fid)
	return String(f.get("name", fid))


func msg(text: String) -> void:
	msg_text = text
	msg_timer = 4.0


## Reduce-motion aware effects. With the setting on, shakes and flashes
## are dropped entirely (the sound still plays) so the screen never
## strobes or jolts.
func fx_shake(amount: float) -> void:
	if GameState.reduce_motion():
		return
	shake = maxf(shake, amount)


func fx_flash(amount: float) -> void:
	if GameState.reduce_motion():
		return
	flash = maxf(flash, amount)


func fx_hurt(amount: float) -> void:
	if GameState.reduce_motion():
		return
	hurt_flash = maxf(hurt_flash, amount)


func show_menu() -> void:
	hide_all_ui()
	menu_panel_show()


func hide_all_ui() -> void:
	if index_panel:
		index_panel.visible = false
	if shop_panel:
		shop_panel.visible = false
	if stats_panel:
		stats_panel.visible = false
	if pause_panel:
		pause_panel.visible = false
	if updates_panel:
		updates_panel.visible = false
	if settings_panel:
		settings_panel.visible = false
	if almanac_panel:
		almanac_panel.visible = false


func menu_panel_show() -> void:
	state = STATE_MENU
	hooked = false


func _on_start() -> void:
	GameState.session_started = true
	hide_all_ui()
	state = STATE_WORLD
	catch_fish_id = ""
	bobber_pos = rod_tip


func _on_back() -> void:
	if state == STATE_SETTINGS:
		settings_reset_confirm = false
		_refresh_settings()
	match state:
		STATE_INDEX:
			# opened mid-fishing with I / the INDEX button -> go back to the
			# water instead of the start menu
			if index_from_world:
				hide_all_ui()
				state = STATE_WORLD
			else:
				show_menu()
		STATE_SHOP:
			if shop_from_pause:
				shop_from_pause = false
				hide_all_ui()
				if pause_panel:
					pause_panel.visible = true
				state = STATE_PAUSED
				_refresh_pause()
			else:
				show_menu()
		STATE_STATS: show_menu()
		STATE_SETTINGS:
			if settings_from_pause:
				settings_from_pause = false
				hide_all_ui()
				if pause_panel:
					pause_panel.visible = true
				state = STATE_PAUSED
				_refresh_pause()
			else:
				show_menu()
		STATE_UPDATES:
			if updates_from_pause:
				updates_from_pause = false
				hide_all_ui()
				if pause_panel:
					pause_panel.visible = true
				state = STATE_PAUSED
				_refresh_pause()
			else:
				show_menu()
		STATE_ALMANAC:
			if almanac_from_world:
				hide_all_ui()
				state = STATE_WORLD
			elif almanac_from_pause:
				hide_all_ui()
				if pause_panel:
					pause_panel.visible = true
				state = STATE_PAUSED
				_refresh_pause()
			else:
				show_menu()
		STATE_CAUGHT: _on_catch_continue()
		_: show_menu()


func _on_index(from_world := false) -> void:
	hide_all_ui()
	index_from_world = from_world
	index_panel.visible = true
	state = STATE_INDEX
	_refresh_index()


func _on_shop(from_pause := false) -> void:
	shop_from_pause = from_pause
	hide_all_ui()
	shop_panel.visible = true
	state = STATE_SHOP
	_refresh_shop()


func _on_harvest_board() -> void:
	hide_all_ui()
	state = STATE_HARVEST
	HarvestTable.open_board(ui_layer, func() -> void:
		state = STATE_MENU
		show_menu()
	)


func _on_stats() -> void:
	hide_all_ui()
	stats_panel.visible = true
	state = STATE_STATS
	_refresh_stats()


## Settings is reachable from both the start menu and the pause menu.
func _on_settings(from_pause := false) -> void:
	GameState.play_sound("ui")
	settings_from_pause = from_pause
	hide_all_ui()
	_refresh_settings()
	settings_panel.visible = true
	state = STATE_SETTINGS
	if touch_controls != null:
		touch_controls.set_context("hidden")


## The What's New screen is reachable from the main menu and the pause menu
## (and U in Town). Opening it marks this version as read.
func _on_updates(from_pause := false) -> void:
	GameState.play_sound("ui")
	ChangelogLib.mark_seen()
	updates_from_pause = from_pause
	hide_all_ui()
	_refresh_updates()
	updates_panel.visible = true
	state = STATE_UPDATES


func _on_catch_continue() -> void:
	state = STATE_WORLD
	catch_fish_id = ""
	bobber_pos = rod_tip


func _build_stats() -> void:
	var p := Control.new()
	p.name = "Stats"
	p.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_layer.add_child(p)
	stats_panel = p
	var bg := ColorRect.new()
	bg.color = GameTheme.PANEL
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	p.add_child(bg)
	_add_leaf_sprigs(p)
	TownUI.ribbon(p, "ANGLER STATS", Vector2(16, 8), 330.0, 42.0)
	var sub := UILib.label(p, "EVERYTHING YOU HAVE LANDED SO FAR", 15, GameTheme.SUBTEXT)
	sub.position = Vector2(28, 54)
	# 12 lines do not fit the stats area on a 360px-tall window, so scroll.
	var stats_scroll := ScrollContainer.new()
	stats_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	stats_scroll.offset_left = 48
	stats_scroll.offset_top = 96
	stats_scroll.offset_right = -48
	stats_scroll.offset_bottom = -100
	stats_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	p.add_child(stats_scroll)
	UILib.style_scroll(stats_scroll)
	stats_label = UILib.label(stats_scroll, "", 20, GameTheme.CREAM, false, HORIZONTAL_ALIGNMENT_LEFT)
	stats_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	var b := UILib.button(p, "BACK", _on_back, 20, GameTheme.PANEL_LIGHT)
	b.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	b.offset_left = 28
	b.offset_top = -60
	b.offset_right = 188
	b.offset_bottom = -16
	b.custom_minimum_size = Vector2(160, 44)
	stats_mute_btn = UILib.button(p, "SOUND: ON", _toggle_mute, 18, GameTheme.PANEL_LIGHT)
	stats_mute_btn.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	stats_mute_btn.offset_left = -220
	stats_mute_btn.offset_top = -60
	stats_mute_btn.offset_right = -28
	stats_mute_btn.offset_bottom = -16
	stats_mute_btn.custom_minimum_size = Vector2(192, 44)
	p.visible = false


func _refresh_stats() -> void:
	if stats_label == null:
		return
	var s := GameState.stats
	var total_species := FishDB.all_ids(_season_id()).size()
	var caught_species := int(round(GameState.completion_percent() * float(total_species)))
	var mc: Array = GameState.mastery_counts()
	var hot := GameState.daily_hot_ids()
	var hot_names: Array[String] = []
	for fid in hot:
		hot_names.append(fish_name(String(fid)))
	var daily := fish_name(GameState.daily_fish_id())
	var biggest_name := String(s.get("biggest_name", "-"))
	if biggest_name == "":
		biggest_name = "-"
	var lines := [
		"TOTAL CATCHES      %d" % GameState.total_caught,
		"SPECIES            %d / %d  (%.0f%%)" % [caught_species, total_species,
				GameState.completion_percent() * 100.0],
		"ANGLER RANK        %s - %d PTS" % [GameState.angler_title(), GameState.angler_points()],
		"MASTERY            GOLD %d  SILVER %d  BRONZE %d" % [int(mc[0]), int(mc[1]), int(mc[2])],
		"GOLD SALE BONUS    +%.1f%%" % ((GameState.mastery_sale_mult() - 1.0) * 100.0),
		"COINS EARNED       %d" % int(s.get("coins_earned", 0)),
		"FISH SOLD          %d" % int(s.get("fish_sold", 0)),
		"PERFECT CATCHES    %d" % int(s.get("perfect_catches", 0)),
		"STREAK             %d  (BEST %d)" % [int(s.get("current_streak", 0)),
				int(s.get("best_streak", 0))],
		"DAILY CATCHES      %d" % int(s.get("daily_catches", 0)),
		"BIGGEST FISH       %.2f KG  %s" % [float(s.get("biggest_fish", 0.0)), biggest_name],
		"BUCKET             %d / %d" % [GameState.inventory_count(), GameState.bucket_capacity()],
		"DAILY CATCH        %s x2" % daily,
		"HOT DEMAND         %s" % "  ".join(hot_names),
		"2X COIN EVENT      %s" % (("LIVE - %s LEFT" % GameState.event_time_text())
				if GameState.event_active() else "ENDED"),
	]
	if GameState.harvest_season_open() or GameState.harvest_tokens() > 0 			or not (GameState.harvest.get("cards", {}) as Dictionary).is_empty() 			or bool(GameState.harvest.get("boat_claimed", false)):
		lines.append("HARVEST TOKENS     %d  (ALBUM %d / 20 - SPARES %d)" % [
				GameState.harvest_tokens(), GameState.harvest_owned_count(),
				GameState.harvest_spares_count()])
		if GameState.harvest_season_open():
			lines.append("HARVEST CLOSES     %s" % GameState.harvest_deadline_text())
		else:
			lines.append("HARVEST FEAST      CLOSED - RETURNS NOV 22")
	stats_label.text = "\n".join(lines)
	if stats_mute_btn != null:
		stats_mute_btn.text = "SOUND: %s" % ("OFF" if GameState.muted else "ON")


func _build_pause() -> void:
	var p := Control.new()
	p.name = "Pause"
	p.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_layer.add_child(p)
	pause_panel = p
	var dim := ColorRect.new()
	dim.color = Color(GameTheme.DIM, 0.62)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	p.add_child(dim)
	var card := Control.new()
	card.size = Vector2(420.0, 468.0)
	p.add_child(card)
	pause_card = card
	var bg := Panel.new()
	bg.size = Vector2(420.0, 468.0)
	bg.add_theme_stylebox_override("panel", UILib.sfx_bg())
	card.add_child(bg)
	if SeasonTheme.is_harvest():
		var wheat := ColorRect.new()
		wheat.color = GameTheme.WHEAT
		wheat.position = Vector2(14.0, 3.0)
		wheat.size = Vector2(392.0, 1.0)
		card.add_child(wheat)
	TownUI.ribbon(card, "PAUSED", Vector2(60.0, 10.0), 300.0, 40.0)
	var hint := UILib.label(card, "THE FISH WILL WAIT", 14, GameTheme.SUBTEXT, false, HORIZONTAL_ALIGNMENT_CENTER)
	hint.position = Vector2(0.0, 54.0)
	hint.size = Vector2(420.0, 22.0)
	var resume := UILib.button(card, "RESUME", _resume_game, 18, GameTheme.LEAF,
			UILib.LEAF.lightened(0.12), UILib.LEAF.darkened(0.25), UILib.CREAM, Vector2(340.0, 44.0))
	resume.position = Vector2(40.0, 84.0)
	pause_mute_btn = UILib.button(card, "SOUND: ON", _toggle_mute, 18, GameTheme.PANEL_LIGHT,
			GameTheme.BUTTON_HOVER, GameTheme.BUTTON_PRESS, UILib.CREAM, Vector2(340.0, 44.0))
	pause_mute_btn.position = Vector2(40.0, 132.0)
	var shop := UILib.button(card, "SHOP & CRAFT", _open_shop_from_pause, 18, GameTheme.PANEL_LIGHT,
			GameTheme.BUTTON_HOVER, GameTheme.BUTTON_PRESS, UILib.CREAM, Vector2(340.0, 44.0))
	shop.position = Vector2(40.0, 180.0)
	var updates := UILib.button(card, "WHAT'S NEW", _on_updates.bind(true), 18, GameTheme.PANEL_LIGHT,
			GameTheme.BUTTON_HOVER, GameTheme.BUTTON_PRESS, UILib.CREAM, Vector2(340.0, 44.0))
	updates.position = Vector2(40.0, 228.0)
	var settings := UILib.button(card, "SETTINGS", _on_settings.bind(true), 18, GameTheme.PANEL_LIGHT,
			GameTheme.BUTTON_HOVER, GameTheme.BUTTON_PRESS, UILib.CREAM, Vector2(340.0, 44.0))
	settings.position = Vector2(40.0, 276.0)
	var almanac := UILib.button(card, "ALMANAC", _on_almanac.bind(false, true), 18,
			GameTheme.WOOD, GameTheme.WOOD.lightened(0.12), GameTheme.WOOD.darkened(0.25),
			UILib.CREAM, Vector2(340.0, 44.0))
	almanac.position = Vector2(40.0, 324.0)
	var menu := UILib.button(card, "MAIN MENU", _pause_to_menu, 18, GameTheme.PANEL_LIGHT,
			GameTheme.BUTTON_HOVER, GameTheme.BUTTON_PRESS, UILib.CREAM, Vector2(340.0, 44.0))
	menu.position = Vector2(40.0, 372.0)
	p.visible = false
	_layout_pause_card()


## The pause card is a fixed 420x468 sheet; shrink it on short windows so
## the title and MAIN MENU do not leave the screen on a landscape phone.
func _layout_pause_card() -> void:
	if pause_card == null:
		return
	var sc := clampf(minf((view_size.x - 16.0) / 420.0,
			(view_size.y - 16.0) / 468.0), 0.4, 1.0)
	pause_card.scale = Vector2(sc, sc)
	pause_card.position = (view_size - Vector2(420.0, 468.0) * sc) * 0.5


## --- The Angler Almanac (v1.10) --------------------------------------
## A full-screen reference: rank card, the 68-species mastery grid, the
## live daily board, lifetime records and three rotating field notes.
## The grid is built once here; every other field is refreshed on open.
func _build_almanac() -> void:
	var p := Control.new()
	p.name = "Almanac"
	p.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_layer.add_child(p)
	almanac_panel = p
	var bg := ColorRect.new()
	bg.color = GameTheme.PANEL
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	p.add_child(bg)
	_add_leaf_sprigs(p)
	TownUI.ribbon(p, "THE ANGLER ALMANAC", Vector2(16, 8), 430.0, 42.0)
	var sub := UILib.label(p, "RANK, SPECIES MASTERY, DAILY CHALLENGES AND FIELD NOTES", 14,
			GameTheme.SUBTEXT)
	sub.position = Vector2(28, 54)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = 24
	scroll.offset_top = 84
	scroll.offset_right = -24
	scroll.offset_bottom = -68
	p.add_child(scroll)
	almanac_scroll = scroll
	UILib.style_scroll(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 8)
	scroll.add_child(body)
	almanac_body = body

	# --- rank card ---
	var rank_card := PanelContainer.new()
	rank_card.add_theme_stylebox_override("panel", UILib.sfx_paper())
	body.add_child(rank_card)
	var rank_margin := MarginContainer.new()
	rank_margin.add_theme_constant_override("margin_left", 18)
	rank_margin.add_theme_constant_override("margin_right", 18)
	rank_margin.add_theme_constant_override("margin_top", 12)
	rank_margin.add_theme_constant_override("margin_bottom", 12)
	rank_card.add_child(rank_margin)
	var rank_box := VBoxContainer.new()
	rank_box.add_theme_constant_override("separation", 4)
	rank_margin.add_child(rank_box)
	UILib.label(rank_box, "ANGLER RANK", 13, UILib.WOOD_DARK, false)
	almanac_rank_label = UILib.label(rank_box, "", 28, GameTheme.INK, false)
	almanac_next_label = UILib.label(rank_box, "", 13, Color("#5a4a55"), false)
	almanac_bar = ProgressBar.new()
	almanac_bar.custom_minimum_size = Vector2(0, 16)
	almanac_bar.max_value = 1.0
	almanac_bar.step = 0.001
	almanac_bar.show_percentage = false
	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color("#b79a72")
	bar_bg.set_corner_radius_all(8)
	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = GameTheme.GOLD
	bar_fill.set_corner_radius_all(8)
	almanac_bar.add_theme_stylebox_override("background", bar_bg)
	almanac_bar.add_theme_stylebox_override("fill", bar_fill)
	rank_box.add_child(almanac_bar)

	# --- mastery grid ---
	var mh := HBoxContainer.new()
	mh.add_theme_constant_override("separation", 18)
	body.add_child(mh)
	var ml := UILib.label(mh, "SPECIES MASTERY", 17, GameTheme.GOLD, true)
	ml.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	almanac_gold_label = UILib.label(mh, "", 14, GameTheme.CREAM, false,
			HORIZONTAL_ALIGNMENT_RIGHT)
	UILib.label(body, "CATCH EACH SPECIES 5 / 15 / 40 TIMES FOR BRONZE / SILVER / GOLD - MEDALS PAY COINS AND POINTS",
			12, GameTheme.SUBTEXT, false)
	almanac_grid = GridContainer.new()
	almanac_grid.columns = 4
	almanac_grid.add_theme_constant_override("h_separation", 10)
	almanac_grid.add_theme_constant_override("v_separation", 2)
	body.add_child(almanac_grid)
	var ids: Array = FishDB.FISH.keys()
	ids.sort_custom(func(a, b):
		return String(FishDB.FISH[a].get("name", "")) < String(FishDB.FISH[b].get("name", "")))
	for id_v in ids:
		var fid := String(id_v)
		var lab := UILib.label(almanac_grid, "", 12, GameTheme.FAINT, false)
		lab.custom_minimum_size = Vector2(200, 18)
		lab.clip_text = true
		almanac_grid_labels[fid] = lab

	UILib.separator(body, 8.0)
	# --- today board ---
	UILib.label(body, "TODAY'S BOARD", 17, GameTheme.GOLD, true)
	almanac_board_box = VBoxContainer.new()
	almanac_board_box.add_theme_constant_override("separation", 2)
	body.add_child(almanac_board_box)
	UILib.label(body, "CLAIM AT THE QUEST BOARD IN TOWN", 12, GameTheme.SUBTEXT, false)

	UILib.separator(body, 8.0)
	# --- records + notes ---
	UILib.label(body, "RECORDS", 17, GameTheme.GOLD, true)
	almanac_records_label = UILib.label(body, "", 14, GameTheme.CREAM, false)
	almanac_records_label.add_theme_constant_override("line_spacing", 4)
	UILib.separator(body, 8.0)
	UILib.label(body, "FIELD NOTES", 17, GameTheme.GOLD, true)
	almanac_notes_label = UILib.label(body, "", 14, GameTheme.WHEAT, false)
	almanac_notes_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	almanac_notes_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# almanac_notes_label is already parented by UILib.label

	var b := UILib.button(p, "BACK", _on_back, 20, GameTheme.PANEL_LIGHT)
	b.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	b.offset_left = 28
	b.offset_top = -60
	b.offset_right = 188
	b.offset_bottom = -16
	b.custom_minimum_size = Vector2(160, 44)
	p.visible = false


func _on_almanac(from_world := false, from_pause := false) -> void:
	hide_all_ui()
	almanac_from_world = from_world
	almanac_from_pause = from_pause
	almanac_panel.visible = true
	state = STATE_ALMANAC
	if almanac_scroll != null:
		almanac_scroll.scroll_vertical = 0
	_refresh_almanac()


func _mastery_color(rank: int) -> Color:
	match rank:
		1: return Color("#c98a54")
		2: return Color("#cfd6e4")
		3: return GameTheme.GOLD
		_: return GameTheme.FAINT


func _refresh_almanac() -> void:
	if almanac_panel == null or almanac_rank_label == null:
		return
	GameState.ensure_daily()
	var pts := GameState.angler_points()
	almanac_rank_label.text = "ANGLER RANK: %s - %d PTS" % [GameState.angler_title(), pts]
	var nxt: Array = GameState.angler_next()
	if nxt.is_empty() or String(nxt[0]) == "":
		almanac_next_label.text = "MAX RANK - %d / %d POINTS" % [pts,
				AlmanacLib.MASTERY_MAX_POINTS]
		almanac_bar.value = 1.0
	else:
		var need := int(nxt[1])
		almanac_next_label.text = "NEXT: %s AT %d PTS (%d TO GO)" % [String(nxt[0]), need,
				maxi(0, need - pts)]
		almanac_bar.value = clampf(float(pts) / float(maxi(1, need)), 0.0, 1.0)
	var mc: Array = GameState.mastery_counts()
	almanac_gold_label.text = "GOLD %d   SILVER %d   BRONZE %d" % [int(mc[0]), int(mc[1]), int(mc[2])]
	for fid in almanac_grid_labels.keys():
		var lab: Label = almanac_grid_labels[fid]
		var rank := GameState.mastery_rank(String(fid))
		var fname := String(FishDB.fish_data(String(fid)).get("name", fid)).to_upper()
		var medal := "-" if rank <= 0 else AlmanacLib.rank_name(rank)
		lab.text = "%s  %s" % [fname, medal]
		lab.add_theme_color_override("font_color", _mastery_color(rank))
	var streak := int(GameState.daily.get("streak", 0))
	for c in almanac_board_box.get_children():
		almanac_board_box.remove_child(c)
		c.queue_free()
	UILib.label(almanac_board_box, "STREAK %d DAYS - FINISH ALL THREE FOR +%d COINS" % [streak,
			AlmanacLib.DAILY_BONUS], 12, GameTheme.SUBTEXT, false)
	var ids: Array = GameState.daily.get("ids", [])
	for id_v in ids:
		var id := String(id_v)
		var def := AlmanacLib.daily_def(id)
		var need := GameState.daily_need(id)
		var prog := mini(GameState.daily_progress(id), need)
		var status := "CLAIMED" if GameState.daily_claimed(id) else (
				"READY" if prog >= need else "%d / %d" % [prog, need])
		var c := GameTheme.LEAF if status == "READY" else (
				GameTheme.FAINT if status == "CLAIMED" else GameTheme.CREAM)
		UILib.label(almanac_board_box, "%s   %s   +%d" % [String(def.get("label", "")).to_upper(),
				status, int(def.get("reward", 0))], 14, c, false)
	var st := GameState.stats
	var biggest := String(st.get("biggest_name", "-"))
	if biggest == "":
		biggest = "-"
	var rec := [
		"BIGGEST FISH       %.2f KG  %s" % [float(st.get("biggest_fish", 0.0)), biggest],
		"BEST CATCH STREAK  %d" % int(st.get("best_streak", 0)),
		"PERFECT CATCHES    %d" % int(st.get("perfect_catches", 0)),
		"DAYS FISHED        %d" % int(st.get("days_fished", 0)),
		"FISH SOLD          %d" % int(st.get("fish_sold", 0)),
		"SET LINES PLACED   %d" % int(st.get("lines_set", 0)),
	]
	almanac_records_label.text = "\n".join(rec)
	var notes: Array[String] = []
	for n in AlmanacLib.pick_field_notes(GameState.day_index()):
		notes.append("- " + String(n))
	almanac_notes_label.text = "\n".join(notes)


## Medal rank-up toast + flash. The card also tags the species on the
## catch screen via GameState.last_mastery_rank.
func _on_mastery_ranked(fish_id: String, rank: int) -> void:
	var fname := String(FishDB.fish_data(fish_id).get("name", fish_id)).to_upper()
	msg("%s %s! +%d COINS" % [fname, AlmanacLib.rank_name(rank), AlmanacLib.rank_coins(rank)])
	fx_flash(0.45 if rank < 3 else 0.9)

## Patch-notes screen. The body is rebuilt on open so the 2x event
## countdown is always current.
func _build_updates() -> void:
	var p := Control.new()
	p.name = "Updates"
	p.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_layer.add_child(p)
	updates_panel = p
	var bg := ColorRect.new()
	bg.color = GameTheme.PANEL
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	p.add_child(bg)
	_add_leaf_sprigs(p)
	TownUI.ribbon(p, "WHAT'S NEW", Vector2(16, 8), 330.0, 42.0)
	var sub := UILib.label(p, "V%s - EVERYTHING IN THE LATEST UPDATE" % ChangelogLib.VERSION, 15,
			GameTheme.SUBTEXT)
	sub.position = Vector2(28, 54)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = 28
	scroll.offset_top = 88
	scroll.offset_right = -28
	scroll.offset_bottom = -76
	p.add_child(scroll)
	UILib.style_scroll(scroll)
	updates_body = VBoxContainer.new()
	updates_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	updates_body.add_theme_constant_override("separation", 4)
	scroll.add_child(updates_body)
	var b := UILib.button(p, "BACK", _on_back, 20, GameTheme.PANEL_LIGHT)
	b.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	b.offset_left = 28
	b.offset_top = -60
	b.offset_right = 188
	b.offset_bottom = -16
	b.custom_minimum_size = Vector2(160, 44)
	p.visible = false


func _refresh_updates() -> void:
	if updates_body == null:
		return
	for c in updates_body.get_children():
		updates_body.remove_child(c)
		c.queue_free()
	ChangelogLib.fill(updates_body)


## --- Settings screen (v1.7) ------------------------------------------
## Music/SFX sliders, fullscreen, reduce motion, touch UI override, render
## quality and a confirmed progress reset. Reachable from the start menu
## and the pause menu, and every control is touch sized (48dp+).
func _build_settings() -> void:
	var p := Control.new()
	p.name = "Settings"
	p.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_layer.add_child(p)
	settings_panel = p
	var bg := ColorRect.new()
	bg.color = GameTheme.PANEL
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	p.add_child(bg)
	_add_leaf_sprigs(p)
	# A fixed 640x360 content sheet, scaled to fit short windows so the
	# bottom row never falls off a landscape phone (or the 640x360 min).
	var content := Control.new()
	content.name = "SettingsContent"
	content.size = Vector2(640.0, 360.0)
	p.add_child(content)
	settings_content = content
	TownUI.ribbon(content, "SETTINGS", Vector2(20, 4), 250.0, 38.0)
	var sub := UILib.label(content, "SOUND, SCREEN AND TOUCH OPTIONS - SAVED AUTOMATICALLY", 12,
			GameTheme.SUBTEXT)
	sub.position = Vector2(28, 46)

	var rows := [
		{"key": "music", "label": "MUSIC", "y": 76.0},
		{"key": "sfx", "label": "SOUND EFFECTS", "y": 124.0},
	]
	for row in rows:
		var key := String(row["key"])
		var yv := float(row["y"])
		var lab := UILib.label(content, String(row["label"]), 16, GameTheme.CREAM, true,
				HORIZONTAL_ALIGNMENT_LEFT)
		lab.position = Vector2(40, yv + 8.0)
		var slider := HSlider.new()
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.step = 0.05
		slider.custom_minimum_size = Vector2(330, 44)
		slider.position = Vector2(230, yv)
		slider.size = Vector2(330, 44)
		slider.value = float(GameState.settings.get(key, 0.7))
		slider.value_changed.connect(_on_volume_changed.bind(key))
		# wooden knob on a wheat track
		var track := StyleBoxFlat.new()
		track.bg_color = GameTheme.HUSK
		track.set_corner_radius_all(5)
		track.content_margin_top = 3.0
		track.content_margin_bottom = 3.0
		slider.add_theme_stylebox_override("slider", track)
		var filled := StyleBoxFlat.new()
		filled.bg_color = GameTheme.WHEAT
		filled.set_corner_radius_all(5)
		slider.add_theme_stylebox_override("grabber_area", filled)
		var filled_hi := filled.duplicate() as StyleBoxFlat
		filled_hi.bg_color = GameTheme.GOLD
		slider.add_theme_stylebox_override("grabber_area_highlight", filled_hi)
		var knob := _wood_knob_texture()
		slider.add_theme_icon_override("grabber", knob)
		slider.add_theme_icon_override("grabber_highlight", knob)
		content.add_child(slider)
		settings_sliders[key] = slider
		var val := UILib.label(content, "70%", 16, GameTheme.GOLD, true, HORIZONTAL_ALIGNMENT_RIGHT)
		val.position = Vector2(570, yv + 8.0)
		val.size = Vector2(50, 28)
		settings_sliders[key + "_label"] = val

	settings_fs_btn = UILib.button(content, "FULLSCREEN: OFF", _toggle_fullscreen_setting, 15,
			GameTheme.PANEL_LIGHT)
	settings_fs_btn.position = Vector2(40, 180)
	settings_fs_btn.size = Vector2(270, 44)
	settings_fs_btn.custom_minimum_size = Vector2(270, 44)
	settings_motion_btn = UILib.button(content, "REDUCE MOTION: OFF", _toggle_reduce_motion, 15,
			GameTheme.PANEL_LIGHT)
	settings_motion_btn.position = Vector2(326, 180)
	settings_motion_btn.size = Vector2(274, 44)
	settings_motion_btn.custom_minimum_size = Vector2(274, 44)

	var touch_lab := UILib.label(content, "TOUCH CONTROLS", 14, GameTheme.SUBTEXT)
	touch_lab.position = Vector2(40, 240)
	settings_touch_btn = UILib.button(content, "TOUCH: AUTO", _cycle_touch_ui, 15,
			GameTheme.PANEL_LIGHT)
	settings_touch_btn.position = Vector2(222, 234)
	settings_touch_btn.size = Vector2(170, 44)
	settings_touch_btn.custom_minimum_size = Vector2(170, 44)
	var quality_lab := UILib.label(content, "QUALITY", 14, GameTheme.SUBTEXT)
	quality_lab.position = Vector2(408, 240)
	settings_quality_btn = UILib.button(content, "QUALITY: AUTO", _cycle_quality, 15,
			GameTheme.PANEL_LIGHT)
	settings_quality_btn.position = Vector2(500, 234)
	settings_quality_btn.size = Vector2(118, 44)
	settings_quality_btn.custom_minimum_size = Vector2(118, 44)

	settings_reset_btn = UILib.button(content, "RESET PROGRESS", _on_reset_progress, 15,
			UILib.CRANBERRY, UILib.EMBER, UILib.CRANBERRY.darkened(0.3))
	settings_reset_btn.position = Vector2(40, 288)
	settings_reset_btn.size = Vector2(270, 44)
	settings_reset_btn.custom_minimum_size = Vector2(270, 44)
	var save_lab := UILib.label(content, "PROGRESS IS SAVED TO THIS DEVICE", 12, UILib.FAINT)
	save_lab.position = Vector2(40, 338)

	var b := UILib.button(content, "BACK", _on_back, 18, GameTheme.PANEL_LIGHT)
	b.position = Vector2(426, 288)
	b.size = Vector2(174, 44)
	b.custom_minimum_size = Vector2(174, 44)
	p.visible = false
	_layout_settings_content()


## Small round wooden knob for the settings sliders.
func _wood_knob_texture() -> ImageTexture:
	var img := Image.create(18, 18, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in range(18):
		for x in range(18):
			var d := Vector2(float(x) - 8.5, float(y) - 8.5).length()
			if d <= 8.0:
				var c := GameTheme.WOOD if d > 6.0 else GameTheme.WOOD.lightened(0.12)
				if d < 3.0:
					c = GameTheme.WOOD_DARK
				img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


func _layout_settings_content() -> void:
	if settings_content == null:
		return
	var sc := clampf(minf((view_size.x - 24.0) / 640.0,
			(view_size.y - 24.0) / 360.0), 0.5, 1.0)
	settings_content.scale = Vector2(sc, sc)
	settings_content.position = (view_size - Vector2(640.0, 360.0) * sc) * 0.5


func _refresh_settings() -> void:
	if settings_panel == null:
		return
	for key in ["music", "sfx"]:
		var slider: HSlider = settings_sliders.get(key)
		if slider != null:
			slider.set_value_no_signal(float(GameState.settings.get(key, 0.7)))
		var lab: Label = settings_sliders.get(key + "_label")
		if lab != null:
			lab.text = "%d%%" % int(round(float(GameState.settings.get(key, 0.7)) * 100.0))
	if settings_fs_btn != null:
		settings_fs_btn.text = "FULLSCREEN: %s" % ("ON" if bool(GameState.settings.get("fullscreen", false)) else "OFF")
	if settings_motion_btn != null:
		settings_motion_btn.text = "REDUCE MOTION: %s" % ("ON" if GameState.reduce_motion() else "OFF")
	if settings_touch_btn != null:
		settings_touch_btn.text = "TOUCH: %s" % GameState.touch_ui_mode().to_upper()
	if settings_quality_btn != null:
		settings_quality_btn.text = "QUALITY: %s" % String(GameState.settings.get("quality", "auto")).to_upper()
	if settings_reset_btn != null and not settings_reset_confirm:
		settings_reset_btn.text = "RESET PROGRESS"


func _on_volume_changed(value: float, key: String) -> void:
	GameState.set_setting(key, value)
	var lab: Label = settings_sliders.get(key + "_label")
	if lab != null:
		lab.text = "%d%%" % int(round(value * 100.0))


func _toggle_fullscreen_setting() -> void:
	GameState.set_setting("fullscreen", not bool(GameState.settings.get("fullscreen", false)))
	GameState.play_sound("ui")
	_refresh_settings()


func _toggle_reduce_motion() -> void:
	GameState.set_setting("reduce_motion", not GameState.reduce_motion())
	GameState.play_sound("ui")
	_refresh_settings()


func _cycle_touch_ui() -> void:
	var order := ["auto", "on", "off"]
	var at := order.find(GameState.touch_ui_mode())
	GameState.set_setting("touch_ui", order[(at + 1) % order.size()])
	if touch_controls != null:
		touch_controls.sync_settings(true)
	GameState.play_sound("ui")
	_refresh_settings()


func _cycle_quality() -> void:
	var order := ["auto", "low", "medium", "high"]
	var at := order.find(String(GameState.settings.get("quality", "auto")))
	GameState.set_setting("quality", order[(at + 1) % order.size()])
	_build_ambient_fish()
	if GameState.quality_level() == 0:
		ambient_particles.clear()
	GameState.play_sound("ui")
	_refresh_settings()


func _on_reset_progress() -> void:
	if not settings_reset_confirm:
		settings_reset_confirm = true
		if settings_reset_btn != null:
			settings_reset_btn.text = "CONFIRM RESET - CLICK AGAIN"
		GameState.play_sound("buzz")
		return
	settings_reset_confirm = false
	GameState.reset_progress()
	# the pond is the only unlocked water now - do not strand the player on
	# a Deep Sea save that reset just locked again
	is_island = false
	open_water = false
	open_zone = 0
	in_boat = false
	axe_out = false
	rod_out = true
	open_water_from = "pond"
	region = "pond"
	art_from = art.duplicate(true)
	art_target = RegionArt.get_art("pond")
	art = art_target.duplicate(true)
	art_t = 1.0
	art_waterline = float(art.get("waterline", WATER_RATIO))
	_relayout_water()
	GameState.play_sound("rare")
	msg("PROGRESS RESET - A BACKUP SAVE WAS KEPT")
	_refresh_settings()
	_refresh_stats()
	_refresh_shop()


## The pause menu can open the Tackle Shop, so the Coconut Isle rods and
## the axe are reachable without sailing back to the main menu.
func _open_shop_from_pause() -> void:
	if pause_panel != null:
		pause_panel.visible = false
	_on_shop(true)


func _open_pause() -> void:
	if pause_panel == null:
		return
	if state == STATE_MENU or state == STATE_INDEX or state == STATE_SHOP \
			or state == STATE_STATS or state == STATE_CAUGHT or state == STATE_PAUSED \
			or state == STATE_SETTINGS:
		return
	paused_from = state
	state = STATE_PAUSED
	pause_panel.visible = true
	_refresh_pause()


func _resume_game() -> void:
	if pause_panel != null:
		pause_panel.visible = false
	state = paused_from


func _pause_to_menu() -> void:
	if pause_panel != null:
		pause_panel.visible = false
	show_menu()


func _refresh_pause() -> void:
	if pause_mute_btn != null:
		pause_mute_btn.text = "SOUND: %s" % ("OFF" if GameState.muted else "ON")


func _toggle_mute() -> void:
	var now_muted := GameState.toggle_mute()
	_refresh_pause()
	_refresh_stats()
	if not now_muted:
		GameState.play_sound("ui")


func _build_index() -> void:
	var p := Control.new()
	p.name = "Index"
	p.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_layer.add_child(p)
	index_panel = p
	var bg := ColorRect.new()
	bg.color = GameTheme.PANEL
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	p.add_child(bg)
	_add_leaf_sprigs(p)
	TownUI.ribbon(p, "FISH INDEX", Vector2(16, 8), 330.0, 42.0)
	index_comp_label = UILib.label(p, "COLLECTION: 0%", 18, GameTheme.GOLD, true, HORIZONTAL_ALIGNMENT_LEFT)
	index_comp_label.position = Vector2(24, 52)
	index_gold_label = UILib.label(p, "", 12, GameTheme.SUBTEXT, false,
			HORIZONTAL_ALIGNMENT_LEFT)
	index_gold_label.position = Vector2(24, 76)
	index_filter_btn = UILib.button(p, "REGION: ALL", _cycle_index_region, 14, GameTheme.PANEL_LIGHT,
			GameTheme.BUTTON_HOVER, GameTheme.BUTTON_PRESS, UILib.CREAM, Vector2(190.0, 40.0))
	index_filter_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	index_filter_btn.offset_left = -430
	index_filter_btn.offset_top = 18
	index_filter_btn.offset_right = -240
	index_filter_btn.offset_bottom = 58
	index_uncaught_btn = UILib.button(p, "SHOW: ALL", _toggle_index_uncaught, 14, GameTheme.PANEL_LIGHT,
			GameTheme.BUTTON_HOVER, GameTheme.BUTTON_PRESS, UILib.CREAM, Vector2(190.0, 40.0))
	index_uncaught_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	index_uncaught_btn.offset_left = -220
	index_uncaught_btn.offset_top = 18
	index_uncaught_btn.offset_right = -24
	index_uncaught_btn.offset_bottom = 58

	# left: the species list (works with click, tap, hover and keys)
	var list := ItemList.new()
	list.name = "List"
	list.anchor_left = 0.0
	list.anchor_right = 0.44
	list.anchor_top = 0.0
	list.anchor_bottom = 1.0
	list.offset_left = 20.0
	list.offset_top = 96.0
	list.offset_right = -6.0
	list.offset_bottom = -70.0
	list.allow_reselect = true
	list.add_theme_font_size_override("font_size", 15)
	list.item_selected.connect(_on_index_selected)
	p.add_child(list)
	index_list = list
	UILib.style_item_list(list)

	# right: the detail pane (FishArt, rarity, description, where/when, PB)
	index_detail = Control.new()
	index_detail.name = "Detail"
	index_detail.anchor_left = 0.44
	index_detail.anchor_right = 1.0
	index_detail.anchor_top = 0.0
	index_detail.anchor_bottom = 1.0
	index_detail.offset_left = 10.0
	index_detail.offset_top = 96.0
	index_detail.offset_right = -24.0
	index_detail.offset_bottom = -70.0
	index_detail.clip_contents = true
	p.add_child(index_detail)
	var dbg := ColorRect.new()
	dbg.color = GameTheme.PANEL.darkened(0.08)
	dbg.set_anchors_preset(Control.PRESET_FULL_RECT)
	index_detail.add_child(dbg)

	# On short windows the detail pane is only ~190px tall. Put its fixed
	# 360px sheet in a scroll container so every field stays reachable
	# instead of being clipped below the fold.
	index_detail_scroll = ScrollContainer.new()
	index_detail_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	index_detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	index_detail_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	index_detail.add_child(index_detail_scroll)
	index_detail_content = Control.new()
	index_detail_content.custom_minimum_size = Vector2(0.0, 388.0)
	index_detail_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	index_detail_scroll.add_child(index_detail_content)

	index_detail_art = Control.new()
	index_detail_art.anchor_left = 0.0
	index_detail_art.anchor_right = 1.0
	index_detail_art.anchor_top = 0.0
	index_detail_art.anchor_bottom = 0.0
	index_detail_art.offset_left = 12.0
	index_detail_art.offset_top = 8.0
	index_detail_art.offset_right = -12.0
	index_detail_art.offset_bottom = 116.0
	index_detail_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	index_detail_content.add_child(index_detail_art)
	index_detail_art.draw.connect(_draw_index_art)

	index_detail_name = UILib.label(index_detail_content, "", 24, GameTheme.CREAM, true,
			HORIZONTAL_ALIGNMENT_LEFT)
	index_detail_name.anchor_left = 0.0
	index_detail_name.anchor_right = 1.0
	index_detail_name.offset_left = 14.0
	index_detail_name.offset_right = -14.0
	index_detail_name.offset_top = 118.0
	index_detail_name.offset_bottom = 150.0

	index_detail_rarity = UILib.pill(index_detail_content, "COMMON", GameTheme.get_rarity_color("Common"), 13)
	index_detail_rarity.position = Vector2(14.0, 156.0)
	index_detail_rarity.size = Vector2(150.0, 26.0)

	index_detail_desc = UILib.label(index_detail_content, "", 14, GameTheme.SUBTEXT, false,
			HORIZONTAL_ALIGNMENT_LEFT)
	index_detail_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	index_detail_desc.anchor_left = 0.0
	index_detail_desc.anchor_right = 1.0
	index_detail_desc.offset_left = 14.0
	index_detail_desc.offset_right = -14.0
	index_detail_desc.offset_top = 190.0
	index_detail_desc.offset_bottom = 236.0
	index_detail_desc.vertical_alignment = VERTICAL_ALIGNMENT_TOP

	index_detail_where = UILib.label(index_detail_content, "", 14, GameTheme.LEAF, false,
			HORIZONTAL_ALIGNMENT_LEFT)
	index_detail_where.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	index_detail_where.anchor_left = 0.0
	index_detail_where.anchor_right = 1.0
	index_detail_where.offset_left = 14.0
	index_detail_where.offset_right = -14.0
	index_detail_where.offset_top = 240.0
	index_detail_where.offset_bottom = 292.0
	index_detail_where.vertical_alignment = VERTICAL_ALIGNMENT_TOP

	index_detail_stats = UILib.label(index_detail_content, "", 15, GameTheme.CREAM, false,
			HORIZONTAL_ALIGNMENT_LEFT)
	index_detail_stats.anchor_left = 0.0
	index_detail_stats.anchor_right = 1.0
	index_detail_stats.offset_left = 14.0
	index_detail_stats.offset_right = -14.0
	index_detail_stats.offset_top = 296.0
	index_detail_stats.offset_bottom = 322.0

	index_detail_region = UILib.label(index_detail_content, "", 13, GameTheme.SUBTEXT, false,
			HORIZONTAL_ALIGNMENT_LEFT)
	index_detail_region.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	index_detail_region.anchor_left = 0.0
	index_detail_region.anchor_right = 1.0
	index_detail_region.offset_left = 14.0
	index_detail_region.offset_right = -14.0
	index_detail_region.offset_top = 324.0
	index_detail_region.offset_bottom = 352.0

	index_detail_mastery = UILib.label(index_detail_content, "", 15, GameTheme.GOLD, true,
			HORIZONTAL_ALIGNMENT_LEFT)
	index_detail_mastery.anchor_left = 0.0
	index_detail_mastery.anchor_right = 1.0
	index_detail_mastery.offset_left = 14.0
	index_detail_mastery.offset_right = -14.0
	index_detail_mastery.offset_top = 356.0
	index_detail_mastery.offset_bottom = 382.0

	var b := UILib.button(p, "BACK", _on_back, 20, GameTheme.PANEL_LIGHT)
	b.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	b.offset_left = 24
	b.offset_top = -60
	b.offset_right = 184
	b.offset_bottom = -12
	b.custom_minimum_size = Vector2(160, 48)
	p.visible = false


## Skin a pill label with a new colour (used for the rarity tag).
func _set_pill(label: Label, text: String, color: Color) -> void:
	label.text = text
	label.add_theme_color_override("font_color", UILib.INK)
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(12)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 3
	sb.content_margin_bottom = 3
	label.add_theme_stylebox_override("normal", sb)


func _refresh_index() -> void:
	if index_list == null:
		return
	index_list.clear()
	index_shown_ids.clear()
	var season := _season_id()
	var ids := FishDB.all_ids(season)
	var total := ids.size()
	var caught := 0
	var shown := 0
	for fid in ids:
		var fid_s := String(fid)
		var f := FishDB.fish_data(fid_s)
		var entry: Dictionary = GameState.index.get(fid_s, {})
		var caught_flag := bool(entry.get("caught", false))
		if caught_flag:
			caught += 1
		if index_filter_region == "harvest":
			if String(f.get("season", "")) != "harvest":
				continue
		elif index_filter_region != "" and String(f.get("region", "")) != index_filter_region:
			continue
		if index_only_uncaught and caught_flag:
			continue
		shown += 1
		var name_val := String(f.get("name", fid_s))
		if not caught_flag:
			name_val = "???"
		var rarity := String(f.get("rarity", "Common"))
		var color := GameTheme.get_rarity_color(rarity)
		var season_tag := "  [HARVEST]" if String(f.get("season", "")) == "harvest" else ""
		var idx := index_list.add_item("  %s   [%s]%s" % [name_val, rarity.to_upper(), season_tag])
		index_list.set_item_custom_fg_color(idx, color if caught_flag else UILib.FAINT)
		index_list.set_item_metadata(idx, fid_s)
		index_shown_ids.append(fid_s)
	if shown == 0:
		var empty_idx := index_list.add_item("NO FISH MATCH THIS FILTER")
		index_list.set_item_disabled(empty_idx, true)
	var pct := float(caught) / float(total) * 100.0 if total > 0 else 0.0
	index_comp_label.text = "COLLECTION: %d / %d  (%.0f%%)   SHOWING %d" % [caught, total, pct, shown]
	if index_gold_label != null:
		var mc: Array = GameState.mastery_counts()
		index_gold_label.text = "GOLD %d   SILVER %d   BRONZE %d" % [int(mc[0]), int(mc[1]),
				int(mc[2])]
	if index_filter_btn != null:
		var region_name := "ALL" if index_filter_region == "" else RegionArt.display(index_filter_region).to_upper()
		if index_filter_region == "harvest":
			region_name = "HARVEST"
			if not GameState.harvest_season_open():
				region_name = "HARVEST (CLOSED)"
		index_filter_btn.text = "REGION: %s" % region_name
	if index_uncaught_btn != null:
		index_uncaught_btn.text = "SHOW: %s" % ("UNCAUGHT" if index_only_uncaught else "ALL")
	# keep the same fish selected when the filter changes if it is still shown
	index_selected = clampi(index_selected, -1, index_shown_ids.size() - 1)
	if index_selected < 0 and not index_shown_ids.is_empty():
		index_selected = 0
	if index_selected >= 0 and index_selected < index_shown_ids.size():
		index_list.select(index_selected)
		_show_index_detail(index_shown_ids[index_selected])
	else:
		_show_index_detail("")


func _on_index_selected(idx: int) -> void:
	if idx < 0 or idx >= index_shown_ids.size():
		return
	index_selected = idx
	_show_index_detail(index_shown_ids[idx])


## Hover and keyboard navigation for the list. Both keep the detail pane in
## sync, so the index is fully usable without a mouse.
func _update_index_selection() -> void:
	if index_list == null or index_shown_ids.is_empty():
		return
	var moved := 0
	if Input.is_action_just_pressed("ui_up") or Input.is_action_just_pressed("move_up"):
		moved = -1
	elif Input.is_action_just_pressed("ui_down") or Input.is_action_just_pressed("move_down"):
		moved = 1
	if moved != 0:
		index_selected = (index_selected + moved + index_shown_ids.size()) % index_shown_ids.size()
		index_list.select(index_selected)
		_show_index_detail(index_shown_ids[index_selected])
		GameState.play_sound("ui")
		return
	var hovered := index_list.get_item_at_position(index_list.get_local_mouse_position())
	if hovered >= 0 and hovered < index_shown_ids.size() and hovered != index_selected:
		index_selected = hovered
		index_list.select(hovered)
		_show_index_detail(index_shown_ids[index_selected])


func _show_index_detail(fid: String) -> void:
	if index_detail == null:
		return
	if fid == "":
		index_detail_fish = {}
		index_detail_caught = false
		index_detail_name.text = "SELECT A FISH"
		_set_pill(index_detail_rarity, "INDEX", UILib.PANEL_LIGHT)
		index_detail_desc.text = "Pick a species to see its art, rarity, where and when it bites, and your personal best."
		index_detail_where.text = ""
		index_detail_stats.text = "COLLECTION: %.0f%%" % (GameState.completion_percent() * 100.0)
		index_detail_region.text = ""
		index_detail_mastery.text = ""
		index_detail_mastery.add_theme_color_override("font_color", GameTheme.SUBTEXT)
		if index_detail_art != null:
			index_detail_art.queue_redraw()
		return
	var f := FishDB.fish_data(fid)
	var entry: Dictionary = GameState.index.get(fid, {})
	var caught := bool(entry.get("caught", false))
	var rarity := String(f.get("rarity", "Common"))
	index_detail_fish = f
	index_detail_caught = caught
	var season_suffix := "  [HARVEST]" if String(f.get("season", "")) == "harvest" else ""
	index_detail_name.text = (String(f.get("name", fid)).to_upper() if caught else "???") + season_suffix
	_set_pill(index_detail_rarity, rarity.to_upper(),
			GameTheme.get_rarity_color(rarity) if caught else UILib.PANEL_LIGHT)
	if caught:
		index_detail_desc.text = String(f.get("desc", ""))
	else:
		index_detail_desc.text = "Not discovered yet. Catch it to fill in this entry."
	index_detail_where.text = _index_where_text(f, caught)
	if caught:
		index_detail_stats.text = "PB: %.2f KG    CAUGHT: %d" % [float(entry.get("pb_weight", 0.0)),
				int(entry.get("count", 0))]
	else:
		index_detail_stats.text = "PB: --    CAUGHT: 0"
	var mrank := GameState.mastery_rank(fid)
	index_detail_mastery.text = "MASTERY: " + (AlmanacLib.mastery_line(int(entry.get("count", 0)))
			if caught else "-")
	index_detail_mastery.add_theme_color_override("font_color",
			_mastery_color(mrank) if mrank > 0 else GameTheme.SUBTEXT)
	var region_name := String(f.get("region", "pond"))
	var region_fishes := FishDB.fish_by_region(region_name, _season_id())
	var region_caught := 0
	for rf in region_fishes:
		var rid := String(rf.get("id", ""))
		if bool((GameState.index.get(rid, {}) as Dictionary).get("caught", false)):
			region_caught += 1
	var pct := 0.0
	if region_fishes.size() > 0:
		pct = float(region_caught) / float(region_fishes.size()) * 100.0
	index_detail_region.text = "%s COMPLETION: %d / %d  (%.0f%%)" % [
			RegionArt.display(region_name).to_upper(), region_caught, region_fishes.size(), pct]
	if index_detail_scroll != null:
		index_detail_scroll.scroll_vertical = 0
	if index_detail_art != null:
		index_detail_art.queue_redraw()


func _index_where_text(f: Dictionary, caught: bool) -> String:
	if not caught:
		return "WHERE: ???    WHEN: ???"
	var where := RegionArt.display(String(f.get("region", "pond"))).to_upper()
	var when := "ANY TIME"
	match String(f.get("time", "")):
		"day": when = "DAY ONLY"
		"night": when = "NIGHT ONLY"
	var weather := String(f.get("weather", ""))
	if weather == "rain":
		when += " - RAIN"
	elif weather == "storm":
		when += " - THUNDERSTORM"
	elif weather != "":
		when += " - " + weather.to_upper()
	if bool(f.get("bait_only", false)):
		when += " - NEEDS BAIT"
	if String(f.get("season", "")) == "harvest":
		when += " - HARVEST FEAST"
	return "WHERE: %s\nWHEN: %s" % [where, when]


func _draw_index_art() -> void:
	if index_detail_art == null:
		return
	if index_detail_art.size.x < 16.0 or index_detail_art.size.y < 16.0:
		return
	var r := Rect2(Vector2(10.0, 4.0), index_detail_art.size - Vector2(20.0, 8.0))
	if index_detail_fish.is_empty():
		RegionArt.draw_glyph(index_detail_art, "pond", r.get_center(), 40.0, UILib.PANEL_LIGHT)
		return
	FishArt.draw_fish(index_detail_art, r, index_detail_fish, not index_detail_caught, 1.0)


func _cycle_index_region() -> void:
	var options := ["", "pond", "river", "lake", "ocean", "open", "island"]
	if GameState.harvest_season_open():
		options.append("harvest")
	var at := options.find(index_filter_region)
	index_filter_region = String(options[(at + 1) % options.size()])
	index_selected = 0
	GameState.play_sound("ui")
	_refresh_index()


func _toggle_index_uncaught() -> void:
	index_only_uncaught = not index_only_uncaught
	index_selected = 0
	GameState.play_sound("ui")
	_refresh_index()


func _build_shop() -> void:
	var p := Control.new()
	p.name = "Shop"
	p.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_layer.add_child(p)
	shop_panel = p
	var bg := ColorRect.new()
	bg.color = GameTheme.PANEL
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	p.add_child(bg)
	_add_leaf_sprigs(p)
	TownUI.ribbon(p, "TACKLE SHOP", Vector2(16, 8), 330.0, 42.0)
	var coins := UILib.label(p, "", 20, GameTheme.GOLD, true, HORIZONTAL_ALIGNMENT_RIGHT)
	coins.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	coins.offset_left = -320
	coins.offset_right = -24
	coins.offset_top = 20
	coins.offset_bottom = 50
	shop_coins_label = coins
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = 24
	scroll.offset_top = 68
	scroll.offset_right = -24
	scroll.offset_bottom = -72
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	p.add_child(scroll)
	shop_scroll = scroll
	UILib.style_scroll(scroll)
	shop_content = VBoxContainer.new()
	shop_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shop_content.add_theme_constant_override("separation", 4)
	scroll.add_child(shop_content)
	var sell_btn := UILib.button(p, "SELL ALL FISH", _on_sell_all, 20, GameTheme.WOOD)
	sell_btn.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	sell_btn.offset_left = -224
	sell_btn.offset_right = -24
	sell_btn.offset_top = -60
	sell_btn.offset_bottom = -16
	sell_btn.custom_minimum_size = Vector2(200, 44)
	var b := UILib.button(p, "BACK", _on_back, 20, GameTheme.PANEL_LIGHT)
	b.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	b.offset_left = 24
	b.offset_right = 184
	b.offset_top = -60
	b.offset_bottom = -16
	b.custom_minimum_size = Vector2(160, 44)
	p.visible = false


var shop_coins_label: Label


func _refresh_shop() -> void:
	if shop_coins_label:
		shop_coins_label.text = "COINS: %d" % GameState.coins
	# Rebuilding the rows resets the ScrollContainer, so remember where the
	# player was and put it back once the new rows have been laid out.
	if shop_scroll != null:
		shop_scroll_pos = shop_scroll.scroll_vertical
	for c in shop_content.get_children():
		shop_content.remove_child(c)
		c.queue_free()
	_craft_section()
	_shop_cat("Rods", "rods", _on_buy)
	_shop_cat("Lines", "lines", _on_buy)
	_shop_cat("Bait", "baits", _on_buy_bait)
	_shop_cat("Lanterns", "lanterns", _on_buy)
	_shop_cat("Bucket", "buckets", _on_buy)
	_trotline_section()
	_restore_shop_scroll(shop_scroll_pos)


## Restore the shop scroll now and once more after the container has
## re-sorted, since the scroll range is recalculated on the next frame.
func _restore_shop_scroll(pos: int) -> void:
	if shop_scroll == null:
		return
	shop_scroll.scroll_vertical = pos
	await get_tree().process_frame
	if is_instance_valid(shop_scroll):
		shop_scroll.scroll_vertical = pos


func _shop_cat(title: String, category: String, buy_func: Callable) -> void:
	# note: UILib.label / UILib.button already parent their widget
	var t := UILib.label(shop_content, title.to_upper(), 20, GameTheme.GOLD, true, HORIZONTAL_ALIGNMENT_LEFT)
	t.custom_minimum_size = Vector2(0.0, 28)
	var db: Dictionary = ShopDB.category(category)
	for id in db.keys():
		var d: Dictionary = db[id]
		if String(d.get("season", "")) == "harvest" and not GameState.harvest_season_open():
			continue
		var is_bait := category == "baits"
		var owned := bool(d.get("owned", false)) and not is_bait
		var equipped := String(GameState.gear.get(GameState.gear_key(category), "")) == String(id)
		var row := Control.new()
		row.custom_minimum_size = Vector2(0.0, 50.0)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		shop_content.add_child(row)
		var name_l := UILib.label(row, String(d.get("name", id)), 17, GameTheme.CREAM, true)
		name_l.position = Vector2(10, 6)
		var desc_l := UILib.label(row, String(d.get("desc", "")), 13, GameTheme.SUBTEXT, false)
		desc_l.position = Vector2(10, 26)
		var stat_l := UILib.label(row, _stat_line(category, d), 13, GameTheme.LEAF, false)
		stat_l.position = Vector2(330, 10)
		var cost := int(d.get("cost", 0))
		# Bait is a consumable: a bag with charges left can be equipped for
		# free, so the player can switch between the baits they own.
		var charges := GameState.bait_count(String(id)) if is_bait else 0
		var btn_text := "BUY %d" % cost
		if String(d.get("season", "")) == "harvest":
			btn_text = "EQUIPPED" if equipped else ("EQUIP" if owned else "BUY %d TOKENS" % int(d.get("token_cost", 0)))
		elif is_bait:
			if equipped and charges > 0:
				btn_text = "BUY %d" % cost
			elif charges > 0:
				btn_text = "USE x%d" % charges
		else:
			btn_text = "EQUIPPED" if equipped else ("EQUIP" if owned else "BUY %d" % cost)
		var btn := UILib.button(row, btn_text, buy_func.bind(category, String(id)), 14, GameTheme.PANEL_LIGHT)
		btn.custom_minimum_size = Vector2(120, 36)
		btn.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
		btn.offset_left = -130
		btn.offset_right = -10
		btn.offset_top = -18
		btn.offset_bottom = 18


## Coconut Isle crafting: the axe and the island rods. They are paid in
## coconuts (from chopped palms), never in coins, so they feel like
## found-and-built upgrades rather than shop stock.
## Set Lines are a one-time capacity upgrade, not equipable gear, so they
## get their own row layout instead of the generic shop category.
func _trotline_section() -> void:
	var t := UILib.label(shop_content, "SET LINES", 20, GameTheme.GOLD, true,
			HORIZONTAL_ALIGNMENT_LEFT)
	t.custom_minimum_size = Vector2(0.0, 28)
	var note := UILib.label(shop_content,
			"PASSIVE FISH - PRESS P ON THE BANK TO SET OR COLLECT (8 MIN)", 13,
			GameTheme.SUBTEXT, false)
	note.custom_minimum_size = Vector2(0.0, 20)
	var have := GameState.trotline_tier
	for tier_v in [1, 2, 3]:
		var tier := int(tier_v)
		var d := ShopDB.trotline_item(tier)
		var owned := tier <= have
		var next := tier == have + 1
		var row := Control.new()
		row.custom_minimum_size = Vector2(0.0, 50.0)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		shop_content.add_child(row)
		var name_l := UILib.label(row, String(d.get("name", "")), 17,
				GameTheme.FAINT if owned else GameTheme.CREAM, true)
		name_l.position = Vector2(10, 6)
		var desc_l := UILib.label(row, String(d.get("desc", "")), 13, GameTheme.SUBTEXT, false)
		desc_l.position = Vector2(10, 26)
		var stat := "%d LINE%s" % [int(d.get("slots", 1)),
				"" if int(d.get("slots", 1)) == 1 else "S"]
		if owned:
			stat = "OWNED - %s" % stat
		elif not next:
			stat = "NEEDS THE TIER BEFORE"
		var stat_l := UILib.label(row, stat, 13, GameTheme.LEAF if next else GameTheme.FAINT, false)
		stat_l.position = Vector2(330, 10)
		var btn_text := "OWNED" if owned else ("BUY %d" % int(d.get("cost", 0)) if next
				else "LOCKED")
		var cb: Callable = func() -> void: pass
		if next:
			cb = _on_buy_trotline
		var btn := UILib.button(row, btn_text, cb, 14, GameTheme.PANEL_LIGHT)
		btn.disabled = not next
		btn.custom_minimum_size = Vector2(120, 36)
		btn.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
		btn.offset_left = -130
		btn.offset_right = -10
		btn.offset_top = -18
		btn.offset_bottom = 18


func _on_buy_trotline() -> void:
	if GameState.buy_trotline():
		GameState.play_sound("bell")
		msg("SET LINE UPGRADED - %d SLOTS" % GameState.trotline_slots())
		_refresh_shop()
	else:
		GameState.play_sound("buzz")
		msg("NOT ENOUGH COINS FOR THAT SET LINE")

func _craft_section() -> void:
	var t := UILib.label(shop_content, "COCONUT ISLE CRAFTING", 20, GameTheme.GOLD, true,
			HORIZONTAL_ALIGNMENT_LEFT)
	t.custom_minimum_size = Vector2(0.0, 28)
	var note := UILib.label(shop_content,
			"COCONUTS: %d - CHOP PALMS ON THE ISLE (THEY REGROW IN 20 MIN)" % GameState.coconuts,
			13, GameTheme.SUBTEXT, false)
	note.custom_minimum_size = Vector2(0.0, 20)
	var axe_text := "OWNED"
	var axe_desc := "Palm axe: 3 coconuts per tree."
	var axe_stat := "AXE LEVEL %d" % GameState.axe_level
	if not GameState.has_axe:
		axe_text = "BUY %d" % ShopDB.AXE_COST
		axe_desc = "Chop palms on Coconut Isle for coconuts."
		axe_stat = "NO AXE"
	elif GameState.axe_level < 2:
		axe_text = "UPGRADE %d" % ShopDB.PALM_AXE_COST
	_craft_row("Axe", axe_desc, axe_stat, axe_text, _on_buy_axe)
	for id in ShopDB.CRAFTED_RODS.keys():
		var d: Dictionary = ShopDB.CRAFTED_RODS[id]
		var owned := ShopDB.owned("rods", String(id))
		var equipped := String(GameState.gear.get("rod", "")) == String(id)
		var btn := "EQUIPPED" if equipped else ("EQUIP" if owned else "CRAFT %d" % int(d.get("cost", 4)))
		_craft_row(String(d.get("name", id)), String(d.get("desc", "")),
				"%s  -  %d COCONUTS" % [_stat_line("rods", d), int(d.get("cost", 4))],
				btn, _on_craft.bind(String(id)))


func _craft_row(item_name: String, desc: String, stat: String, btn_text: String,
		cb: Callable) -> void:
	var row := Control.new()
	row.custom_minimum_size = Vector2(0.0, 50.0)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shop_content.add_child(row)
	var name_l := UILib.label(row, item_name, 17, GameTheme.CREAM, true)
	name_l.position = Vector2(10, 6)
	var desc_l := UILib.label(row, desc, 12, GameTheme.SUBTEXT, false)
	desc_l.position = Vector2(10, 26)
	var stat_l := UILib.label(row, stat, 13, GameTheme.LEAF, false)
	stat_l.position = Vector2(330, 10)
	var btn := UILib.button(row, btn_text, cb, 13, GameTheme.PANEL_LIGHT)
	btn.custom_minimum_size = Vector2(140, 36)
	btn.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	btn.offset_left = -150
	btn.offset_right = -10
	btn.offset_top = -18
	btn.offset_bottom = 18


func _on_buy_axe() -> void:
	if GameState.buy_axe():
		GameState.play_sound("ui")
		msg("AXE READY - ON COCONUT ISLE PRESS G TO HOLD IT")
		_refresh_shop()
	else:
		GameState.play_sound("buzz")
		msg("NOT ENOUGH COINS FOR THE AXE!")


func _on_craft(id: String) -> void:
	var err := GameState.craft_rod(id)
	if err == "":
		GameState.play_sound("ui")
		msg("%s BUILT AND EQUIPPED!" % String(ShopDB.item("rods", id).get("name", "ROD")).to_upper())
		_refresh_shop()
		return
	GameState.play_sound("buzz")
	if err == "need_coconuts":
		msg("NEED %d COCONUTS - CHOP PALMS ON COCONUT ISLE" %
				int(ShopDB.crafted_recipe(id).get("coconuts", 0)))
	else:
		msg("CAN'T CRAFT THAT RIGHT NOW")


func _is_equipped(category: String, id: String) -> bool:
	return String(GameState.gear.get(GameState.gear_key(category), "")) == id

func _stat_line(category: String, d: Dictionary) -> String:
	match category:
		"rods":
			var rod_id := String(d.get("id", ""))
			return "REEL: %.1fx  GREEN: %d%%" % [float(d.get("reel_speed", 1.0)),
					ShopDB.rod_green_percent(rod_id)]
		"lines": return "KEEP: %.0f%%" % [(1.0 - float(d.get("escape_chance", 0.3))) * 100.0]
		"baits":
			var bait_id := String(d.get("id", ""))
			var line := "%d CASTS - BAG %d - %s" % [int(d.get("charges", 1)),
					GameState.bait_count(bait_id), ", ".join(d.get("rarity_boost", []))]
			if String(GameState.gear.get("bait", "")) == bait_id:
				line += " - EQUIPPED"
			return line
		"buckets": return "CAPACITY: %d" % [int(d.get("capacity", 12))]
		"lanterns": return "NIGHT BITE x%.2f  NIGHT RARE +%.0f%%" % [
				float(d.get("night_bite", 1.0)), (float(d.get("night_rare", 1.0)) - 1.0) * 100.0]
		_: return ""


func _on_buy(category: String, id: String) -> void:
	if GameState.buy_item(category, id):
		GameState.play_sound("ui")
		_refresh_shop()
	else:
		msg("NOT ENOUGH COINS!")
		GameState.play_sound("buzz")


func _on_buy_bait(category: String, id: String) -> void:
	# A bait already in the bag equips for free; otherwise this buys more.
	var equipped := String(GameState.gear.get("bait", "")) == id
	if not equipped and GameState.bait_count(id) > 0:
		GameState.activate_bait(id)
		GameState.play_sound("ui")
		msg("%s EQUIPPED - %d CASTS LEFT" % [
				String(ShopDB.item("baits", id).get("name", "BAIT")).to_upper(),
				GameState.bait_count(id)])
		_refresh_shop()
		return
	# buy_item adds the charges and equips the bait
	if GameState.buy_item(category, id):
		GameState.play_sound("ui")
		_refresh_shop()
	else:
		msg("NOT ENOUGH COINS!")
		GameState.play_sound("buzz")


func _on_sell_all() -> void:
	if GameState.inventory.is_empty():
		msg("BUCKET EMPTY - CATCH SOME FISH FIRST")
		GameState.play_sound("buzz")
		return
	var total := GameState.sell_all()
	msg("SOLD ALL FISH FOR %d COINS!" % total)
	_refresh_shop()


## The menu panel is designed at 520x480. Shrink the whole panel on short
## windows (a landscape phone or the 640x360 minimum) instead of drawing
## the title and the last button off-screen.
func _menu_scale() -> float:
	return clampf(minf((view_size.x - 16.0) / 520.0,
			(view_size.y - 16.0) / float(MENU_PANEL_H)), 0.4, 1.0)


func _menu_button_rects() -> Array:
	var sc := _menu_scale()
	var vw := view_size.x / sc
	var vh := view_size.y / sc
	var bw := 260.0
	var bh := 34.0
	var bx := (vw - bw) * 0.5
	var by := (vh - MENU_PANEL_H) * 0.5 + 146.0
	var defs := [
		{"id": "start", "y": by, "label": "START FISHING"},
		{"id": "index", "y": by + 37.0, "label": "FISH INDEX"},
		{"id": "shop", "y": by + 74.0, "label": "TACKLE SHOP"},
		{"id": "harvest", "y": by + 111.0,
				"label": "HARVEST FEAST" if GameState.harvest_season_open() else "FEAST & ALBUM"},
		{"id": "stats", "y": by + 148.0, "label": "STATS & SOUND"},
		{"id": "settings", "y": by + 185.0, "label": "SETTINGS"},
		{"id": "updates", "y": by + 222.0,
				"label": "WHAT'S NEW!" if ChangelogLib.is_unseen() else "WHAT'S NEW"},
		{"id": "almanac", "y": by + 259.0, "label": "ALMANAC"},
	]
	var out: Array = []
	for d in defs:
		out.append({"id": d["id"], "label": d["label"],
				"rect": Rect2(Vector2(bx, float(d["y"])) * sc, Vector2(bw, bh) * sc)})
	return out


func _pixel_rect(r: Rect2, c: Color) -> void:
	if r.size.x <= 0.0 or r.size.y <= 0.0:
		return
	draw_rect(Rect2(floorf(r.position.x), floorf(r.position.y),
			maxf(1.0, floorf(r.size.x)), maxf(1.0, floorf(r.size.y))), c)


func _draw_pixel_circle(center: Vector2, radius: float, color: Color, pixel := 4.0) -> void:
	var steps := maxi(1, int(radius * 2.0 / pixel))
	for i in range(steps):
		var y := center.y - radius + (float(i) + 0.5) * pixel
		var dy := (y - center.y) / radius
		if absf(dy) > 1.0:
			continue
		var half := radius * sqrt(maxf(0.0, 1.0 - dy * dy))
		var w := maxf(pixel, floorf(half * 2.0))
		_pixel_rect(Rect2(center.x - w * 0.5, floorf(y), w, pixel), color)


## Soft pixel shadow (a flattened ellipse) used under the fisher's boots.
func _draw_ground_shadow(center: Vector2, rx: float, ry: float, color: Color) -> void:
	var rows := maxi(2, int(ry / 2.0))
	for i in range(rows):
		var y := center.y - ry + (float(i) + 0.5) * (ry * 2.0 / float(rows))
		var dy := (y - center.y) / maxf(0.001, ry)
		var w := rx * sqrt(maxf(0.0, 1.0 - dy * dy))
		if w > 0.5:
			_pixel_rect(Rect2(center.x - w, y - 1.0, w * 2.0, 2.0), color)


func _ui_panel(r: Rect2, fill: Color, border: Color, bw := 4.0) -> void:
	_pixel_rect(r, fill)
	_pixel_rect(Rect2(r.position.x, r.position.y, r.size.x, bw), border)
	_pixel_rect(Rect2(r.position.x, r.position.y + r.size.y - bw, r.size.x, bw), border)
	_pixel_rect(Rect2(r.position.x, r.position.y, bw, r.size.y), border)
	_pixel_rect(Rect2(r.position.x + r.size.x - bw, r.position.y, bw, r.size.y), border)


## Static leaf sprigs in the corners of a full-screen board. They ignore
## input and never animate, so reduce_motion leaves them untouched.
func _add_leaf_sprigs(parent: Control) -> void:
	if not SeasonTheme.is_harvest():
		return
	var c := Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(c)
	c.draw.connect(func() -> void:
		_draw_leaf_sprig(c, Vector2(18.0, 16.0))
		_draw_leaf_sprig(c, c.size - Vector2(62.0, 48.0))
	)


func _draw_leaf_sprig(c: Control, o: Vector2) -> void:
	c.draw_line(o, o + Vector2(30.0, 20.0), GameTheme.WOOD_DARK, 2.0)
	for i in range(4):
		var p := o + Vector2(8.0 + float(i) * 7.0, 5.0 + float(i) * 4.0)
		var col: Color = [GameTheme.PUMPKIN, GameTheme.GOLD, GameTheme.EMBER, GameTheme.LEAF][i]
		c.draw_colored_polygon(PackedVector2Array([p, p + Vector2(10.0, -5.0),
			p + Vector2(12.0, 4.0)]), col)


## Notched ribbon banner behind a screen title.
func _draw_ribbon_bg(r: Rect2, fill: Color, border: Color) -> void:
	var notch := minf(14.0, r.size.x * 0.08)
	var pts := PackedVector2Array([
		Vector2(r.position.x + notch, r.position.y),
		Vector2(r.position.x + r.size.x - notch, r.position.y),
		Vector2(r.position.x + r.size.x, r.position.y + r.size.y * 0.5),
		Vector2(r.position.x + r.size.x - notch, r.position.y + r.size.y),
		Vector2(r.position.x + notch, r.position.y + r.size.y),
		Vector2(r.position.x, r.position.y + r.size.y * 0.5),
	])
	draw_colored_polygon(pts, fill)
	var edge := PackedVector2Array(pts)
	edge.append(pts[0])
	draw_polyline(edge, border, 2.0)
	_pixel_rect(Rect2(r.position.x + notch + 4.0, r.position.y + 1.0,
			maxf(0.0, r.size.x - notch * 2.0 - 8.0), 2.0), GameTheme.WHEAT)


func _hud_panel(txt: String, anchor_right: bool) -> Rect2:
	var w := PixFont.text_width(txt, 3) + 24.0
	var h := 34.0
	var x := 12.0 if not anchor_right else view_size.x - w - 12.0
	var r := Rect2(x, 12.0, w, h)
	_ui_panel(r, Color(GameTheme.PANEL.darkened(0.15), 0.8), Color(GameTheme.PANEL_LIGHT, 0.9))
	PixFont.draw_text_shadowed(self, Vector2(x + 12.0, 20.0), txt, GameTheme.CREAM,
			Color("#050a12", 0.65), 3, 1, 1)
	return r


func _draw() -> void:
	var t := Time.get_ticks_msec() / 1000.0
	if shake > 0.0:
		draw_set_transform(Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * shake * 10.0)

	_draw_sky()
	_draw_clouds(t)
	_draw_mountains()
	if open_water:
		_draw_islands(t)
	elif String(art.get("trees", "pine")) != "none" and not is_island:
		_draw_treeline(t)
	_draw_water(t)
	_draw_underwater_decor(t)
	_draw_ambient_fish(t)
	if not open_water:
		_draw_bank()
	_draw_region_props(t)
	if is_island:
		_draw_palms(t)
	_draw_set_lines(t)
	_draw_ambient_particles(t)
	_draw_splashes()
	_draw_fisher(t)
	_draw_line_and_bobber(t)
	_draw_weather(t)
	_draw_water_wipe()

	draw_set_transform(Vector2.ZERO)

	if state != STATE_MENU and state != STATE_HARVEST:
		_draw_hud()
	if state == STATE_MENU:
		_draw_menu()
	if state == STATE_REEL:
		_draw_reel_meter()
	if state == STATE_CAUGHT:
		_draw_catch_popup()
	if harvest_award_t > 0.0:
		_draw_harvest_award()
	_draw_coin_fly()
	if hurt_flash > 0.0:
		draw_rect(Rect2(-40.0, -40.0, view_size.x + 80.0, view_size.y + 80.0),
				Color(1.0, 0.18, 0.28, hurt_flash * 0.32))
	if flash > 0.0:
		draw_rect(Rect2(-40.0, -40.0, view_size.x + 80.0, view_size.y + 80.0),
				Color(1.0, 1.0, 1.0, flash * 0.45))


## Palette helper: blend a day colour from the region table into night.
func _day_night(c: Color, nf: float, night_c: Color) -> Color:
	return c.lerp(night_c, nf)


func _art_c(key: String, fallback := Color.WHITE) -> Color:
	return art.get(key, fallback)


func _draw_sky() -> void:
	var nf := _night_factor()
	var top := _day_night(_art_c("sky_top"), nf, _art_c("night_top"))
	var mid := _day_night(_art_c("sky_mid"), nf, _art_c("night_mid"))
	var low := _day_night(_art_c("sky_low"), nf, _art_c("night_low"))
	var bands := 24
	for i in range(bands):
		var y0 := water_line * float(i) / float(bands)
		var y1 := water_line * float(i + 1) / float(bands)
		var tt := float(i) / float(bands - 1)
		var c: Color
		if tt < 0.45:
			c = top.lerp(mid, clampf(tt / 0.45, 0.0, 1.0))
		else:
			c = mid.lerp(low, clampf((tt - 0.45) / 0.55, 0.0, 1.0))
		draw_rect(Rect2(0.0, y0, view_size.x, y1 - y0 + 1.0), c)

	var sun_c := _art_c("sun", Color("#fff2cf"))
	if is_night:
		sun_c = Color("#e9edf7")
	var sun_y := 84.0 if String(art.get("glyph", "pond")) != "ocean" else 120.0
	_draw_pixel_circle(Vector2(view_size.x * 0.74, sun_y), 24.0, sun_c, 4.0)
	if not is_night:
		for i in range(6):
			_draw_pixel_circle(Vector2(view_size.x * 0.74 + 26.0 + float(i) * 3.0,
					sun_y - 22.0 + float(i) * 6.0), 3.0, mid, 2.0)


func _draw_clouds(t: float) -> void:
	var nf := _night_factor()
	var base := _art_c("cloud", Color("#fdf2f5"))
	base.a = 0.8
	base = base.lerp(Color("#232a4a", 0.65), nf)
	var count := 6 if GameState.quality_level() >= 1 else 4
	for i in range(count):
		var y := 40.0 + float(i) * 27.0
		var x := fposmod(float(i) * 197.0 + t * (4.0 + float(i) * 2.0), view_size.x + 320.0) - 160.0
		var w := 150.0 + float(i) * 45.0
		_pixel_rect(Rect2(x, y, w, 8.0), base)
		_pixel_rect(Rect2(x + w * 0.22, y - 8.0, w * 0.45, 8.0), base)
		_pixel_rect(Rect2(x + w * 0.6, y - 4.0, w * 0.32, 4.0), base)


func _mountain_height(x: float, f: float, amp: float, off: float) -> float:
	var h := water_line - 96.0
	h -= absf(sin(x * f + off)) * amp
	h -= sin(x * f * 2.3 + off * 1.9) * amp * 0.28
	return h


func _draw_mountains() -> void:
	var nf := _night_factor()
	var layers := [
		{"c": _art_c("mtn_far"), "amp": 58.0, "off": 0.0, "w": 8.0, "f": 0.0026},
		{"c": _art_c("mtn_mid"), "amp": 42.0, "off": 1.7, "w": 8.0, "f": 0.0041},
		{"c": _art_c("mtn_near"), "amp": 28.0, "off": 3.4, "w": 10.0, "f": 0.0062},
	]
	var count := 3
	if open_water:
		count = 1
	elif is_island:
		count = 2
	for li in range(count):
		var l: Dictionary = layers[li]
		var c: Color = (l["c"] as Color).lerp(Color("#161c30"), nf)
		var x := 0.0
		while x < view_size.x:
			var hgt := _mountain_height(x, float(l["f"]), float(l["amp"]), float(l["off"]))
			draw_rect(Rect2(x, hgt, float(l["w"]) + 1.0, water_line + 70.0 - hgt), c)
			x += float(l["w"])


## Horizon decor for the open-water section: low sand islands with palms.
func _draw_islands(t: float) -> void:
	if region == "open_trench":
		_draw_trench_rocks(t)
		return
	var nf := _night_factor()
	var sand := _art_c("bank").darkened(0.1 + nf * 0.45)
	var sand_l := _art_c("bank_light").lightened(0.05).darkened(nf * 0.5)
	var trunk := GameTheme.WOOD_DARK.lerp(Color("#101522"), nf)
	var leaf := _art_c("tree").lerp(Color("#0f1a22"), nf)
	var count := 3 if GameState.quality_level() >= 1 else 2
	for i in range(count):
		var ix := view_size.x * (0.16 + 0.34 * float(i)) + sin(t * 0.1 + float(i) * 1.7) * 2.0
		var iw := 110.0 + float(i) * 36.0
		_pixel_rect(Rect2(ix - iw * 0.5, water_line - 11.0, iw, 13.0), sand)
		_pixel_rect(Rect2(ix - iw * 0.5 + 14.0, water_line - 17.0, iw - 28.0, 7.0), sand_l)
		_pixel_rect(Rect2(ix - 3.0, water_line - 48.0, 6.0, 34.0), trunk)
		for k in range(3):
			var fy := water_line - 52.0 + float(k) * 4.0
			var reach := 16.0 + float(k) * 6.0
			_pixel_rect(Rect2(ix + 2.0, fy, reach, 5.0), leaf)
			_pixel_rect(Rect2(ix - 2.0 - reach, fy, reach, 5.0), leaf)


## Jagged black rocks replace the palm islands in the Midnight Trench.
func _draw_trench_rocks(t: float) -> void:
	var nf := _night_factor()
	var rock := _art_c("mtn_near").darkened(0.16).lerp(Color("#070b16"), nf * 0.55)
	var rock_l := _art_c("mtn_mid").darkened(0.10).lerp(Color("#111a2c"), nf * 0.45)
	for i in range(4):
		var x := view_size.x * (0.12 + 0.24 * float(i)) + sin(t * 0.18 + float(i) * 1.3) * 2.0
		var h := 34.0 + float(i % 3) * 22.0
		var base := water_line - 2.0
		_pixel_rect(Rect2(x - 22.0, base - h * 0.55, 44.0, h * 0.55), rock)
		_pixel_rect(Rect2(x - 13.0, base - h, 26.0, h * 0.5), rock_l)
		_pixel_rect(Rect2(x - 6.0, base - h - 8.0, 12.0, 10.0), rock_l.lightened(0.06))
		_pixel_rect(Rect2(x - 30.0, base - 4.0, 60.0, 5.0), rock.darkened(0.18))


## Dense swaying kelp forest for the Kelp Shelf.
func _prop_kelp(t: float, nf: float) -> void:
	var stalk := _art_c("tree").darkened(0.12).lerp(Color("#0f3028"), nf * 0.35)
	var blade := _art_c("tree").lightened(0.10).lerp(Color("#1a4a3c"), nf * 0.30)
	for i in range(10):
		var bx := 34.0 + float(i) * (view_size.x - 68.0) / 9.0
		for k in range(4):
			var y := water_line + 34.0 + float(k) * 27.0
			if y > view_size.y - 8.0:
				break
			var sway := sin(t * 1.25 + float(i) * 0.9 + float(k) * 0.55) * 7.0
			_pixel_rect(Rect2(bx + sway, y, 4.0, 26.0), stalk)
			_pixel_rect(Rect2(bx + sway - 8.0, y + 7.0, 9.0, 3.0), blade)
			_pixel_rect(Rect2(bx + sway + 3.0, y + 14.0, 8.0, 3.0), blade.darkened(0.08))


## A half-sunk wreck gives the Trench a landmark to sail toward.
func _prop_wreck(t: float, nf: float) -> void:
	var x := view_size.x * 0.76
	var y := water_line - 1.0 + sin(t * 0.9) * 1.2
	var hull := _art_c("bank_dark").darkened(0.28).lerp(Color("#070c16"), nf * 0.45)
	var wood := _art_c("bank").darkened(0.30).lerp(Color("#10192a"), nf * 0.40)
	var sail := _art_c("cloud").darkened(0.28).lerp(Color("#1c2740"), nf * 0.50)
	draw_colored_polygon(PackedVector2Array([
		Vector2(x - 58.0, y), Vector2(x - 38.0, y - 17.0), Vector2(x + 30.0, y - 11.0),
		Vector2(x + 64.0, y + 3.0), Vector2(x + 18.0, y + 8.0)]), hull)
	draw_colored_polygon(PackedVector2Array([
		Vector2(x - 38.0, y - 17.0), Vector2(x - 30.0, y - 24.0), Vector2(x + 28.0, y - 17.0),
		Vector2(x + 30.0, y - 11.0)]), wood)
	# broken mast and tattered sail
	draw_line(Vector2(x - 6.0, y - 16.0), Vector2(x - 13.0, y - 82.0), wood, 4.0)
	draw_colored_polygon(PackedVector2Array([
		Vector2(x - 13.0, y - 80.0), Vector2(x + 28.0, y - 64.0),
		Vector2(x + 16.0, y - 43.0), Vector2(x - 11.0, y - 50.0)]), sail)
	_pixel_rect(Rect2(x + 24.0, y - 66.0, 20.0, 3.0), wood.darkened(0.2))
	for i in range(4):
		_pixel_rect(Rect2(x - 46.0 + float(i) * 18.0, y - 4.0, 3.0, 13.0), wood.darkened(0.25))


func _draw_pine(x: float, base_y: float, h: float, w: float, c: Color) -> void:
	var tiers := 4
	for i in range(tiers):
		var tt := float(i) / float(tiers)
		var y := base_y - h + h * tt * 0.78
		var ww := maxf(4.0, w * (1.0 - tt * 0.45))
		_pixel_rect(Rect2(x - ww * 0.5, y, ww, maxf(3.0, h * 0.22)), c)
	_pixel_rect(Rect2(x - 2.0, base_y - h * 0.24, 4.0, h * 0.24), Color("#2a1f1c"))


## Rounded cottagecore willow for the pond bank.
func _draw_willow(x: float, base_y: float, h: float, c: Color, dark: Color, t: float) -> void:
	_pixel_rect(Rect2(x - 4.0, base_y - h * 0.7, 8.0, h * 0.7), Color("#5c4230"))
	var crown := Vector2(x, base_y - h * 0.78)
	_draw_pixel_circle(crown, h * 0.34, c, 4.0)
	_draw_pixel_circle(crown + Vector2(-h * 0.18, h * 0.06), h * 0.22, c.lightened(0.08), 4.0)
	_draw_pixel_circle(crown + Vector2(h * 0.2, h * 0.04), h * 0.20, dark, 4.0)
	for k in range(3):
		var sway := sin(t * 0.8 + float(k) * 1.2 + x * 0.01) * 2.0
		var fx := x - h * 0.3 + float(k) * h * 0.28 + sway
		draw_line(Vector2(fx, base_y - h * 0.8), Vector2(fx - 4.0, base_y - h * 0.35),
				dark, 3.0)


## White-trunked birch for the river bank.
func _draw_birch(x: float, base_y: float, h: float, c: Color, dark: Color) -> void:
	var trunk := Color("#e6e2d6")
	_pixel_rect(Rect2(x - 3.0, base_y - h * 0.75, 6.0, h * 0.75), trunk)
	for k in range(4):
		var y := base_y - h * 0.2 - float(k) * h * 0.14
		_pixel_rect(Rect2(x - 3.0, y, 6.0, 2.0), Color("#4a4a46"))
	var crown := Vector2(x, base_y - h * 0.82)
	_draw_pixel_circle(crown, h * 0.26, c, 4.0)
	_draw_pixel_circle(crown + Vector2(-h * 0.15, h * 0.05), h * 0.18, dark, 4.0)


func _draw_treeline(t: float) -> void:
	var nf := _night_factor()
	var trees := String(art.get("trees", "pine"))
	var c := _art_c("tree").lerp(Color("#0f1721"), nf * 0.85)
	var dark := _art_c("tree_dark").lerp(Color("#0a1119"), nf * 0.85)
	var q := GameState.quality_level()
	match trees:
		"willow":
			var x := 24.0
			while x < view_size.x:
				var hgt := 46.0 + sin(x * 0.045) * 10.0 + sin(x * 0.021) * 6.0
				_draw_willow(x, water_line + 10.0, hgt, c, dark, t)
				x += 74.0 if q >= 1 else 104.0
		"birch":
			var x := 26.0
			while x < view_size.x:
				var hgt := 44.0 + sin(x * 0.06) * 11.0 + sin(x * 0.027) * 5.0
				_draw_birch(x, water_line + 10.0, hgt, c, dark)
				x += 58.0 if q >= 1 else 84.0
		_:
			var rows := [
				{"c": c, "h": 34.0, "w": 13.0, "gap": 27.0, "off": 6.0},
				{"c": dark, "h": 48.0, "w": 17.0, "gap": 37.0, "off": 18.0},
			]
			if q == 0:
				rows = [rows[1]]
			for r in rows:
				var x := 20.0 + float(r["off"])
				while x < view_size.x:
					var hgt := maxf(18.0, float(r["h"]) + sin(x * 0.11) * 7.0 + sin(x * 0.031) * 5.0)
					_draw_pine(x, water_line + 8.0, hgt, float(r["w"]), r["c"])
					x += float(r["gap"])


func _draw_water(t: float) -> void:
	var nf := _night_factor()
	var depth := view_size.y - water_line
	var bands := 22
	var deep_night := Color("#0a1120")
	for i in range(bands):
		var y0 := water_line + depth * float(i) / float(bands)
		var y1 := water_line + depth * float(i + 1) / float(bands)
		var tt := float(i) / float(bands)
		var c := _art_c("w_shallow").lerp(_art_c("w_mid"), clampf(tt * 1.8, 0.0, 1.0))
		c = c.lerp(_art_c("w_deep").lerp(deep_night, nf), clampf(tt * 1.1, 0.0, 1.0))
		draw_rect(Rect2(0.0, y0, view_size.x, y1 - y0 + 1.0), c)

	var surf := _day_night(_art_c("w_surface"), nf, Color("#9fb6c8"))
	match String(art.get("wave", "ripples")):
		"current":
			for i in range(34):
				var cx := fposmod(float(i) * 83.0 + t * (110.0 + float(i % 7) * 26.0),
						view_size.x + 120.0) - 60.0
				var cy := water_line + 8.0 + fposmod(float(i) * 47.0, maxf(1.0, depth - 12.0))
				draw_rect(Rect2(cx, cy, 18.0 + float(i % 4) * 8.0, 2.0),
						Color(surf.r, surf.g, surf.b, 0.22))
			for i in range(8):
				var rx := fposmod(float(i) * 151.0 + t * 12.0, view_size.x)
				var ry := water_line + 20.0 + float(i % 3) * 26.0
				_pixel_rect(Rect2(rx, ry, 14.0, 4.0), Color(1.0, 1.0, 1.0, 0.32))
		"glassy":
			var sun_x := view_size.x * 0.74
			for i in range(12):
				var ry := water_line + 6.0 + float(i) * 7.0
				var rw := 26.0 + float(i) * 16.0
				draw_rect(Rect2(sun_x - rw * 0.5 + sin(t * 0.7 + float(i)) * 5.0, ry, rw, 2.0),
						Color(surf.r, surf.g, surf.b, 0.12))
			for i in range(18):
				var cx := fposmod(float(i) * 127.0 + t * 5.0, view_size.x)
				var cy := water_line + 14.0 + fposmod(float(i) * 71.0, maxf(1.0, depth - 20.0))
				draw_rect(Rect2(cx, cy, 34.0 + float(i % 3) * 18.0, 2.0),
						Color(surf.r, surf.g, surf.b, 0.10 + float(i % 3) * 0.02))
		"swell":
			for i in range(9):
				var base_y := water_line + 16.0 + float(i) * (depth - 20.0) / 9.0
				for k in range(3):
					var cx := fposmod(float(k) * 210.0 + float(i) * 61.0
							+ t * (9.0 + float(i) * 1.5), view_size.x + 240.0) - 120.0
					var wy := base_y + sin(t * 1.1 + float(i) * 0.9 + float(k)) * 5.0
					var ww := 80.0 + float(i % 4) * 24.0
					draw_rect(Rect2(cx, wy, ww, 4.0), Color(surf.r, surf.g, surf.b, 0.16))
					_pixel_rect(Rect2(cx + ww * 0.15, wy - 4.0, ww * 0.3, 3.0),
							Color(1.0, 1.0, 1.0, 0.20))
		_:
			for i in range(26):
				var cx := fposmod(float(i) * 61.0 + t * 9.0, view_size.x)
				var cy := water_line + 10.0 + fposmod(float(i) * 43.0, maxf(1.0, depth - 10.0))
				draw_rect(Rect2(cx, cy, 10.0, 2.0), Color(surf.r, surf.g, surf.b, 0.18))
			for i in range(10):
				var cx := fposmod(float(i) * 149.0 + t * 4.0, view_size.x)
				draw_line(Vector2(cx, water_line + 18.0 + float(i % 4) * 18.0),
						Vector2(cx + 12.0, water_line + 18.0 + float(i % 4) * 18.0),
						Color(1.0, 1.0, 1.0, 0.08), 1.0)

	var x := 0.0
	var step := 14.0 if String(art.get("wave", "ripples")) != "glassy" else 26.0
	while x < view_size.x:
		var w := 6.0 + absf(sin(x * 0.05 + t * 1.6)) * 10.0
		draw_rect(Rect2(x, water_line - 3.0, w, 4.0), surf)
		x += step


func _draw_underwater_decor(t: float) -> void:
	var nf := _night_factor()
	var q := GameState.quality_level()
	var weed := _art_c("tree_dark").lerp(Color("#0d1c14"), 0.2 + nf * 0.6)
	var weed_count := 16 if q >= 2 else (9 if q >= 1 else 5)
	for i in range(weed_count):
		var sx := 70.0 + float(i) * (38.0 if q >= 1 else 70.0)
		if sx > view_size.x - 20.0:
			break
		var seg := (view_size.y - water_line) * 0.45
		for k in range(6):
			var y := water_line + seg + float(k) * 13.0
			if y > view_size.y - 8.0:
				break
			var sway := sin(t * 1.2 + float(i) * 0.7 + float(k) * 0.5) * 6.0
			_pixel_rect(Rect2(sx + sway, y, 5.0, 13.0), weed)

	var rock := _art_c("bank_dark").lerp(Color("#0d1320"), nf)
	var rock_count := 6 if not open_water else 3
	for i in range(rock_count):
		var rx := view_size.x - 100.0 + float(i) * 17.0
		var ry := view_size.y - 24.0
		_draw_pixel_circle(Vector2(rx, ry), 12.0 + float(i % 3) * 5.0, rock, 4.0)

	for i in range(6):
		var bx := view_size.x - 220.0 + float(i) * 27.0
		var by := view_size.y - 32.0 - sin(float(i) * 0.9) * 14.0
		_pixel_rect(Rect2(bx, by, 28.0, 5.0), Color("#2c2422"))

	var bubbles := 12 if q >= 2 else 7
	for i in range(bubbles):
		var bx := fposmod(float(i) * 137.0 - t * 10.0, view_size.x)
		var span := maxf(20.0, view_size.y - water_line - 30.0)
		var by := water_line + fposmod(float(i) * 91.0 + t * 26.0, span) + 12.0
		_draw_pixel_circle(Vector2(bx, by), 2.0 + float(i % 3), Color(0.81, 0.9, 0.94, 0.35), 2.0)


func _draw_ambient_fish(t: float) -> void:
	for f in ambient_fish:
		var fish: Dictionary = f["fish"]
		var y := float(f["y"]) + sin(float(f["phase"])) * float(f["amp"])
		var s := float(f["scale"])
		var rect := Rect2(float(f["x"]) - s * 1.5, y - s * 0.55, s * 3.0, s * 1.1)
		FishArt.draw_fish(self, rect, fish, is_night, float(f["dir"]))


func _draw_bank() -> void:
	var nf := _night_factor()
	var style := String(art.get("bank_style", "grass"))
	if style == "none":
		return
	var h := view_size.y - bank_top
	match style:
		"gravel":
			var gravel := _day_night(_art_c("bank"), nf, Color("#14161f"))
			var gravel_l := _day_night(_art_c("bank_light"), nf, Color("#1e2028"))
			var soil := _day_night(_art_c("bank_soil"), nf, Color("#14161f"))
			draw_rect(Rect2(0.0, bank_top, bank_w, h + 2.0), soil)
			_pixel_rect(Rect2(0.0, bank_top - 6.0, bank_w, 14.0), gravel)
			_pixel_rect(Rect2(0.0, bank_top + 6.0, bank_w, 8.0), gravel_l)
			for i in range(56):
				var sx := fmod(float(i) * 59.0 + 7.0, maxf(1.0, bank_w - 10.0))
				var sy := bank_top - 4.0 + fmod(float(i) * 37.0, maxf(1.0, h - 10.0))
				var r := 3.0 + float(i % 3) * 2.0
				_draw_pixel_circle(Vector2(sx, sy), r,
						gravel_l if i % 2 == 0 else gravel.darkened(0.18), 2.0)
			for i in range(9):
				var sx := 18.0 + float(i) * 41.0
				if sx > bank_w - 12.0:
					break
				_pixel_rect(Rect2(sx, bank_top - 12.0, 3.0, 9.0),
						_art_c("tree").lerp(Color("#141a16"), nf * 0.6))
		"stone":
			var stone := _day_night(_art_c("bank"), nf, Color("#14161f"))
			var stone_d := _day_night(_art_c("bank_dark"), nf, Color("#10131c"))
			var stone_l := _day_night(_art_c("bank_light"), nf, Color("#1e2028"))
			draw_rect(Rect2(0.0, bank_top, bank_w, h + 2.0), stone_d)
			var row_h := 22.0
			var y := bank_top
			var row := 0
			while y < view_size.y:
				var off := 0.0 if row % 2 == 0 else 34.0
				var x := off
				while x < bank_w:
					_pixel_rect(Rect2(x + 2.0, y + 2.0, 30.0, row_h - 4.0), stone)
					_pixel_rect(Rect2(x + 2.0, y + 2.0, 30.0, 3.0), stone_l)
					x += 34.0
				y += row_h
				row += 1
			for i in range(4):
				var bx := 40.0 + float(i) * 92.0
				_pixel_rect(Rect2(bx, bank_top - 18.0, 8.0, 20.0), Color("#3f4650"))
				_pixel_rect(Rect2(bx - 3.0, bank_top - 22.0, 14.0, 6.0), Color("#5b636e"))
			_draw_pixel_circle(Vector2(bank_w - 46.0, bank_top + 32.0), 11.0, Color("#b0905a"), 3.0)
			_draw_pixel_circle(Vector2(bank_w - 46.0, bank_top + 32.0), 6.0, Color("#8a6c40"), 3.0)
			_pixel_rect(Rect2(0.0, bank_top - 3.0, bank_w, 4.0), stone_l)
		"sand":
			_draw_island_bank(nf)
		_:
			var soil := _day_night(_art_c("bank_soil"), nf, Color("#14161f"))
			var soil_l := _day_night(_art_c("bank_soil_light"), nf, Color("#1e2028"))
			draw_rect(Rect2(0.0, bank_top, bank_w, h + 2.0), soil)
			_pixel_rect(Rect2(0.0, bank_top + h * 0.55, bank_w, 6.0), soil_l)
			for i in range(46):
				var sx := fmod(float(i) * 71.0, bank_w - 12.0)
				var sy := bank_top + 22.0 + fmod(float(i) * 53.0, maxf(1.0, h - 34.0))
				_pixel_rect(Rect2(sx, sy, 6.0, 4.0), soil_l if i % 2 == 0 else soil.darkened(0.25))
			var grass := _day_night(_art_c("bank"), nf, Color("#141a20"))
			var grass_d := _day_night(_art_c("bank_dark"), nf, Color("#10161c"))
			_pixel_rect(Rect2(0.0, bank_top - 10.0, bank_w, 14.0), grass)
			_pixel_rect(Rect2(0.0, bank_top + 4.0, bank_w, 6.0), grass_d)
			var tuft := 16.0 if GameState.quality_level() >= 1 else 26.0
			var ti := 0.0
			while ti < bank_w:
				var bh := 5.0 + absf(sin(ti * 0.37)) * 9.0
				_pixel_rect(Rect2(ti, bank_top - 10.0 - bh, 4.0, bh), grass)
				ti += tuft
			for i in range(9 if GameState.quality_level() >= 1 else 5):
				_pixel_rect(Rect2(bank_w - 2.0 - float(i) * 3.0,
						bank_top + 16.0 + float(i) * 9.0, 7.0, 7.0),
						_day_night(GameTheme.ROCK, nf, Color("#10131c")))


func _draw_island_bank(nf: float) -> void:
	# A bright tropical beach in place of the usual grass bank, with a
	# little jetty on the right and the path home on the left.
	var sand := _day_night(_art_c("bank"), nf, Color("#14161f"))
	var dry := _day_night(_art_c("bank_light"), nf, Color("#1e2028"))
	var wet := _day_night(_art_c("bank_dark"), nf, Color("#10131c"))
	var h := view_size.y - bank_top
	draw_rect(Rect2(0.0, bank_top, bank_w, h + 2.0), sand)
	_pixel_rect(Rect2(0.0, bank_top - 10.0, bank_w, 14.0), dry)
	_pixel_rect(Rect2(0.0, bank_top + 4.0, bank_w, 6.0), wet)
	for i in range(24 if GameState.quality_level() >= 1 else 14):
		var sx := fmod(float(i) * 73.0 + 11.0, maxf(1.0, bank_w - 10.0))
		var sy := bank_top + 18.0 + fmod(float(i) * 41.0, maxf(1.0, h - 30.0))
		_pixel_rect(Rect2(sx, sy, 3.0, 2.0), dry)
	# the jetty the boat ties up to
	_pixel_rect(Rect2(bank_w - 6.0, bank_top - 2.0, 30.0, 6.0), GameTheme.WOOD)
	_pixel_rect(Rect2(bank_w - 2.0, bank_top + 4.0, 4.0, 26.0), GameTheme.WOOD_DARK)
	_pixel_rect(Rect2(bank_w + 14.0, bank_top + 4.0, 4.0, 26.0), GameTheme.WOOD_DARK)
	PixFont.draw_text_shadowed(self, Vector2(8.0, bank_top - 18.0), "<- DEEP SEA",
			GameTheme.CREAM, Color("#050a12", 0.6), 2, 1, 1)


## Splash droplets and expanding ripple rings at the bobber.
func _draw_splashes() -> void:
	for s in splashes:
		var p: Vector2 = s["pos"]
		var k := clampf(float(s["life"]) / float(s["max"]), 0.0, 1.0)
		var strength := float(s["strength"])
		var a := (1.0 - k) * 0.6 * strength
		var r := 5.0 + k * 40.0 * strength
		draw_arc(p, r, 0.0, TAU, 26, Color(0.9, 0.97, 1.0, a), 2.0)
		draw_arc(p, r * 0.55, 0.0, TAU, 18, Color(0.9, 0.97, 1.0, a * 0.7), 1.5)
		for d in range(5):
			var ang := float(d) * TAU / 5.0 + float(s["life"])
			var dist := 6.0 + k * (26.0 + float(d % 3) * 8.0) * strength
			var hp := p + Vector2(cos(ang) * dist, sin(ang) * dist * 0.6 - k * 10.0)
			_pixel_rect(Rect2(hp.x - 2.0, hp.y - 2.0, 4.0, 4.0),
					Color(0.94, 0.99, 1.0, (1.0 - k) * 0.8))


## Ambient particles: fireflies / dragonflies / gulls / mist / spray.
## Counts are already capped by the quality setting in _update_ambient_particles.
func _draw_ambient_particles(t: float) -> void:
	for pa in ambient_particles:
		var p: Vector2 = pa["pos"]
		var k := clampf(float(pa["life"]) / float(pa["max"]), 0.0, 1.0)
		var seed := float(pa["seed"])
		match String(pa["kind"]):
			"firefly":
				var blink := 0.35 + 0.65 * absf(sin(t * 2.4 + seed))
				draw_circle(p, 3.5, Color(1.0, 0.94, 0.5, 0.10 * blink))
				_pixel_rect(Rect2(p.x - 1.0, p.y - 1.0, 3.0, 3.0),
						Color(1.0, 0.95, 0.6, blink * minf(1.0, k * 3.0)))
			"dragonfly":
				var flap := sin(t * 26.0 + seed) * 3.0
				draw_line(p + Vector2(-4.0, flap), p + Vector2(0.0, 0.0), Color(0.75, 0.9, 0.95, 0.55), 1.5)
				draw_line(p + Vector2(4.0, flap), p + Vector2(0.0, 0.0), Color(0.75, 0.9, 0.95, 0.55), 1.5)
				_pixel_rect(Rect2(p.x - 1.0, p.y - 1.0, 6.0, 2.0), Color(0.25, 0.42, 0.32, 0.85))
			"gull":
				var dir := 1.0 if float((pa["vel"] as Vector2).x) >= 0.0 else -1.0
				var flap := sin(t * 3.2 + seed) * 5.0
				draw_line(p, p + Vector2(-12.0 * dir, -flap), Color(0.96, 0.97, 1.0, 0.85), 2.0)
				draw_line(p, p + Vector2(12.0 * dir, -flap), Color(0.96, 0.97, 1.0, 0.85), 2.0)
				_pixel_rect(Rect2(p.x - 2.0, p.y - 1.0, 5.0, 3.0), Color(0.96, 0.97, 1.0, 0.9))
			"mist":
				var w := 90.0 + seed * 18.0
				draw_rect(Rect2(p.x - w * 0.5, p.y, w, 7.0), Color(0.9, 0.95, 1.0, 0.055 * k))
				draw_rect(Rect2(p.x - w * 0.3, p.y - 5.0, w * 0.6, 5.0), Color(0.9, 0.95, 1.0, 0.04 * k))
			"spray":
				_pixel_rect(Rect2(p.x - 1.5, p.y - 1.5, 3.0, 3.0), Color(0.94, 0.99, 1.0, k * 0.75))
			"leaf":
				var lc: Color = [GameTheme.PUMPKIN, GameTheme.GOLD, GameTheme.EMBER, GameTheme.CRANBERRY][int(seed) % 4]
				lc.a = minf(1.0, k * 2.0)
				var a := t * 1.6 + seed
				var v := Vector2(cos(a), sin(a)) * 5.0
				draw_colored_polygon(PackedVector2Array([
					p + Vector2(-v.y, v.x), p + v + Vector2(v.x, -v.y) * 0.5,
					p - Vector2(-v.y, v.x) * 0.8, p - v * 0.6]), lc)
			_:
				pass


## Moving water band drawn over the world while a region change fades.
func _draw_water_wipe() -> void:
	if water_wipe <= 0.0:
		return
	var p := 1.0 - water_wipe
	var x := -160.0 + p * (view_size.x + 320.0) * 1.1
	var w := 70.0 + view_size.x * 0.14
	var c := _art_c("w_surface")
	var top := water_line * 0.55
	for i in range(3):
		var ww := w * (1.0 - float(i) * 0.22)
		draw_rect(Rect2(x - float(i) * 20.0, top, ww, view_size.y - top),
				Color(c.r, c.g, c.b, 0.055 * water_wipe))
	for i in range(8):
		var y := top + (view_size.y - top) * float(i) / 8.0
		draw_line(Vector2(x, y), Vector2(x + w * 0.8, y), Color(c.r, c.g, c.b, 0.10 * water_wipe), 2.0)


## --- Region set pieces ------------------------------------------------
## Every prop listed in RegionArt's table for the current place is drawn
## here. Counts are kept modest so the phone build never pays for art it
## cannot show at 60fps.
func _draw_region_props(t: float) -> void:
	var nf := _night_factor()
	var q := GameState.quality_level()
	for prop in art.get("props", []):
		match String(prop):
			"lily":
				_prop_lilies(t, nf, q)
			"reeds":
				_prop_reeds(t, nf)
			"willow":
				_prop_willows(t, nf)
			"ducks":
				_prop_ducks(t, nf)
			"bridge":
				_prop_bridge(nf)
			"rocks":
				_prop_rocks(t, nf)
			"whitewater":
				_prop_whitewater(t)
			"dock":
				_prop_dock(nf)
			"rowboat":
				_prop_rowboat(t, nf)
			"island_cabin":
				_prop_cabin(t, nf)
			"mist":
				if q >= 1:
					_prop_mist(t)
			"loons":
				_prop_loons(t, nf)
			"lighthouse":
				_prop_lighthouse(t, nf)
			"gulls":
				_prop_gulls(t)
			"sailboat":
				_prop_sailboat(t, nf)
			"kelp":
				_prop_kelp(t, nf)
			"wreck":
				_prop_wreck(t, nf)
			"jetty":
				_prop_jetty(nf)
			_:
				pass
	if GameState.harvest_season_open() and not open_water:
		_draw_harvest_dressing(t, nf)


## A short plank jetty reaching from the island beach into the lagoon.
func _prop_jetty(nf: float) -> void:
	var wood := _art_c("bank_dark", Color("#5b4636")).lerp(Color("#1a2430"), nf * 0.5)
	var light := _art_c("bank_light", Color("#b08a5f")).lerp(Color("#2a3746"), nf * 0.5)
	var x0 := bank_w - 10.0
	var y0 := water_line + 2.0
	for i in range(7):
		var px := x0 + float(i) * 14.0
		var py := y0 + float(i) * 2.5
		_pixel_rect(Rect2(px, py, 14.0, 7.0), wood)
		_pixel_rect(Rect2(px, py, 14.0, 2.0), light)
		if i % 2 == 0:
			_pixel_rect(Rect2(px + 5.0, py + 7.0, 4.0, 12.0), wood.darkened(0.22))


func _prop_lilies(t: float, nf: float, q: int) -> void:
	var pad := _art_c("tree").lerp(Color("#10261f"), nf * 0.5)
	var pad_light := pad.lightened(0.16)
	var n := 9 if q >= 2 else (6 if q >= 1 else 4)
	var span := maxf(120.0, view_size.x - bank_w - 60.0)
	for i in range(n):
		var x := bank_w + 40.0 + fposmod(float(i) * 149.0 + 41.0, span)
		var y := water_line + 30.0 + fposmod(float(i) * 61.0, maxf(30.0, (view_size.y - water_line) * 0.45))
		var bob := sin(t * 0.9 + float(i) * 1.3) * 1.5
		_draw_pixel_circle(Vector2(x, y + bob), 9.0 + float(i % 3) * 2.0, pad, 3.0)
		_pixel_rect(Rect2(x - 2.0, y + bob - 1.0, 6.0, 2.0), pad.darkened(0.3))
		_draw_pixel_circle(Vector2(x - 4.0, y + bob - 3.0), 5.0, pad_light, 3.0)
		if i % 3 == 0:
			_pixel_rect(Rect2(x - 1.0, y + bob - 8.0, 4.0, 6.0), Color("#f3c1d7"))
			_pixel_rect(Rect2(x + 1.0, y + bob - 9.0, 2.0, 2.0), Color("#fbe3b0"))


func _prop_reeds(t: float, nf: float) -> void:
	var stem := _art_c("tree_dark").lerp(Color("#1a2a1e"), nf * 0.5)
	for i in range(14):
		var side := 0.0 if i % 2 == 0 else 1.0
		var x := (bank_w - 26.0 + float(i % 4) * 9.0) if side < 0.5 else (view_size.x - 40.0 - float(i % 5) * 8.0)
		var base_y := water_line + 12.0
		var h := 26.0 + float(i % 4) * 9.0
		var sway := sin(t * 1.4 + float(i) * 0.8) * 4.0
		draw_line(Vector2(x, base_y), Vector2(x + sway, base_y - h), stem, 2.0)
		_pixel_rect(Rect2(x + sway - 1.0, base_y - h - 5.0, 4.0, 7.0), stem.darkened(0.2))


func _prop_willows(t: float, nf: float) -> void:
	# a couple of big willows framing the bank edge, behind the fisher
	var c := _art_c("tree").lerp(Color("#0f1a16"), nf * 0.5)
	var dark := _art_c("tree_dark").lerp(Color("#0a1410"), nf * 0.5)
	_draw_willow(bank_w - 26.0, bank_top + 4.0, 82.0, c, dark, t)
	_draw_willow(30.0, bank_top + 4.0, 70.0, c, dark, t)


func _prop_ducks(t: float, nf: float) -> void:
	var body := Color("#c8b48a").lerp(Color("#2a2f34"), nf * 0.6)
	var head := Color("#3f6b4a").lerp(Color("#20282c"), nf * 0.6)
	for i in range(2):
		var x := view_size.x * (0.62 + float(i) * 0.16) + sin(t * 0.5 + float(i) * 2.0) * 18.0
		var y := water_line + 44.0 + float(i) * 16.0 + sin(t * 1.1 + float(i)) * 2.0
		_pixel_rect(Rect2(x - 12.0, y - 5.0, 24.0, 7.0), body)
		_pixel_rect(Rect2(x + 2.0, y - 12.0, 8.0, 8.0), head)
		_pixel_rect(Rect2(x + 10.0, y - 9.0, 5.0, 3.0), Color("#e8b04a"))
		_pixel_rect(Rect2(x - 12.0, y + 2.0, 20.0, 2.0), Color(0.85, 0.95, 1.0, 0.16))
		_pixel_rect(Rect2(x - 16.0, y + 4.0, 8.0, 2.0), Color(0.85, 0.95, 1.0, 0.12))


func _prop_bridge(nf: float) -> void:
	# weathered plank bridge across the current, in the middle distance
	var x := view_size.x * 0.60
	var y := water_line + 6.0
	var wood := GameTheme.WOOD.lerp(Color("#171a22"), nf * 0.6)
	var dark := GameTheme.WOOD_DARK.lerp(Color("#10131a"), nf * 0.6)
	_pixel_rect(Rect2(x - 84.0, y, 168.0, 8.0), wood)
	for i in range(10):
		_pixel_rect(Rect2(x - 82.0 + float(i) * 17.0, y - 2.0, 14.0, 4.0), dark)
	_pixel_rect(Rect2(x - 80.0, y - 26.0, 4.0, 28.0), dark)
	_pixel_rect(Rect2(x + 76.0, y - 26.0, 4.0, 28.0), dark)
	_pixel_rect(Rect2(x - 80.0, y - 26.0, 160.0, 4.0), wood)
	for i in range(5):
		_pixel_rect(Rect2(x - 70.0 + float(i) * 36.0, y - 24.0, 3.0, 24.0), dark.lightened(0.1))
	# white water churning under the planks
	for i in range(6):
		var wx := x - 80.0 + float(i) * 30.0
		_pixel_rect(Rect2(wx, y + 10.0 + sin(i * 1.7) * 2.0, 18.0, 3.0),
				Color(0.9, 0.97, 1.0, 0.35))


func _prop_rocks(t: float, nf: float) -> void:
	var rock := _art_c("bank_dark").lerp(Color("#20242b"), nf * 0.4)
	var light := _art_c("bank_light").lerp(Color("#2c3138"), nf * 0.4)
	for i in range(7):
		var x := view_size.x * (0.58 + float(i) * 0.06)
		var y := water_line + 30.0 + float(i % 3) * 18.0
		var r := 9.0 + float(i % 3) * 4.0
		_draw_pixel_circle(Vector2(x, y), r, rock, 3.0)
		_pixel_rect(Rect2(x - r * 0.4, y - r * 0.7, r * 0.8, 3.0), light)


func _prop_whitewater(t: float) -> void:
	if GameState.quality_level() < 1:
		return
	for i in range(10):
		var x := view_size.x * 0.60 + float(i) * 26.0 - 40.0
		var y := water_line + 34.0 + float(i % 4) * 15.0 + sin(t * 3.0 + float(i)) * 2.0
		_pixel_rect(Rect2(x, y, 20.0, 4.0), Color(0.93, 0.99, 1.0, 0.42))
		_pixel_rect(Rect2(x + 6.0, y - 4.0, 8.0, 3.0), Color(0.93, 0.99, 1.0, 0.30))
		if GameState.quality_level() >= 2:
			_pixel_rect(Rect2(x + 14.0, y + 4.0, 6.0, 3.0), Color(1.0, 1.0, 1.0, 0.35))


func _prop_dock(nf: float) -> void:
	# a long wooden dock reaching into the lake
	var y := water_line + 4.0
	var x0 := bank_w - 4.0
	var length := 150.0
	var wood := GameTheme.WOOD.lerp(Color("#171a22"), nf * 0.6)
	var dark := GameTheme.WOOD_DARK.lerp(Color("#10131a"), nf * 0.6)
	_pixel_rect(Rect2(x0, y, length, 7.0), wood)
	for i in range(9):
		_pixel_rect(Rect2(x0 + float(i) * 17.0, y - 2.0, 13.0, 4.0), dark)
	for i in range(4):
		var px := x0 + 16.0 + float(i) * 40.0
		_pixel_rect(Rect2(px, y + 5.0, 4.0, 20.0), dark)
	_pixel_rect(Rect2(x0, y - 12.0, 3.0, 16.0), dark)
	_pixel_rect(Rect2(x0 + length - 3.0, y - 12.0, 3.0, 16.0), dark)
	_pixel_rect(Rect2(x0, y - 12.0, length, 3.0), wood)


func _prop_rowboat(t: float, nf: float) -> void:
	var x := bank_w + 120.0
	var y := _boat_surface_y() + sin(t * 1.3) * 1.5
	var hull := GameTheme.WOOD.lerp(Color("#1a1d25"), nf * 0.5)
	var rim := hull.lightened(0.2)
	_pixel_rect(Rect2(x - 34.0, y - 2.0, 68.0, 7.0), rim)
	_pixel_rect(Rect2(x - 30.0, y + 4.0, 60.0, 5.0), hull)
	_pixel_rect(Rect2(x - 36.0, y - 1.0, 6.0, 8.0), hull)
	_pixel_rect(Rect2(x + 30.0, y - 1.0, 6.0, 8.0), hull)
	_pixel_rect(Rect2(x - 22.0, y - 3.0, 10.0, 4.0), rim.lightened(0.1))
	draw_line(Vector2(x + 20.0, y), Vector2(x + 30.0, y - 22.0), Color("#3f3a30"), 2.0)


func _prop_cabin(t: float, nf: float) -> void:
	# forested island on the lake with a smoking cabin
	var cx := view_size.x * 0.62
	var base := water_line - 6.0
	var island := _art_c("tree").lerp(Color("#12201c"), nf * 0.55)
	_draw_pixel_circle(Vector2(cx, base), 68.0, island.darkened(0.12), 5.0)
	_draw_pixel_circle(Vector2(cx - 40.0, base), 34.0, island, 5.0)
	_draw_pixel_circle(Vector2(cx + 44.0, base), 38.0, island.darkened(0.05), 5.0)
	for i in range(7):
		var tx := cx - 58.0 + float(i) * 19.0
		_pixel_rect(Rect2(tx, base - 34.0 - float(i % 3) * 8.0, 5.0, 22.0),
				_art_c("tree_dark").lerp(Color("#0f1a16"), nf * 0.5))
	# cabin
	var cabin := GameTheme.WOOD.lerp(Color("#221f22"), nf * 0.5)
	_pixel_rect(Rect2(cx - 14.0, base - 24.0, 28.0, 18.0), cabin)
	_pixel_rect(Rect2(cx - 18.0, base - 30.0, 36.0, 7.0), cabin.darkened(0.25))
	_pixel_rect(Rect2(cx + 3.0, base - 20.0, 6.0, 6.0), GameTheme.GOLD)
	# chimney smoke: the harvest fire burns heavier
	var puffs := 9 if GameState.harvest_season_open() else 5
	for i in range(puffs):
		var sy := base - 38.0 - float(i) * 8.0 + fposmod(t * 6.0, 8.0)
		var sx := cx + 8.0 + sin(t * 0.8 + float(i)) * (2.0 + float(i) * 1.2)
		_pixel_rect(Rect2(sx, sy, 5.0 + float(i), 4.0 + float(i)), Color(0.9, 0.92, 0.95, 0.22))


func _prop_mist(t: float) -> void:
	var y := water_line - 4.0
	for i in range(5):
		var x := fposmod(float(i) * 211.0 + t * (4.0 + float(i) * 1.5), view_size.x + 260.0) - 130.0
		_pixel_rect(Rect2(x, y, 200.0 + float(i) * 34.0, 8.0), Color(0.9, 0.95, 1.0, 0.10))
		_pixel_rect(Rect2(x + 30.0, y - 7.0, 130.0 + float(i) * 20.0, 6.0), Color(0.9, 0.95, 1.0, 0.07))


func _prop_loons(t: float, nf: float) -> void:
	var body := Color("#2b3238").lerp(Color("#141a20"), nf * 0.4)
	for i in range(2):
		var x := view_size.x * (0.50 + float(i) * 0.22) + sin(t * 0.4 + float(i) * 2.2) * 20.0
		var y := water_line + 32.0 + float(i) * 9.0 + sin(t * 1.2 + float(i)) * 1.5
		_pixel_rect(Rect2(x - 9.0, y - 3.0, 18.0, 5.0), body)
		_pixel_rect(Rect2(x + 6.0, y - 10.0, 5.0, 8.0), body)
		_pixel_rect(Rect2(x + 11.0, y - 8.0, 4.0, 2.0), Color("#cfc4a0"))
		_pixel_rect(Rect2(x - 12.0, y + 3.0, 20.0, 2.0), Color(0.85, 0.95, 1.0, 0.14))


func _prop_lighthouse(t: float, nf: float) -> void:
	var x := bank_w - 86.0
	var base := bank_top
	var white := Color("#e8e2d4").lerp(Color("#20242c"), nf * 0.55)
	var red := Color("#c0453c").lerp(Color("#3a2024"), nf * 0.55)
	_pixel_rect(Rect2(x - 14.0, base - 96.0, 28.0, 96.0), white)
	_pixel_rect(Rect2(x - 16.0, base - 8.0, 32.0, 8.0), Color("#4a4d52"))
	for i in range(3):
		_pixel_rect(Rect2(x - 14.0, base - 22.0 - float(i) * 26.0, 28.0, 9.0), red)
	_pixel_rect(Rect2(x - 18.0, base - 104.0, 36.0, 8.0), Color("#3f4248"))
	_pixel_rect(Rect2(x - 10.0, base - 118.0, 20.0, 14.0), Color("#2f3a44"))
	if is_night:
		var glow := Color(1.0, 0.92, 0.55, 0.55 + 0.25 * absf(sin(t * 2.0)))
		_pixel_rect(Rect2(x - 8.0, base - 116.0, 16.0, 10.0), glow)
		draw_circle(Vector2(x, base - 111.0), 26.0, Color(1.0, 0.9, 0.5, 0.08))
		# sweeping beam
		var ang := sin(t * 0.4) * 0.5
		var dir := Vector2(cos(ang), sin(ang))
		draw_line(Vector2(x, base - 111.0), Vector2(x, base - 111.0) + dir * 220.0,
				Color(1.0, 0.93, 0.6, 0.12), 10.0)
	else:
		_pixel_rect(Rect2(x - 8.0, base - 116.0, 16.0, 10.0), Color("#8fb6c8"))


func _prop_gulls(t: float) -> void:
	for i in range(2):
		var x := view_size.x * (0.30 + float(i) * 0.24) + sin(t * 0.25 + float(i) * 1.8) * 60.0
		var y := 96.0 + float(i) * 34.0 + sin(t * 1.4 + float(i)) * 6.0
		var flap := sin(t * 3.0 + float(i)) * 4.0
		draw_line(Vector2(x - 2.0, y), Vector2(x - 14.0, y - flap), Color(0.97, 0.98, 1.0, 0.75), 2.0)
		draw_line(Vector2(x - 2.0, y), Vector2(x + 12.0, y - flap), Color(0.97, 0.98, 1.0, 0.75), 2.0)


func _prop_sailboat(t: float, nf: float) -> void:
	var x := view_size.x * 0.80 + sin(t * 0.12) * 30.0
	var y := water_line - 4.0 + sin(t * 0.7) * 1.0
	var hull := Color("#3a3f48").lerp(Color("#141820"), nf * 0.5)
	var sail := Color("#f6ead8").lerp(Color("#6f7686"), nf * 0.5)
	_pixel_rect(Rect2(x - 18.0, y, 36.0, 5.0), hull)
	draw_line(Vector2(x, y), Vector2(x, y - 34.0), hull, 2.0)
	draw_colored_polygon(PackedVector2Array([Vector2(x + 1.0, y - 34.0),
		Vector2(x + 16.0, y - 6.0), Vector2(x + 1.0, y - 6.0)]), sail)
	draw_colored_polygon(PackedVector2Array([Vector2(x - 1.0, y - 30.0),
		Vector2(x - 12.0, y - 6.0), Vector2(x - 1.0, y - 6.0)]), sail.darkened(0.08))


func _draw_palms(t: float) -> void:
	var nf := _night_factor()
	for palm in palms:
		var pid := String(palm["id"])
		var px := float(palm["x"])
		var py := float(palm["y"])
		var left := GameState.palm_regrow_left(pid)
		if left > 0:
			_pixel_rect(Rect2(px - 8.0, py - 11.0, 16.0, 9.0), GameTheme.WOOD)
			_pixel_rect(Rect2(px - 8.0, py - 11.0, 16.0, 3.0), GameTheme.CREAM)
			var label := _clock_text(left)
			var w := PixFont.text_width(label, 2) + 16.0
			_ui_panel(Rect2(px - w * 0.5, py - 58.0, w, 26.0), Color(GameTheme.PANEL.darkened(0.15), 0.9), GameTheme.GOLD, 2.0)
			PixFont.draw_text_centered(self, px, py - 54.0, label, GameTheme.GOLD, 2, 1)
			continue
		var trunk := Color("#8a643a").darkened(nf * 0.5)
		_pixel_rect(Rect2(px - 4.0, py - 70.0, 9.0, 70.0), trunk)
		_pixel_rect(Rect2(px - 1.0, py - 66.0, 3.0, 58.0), Color("#bb8b4e"))
		for k in range(5):
			_pixel_rect(Rect2(px - 4.0, py - 18.0 - float(k) * 12.0, 9.0, 3.0), GameTheme.WOOD_DARK)
		var crown := Vector2(px, py - 70.0)
		for k in range(6):
			var angle := float(k) * TAU / 6.0
			var tip := crown + Vector2(cos(angle) * 30.0, sin(angle) * 17.0)
			var mid := crown.lerp(tip, 0.5) + Vector2(0.0, -8.0)
			draw_line(mid, tip, GameTheme.PINE.darkened(nf * 0.5), 6.0)
			draw_line(crown, mid, Color("#3f8754").darkened(nf * 0.4), 5.0)
		for k in range(3):
			draw_circle(crown + Vector2(-9.0 + float(k) * 8.0, 5.0), 5.0, Color("#795236"))
		if _nearest_palm_index() >= 0 and absf(fisher_x - px) < 46.0:
			var hint := "E: CHOP" if GameState.has_axe else "NEED AXE"
			PixFont.draw_text_centered(self, px, py - 116.0 + sin(t * 5.0) * 2.0,
					hint, GameTheme.CREAM, 2, 1)


func _draw_axe(o: Vector2) -> void:
	var hand := o + Vector2(13.0, -34.0)
	draw_line(hand, hand + Vector2(18.0, -30.0), GameTheme.WOOD_DARK, 4.0)
	_pixel_rect(Rect2(hand.x + 10.0, hand.y - 34.0, 15.0, 10.0), Color("#c8d4dc"))
	_pixel_rect(Rect2(hand.x + 23.0, hand.y - 31.0, 5.0, 10.0), Color("#8a9fae"))


## A set line is a bank post with a bell, a taut line and a float with a
## READY / countdown bubble. Drawn in the world behind the fisher.
func _draw_set_lines(t: float) -> void:
	if open_water or is_island:
		return
	if not GameState.set_lines.has(region):
		return
	var post := Vector2(bank_w - 12.0, bank_top - 6.0)
	var bob := sin(t * 2.2) * 2.0
	var flt := Vector2(bank_w + 38.0, water_line + 8.0 + bob)
	# post + bell
	draw_line(post, post + Vector2(0.0, -26.0), GameTheme.WOOD_DARK, 4.0)
	draw_line(post + Vector2(0.0, -24.0), post + Vector2(0.0, -18.0), GameTheme.WOOD, 2.0)
	_draw_pixel_circle(post + Vector2(0.0, -30.0), 5.0, GameTheme.GOLD, 2.0)
	_draw_pixel_circle(post + Vector2(0.0, -30.0), 2.0, GameTheme.WHEAT, 2.0)
	# taut line and float
	draw_line(post + Vector2(0.0, -20.0), flt, GameTheme.WHEAT, 1.5)
	draw_line(flt + Vector2(0.0, 2.0), flt + Vector2(0.0, 8.0), GameTheme.WOOD_DARK, 2.0)
	draw_rect(Rect2(flt.x - 4.0, flt.y - 5.0, 8.0, 6.0), GameTheme.BOBBER_RED)
	draw_rect(Rect2(flt.x - 4.0, flt.y + 1.0, 8.0, 3.0), GameTheme.CREAM)
	draw_arc(flt + Vector2(0.0, 1.0), 9.0, 0.0, TAU, 12, Color(GameTheme.WATER_SURFACE, 0.35), 1.0)
	var ready := GameState.line_ready(region)
	var left := GameState.line_seconds_left(region)
	var txt := "READY" if ready else "%d:%02d" % [left / 60, left % 60]
	var tw := PixFont.text_width(txt, 2)
	var bx := clampf(flt.x + 18.0, 8.0, view_size.x - tw - 20.0)
	var by := clampf(water_line - 44.0, 8.0, view_size.y - 40.0)
	_ui_panel(Rect2(bx - 6.0, by - 4.0, tw + 12.0, 22.0),
			Color(GameTheme.PANEL.darkened(0.15), 0.84),
			GameTheme.GOLD if ready else GameTheme.PANEL_LIGHT)
	PixFont.draw_text_shadowed(self, Vector2(bx, by), txt,
			GameTheme.GOLD if ready else GameTheme.CREAM, Color("#050a12", 0.6), 2, 1, 1)

func _draw_fisher(t: float) -> void:
	var on_foot := not in_boat
	var bob := sin(t * 2.0) * 1.2
	var stride := 0.0
	var lift_a := 0.0
	var lift_b := 0.0
	var arm := 0.0
	var ratio := 0.0
	if on_foot and walking:
		ratio = walk_ratio
		bob = absf(sin(walk_phase)) * 1.9 * ratio
		stride = sin(walk_phase) * 5.0 * ratio
		lift_a = maxf(0.0, sin(walk_phase)) * 4.0 * ratio
		lift_b = maxf(0.0, -sin(walk_phase)) * 4.0 * ratio
		arm = sin(walk_phase) * 4.0 * ratio
	var o := Vector2(floorf(fisher_x), floorf(bank_top + bob))
	if in_boat:
		bob = sin(t * 1.9) * 2.0
		o = Vector2(floorf(boat_pos.x - 12.0), floorf(boat_pos.y - 2.0 + bob))
		_draw_boat_at(t, boat_pos, false, false)
	elif is_island:
		# the boat is moored at the jetty while you explore the beach
		_draw_boat_at(t, Vector2(bank_w + 30.0, _boat_surface_y()), true, false)
	else:
		_draw_boat_at(t, Vector2(bank_w + 44.0, _boat_surface_y()), true, false)

	# the Harvest Lantern casts a warm halo after dark
	if is_night and String(GameState.gear.get("lantern", "")) == "lantern_harvest":
		_draw_pixel_circle(o + Vector2(6.0, -28.0), 30.0, Color(1.0, 0.70, 0.30, 0.11), 6.0)
		_draw_pixel_circle(o + Vector2(6.0, -28.0), 18.0, Color(1.0, 0.78, 0.40, 0.10), 5.0)

	if on_foot:
		_draw_ground_shadow(Vector2(o.x, bank_top + 1.0), 14.0 + ratio * 1.5, 4.0,
				Color(0.04, 0.07, 0.1, 0.26))
		for d in dust:
			var p := Vector2(d["pos"])
			var a := clampf(float(d["life"]) / float(d["max_life"]), 0.0, 1.0) * 0.5
			var s := float(d["size"])
			_pixel_rect(Rect2(p.x - s * 0.5, p.y - s * 0.5, s, s), Color(0.86, 0.8, 0.66, a))

	# equipped lanterns cast a warm pool of light after dark
	if is_night and String(GameState.gear.get("lantern", "lantern_none")) != "lantern_none":
		draw_circle(o + Vector2(0.0, -18.0), 48.0, Color(1.0, 0.86, 0.55, 0.10))
		draw_circle(o + Vector2(0.0, -18.0), 26.0, Color(1.0, 0.92, 0.68, 0.09))
		_pixel_rect(Rect2(o.x + 8.0, o.y - 30.0, 5.0, 7.0), GameTheme.GOLD)
	var rod_ready := rod_out or state != STATE_WORLD
	if not rod_ready:
		_draw_rod(o, false)  # stowed across the back

	if on_foot:
		# back arm swings opposite the front arm
		_pixel_rect(Rect2(o.x - 13.0 - arm * 0.8, o.y - 45.0, 6.0, 12.0), GameTheme.SHIRT_DARK)
		_pixel_rect(Rect2(o.x - 14.0 - arm * 1.3, o.y - 35.0, 7.0, 6.0), GameTheme.SKIN)

	# back leg, then the front leg - one foot lifts while the other plants
	_pixel_rect(Rect2(o.x - 9.0 - stride * 0.7, o.y - 24.0, 7.0, 18.0 - lift_a),
			GameTheme.PANTS.darkened(0.12))
	_pixel_rect(Rect2(o.x - 11.0 - stride, o.y - 8.0 - lift_a, 9.0, 5.0), GameTheme.BOOT.darkened(0.1))

	var lean := fisher_facing * ratio * 1.0
	_pixel_rect(Rect2(o.x - 11.0 + lean, o.y - 46.0, 22.0, 24.0), GameTheme.SHIRT)
	_pixel_rect(Rect2(o.x - 11.0 + lean, o.y - 28.0, 22.0, 4.0), GameTheme.BELT)
	_pixel_rect(Rect2(o.x + 7.0 + lean, o.y - 45.0, 9.0, 15.0), GameTheme.SHIRT_DARK)
	_pixel_rect(Rect2(o.x - 6.0 + lean, o.y - 45.0, 2.0, 15.0), GameTheme.SHIRT.lightened(0.12))

	# front leg
	_pixel_rect(Rect2(o.x + 2.0 + stride * 0.7, o.y - 24.0, 7.0, 18.0 - lift_b), GameTheme.PANTS)
	_pixel_rect(Rect2(o.x + 3.0 + stride, o.y - 8.0 - lift_b, 9.0, 5.0), GameTheme.BOOT)

	# front arm (the one holding the rod / axe)
	if on_foot:
		_pixel_rect(Rect2(o.x + 8.0 + lean + arm * 0.3, o.y - 45.0, 6.0, 11.0), GameTheme.SHIRT)
		_pixel_rect(Rect2(o.x + 10.0 + lean, o.y - 36.0, 7.0, 6.0), GameTheme.SKIN)
	else:
		_pixel_rect(Rect2(o.x + 9.0, o.y - 36.0, 7.0, 6.0), GameTheme.SKIN)

	# head, hair and eye - the eye glances the way the fisher walks
	var look := 1.0 if fisher_facing > 0.0 else -1.0
	_pixel_rect(Rect2(o.x - 7.0 + lean, o.y - 62.0, 15.0, 16.0), GameTheme.SKIN)
	_pixel_rect(Rect2(o.x - 8.0 + lean, o.y - 64.0, 16.0, 7.0), GameTheme.HAIR)
	_pixel_rect(Rect2(o.x + (-9.0 if look > 0.0 else 6.0) + lean, o.y - 59.0, 3.0, 10.0),
			GameTheme.HAIR)
	_pixel_rect(Rect2(o.x + (4.0 if look > 0.0 else -9.0) + lean, o.y - 66.0, 5.0, 4.0),
			GameTheme.HAIR)
	_pixel_rect(Rect2(o.x + (3.0 if look > 0.0 else -6.0) + lean, o.y - 56.0, 3.0, 3.0), GameTheme.INK)
	_pixel_rect(Rect2(o.x - 7.0 + lean, o.y - 52.0, 3.0, 2.0), GameTheme.SKIN.darkened(0.12))
	if rod_ready:
		_draw_rod(o, true)
	elif axe_out:
		_draw_axe(o)
	elif not on_foot:
		_pixel_rect(Rect2(o.x + 9.0, o.y - 33.0, 6.0, 6.0), GameTheme.WOOD_DARK)
	if in_boat:
		_draw_boat_at(t, boat_pos, false, true)  # near gunwale over the boots


## Each rod from the shop has its own look: the Twig Rod is a crooked dark
## stick, the Willow Rod a smooth tan blank, the Bamboo Rod golden with
## segment bands, and the Reed Rod a slim pale composite.
func _rod_style() -> Dictionary:
	match String(GameState.gear.get("rod", "rod_stick")):
		"rod_wood":
			return {"c": Color("#8a6a3b"), "tip": Color("#5f4526"), "reel": Color("#c9853b"),
					"w": 3.0, "bent": false, "marks": 0}
		"rod_bamboo":
			return {"c": Color("#d9a94e"), "tip": Color("#a87c2f"), "reel": GameTheme.GOLD,
					"w": 3.0, "bent": false, "marks": 3}
		"rod_fiber":
			return {"c": Color("#9fc0cc"), "tip": Color("#7f9ef0"), "reel": Color("#cfe0ec"),
					"w": 2.0, "bent": false, "marks": 0}
		_:
			return {"c": Color("#5c3a26"), "tip": Color("#3f2718"), "reel": Color("#8a5a3b"),
					"w": 3.0, "bent": true, "marks": 0}


func _draw_rod(o: Vector2, held: bool) -> void:
	var st := _rod_style()
	var c: Color = st["c"]
	var w: float = st["w"]
	if not held:
		# stowed: strapped diagonally across the back
		draw_line(o + Vector2(-13.0, -20.0), o + Vector2(11.0, -62.0), c, w)
		_pixel_rect(Rect2(o.x + 8.0, o.y - 63.0, 6.0, 6.0), st["tip"])
		_pixel_rect(Rect2(o.x + 10.0, o.y - 33.0, 6.0, 6.0), st["reel"])
		return
	var hand := Vector2(o.x + 14.0, o.y - 38.0)
	if st["bent"]:
		# crooked twig blank: two straight segments with a kink
		var mid := hand.lerp(rod_tip, 0.5) + Vector2(3.0, 9.0)
		draw_line(hand, mid, c, w)
		draw_line(mid, rod_tip, st["tip"], w)
	else:
		draw_line(hand, rod_tip, c, w)
		var n := int(st["marks"])
		for i in range(n):
			var p := hand.lerp(rod_tip, 0.28 + 0.22 * float(i))
			_pixel_rect(Rect2(p.x - 1.0, p.y - w - 1.0, 2.0, w * 2.0 + 2.0), st["tip"])
	_pixel_rect(Rect2(o.x + 10.0, o.y - 34.0, 6.0, 6.0), st["reel"])
	draw_circle(rod_tip + Vector2(0.0, -2.0), 2.5, st["tip"])


## Pixel boat art. `moored` draws it bobbing at the shore dock; otherwise
## it sits under the fisher. Drawn in two passes around the fisher: the
## hull first (`front = false`), then the near gunwale (`front = true`)
## so the fisher stands *inside* the boat. Hull style and size follow the
## equipped boat from the Boat Dealer.
func _draw_boat_at(t: float, c: Vector2, moored: bool, front: bool) -> void:
	var id := String(GameState.gear.get("boat", "boat_raft"))
	var w := 96.0
	var hull := GameTheme.WOOD
	var hull_dark := GameTheme.WOOD_DARK
	var rim := Color("#e2b072")
	var cabin := false
	match id:
		"boat_raft":
			w = 84.0
			hull = Color("#a8763e")
			hull_dark = Color("#7d5429")
			rim = Color("#c99a5e")
		"boat_skiff":
			w = 112.0
			hull = Color("#e8e2d0")
			hull_dark = Color("#4e6472")
			rim = Color("#fdfaf2")
		"boat_trawler":
			w = 132.0
			hull = Color("#b0483a")
			hull_dark = Color("#7c2f24")
			rim = Color("#d8b088")
			cabin = true
		"boat_harvest":
			w = 164.0
			hull = Color("#a3662f")
			hull_dark = Color("#4a2d17")
			rim = Color("#f2b03c")
			cabin = false
	var bob := sin(t * 2.4 + 1.0) * 1.5 if moored else sin(t * 1.9) * 2.0
	var b := Vector2(c.x, c.y + bob)
	var hw := w * 0.5
	if front:
		# near gunwale, drawn over the fisher's boots so they stand inside
		_pixel_rect(Rect2(b.x - hw + 6.0, b.y - 5.0, w - 12.0, 7.0), rim)
		_pixel_rect(Rect2(b.x - hw + 6.0, b.y + 2.0, w - 12.0, 3.0), hull_dark)
		for i in range(4):
			_pixel_rect(Rect2(b.x - hw + 16.0 + float(i) * (w - 38.0) / 3.0, b.y - 5.0, 2.0, 7.0),
					rim.darkened(0.22))
		_draw_hull_waterline(b.x, hw, w)
		return
	# shadow / wake at the waterline, so the hull sits ON the surface
	_pixel_rect(Rect2(b.x - hw - 4.0, water_line + 2.0, w + 8.0, 5.0), Color("#0a1120", 0.28))
	if id == "boat_harvest" and not moored and walking:
		_draw_harvest_wake(b, hw, t)
	if not moored and walking:
		for i in range(3):
			_pixel_rect(Rect2(b.x - hw - 14.0 - float(i) * 9.0, water_line + 2.0 + float(i) * 3.0,
					7.0, 2.0), Color("#dfeef2", 0.35))
	if id == "boat_raft":
		# three lashed logs with rounded ends
		for i in range(3):
			var ly := b.y + float(i) * 6.0
			_pixel_rect(Rect2(b.x - hw, ly, w, 6.0), hull if i < 2 else hull_dark)
			_pixel_rect(Rect2(b.x - hw - 3.0, ly, 4.0, 6.0), hull_dark)
			_pixel_rect(Rect2(b.x + hw - 1.0, ly, 4.0, 6.0), hull_dark)
		for i in range(3):
			_pixel_rect(Rect2(b.x - hw + 10.0 + float(i) * (w - 24.0) * 0.5, b.y - 1.0, 3.0, 16.0),
					rim.darkened(0.2))
		_draw_hull_waterline(b.x, hw, w)
		return
	if cabin:
		# wheelhouse behind the fisher
		_pixel_rect(Rect2(b.x - hw * 0.45, b.y - 26.0, 38.0, 24.0), rim)
		_pixel_rect(Rect2(b.x - hw * 0.45, b.y - 26.0, 38.0, 4.0), hull_dark)
		_pixel_rect(Rect2(b.x - hw * 0.45 + 5.0, b.y - 20.0, 10.0, 9.0), Color("#3d5a70"))
		_pixel_rect(Rect2(b.x - hw * 0.45 + 23.0, b.y - 20.0, 10.0, 9.0), Color("#3d5a70"))
	# hull: stacked slabs with rising bow / stern tips
	_pixel_rect(Rect2(b.x - hw + 10.0, b.y + 8.0, w - 20.0, 8.0), hull_dark)
	_pixel_rect(Rect2(b.x - hw + 4.0, b.y + 1.0, w - 8.0, 8.0), hull)
	_pixel_rect(Rect2(b.x - hw - 2.0, b.y - 6.0, 12.0, 14.0), hull)
	_pixel_rect(Rect2(b.x + hw - 10.0, b.y - 8.0, 12.0, 16.0), hull)
	_pixel_rect(Rect2(b.x - hw - 2.0, b.y - 6.0, 12.0, 3.0), rim)
	_pixel_rect(Rect2(b.x + hw - 10.0, b.y - 8.0, 12.0, 3.0), rim)
	# dark interior + a seat thwart
	_pixel_rect(Rect2(b.x - hw + 12.0, b.y - 3.0, w - 24.0, 5.0), hull_dark.darkened(0.2))
	_pixel_rect(Rect2(b.x - 28.0, b.y - 4.0, 18.0, 5.0), rim.darkened(0.1))
	# plank lines on the hull side
	for i in range(3):
		_pixel_rect(Rect2(b.x - hw + 16.0 + float(i) * (w - 40.0) * 0.5, b.y + 2.0, 2.0, 6.0),
				hull.darkened(0.22))
	if id == "boat_harvest":
		_draw_harvest_canopy(b, hw, w)
		_draw_harvest_boat_details(b, hw, w)
	_draw_hull_waterline(b.x, hw, w)


## Golden leaves trail behind the Queen while she is under way.
func _draw_harvest_wake(b: Vector2, hw: float, t: float) -> void:
	for i in range(5):
		var x := b.x - hw - 7.0 - float(i) * 8.0
		var y := water_line + 4.0 + sin(t * 3.1 + float(i) * 1.4) * 2.0
		var c: Color = [GameTheme.PUMPKIN, GameTheme.GOLD, GameTheme.EMBER, GameTheme.LEAF][i % 4]
		c.a = 0.55
		draw_colored_polygon(PackedVector2Array([
			Vector2(x, y), Vector2(x + 6.0, y - 3.0), Vector2(x + 7.0, y + 2.0)]), c)


## A striped festival canopy, twin lanterns and a pumpkin finial make the
## Queen read as the event's grand prize from across the water.
func _draw_harvest_canopy(b: Vector2, hw: float, w: float) -> void:
	var roof_y := b.y - 96.0
	var left := b.x - hw + 8.0
	var right := b.x + hw - 8.0
	# posts
	for px in [-hw * 0.64, hw * 0.64]:
		_pixel_rect(Rect2(b.x + px - 2.0, roof_y + 4.0, 4.0, 94.0), GameTheme.WOOD_DARK)
		_pixel_rect(Rect2(b.x + px - 3.0, roof_y + 2.0, 6.0, 4.0), GameTheme.GOLD.darkened(0.18))
	# striped roof and scalloped valance
	var bands := 8
	var bw := (right - left) / float(bands)
	for i in range(bands):
		var c: Color = GameTheme.CREAM if i % 2 == 0 else GameTheme.PUMPKIN
		_pixel_rect(Rect2(left + float(i) * bw, roof_y, bw + 1.0, 10.0), c)
		_pixel_rect(Rect2(left + float(i) * bw, roof_y + 12.0, bw, 4.0), c.darkened(0.04))
		_pixel_rect(Rect2(left + float(i) * bw + 2.0, roof_y + 16.0, bw - 4.0, 2.0),
				c.darkened(0.12))
	_pixel_rect(Rect2(left - 2.0, roof_y - 2.0, right - left + 4.0, 3.0), GameTheme.GOLD)
	_pixel_rect(Rect2(left, roof_y + 10.0, right - left, 2.0), GameTheme.EMBER.darkened(0.24))
	# pumpkin finial
	_pixel_rect(Rect2(b.x - 4.0, roof_y - 12.0, 8.0, 10.0), GameTheme.PUMPKIN)
	_pixel_rect(Rect2(b.x - 2.0, roof_y - 15.0, 4.0, 4.0), GameTheme.PUMPKIN.lightened(0.16))
	_pixel_rect(Rect2(b.x - 1.0, roof_y - 18.0, 2.0, 4.0), GameTheme.LEAF)
	# twin lanterns hanging from the valance
	for px in [-hw * 0.34, hw * 0.34]:
		var lx: float = b.x + float(px)
		draw_line(Vector2(lx, roof_y + 16.0), Vector2(lx, roof_y + 22.0), GameTheme.WOOD_DARK, 1.0)
		draw_circle(Vector2(lx, roof_y + 26.0), 8.0, Color(1.0, 0.76, 0.30, 0.16))
		_pixel_rect(Rect2(lx - 3.0, roof_y + 22.0, 6.0, 6.0), GameTheme.GOLD)


## The Harvest Queen: varnished planks, a leaf garland on the bow, a stern
## lantern, a pennant and a glassy waterline.
func _draw_harvest_boat_details(b: Vector2, hw: float, w: float) -> void:
	# gilded gunwale plank
	_pixel_rect(Rect2(b.x - hw + 2.0, b.y + 1.0, w - 4.0, 2.0), GameTheme.GOLD)
	_pixel_rect(Rect2(b.x - hw + 6.0, b.y + 10.0, w - 12.0, 2.0), GameTheme.GOLD.darkened(0.3))
	# leaf garland draped over the bow
	for i in range(7):
		var lx := b.x - hw + 10.0 + float(i) * 5.0
		var ly := b.y - 6.0 + sin(float(i) * 1.1) * 2.0 + float(i) * 0.8
		var lc: Color = [GameTheme.PUMPKIN, GameTheme.EMBER, GameTheme.GOLD, GameTheme.LEAF][i % 4]
		draw_colored_polygon(PackedVector2Array([
			Vector2(lx, ly), Vector2(lx + 5.0, ly - 3.0), Vector2(lx + 6.0, ly + 2.0)]), lc)
	# carved pumpkin on the bow
	var px := b.x - hw + 5.0
	_pixel_rect(Rect2(px, b.y - 13.0, 13.0, 10.0), GameTheme.PUMPKIN)
	_pixel_rect(Rect2(px + 3.0, b.y - 16.0, 7.0, 4.0), GameTheme.PUMPKIN.lightened(0.12))
	_pixel_rect(Rect2(px + 6.0, b.y - 18.0, 2.0, 3.0), GameTheme.LEAF)
	# stern lantern on a short post
	_pixel_rect(Rect2(b.x + hw - 16.0, b.y - 24.0, 3.0, 18.0), GameTheme.WOOD_DARK)
	_pixel_rect(Rect2(b.x + hw - 19.0, b.y - 30.0, 9.0, 8.0), GameTheme.HUSK)
	var glow := GameTheme.GOLD
	glow.a = 0.28
	draw_circle(Vector2(b.x + hw - 14.5, b.y - 26.0), 12.0, glow)
	_pixel_rect(Rect2(b.x + hw - 18.0, b.y - 29.0, 7.0, 6.0), GameTheme.GOLD)
	# pennant at the bow
	_pixel_rect(Rect2(b.x - hw + 2.0, b.y - 34.0, 2.0, 30.0), GameTheme.WOOD_DARK)
	draw_colored_polygon(PackedVector2Array([
		Vector2(b.x - hw + 4.0, b.y - 34.0), Vector2(b.x - hw + 22.0, b.y - 29.0),
		Vector2(b.x - hw + 4.0, b.y - 24.0)]), GameTheme.CRANBERRY)
	draw_colored_polygon(PackedVector2Array([
		Vector2(b.x - hw + 4.0, b.y - 34.0), Vector2(b.x - hw + 16.0, b.y - 31.0),
		Vector2(b.x - hw + 4.0, b.y - 28.0)]), GameTheme.GOLD)


## Water lapping at the hull where it meets the surface, so the boat reads
## as floating on top of the water instead of sinking through it.
func _draw_hull_waterline(bx: float, hw: float, w: float) -> void:
	var surf := GameTheme.WATER_SURFACE
	_pixel_rect(Rect2(bx - hw - 3.0, water_line - 2.0, w + 6.0, 4.0),
			Color(surf.r, surf.g, surf.b, 0.5))
	for i in range(3):
		_pixel_rect(Rect2(bx - hw + 4.0 + float(i) * (w - 16.0) * 0.5, water_line - 3.0,
				10.0, 2.0), Color(surf.r, surf.g, surf.b, 0.35))


## Autumn dressing on the bank: pumpkins, corn-stalk bundles, straw bales,
## a lit quay lantern in the Deep Sea and leaves drifting on the water.
## Pure decoration - it never changes a hit target or a fish pool.
func _draw_harvest_dressing(t: float, nf: float) -> void:
	var straw := GameTheme.WHEAT.lerp(Color("#3a2a1a"), nf * 0.30)
	var straw_dark := straw.darkened(0.25)
	var glow := Color(1.0, 0.62, 0.22, 0.10 + nf * 0.12)
	# pumpkins tucked along the bank
	var spots := [Vector2(bank_w * 0.08, bank_top + 26.0), Vector2(bank_w * 0.30, bank_top + 20.0),
		Vector2(bank_w * 0.62, bank_top + 30.0), Vector2(bank_w * 0.88, bank_top + 24.0)]
	for i in range(spots.size()):
		var c: Vector2 = spots[i]
		var rad := 8.0 + float(i % 2) * 3.0
		var col: Color = [GameTheme.PUMPKIN, GameTheme.EMBER, GameTheme.GOLD][i % 3]
		col = col.lerp(Color("#5a2a14"), nf * 0.35)
		if nf > 0.35:
			_draw_pixel_circle(c + Vector2(0.0, -2.0), rad * 2.0, glow, 5.0)
		_draw_pixel_circle(c, rad, col, 3.0)
		_pixel_rect(Rect2(c.x - rad * 0.2, c.y - rad * 1.05, 3.0, 4.0), straw_dark)
		# jack-o'-lantern face after dark
		if nf > 0.4:
			_pixel_rect(Rect2(c.x - rad * 0.5, c.y - 2.0, 3.0, 3.0), GameTheme.GOLD)
			_pixel_rect(Rect2(c.x + rad * 0.3, c.y - 2.0, 3.0, 3.0), GameTheme.GOLD)
			_pixel_rect(Rect2(c.x - 3.0, c.y + 3.0, 6.0, 2.0), GameTheme.GOLD)
	# straw bales
	for i in range(2):
		var bx := bank_w * 0.42 + float(i) * 58.0
		var by := bank_top + 30.0
		_pixel_rect(Rect2(bx, by, 34.0, 18.0), straw)
		_pixel_rect(Rect2(bx, by, 34.0, 3.0), straw.lightened(0.18))
		for j in range(3):
			_pixel_rect(Rect2(bx + 4.0 + float(j) * 10.0, by + 4.0, 2.0, 12.0), straw_dark)
	# corn-stalk bundles
	for i in range(3):
		var cx := bank_w * 0.18 + float(i) * 22.0
		var top := bank_top - 26.0 + float(i % 2) * 6.0
		_pixel_rect(Rect2(cx, top, 3.0, bank_top + 34.0 - top), straw_dark)
		_pixel_rect(Rect2(cx + 5.0, top + 4.0, 3.0, bank_top + 30.0 - top), straw_dark)
		_pixel_rect(Rect2(cx - 6.0, top + 14.0, 12.0, 3.0), GameTheme.LEAF.lerp(Color("#4a3a1a"), nf * 0.3))
		_pixel_rect(Rect2(cx - 2.0, top + 4.0, 6.0, 8.0), GameTheme.GOLD.lerp(Color("#5a3a12"), nf * 0.3))
	# a lit lantern post on the Deep Sea quay
	if region == "ocean" or region == "open":
		var lx := bank_w - 26.0
		var ly := bank_top - 6.0
		_pixel_rect(Rect2(lx, ly - 46.0, 4.0, 46.0), GameTheme.WOOD_DARK)
		_pixel_rect(Rect2(lx - 3.0, ly - 56.0, 10.0, 12.0), GameTheme.HUSK)
		if nf > 0.2:
			_draw_pixel_circle(Vector2(lx + 2.0, ly - 50.0), 22.0, Color(1.0, 0.72, 0.30, 0.10 + nf * 0.12), 5.0)
		_pixel_rect(Rect2(lx - 1.0, ly - 54.0, 6.0, 8.0), GameTheme.GOLD)
	# leaves drifting on the water (frozen entirely under reduce motion)
	if GameState.reduce_motion():
		return
	for i in range(8):
		var lx := fposmod(float(i) * 131.0 + t * (7.0 + float(i) * 1.5), view_size.x)
		var ly := water_line + 14.0 + fposmod(float(i) * 47.0 + t * 3.0,
				maxf(1.0, view_size.y - water_line - 24.0))
		var lc: Color = [GameTheme.PUMPKIN, GameTheme.GOLD, GameTheme.EMBER, GameTheme.CRANBERRY][i % 4]
		lc.a = 0.85
		_pixel_rect(Rect2(lx, ly, 6.0, 3.0), lc)
		_pixel_rect(Rect2(lx + 2.0, ly - 2.0, 3.0, 2.0), lc.lightened(0.15))


func _draw_dotted_line(from: Vector2, to: Vector2, c: Color, segs := 18, sag := 16.0) -> void:
	for i in range(1, segs):
		var f := float(i) / float(segs)
		var p := from.lerp(to, f)
		p.y += sin(f * PI) * sag
		_pixel_rect(Rect2(p.x - 1.5, p.y - 1.5, 3.0, 3.0), c)


func _draw_line_and_bobber(t: float) -> void:
	if state == STATE_WORLD:
		if rod_out:
			_draw_dotted_line(rod_tip, cast_target, Color("#f7f3e8", 0.35), 16, 12.0)
		return
	if state == STATE_CAST or state == STATE_BITE or state == STATE_REEL:
		_draw_dotted_line(rod_tip, bobber_pos, Color("#f7f3e8"), 18, 16.0)
		var bob_c := GameTheme.BOBBER_RED
		_pixel_rect(Rect2(bobber_pos.x - 5.0, bobber_pos.y - 7.0, 10.0, 10.0), GameTheme.CREAM)
		_pixel_rect(Rect2(bobber_pos.x - 5.0, bobber_pos.y - 7.0, 10.0, 5.0), bob_c)
		_pixel_rect(Rect2(bobber_pos.x - 1.0, bobber_pos.y - 11.0, 2.0, 4.0), GameTheme.INK)
		if state == STATE_BITE and hooked:
			var alpha := absf(sin(t * 8.0))
			PixFont.draw_text_shadowed(self, Vector2(bobber_pos.x - 6.0, bobber_pos.y - 38.0),
					"!", Color(1.0, 0.95, 0.75, 0.4 + alpha * 0.6), Color(0.1, 0.05, 0.05, alpha * 0.6), 4, 1, 1)
		if catch_fish_id != "" and state == STATE_REEL:
			var s := 32.0
			var sy := water_line + 46.0 + sin(t * 3.0) * 6.0
			FishArt.draw_fish(self, Rect2(bobber_pos.x - s * 1.5, sy - s * 0.55, s * 3.0, s * 1.1),
					FishDB.fish_data(catch_fish_id), true, -1.0)


func _draw_reel_meter() -> void:
	var w := 420.0
	var h := 48.0
	var x := (view_size.x - w) * 0.5
	var y := view_size.y - 96.0
	_ui_panel(Rect2(x, y, w, h), Color(GameTheme.PANEL.darkened(0.15), 0.85), Color(GameTheme.PANEL_LIGHT, 0.95))
	var bar_x := x + 16.0
	var bar_w := w - 32.0
	var bar_y := y + 22.0
	_pixel_rect(Rect2(bar_x, bar_y, bar_w, 12.0), GameTheme.PANEL.darkened(0.18))
	if _is_tug_fight():
		var band := _tug_band()
		_pixel_rect(Rect2(bar_x + bar_w * (tug_center - band), bar_y, bar_w * band * 2.0, 12.0), GameTheme.LEAF)
		_pixel_rect(Rect2(bar_x + bar_w * reel_tension - 2.0, bar_y - 5.0, 4.0, 22.0), GameTheme.CREAM)
		PixFont.draw_text_shadowed(self, Vector2(bar_x, y + 6.0), "HOLD TO REEL - FOLLOW THE GREEN",
				GameTheme.CREAM, Color("#050a12", 0.6), 2, 1, 1)
	else:
		var good := _green_half()
		_pixel_rect(Rect2(bar_x + bar_w * (timing_center - good), bar_y, bar_w * good * 2.0, 12.0),
				GameTheme.LEAF)
		_pixel_rect(Rect2(bar_x + bar_w * timing_center - 1.5, bar_y, 3.0, 12.0), GameTheme.GOLD)
		_pixel_rect(Rect2(bar_x + bar_w * reel_pos - 2.0, bar_y - 5.0, 4.0, 22.0), GameTheme.CREAM)
		var hint := "HIT THE GREEN - SET ONCE PER FISH"
		PixFont.draw_text_shadowed(self, Vector2(bar_x, y + 6.0), hint,
				GameTheme.CREAM, Color("#050a12", 0.6), 2, 1, 1)


func _draw_hud() -> void:
	var coins_r := _hud_panel("COINS %d" % GameState.coins, true)
	var harvest_on := GameState.harvest_season_open()
	if harvest_on:
		_draw_harvest_chip(coins_r)
	var area_label := RegionArt.display(region)
	if open_water:
		area_label = "%s  %d/%d" % [area_label.to_upper(), open_zone + 1, OPEN_ZONES.size()]
	var rt := "%s  %s  %s" % [area_label.to_upper(),
			"NIGHT" if is_night else "DAY", _weather_label()]
	var left_r: Rect2 = _hud_panel("BUCKET %d/%d" % [GameState.inventory_count(), GameState.bucket_capacity()], false)
	RegionArt.draw_glyph(self, String(art.get("glyph", "pond")),
			Vector2(16.0, 68.0), 15.0, GameTheme.CREAM)
	PixFont.draw_text_shadowed(self, Vector2(30.0, 54.0), rt,
			GameTheme.WHEAT, Color("#050a12", 0.6), 2, 1, 1)
	var forecast := "NEXT %s IN %ds" % [_weather_name(weather_next), maxi(0, int(ceil(weather_timer)))]
	PixFont.draw_text_shadowed(self, Vector2(12.0, 82.0), forecast,
			GameTheme.SUBTEXT, Color("#050a12", 0.6), 2, 1, 1)
	var daily_id := GameState.daily_fish_id()
	if daily_id != "":
		var daily_txt := "DAILY: %s x2" % fish_name(daily_id).to_upper()
		PixFont.draw_text_shadowed(self, Vector2(12.0, 100.0), daily_txt,
				GameTheme.GOLD, Color("#050a12", 0.6), 2, 1, 1)
	var touch := touch_controls != null and touch_controls.enabled
	# On touch the bottom hint already explains the controls and the left
	# column belongs to the on-screen buttons, so skip the keyboard line.
	if not touch:
		if is_island:
			PixFont.draw_text_shadowed(self, Vector2(12.0, left_r.position.y + 120.0),
					"G AXE - E OR CLICK CHOP",
					GameTheme.SUBTEXT, Color("#050a12", 0.6), 2, 1, 1)
			PixFont.draw_text_shadowed(self, Vector2(12.0, left_r.position.y + 138.0),
					"WALK WEST TO SAIL HOME",
					GameTheme.SUBTEXT, Color("#050a12", 0.6), 2, 1, 1)
		elif not open_water:
			# Keep this to short left-hand lines: the boat/bait readout lives
			# in the same band on the right, and five more keys no longer fit
			# on one line at the 960x540 base size.
			PixFont.draw_text_shadowed(self, Vector2(12.0, left_r.position.y + 120.0),
					"1-4 SPOTS - R ROD - B BOAT",
					GameTheme.SUBTEXT, Color("#050a12", 0.6), 2, 1, 1)
			PixFont.draw_text_shadowed(self, Vector2(12.0, left_r.position.y + 138.0),
					"P LINE - I INDEX - ESC PAUSE",
					GameTheme.SUBTEXT, Color("#050a12", 0.6), 2, 1, 1)
	var right_y := 112.0 if harvest_on else 52.0
	var boat_txt := "BOAT: %s" % String(GameState.current_boat().get("name", "Old Raft")).to_upper()
	PixFont.draw_text_shadowed(self,
			Vector2(view_size.x - PixFont.text_width(boat_txt, 2) - 12.0, right_y),
			boat_txt, GameTheme.WHEAT, Color("#050a12", 0.6), 2, 1, 1)
	var bait_txt := _bait_hud_text()
	var bait_c := GameTheme.LEAF if String(GameState.gear.get("bait", "")) != "" else GameTheme.PUMPKIN
	PixFont.draw_text_shadowed(self,
			Vector2(view_size.x - PixFont.text_width(bait_txt, 2) - 12.0, right_y + 20.0),
			bait_txt, bait_c, Color("#050a12", 0.6), 2, 1, 1)
	var streak := int(GameState.stats.get("current_streak", 0))
	if streak > 0:
		var streak_txt := "STREAK x%d  +%d%%" % [streak, int((GameState.streak_sale_mult() - 1.0) * 100.0)]
		PixFont.draw_text_shadowed(self,
				Vector2(view_size.x - PixFont.text_width(streak_txt, 2) - 12.0, right_y + 40.0),
				streak_txt, GameTheme.LEAF, Color("#050a12", 0.6), 2, 1, 1)
	# Set lines: slot count always, a blinking prompt once one is ready.
	if GameState.trotline_slots() > 0 or GameState.line_slots_used() > 0:
		var lines_txt := "LINES %d/%d" % [GameState.line_slots_used(), GameState.trotline_slots()]
		PixFont.draw_text_shadowed(self,
				Vector2(view_size.x - PixFont.text_width(lines_txt, 2) - 12.0, right_y + 60.0),
				lines_txt, GameTheme.WHEAT, Color("#050a12", 0.6), 2, 1, 1)
	if GameState.line_ready_any() and int(Time.get_ticks_msec() / 500) % 2 == 0:
		var ready_txt := "LINE READY - P"
		PixFont.draw_text_shadowed(self,
				Vector2(view_size.x - PixFont.text_width(ready_txt, 2) - 12.0, right_y + 80.0),
				ready_txt, GameTheme.GOLD, Color("#050a12", 0.6), 2, 1, 1)

	_draw_event_banner(12.0)
	_draw_arrival()
	_draw_reticle()
	_draw_saved_toast()

	if msg_text != "" and state != STATE_REEL:
		var txt := msg_text
		var ps := 3
		while ps > 1 and PixFont.text_width(txt, ps) > view_size.x - 60.0:
			ps -= 1
		var tw := PixFont.text_width(txt, ps)
		var mx := (view_size.x - tw) * 0.5
		# Touch keeps a six-button row above CAST; lift world messages clear of it.
		var my := view_size.y - (230.0 if touch else 150.0)
		_ui_panel(Rect2(mx - 14.0, my - 8.0, tw + 28.0, 30.0), Color(GameTheme.PANEL.darkened(0.15), 0.72), Color(GameTheme.PANEL_LIGHT, 0.8))
		PixFont.draw_text_shadowed(self, Vector2(mx, my), txt, GameTheme.CREAM,
				Color("#050a12", 0.65), ps, 1, 1)

	if state == STATE_WORLD:
		var hint := "A/D WALK - AIM WITH MOUSE - SPACE TO CAST - P LINE - ESC PAUSE"
		if touch:
			hint = "STICK TO WALK - TAP TO CAST - TAP IDX FOR YOUR FISH"
		if is_island:
			hint = "G AXE - E CHOP - WALK WEST TO SAIL HOME - ESC FOR THE SHOP"
			if touch:
				hint = "AXE AND CHOP BUTTONS - STICK LEFT TO SAIL HOME - MENU FOR SHOP"
		elif open_water:
			var z := _open_zone_data()
			var west := "RETURN TO SHORE" if open_zone == 0 else "WEST: " + String(OPEN_ZONES[open_zone - 1].get("name", ""))
			var east := "FAR EDGE" if open_zone >= OPEN_ZONES.size() - 1 else "EAST: " + String(OPEN_ZONES[open_zone + 1].get("name", ""))
			hint = "%s - A/D SAIL - SPACE TO CAST - %s / %s" % [
				String(z.get("name", "OPEN WATER")), west, east]
			if touch:
				hint = "STICK TO SAIL - TAP TO CAST - WEST / EAST AT THE EDGE"
		elif in_boat:
			hint = "A/D SAIL - AIM WITH MOUSE - SPACE OR CLICK TO CAST - B TO LAND"
			if touch:
				hint = "STICK TO SAIL - TAP TO CAST - BOAT TO LAND"
			if region == "ocean":
				hint = "SAIL EAST TO COCONUT ISLE - SPACE TO CAST - B TO LAND"
				if touch:
					hint = "STICK RIGHT TO REACH COCONUT ISLE - TAP TO CAST"
		elif not rod_out:
			hint = "ROD AWAY - PRESS R TO TAKE IT OUT - B TO BOARD YOUR BOAT"
			if touch:
				hint = "TAP ROD TO READY IT - TAP BOAT TO BOARD"
		var hw := PixFont.text_width(hint, 2)
		PixFont.draw_text_shadowed(self, Vector2((view_size.x - hw) * 0.5, view_size.y - 26.0), hint,
				GameTheme.SUBTEXT, Color("#050a12", 0.6), 2, 1, 1)


## Pumpkin pill under the coins panel: tokens + time left, warning-toned
## in the final three days. It replaces the 2X coin chip during the feast.
func _draw_harvest_chip(coins_r: Rect2) -> void:
	var txt := "%d TOKENS - %s" % [GameState.harvest_tokens(), GameState.harvest_time_text()]
	var w := PixFont.text_width(txt, 2) + 46.0
	var r := Rect2(view_size.x - w - 12.0, coins_r.position.y + coins_r.size.y + 4.0, w, 26.0)
	var fill := GameTheme.EMBER if GameState.harvest_final_days() else GameTheme.PUMPKIN
	_ui_panel(r, fill, GameTheme.WOOD_DARK, 2.0)
	var leaf_c := Vector2(r.position.x + 15.0, r.position.y + 13.0)
	draw_colored_polygon(PackedVector2Array([leaf_c + Vector2(-8.0, 1.0),
		leaf_c + Vector2(-2.0, -7.0), leaf_c + Vector2(8.0, -3.0),
		leaf_c + Vector2(1.0, 7.0)]), GameTheme.LEAF)
	draw_line(leaf_c + Vector2(-5.0, 4.0), leaf_c + Vector2(5.0, -4.0),
		GameTheme.WOOD_DARK, 1.5)
	PixFont.draw_text_shadowed(self, Vector2(r.position.x + 28.0, r.position.y + 5.0), txt,
			GameTheme.CREAM, Color(GameTheme.INK, 0.7), 2, 1, 1)


## Gold strip with the 2x coin countdown, used by the HUD and start menu.
func _draw_event_banner(y: float) -> void:
	if not GameState.event_active() or GameState.harvest_season_open():
		return
	var txt := "2X COINS - %s LEFT" % GameState.event_time_text()
	var w := PixFont.text_width(txt, 2) + 24.0
	var x := (view_size.x - w) * 0.5
	_ui_panel(Rect2(x, y, w, 26.0), Color(GameTheme.PANEL.darkened(0.15), 0.86), GameTheme.GOLD, 3.0)
	PixFont.draw_text_centered(self, view_size.x * 0.5, y + 5.0, txt, GameTheme.GOLD, 2, 1)


## Bait is bought at the shop and used up one charge per cast - without
## it rare fish barely bite, so the HUD keeps nudging the player.
func _bait_hud_text() -> String:
	var bait_id := String(GameState.gear.get("bait", ""))
	if bait_id == "":
		return "NO BAIT - BUY BAIT FOR RARE FISH"
	return "BAIT: %s x%d" % [String(ShopDB.item("baits", bait_id).get("name", "Bait")).to_upper(),
			GameState.bait_count(bait_id)]


## "THE RIVER - FAST CURRENT, SHARP ROCKS": announced like a place,
## not a menu change, with a small glyph and a slow fade.
func _draw_arrival() -> void:
	if arrival_t <= 0.0:
		return
	var fade_in := clampf((4.5 - arrival_t) / 0.35, 0.0, 1.0)
	var fade_out := clampf(arrival_t / 0.7, 0.0, 1.0)
	var a := fade_in * fade_out
	if a <= 0.01:
		return
	var name_w := PixFont.text_width(arrival_name, 4)
	var sub_w := PixFont.text_width(arrival_sub, 2)
	var w := maxf(name_w, sub_w) + 92.0
	var x := (view_size.x - w) * 0.5
	# Keep the banner above the fisher and rod tip, not across the action.
	var y := clampf(water_line - 190.0, 112.0, 190.0)
	var gold := Color(GameTheme.GOLD.r, GameTheme.GOLD.g, GameTheme.GOLD.b, a)
	_ui_panel(Rect2(x, y, w, 74.0), Color(0.08, 0.11, 0.17, 0.84 * a), gold, 3.0)
	RegionArt.draw_glyph(self, arrival_glyph, Vector2(x + 32.0, y + 37.0), 34.0, gold)
	PixFont.draw_text_shadowed(self, Vector2(x + 58.0, y + 12.0), arrival_name, gold,
			Color(0.02, 0.03, 0.05, 0.7 * a), 4, 1, 1)
	PixFont.draw_text_shadowed(self, Vector2(x + 58.0, y + 46.0), arrival_sub,
			Color(0.86, 0.9, 0.94, a), Color(0.02, 0.03, 0.05, 0.6 * a), 2, 1, 1)


func _draw_coin_fly() -> void:
	for c in coin_fly:
		if float(c["delay"]) > 0.0:
			continue
		var p: Vector2 = c["pos"]
		_draw_pixel_circle(p, 6.0, GameTheme.GOLD, 3.0)
		_pixel_rect(Rect2(p.x - 2.0, p.y - 2.0, 4.0, 4.0), Color("#fff2cf"))


func _draw_saved_toast() -> void:
	if saved_toast_t <= 0.0:
		return
	var a := minf(1.0, saved_toast_t / 0.4)
	var txt := "SAVED"
	var w := PixFont.text_width(txt, 2) + 34.0
	var x := (view_size.x - w) * 0.5
	var y := 46.0
	_ui_panel(Rect2(x, y, w, 26.0), Color(0.08, 0.11, 0.17, 0.8 * a),
			Color(GameTheme.LEAF.r, GameTheme.LEAF.g, GameTheme.LEAF.b, a), 2.0)
	PixFont.draw_text_centered(self, x + w * 0.5, y + 5.0, txt,
			Color(0.86, 0.95, 0.84, a), 2, 1)


## Aim crosshair at the cast target while playing with touch controls.
func _draw_reticle() -> void:
	if touch_controls == null or not touch_controls.enabled:
		return
	if state != STATE_WORLD and state != STATE_CAST:
		return
	if not rod_out or axe_out:
		return
	var t := Time.get_ticks_msec() / 1000.0
	var p := cast_target
	var a := 0.45 + 0.25 * absf(sin(t * 3.0))
	var c := Color(1.0, 0.95, 0.82, a)
	draw_arc(p, 13.0, 0.0, TAU, 22, c, 2.0)
	draw_line(p + Vector2(-18.0, 0.0), p + Vector2(-8.0, 0.0), c, 2.0)
	draw_line(p + Vector2(8.0, 0.0), p + Vector2(18.0, 0.0), c, 2.0)
	draw_line(p + Vector2(0.0, 8.0), p + Vector2(0.0, 18.0), c, 2.0)
	_pixel_rect(Rect2(p.x - 2.0, p.y - 2.0, 4.0, 4.0), c)


## Simple centred word wrap for the catch card description.
func _draw_wrapped_centered(center_x: float, y: float, text: String, color: Color,
		ps: int, max_w: float, max_lines: int) -> void:
	var words := text.split(" ", false)
	var lines: Array[String] = []
	var current := ""
	for w in words:
		var trial := String(w) if current == "" else current + " " + String(w)
		if PixFont.text_width(trial, ps) <= max_w:
			current = trial
		else:
			if current != "":
				lines.append(current)
			current = String(w)
		if lines.size() >= max_lines:
			break
	if lines.size() < max_lines and current != "":
		lines.append(current)
	var yy := y
	for line in lines:
		PixFont.draw_text_centered(self, center_x, yy, line, color, ps, 1)
		yy += float(8 * ps + 4)


func _draw_menu() -> void:
	draw_rect(Rect2(0.0, 0.0, view_size.x, view_size.y), Color(GameTheme.DIM, 0.62))
	var sc := _menu_scale()
	var vw := view_size.x / sc
	var vh := view_size.y / sc
	var pw := 520.0
	var ph := MENU_PANEL_H
	var px := (vw - pw) * 0.5
	var py := (vh - ph) * 0.5
	_draw_event_banner(maxf(10.0, py * sc - 36.0))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(sc, sc))
	draw_style_box(UILib.sfx_bg(), Rect2(px, py, pw, ph))
	if SeasonTheme.is_harvest():
		_pixel_rect(Rect2(px + 14.0, py + 3.0, pw - 28.0, 1.0), GameTheme.WHEAT)
	_draw_ribbon_bg(Rect2(px + 34.0, py + 16.0, pw - 68.0, 102.0),
			GameTheme.PANEL_LIGHT, GameTheme.WOOD_DARK)

	var t1 := "COTTAGE CREEK"
	var t2 := "FISHING"
	PixFont.draw_text_centered(self, px + pw * 0.5, py + 30.0, t1, GameTheme.GOLD, 5, 1)
	PixFont.draw_text_centered(self, px + pw * 0.5, py + 78.0, t2, GameTheme.CREAM, 5, 1)
	var sub := "CAST - HOOK - REEL - COLLECT"
	var sw := PixFont.text_width(sub, 2)
	PixFont.draw_text_shadowed(self, Vector2(px + (pw - sw) * 0.5, py + 126.0), sub,
			GameTheme.SUBTEXT, Color("#050a12", 0.6), 2, 1, 1)

	menu_buttons = _menu_button_rects()
	for i in range(menu_buttons.size()):
		var b := menu_buttons[i] as Dictionary
		# menu_buttons are screen-space hit rects; the draw transform is
		# already scaled, so convert back to the 520x480 sheet here.
		var r := Rect2((b["rect"] as Rect2).position / sc, (b["rect"] as Rect2).size / sc)
		var hovered: bool = i == hover_button
		var is_new: bool = String(b["id"]) == "updates" and ChangelogLib.is_unseen()
		var fill := GameTheme.BUTTON_HOVER if hovered else GameTheme.PANEL_LIGHT
		if is_new and not hovered:
			fill = GameTheme.HUSK
		var border := GameTheme.GOLD if (hovered or is_new) else GameTheme.BUTTON_BORDER
		_ui_panel(r, fill, border, 2.0 if (hovered or is_new) else 3.0)
		var label := String(b["label"])
		var lw := PixFont.text_width(label, 3)
		PixFont.draw_text_shadowed(self, Vector2(r.position.x + (r.size.x - lw) * 0.5,
				r.position.y + (r.size.y - 24.0) * 0.5), label,
				GameTheme.CREAM, Color("#050a12", 0.6), 3, 1, 1)

	var mc: Array = GameState.mastery_counts()
	var rank_txt := "%s - %d PTS   GOLD %d" % [GameState.angler_title(),
			GameState.angler_points(), int(mc[0])]
	var rw := PixFont.text_width(rank_txt, 2)
	PixFont.draw_text_shadowed(self, Vector2(px + (pw - rw) * 0.5, py + ph - 66.0), rank_txt,
			GameTheme.GOLD, Color("#050a12", 0.6), 2, 1, 1)

	var foot := "SPACE / CLICK TO START - 1-4 SPOTS"
	var fw := PixFont.text_width(foot, 2)
	PixFont.draw_text_shadowed(self, Vector2(px + (pw - fw) * 0.5, py + ph - 34.0), foot,
			GameTheme.WHEAT, Color("#050a12", 0.6), 2, 1, 1)

	# the HUD message strip only draws in-game, so the cheat confirmation
	# gets its own line under the start-screen panel
	if msg_text != "":
		var mw := PixFont.text_width(msg_text, 2)
		PixFont.draw_text_shadowed(self, Vector2(px + (pw - mw) * 0.5, py + ph + 12.0), msg_text,
				GameTheme.GOLD, Color("#050a12", 0.75), 2, 1, 1)
	draw_set_transform(Vector2.ZERO)


## Trophy reveal shown when the album completes outside the feast board.
func _draw_harvest_award() -> void:
	var fade := clampf(harvest_award_t / 1.2, 0.0, 1.0)
	draw_rect(Rect2(0.0, 0.0, view_size.x, view_size.y), Color(GameTheme.DIM, 0.45 * fade))
	var pw := 440.0
	var ph := 340.0
	var px := (view_size.x - pw) * 0.5
	var py := (view_size.y - ph) * 0.5
	draw_style_box(UILib.sfx_paper(), Rect2(px, py, pw, ph))
	PixFont.draw_text_centered(self, px + pw * 0.5, py + 18.0,
			"20 / 20 - ALBUM COMPLETE", GameTheme.INK, 3, 1)
	HarvestCards.draw_trophy(self, Rect2(px + 40.0, py + 48.0, pw - 80.0, 220.0))
	PixFont.draw_text_centered(self, px + pw * 0.5, py + ph - 44.0,
			"THE HARVEST QUEEN JOINS YOUR FLEET", GameTheme.WOOD_DARK, 2, 1)


## Greedy 1x tag packer for the catch card. Five simultaneous tags are
## wider than the 440px card, so allow at most two lines and let the caller
## nudge the body down.
func _pack_catch_tags(tags: Array[String], max_w: float) -> Array[String]:
	var lines: Array[String] = []
	var cur := ""
	for tag in tags:
		var trial := tag if cur == "" else cur + "   " + tag
		if cur == "" or PixFont.text_width(trial, 1) <= max_w:
			cur = trial
		else:
			lines.append(cur)
			cur = tag
	if cur != "":
		lines.append(cur)
	if lines.size() > 2:
		# Pathological case: fold the overflow into the second line rather
		# than draw off the card.
		for i in range(2, lines.size()):
			lines[1] += "   " + lines[i]
		lines.resize(2)
	return lines


func _draw_catch_popup() -> void:
	draw_rect(Rect2(0.0, 0.0, view_size.x, view_size.y), Color(GameTheme.DIM, 0.55))
	var pw := 440.0
	var ph := 330.0
	var px := (view_size.x - pw) * 0.5
	var py := (view_size.y - ph) * 0.5
	# the card scales in with a little overshoot so a catch lands with juice
	var tc := clampf(catch_card_t, 0.0, 1.0)
	var sc := 1.0 + 2.70158 * pow(tc - 1.0, 3.0) + 1.70158 * pow(tc - 1.0, 2.0)
	var center := Vector2(px + pw * 0.5, py + ph * 0.5)
	draw_set_transform(center - center * sc, 0.0, Vector2(sc, sc))
	draw_style_box(UILib.sfx_paper(), Rect2(px, py, pw, ph))

	var name_val := fish_name(catch_fish_id).to_upper()
	var nps := 4
	while nps > 2 and PixFont.text_width(name_val, nps) > pw - 28.0:
		nps -= 1
	PixFont.draw_text_centered(self, px + pw * 0.5, py + 24.0, name_val, GameTheme.INK, nps, 1)

	var rarity_color := GameTheme.get_rarity_color(catch_rarity)
	var rw := PixFont.text_width(catch_rarity.to_upper(), 3)
	var rx := px + (pw - (rw + 20.0)) * 0.5
	_ui_panel(Rect2(rx, py + 66.0, rw + 20.0, 26.0), rarity_color, GameTheme.INK, 3.0)
	PixFont.draw_text_centered(self, px + pw * 0.5, py + 72.0, catch_rarity.to_upper(),
			UILib.INK, 3, 1)
	if String(FishDB.fish_data(catch_fish_id).get("season", "")) == "harvest":
		var hw := PixFont.text_width("HARVEST", 2) + 20.0
		_ui_panel(Rect2(px + pw - hw - 14.0, py + 66.0, hw, 26.0), GameTheme.PUMPKIN,
				GameTheme.WOOD_DARK, 2.0)
		PixFont.draw_text_centered(self, px + pw - hw * 0.5 - 14.0, py + 72.0, "HARVEST",
				GameTheme.CREAM, 2, 1)

	if catch_new:
		PixFont.draw_text_centered(self, px + pw * 0.5, py + 96.0, "NEW SPECIES!",
				GameTheme.GOLD, 2, 1)
	FishArt.draw_fish(self, Rect2(px + 90.0, py + 110.0, pw - 180.0, 84.0),
			FishDB.fish_data(catch_fish_id), false, 1.0)

	var f := FishDB.fish_data(catch_fish_id)
	var tags: Array[String] = []
	if catch_perfect:
		tags.append("PERFECT +15%")
	if GameState.is_daily_catch(catch_fish_id):
		tags.append("DAILY CATCH x2")
	if GameState.is_hot_demand(catch_fish_id):
		tags.append("HOT DEMAND +30%")
	if GameState.event_active():
		tags.append("2X EVENT")
	if GameState.last_mastery_rank > 0:
		tags.append("%s MASTERED +%d" % [AlmanacLib.rank_name(GameState.last_mastery_rank),
				GameState.last_mastery_coins])
	# Up to five tags can fire at once (perfect + daily + demand + event +
	# mastery). They get one line when they fit, otherwise two at the small
	# size, and the card body shifts down so nothing overlaps the fish.
	var body_shift := 0.0
	if not tags.is_empty():
		var max_w := pw - 30.0
		var tag_line := "   ".join(tags)
		var tps := 2
		if PixFont.text_width(tag_line, tps) > max_w:
			tps = 1
		if PixFont.text_width(tag_line, tps) <= max_w:
			PixFont.draw_text_centered(self, px + pw * 0.5, py + 198.0, tag_line,
					GameTheme.GOLD, tps, 1)
		else:
			body_shift = 12.0
			var lines := _pack_catch_tags(tags, max_w)
			for i in range(lines.size()):
				PixFont.draw_text_centered(self, px + pw * 0.5, py + 196.0 + float(i) * 12.0,
						String(lines[i]), GameTheme.GOLD, 1, 1)

	var w_txt := "%.2f KG   WORTH %d COINS" % [catch_weight, catch_coins]
	PixFont.draw_text_centered(self, px + pw * 0.5, py + 216.0 + body_shift, w_txt, GameTheme.WOOD_DARK, 2, 1)

	var d_txt := String(f.get("desc", ""))
	_draw_wrapped_centered(px + pw * 0.5, py + 238.0 + body_shift, d_txt, Color("#5a4a55"), 2, pw - 40.0, 2)

	var br := Rect2(px + pw * 0.5 - 110.0, py + 272.0 + body_shift, 220.0, 36.0)
	var bh: bool = br.has_point(mouse_pos)
	_ui_panel(br, GameTheme.LEAF if bh else Color("#5c8a52"), GameTheme.INK, 3.0)
	var lab := "KEEP FISHING"
	var lw := PixFont.text_width(lab, 3)
	PixFont.draw_text_centered(self, px + pw * 0.5, py + 277.0, lab, GameTheme.CREAM, 3, 1)
	draw_set_transform(Vector2.ZERO)
