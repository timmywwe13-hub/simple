extends Node2D

const PixFont := preload("res://scripts/pixel_font.gd")
const TouchControls := preload("res://scripts/touch_controls.gd")

const STATE_MENU := 0
const STATE_WORLD := 1
const STATE_CAST := 2
const STATE_BITE := 3
const STATE_REEL := 4
const STATE_CAUGHT := 5
const STATE_INDEX := 6
const STATE_SHOP := 7

const WATER_RATIO := 0.60

## Fishing minigame balance, tuned for human reaction times: a generous
## hook window, a slow readable sweep on the timing bar, and a forgiving
## tug-of-war for big fish - slow tension drift, a wide green band (better
## lines widen it further), and the fish only escapes after the line has
## been fully slack or fully strained for TUG_PEG seconds straight.
const BITE_WINDOW := 2.2
const TIMING_SWEEP := 0.5
const TIMING_ACCEPT := 0.8
const TUG_BUILD := 0.55
const TUG_DECAY := 0.45
const TUG_BAND := 0.2
const TUG_HOLD := 1.2
const TUG_PEG := 0.8

## Forgiveness around the timing window. The press is judged against the
## marker exactly as it was last drawn, and this hair of grace covers
## input latency - clicking the green no longer randomly reads as a miss.
const TIMING_GRACE := 0.03

## Big-fish tug: a quick tap works like a short pump, so clicking in the
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
var tug_ok_time := 0.0
var tug_peg_time := 0.0
var catch_fish_id := ""
var catch_weight := 0.0
var catch_new := false
var catch_rarity := ""
var catch_coins := 0
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

## On-screen touch controls (phones/tablets); null-safe everywhere.
var touch_controls: TouchControls

var ui_layer: CanvasLayer
var index_panel: Control
var shop_panel: Control
var index_list: ItemList
var index_comp_label: Label
var shop_content: VBoxContainer
var shop_scroll: ScrollContainer
## Scroll offset kept across shop rebuilds so buying near the bottom of
## the list no longer snaps the panel back to the top.
var shop_scroll_pos := 0


func _ready() -> void:
	GameState._load_game()
	ui_layer = CanvasLayer.new()
	ui_layer.name = "UI"
	add_child(ui_layer)
	get_viewport().size_changed.connect(_relayout)
	_relayout()
	touch_controls = TouchControls.new()
	add_child(touch_controls)
	touch_controls.setup("fishing")
	_spawn_tunnel()
	_build_index()
	_build_shop()
	_build_ambient_fish()
	if GameState.session_started:
		_on_start()
	else:
		show_menu()


func _relayout() -> void:
	view_size = get_viewport_rect().size
	water_line = floor(view_size.y * WATER_RATIO)
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


## Tunnel to the Town scene at the left end of the bank. The fisher has no
## physics body, so main.gd polls proximity_check() while walking.
func _spawn_tunnel() -> void:
	tunnel = Tunnel.new()
	tunnel.name = "Tunnel"
	tunnel.sign = "TOWN"
	tunnel.position = Vector2(30.0, bank_top + 1.5)
	add_child(tunnel)


func _build_ambient_fish() -> void:
	ambient_fish.clear()
	var pool := FishDB.fish_pool("open" if open_water else region, weather)
	if pool.size() == 0:
		pool = FishDB.fish_pool("pond", weather)
	var count := 7
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
const TOUCH_KEY_TAPS := {KEY_R: "rod", KEY_B: "boat", KEY_I: "index",
		KEY_1: "spot1", KEY_2: "spot2", KEY_3: "spot3", KEY_4: "spot4"}


func _key_tick() -> void:
	key_edges = {}
	for code in [KEY_1, KEY_2, KEY_3, KEY_4, KEY_B, KEY_R, KEY_I]:
		var now := Input.is_physical_key_pressed(code)
		var was: bool = bool(key_prev.get(code, false))
		key_prev[code] = now
		key_edges[code] = now and not was


func _process(dt: float) -> void:
	_key_tick()

	day_time = fposmod(day_time + dt * 0.02, 1.0)
	is_night = day_time > 0.75 or day_time < 0.25
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

	mouse_pos = get_viewport().get_mouse_position()
	GameState.update_bait(dt)

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
			pass
		STATE_SHOP:
			pass
		STATE_CAUGHT:
			if _pressed():
				_on_catch_continue()

	if Input.is_action_just_pressed("ui_cancel") or _touch_tap("menu"):
		_on_back()

	if touch_controls != null:
		touch_controls.set_context(_touch_context())
		touch_controls.set_action_label(_touch_action_label())

	_update_ambient(dt)
	queue_redraw()


func _key_edge(code: int) -> bool:
	if touch_controls != null and TOUCH_KEY_TAPS.has(code) \
			and touch_controls.consume_tap(String(TOUCH_KEY_TAPS[code])):
		return true
	return bool(key_edges.get(code, false))


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
		_:
			return "hidden"


func _touch_action_label() -> String:
	match state:
		STATE_BITE:
			return "HOOK"
		STATE_REEL:
			return "HOLD" if _is_big_fish() else "REEL"
		_:
			return "CAST"


func _night_factor() -> float:
	return clampf(absf(day_time - 0.5) * 2.0, 0.0, 1.0)


func _weather_label() -> String:
	match weather:
		"rain": return "RAIN"
		"storm": return "THUNDERSTORM"
		_: return "CLEAR"


## Weather rolls in and out on a timer: clear skies most of the time,
## with rain and thunderstorms following. Storms bring lightning strikes
## (flash + thunder) and both rains change which fish are biting.
func _update_weather(dt: float) -> void:
	weather_timer -= dt
	if weather_timer <= 0.0:
		weather_timer = randf_range(35.0, 80.0)
		var roll := randf()
		var next := "clear"
		if roll > 0.78:
			next = "storm"
		elif roll > 0.45:
			next = "rain"
		if next != weather:
			weather = next
			GameState.play_sound("ui")
			match weather:
				"rain":
					msg("RAIN ROLLS IN - DIFFERENT FISH ARE BITING")
				"storm":
					msg("THUNDERSTORM! STORM FISH ARE ON THE MOVE")
				_:
					msg("THE SKY CLEARS")
			_build_ambient_fish()
	if weather == "storm":
		lightning_timer -= dt
		if lightning_timer <= 0.0:
			lightning_timer = randf_range(5.0, 12.0)
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
	hover_button = -1
	for i in range(menu_buttons.size()):
		var b := menu_buttons[i]["rect"] as Rect2
		if b.has_point(mouse_pos):
			hover_button = i
	if not _pressed():
		return
	if hover_button >= 0:
		GameState.play_sound("ui")
		match String(menu_buttons[hover_button]["id"]):
			"start": _on_start()
			"index": _on_index()
			"shop": _on_shop()
	elif Input.is_action_just_pressed("ui_accept"):
		# SPACE / Enter starts the game even without hovering a button
		GameState.play_sound("ui")
		_on_start()


func _update_world(dt: float) -> void:
	if _key_edge(KEY_R):
		rod_out = not rod_out
		GameState.play_sound("ui")
		msg("ROD READY - SPACE OR CLICK TO CAST" if rod_out else "ROD PUT AWAY - PRESS R TO TAKE IT OUT")
	if _key_edge(KEY_B):
		_toggle_boat()
	if in_boat:
		_update_boat(dt)
	else:
		_update_walk(dt)
	# sailing off the edge of the water loads the open-water section
	if in_boat and not open_water and boat_pos.x >= view_size.x - 20.0 \
			and Input.get_action_strength("move_right") > 0.1:
		_enter_open_water()
	elif open_water and boat_pos.x <= 20.0 \
			and Input.get_action_strength("move_left") > 0.1:
		_exit_open_water()
	if _key_edge(KEY_I):
		_on_index(true)
	for i in range(4):
		if not _key_edge(KEY_1 + i):
			continue
		if open_water:
			msg("SAIL WEST BACK TO SHORE TO CHANGE SPOTS")
			GameState.play_sound("buzz")
			continue
		var target: String = ["pond", "river", "lake", "ocean"][i]
		if target == "ocean" and not GameState.has_seaworthy_boat():
			msg("THE DEEP SEA NEEDS A REAL BOAT - VISIT THE BOAT DEALER")
			GameState.play_sound("buzz")
		elif GameState.unlocked_regions.has(target):
			region = target
			_build_ambient_fish()
			GameState.play_sound("ui")
			msg("Moved to %s." % String(FishDB.REGION_DISPLAY.get(region, region)))
		else:
			msg("Locked: %s costs %d coins." % [FishDB.REGION_DISPLAY.get(target, target),
					int(FishDB.REGION_UNLOCK_COST.get(target, 0))])
			GameState.play_sound("buzz")

	var cast_min_x := 40.0 if open_water else bank_w + 40.0
	cast_target = Vector2(clampf(mouse_pos.x, cast_min_x, view_size.x - 24.0), water_line)
	if _pressed():
		if not rod_out:
			msg("TAKE OUT YOUR ROD FIRST - PRESS R")
			GameState.play_sound("buzz")
		elif GameState.inventory_count() >= GameState.bucket_capacity():
			msg("BUCKET FULL - SELL FISH IN THE SHOP")
			GameState.play_sound("buzz")
		else:
			_cast_start()


## On-foot movement along the bank, plus the tunnel to the Town scene.
func _update_walk(dt: float) -> void:
	var walk := Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	walking = absf(walk) > 0.1
	if walking:
		fisher_x = clampf(fisher_x + walk * fisher_speed * dt, 30.0, bank_w - 40.0)
		walk_phase = fposmod(walk_phase + dt * 9.0, TAU)
	else:
		walk_phase = move_toward(walk_phase, 0.0, dt * 18.0)
	rod_tip = Vector2(fisher_x + 74.0, floor(bank_top - 78.0))
	if tunnel and not tunnel.triggered and tunnel.proximity_check(Vector2(fisher_x, bank_top + 1.5)):
		tunnel.triggered = true
		GameState.travel(tunnel.target_scene)


## Sailing: A/D (or left/right) row the equipped boat along the water.
## The hull floats ON the surface - see _boat_surface_y - so the boat
## rides the waterline instead of drifting through the middle of the
## water. Speed comes from the boat's ShopDB stat, so better boats move
## faster.
func _update_boat(dt: float) -> void:
	var dir := Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
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
		in_boat = true
		boat_pos = Vector2(clampf(fisher_x + 96.0, bank_w + 52.0, view_size.x - 60.0), _boat_surface_y())
		msg("SET SAIL - A/D TO SAIL - B NEAR SHORE TO LAND")


## Sailing past the east edge of a fishing spot loads the open-water
## section: a wide body of open sea with its own fish for the index.
func _enter_open_water() -> void:
	open_water = true
	boat_pos = Vector2(90.0, _boat_surface_y())
	if tunnel:
		tunnel.visible = false
	_build_ambient_fish()
	GameState.play_sound("cast")
	msg("OPEN WATER - UNCHARTED FISH LURK BELOW")
	flash = 0.8


## Sail back west to return to the regular fishing spot.
func _exit_open_water() -> void:
	open_water = false
	boat_pos = Vector2(view_size.x - 110.0, boat_pos.y)
	if tunnel:
		tunnel.visible = true
	_build_ambient_fish()
	GameState.play_sound("cast")
	msg("BACK AT THE %s" % String(FishDB.REGION_DISPLAY.get(region, region)).to_upper())
	flash = 0.8


func _cast_start() -> void:
	state = STATE_CAST
	cast_travel = 0.0
	bobber_home = cast_target
	bobber_pos = rod_tip
	# each cast uses one charge of the equipped bait (bought at the shop)
	cast_bait = GameState.consume_bait()
	GameState.play_sound("cast")


func _update_cast(dt: float) -> void:
	cast_travel = clampf(cast_travel + dt * 2.2, 0.0, 1.0)
	var t := cast_travel
	bobber_pos = rod_tip.lerp(bobber_home, t)
	bobber_pos.y -= sin(t * PI) * 110.0
	if cast_travel >= 1.0:
		state = STATE_BITE
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


func _hook_success() -> void:
	hooked = false
	_select_catch()
	state = STATE_REEL
	reel_active = true
	reel_pos = 0.5
	reel_dir = 1.0
	reel_hold = false
	reel_tension = 0.5
	tug_ok_time = 0.0
	tug_peg_time = 0.0
	if _is_big_fish():
		msg("HEAVY FIGHT - HOLD TO REEL, KEEP THE MARKER IN THE GREEN")
	else:
		msg("PRESS IN THE GREEN ZONE")


func _hook_fail() -> void:
	hooked = false
	state = STATE_WORLD
	GameState.play_sound("escape")
	msg("THE FISH GOT AWAY...")
	shake = 0.6


func _is_big_fish() -> bool:
	return GameTheme.get_rarity_rate(catch_rarity) < 0.25


func _select_catch() -> void:
	var pool := FishDB.fish_pool("open" if open_water else region, weather)
	if pool.size() == 0:
		pool = FishDB.fish_pool("pond", weather)
	var weights := []
	var total := 0.0
	var boost: Array = []
	if cast_bait != "":
		boost = ShopDB.item("baits", cast_bait).get("rarity_boost", [])
	for f in pool:
		var w := float(f.get("catch_rate", 1.0))
		var r := String(f.get("rarity", "Common"))
		if bool(f.get("anywhere", false)):
			# roaming monsters bite no matter what bait is on the hook
			pass
		elif cast_bait != "":
			if boost.has(r):
				w *= BAIT_BOOST
		else:
			# fishing bare: rare fish almost never show up - buy bait!
			w *= float(NO_BAIT_PENALTY.get(r, 1.0))
		if is_night and r == "Legendary":
			w *= 1.5
		if weather == "storm" and GameTheme.get_rarity_rate(r) < 0.25:
			w *= 1.3
		if String(f.get("weather", "")) != "":
			# weather fish are hungry in their own weather
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
	catch_coins = GameState.coin_value(catch_fish_id, catch_weight)


func _update_reel(dt: float) -> void:
	var target := rod_tip
	bobber_pos = bobber_pos.lerp(target, clampf(dt * 0.9, 0.0, 1.0))
	if _is_big_fish():
		_update_tug(dt)
	else:
		_update_timing(dt)


func _update_timing(dt: float) -> void:
	var window := _timing_window()
	var prev_pos := reel_pos
	reel_pos += reel_dir * dt * (TIMING_SWEEP / maxf(window, 0.1))
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
	var window := _timing_window()
	var good: float = window * TIMING_ACCEPT
	var lo := 0.5 - good - TIMING_GRACE
	var hi := 0.5 + good + TIMING_GRACE
	var ok := reel_pos >= lo and reel_pos <= hi
	if not ok and prev_pos >= 0.0:
		var swept_lo := minf(prev_pos, reel_pos) - TIMING_GRACE
		var swept_hi := maxf(prev_pos, reel_pos) + TIMING_GRACE
		ok = swept_hi >= lo and swept_lo <= hi
	_complete_catch(ok)


## Timing window of the equipped rod. Rarer fish fight a little harder:
## Rare / Epic / Legendary catches shrink the green zone slightly.
func _timing_window() -> float:
	var base := float(ShopDB.item("rods", String(GameState.gear.get("rod", "rod_stick"))).get("timing_window", 0.18))
	return base * _fight_scale()


## 1.0 for common fish, a touch tighter for the rare ones.
func _fight_scale() -> float:
	match catch_rarity:
		"Legendary": return 0.82
		"Epic": return 0.88
		"Rare": return 0.94
		_: return 1.0


## Big-fish tug-of-war: holding reels in and raises tension, releasing
## lets it fall. Keep the marker in the green band long enough to land the
## fish. The line only snaps after it has been fully slack or fully
## strained for TUG_PEG seconds straight, so one clumsy pause is
## survivable - the old build failed within half a second no matter what.
func _update_tug(dt: float) -> void:
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
	if absf(reel_tension - 0.5) < _tug_band():
		tug_ok_time += dt
		if tapped:
			tug_ok_time += TUG_TAP_PROGRESS
	else:
		# a short misstep only slows the landing, it does not reset it
		tug_ok_time = maxf(0.0, tug_ok_time - dt * 0.5)
	if tug_ok_time >= TUG_HOLD:
		_complete_catch(true)


func _reel_held() -> bool:
	if Input.is_key_pressed(KEY_SPACE) or Input.is_action_pressed("ui_accept"):
		return true
	if touch_controls != null and touch_controls.action_held:
		return true
	return Input.is_action_pressed("click") and not _click_blocked()


## Safe tension band around the middle; better lines widen it (the line's
## ShopDB escape_chance), so the upgrade finally matters in the fight.
func _tug_band() -> float:
	var line := ShopDB.item("lines", String(GameState.gear.get("line", "line_nylon")))
	return (TUG_BAND + (0.3 - float(line.get("escape_chance", 0.3))) * 0.5) * _fight_scale()


func _complete_catch(success: bool) -> void:
	reel_active = false
	if success:
		var f := FishDB.fish_data(catch_fish_id)
		if bool(f.get("monster", false)) and randf() < MONSTER_SHOCK_CHANCE:
			_monster_shock(f)
			return
		# The fish goes into the bucket; selling it in the Tackle Shop or the
		# Fish Market is what pays - no coins at catch time (that used to pay
		# every fish twice and wreck the economy).
		GameState.record_catch(catch_fish_id, catch_weight, "open" if open_water else region, is_night)
		state = STATE_CAUGHT
		if catch_new and GameTheme.get_rarity_rate(catch_rarity) < 0.1:
			flash = 1.0
			shake = 0.8
			GameState.play_sound("rare")
		else:
			GameState.play_sound("catch")
	else:
		state = STATE_WORLD
		GameState.play_sound("escape")
		msg("THE FISH GOT AWAY...")
		shake = 0.6


## The Volt Serpent's bad side: it bites the hand that reels it in, costs
## the fisher MONSTER_SHOCK_COST coins and escapes. The other 95% of the
## time it goes straight into the bucket and can be sold like any fish.
func _monster_shock(f: Dictionary) -> void:
	var lost := mini(MONSTER_SHOCK_COST, GameState.coins)
	GameState.lose_coins(MONSTER_SHOCK_COST)
	state = STATE_WORLD
	hooked = false
	catch_fish_id = ""
	bobber_pos = rod_tip
	GameState.play_sound("shock")
	shake = 1.0
	flash = 0.6
	hurt_flash = 1.0
	# a bolt snaps out of the water where the serpent broke free
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


func show_menu() -> void:
	hide_all_ui()
	menu_panel_show()


func hide_all_ui() -> void:
	if index_panel:
		index_panel.visible = false
	if shop_panel:
		shop_panel.visible = false


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
	match state:
		STATE_INDEX:
			# opened mid-fishing with I / the INDEX button -> go back to the
			# water instead of the start menu
			if index_from_world:
				hide_all_ui()
				state = STATE_WORLD
			else:
				show_menu()
		STATE_SHOP: show_menu()
		STATE_CAUGHT: _on_catch_continue()
		_: show_menu()


func _on_index(from_world := false) -> void:
	hide_all_ui()
	index_from_world = from_world
	index_panel.visible = true
	state = STATE_INDEX
	_refresh_index()


func _on_shop() -> void:
	hide_all_ui()
	shop_panel.visible = true
	state = STATE_SHOP
	_refresh_shop()


func _on_catch_continue() -> void:
	state = STATE_WORLD
	catch_fish_id = ""
	bobber_pos = rod_tip


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
	var title := UILib.label(p, "FISH INDEX", 30, GameTheme.CREAM, true, HORIZONTAL_ALIGNMENT_LEFT)
	title.position = Vector2(24, 18)
	index_comp_label = UILib.label(p, "COLLECTION: 0%", 18, GameTheme.GOLD, true, HORIZONTAL_ALIGNMENT_LEFT)
	index_comp_label.position = Vector2(24, 54)
	var list := ItemList.new()
	list.name = "List"
	list.set_anchors_preset(Control.PRESET_FULL_RECT)
	list.offset_left = 20
	list.offset_top = 96
	list.offset_right = -20
	list.offset_bottom = -70
	p.add_child(list)
	index_list = list
	var b := UILib.button(p, "BACK", _on_back, 20, GameTheme.PANEL_LIGHT)
	b.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	b.offset_left = 24
	b.offset_top = -60
	b.offset_right = 184
	b.offset_bottom = -16
	b.custom_minimum_size = Vector2(160, 44)
	p.visible = false


func _refresh_index() -> void:
	index_list.clear()
	var ids := FishDB.all_ids()
	var caught := 0
	for fid in ids:
		var fid_s := String(fid)
		var f := FishDB.fish_data(fid_s)
		var entry: Dictionary = GameState.index.get(fid_s, {})
		var caught_flag := bool(entry.get("caught", false))
		if caught_flag:
			caught += 1
		var name_val := String(f.get("name", fid_s))
		if not caught_flag:
			name_val = "???"
		var rarity := String(f.get("rarity", "Common"))
		var color := GameTheme.get_rarity_color(rarity)
		var idx := index_list.add_item(name_val)
		index_list.set_item_custom_fg_color(idx, color if caught_flag else Color("#5c6a78"))
		var sub := "RARITY: %s  PB: %.2f KG" % [rarity, float(entry.get("pb_weight", 0.0))]
		index_list.set_item_tooltip(idx, sub)
	var total := ids.size()
	index_comp_label.text = "COLLECTION: %d / %d  (%.0f%%)" % [caught, total, float(caught) / float(total) * 100.0] if total > 0 else "COLLECTION: 0 / 0"


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
	var title := UILib.label(p, "TACKLE SHOP", 30, GameTheme.CREAM, true, HORIZONTAL_ALIGNMENT_LEFT)
	title.position = Vector2(24, 18)
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
	p.add_child(scroll)
	shop_scroll = scroll
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
	_shop_cat("Rods", "rods", _on_buy)
	_shop_cat("Lines", "lines", _on_buy)
	_shop_cat("Bait", "baits", _on_buy_bait)
	_shop_cat("Bucket", "buckets", _on_buy)
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
		var is_bait := category == "baits"
		var owned := bool(d.get("owned", false)) and not is_bait
		var equipped := String(GameState.gear.get(GameState.gear_key(category), "")) == String(id)
		var row := Control.new()
		row.custom_minimum_size = Vector2(600.0, 50.0)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		shop_content.add_child(row)
		var name_l := UILib.label(row, String(d.get("name", id)), 17, GameTheme.CREAM, true)
		name_l.position = Vector2(10, 6)
		var desc_l := UILib.label(row, String(d.get("desc", "")), 13, Color("#a8c0cc"), false)
		desc_l.position = Vector2(10, 26)
		var stat_l := UILib.label(row, _stat_line(category, d), 13, GameTheme.LEAF, false)
		stat_l.position = Vector2(330, 10)
		var cost := int(d.get("cost", 0))
		# Bait is a consumable: a bag with charges left can be equipped for
		# free, so the player can switch between the baits they own.
		var charges := GameState.bait_count(String(id)) if is_bait else 0
		var btn_text := "BUY %d" % cost
		if is_bait:
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


func _is_equipped(category: String, id: String) -> bool:
	return String(GameState.gear.get(category, "")) == id


func _stat_line(category: String, d: Dictionary) -> String:
	match category:
		"rods": return "SPEED: %.1fx  WINDOW: %.2f" % [float(d.get("reel_speed", 1.0)), float(d.get("timing_window", 0.2))]
		"lines": return "KEEP: %.0f%%" % [(1.0 - float(d.get("escape_chance", 0.3))) * 100.0]
		"baits":
			var bait_id := String(d.get("id", ""))
			var line := "%d CASTS - BAG %d - %s" % [int(d.get("charges", 1)),
					GameState.bait_count(bait_id), ", ".join(d.get("rarity_boost", []))]
			if String(GameState.gear.get("bait", "")) == bait_id:
				line += " - EQUIPPED"
			return line
		"buckets": return "CAPACITY: %d" % [int(d.get("capacity", 12))]
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
	var total := GameState.sell_all()
	msg("SOLD ALL FISH FOR %d COINS!" % total)
	_refresh_shop()


func _menu_button_rects() -> Array:
	var bw := 260.0
	var bh := 42.0
	var bx := (view_size.x - bw) * 0.5
	var by := view_size.y * 0.56
	return [
		{"id": "start", "rect": Rect2(bx, by, bw, bh), "label": "START FISHING"},
		{"id": "index", "rect": Rect2(bx, by + 52.0, bw, bh), "label": "FISH INDEX"},
		{"id": "shop", "rect": Rect2(bx, by + 104.0, bw, bh), "label": "TACKLE SHOP"},
	]


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


func _ui_panel(r: Rect2, fill: Color, border: Color, bw := 4.0) -> void:
	_pixel_rect(r, fill)
	_pixel_rect(Rect2(r.position.x, r.position.y, r.size.x, bw), border)
	_pixel_rect(Rect2(r.position.x, r.position.y + r.size.y - bw, r.size.x, bw), border)
	_pixel_rect(Rect2(r.position.x, r.position.y, bw, r.size.y), border)
	_pixel_rect(Rect2(r.position.x + r.size.x - bw, r.position.y, bw, r.size.y), border)


func _hud_panel(txt: String, anchor_right: bool) -> Rect2:
	var w := PixFont.text_width(txt, 3) + 24.0
	var h := 34.0
	var x := 12.0 if not anchor_right else view_size.x - w - 12.0
	var r := Rect2(x, 12.0, w, h)
	_ui_panel(r, Color("#141c2c", 0.8), Color("#3b4a63", 0.9))
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
	else:
		_draw_pines()
	_draw_water(t)
	_draw_underwater_decor(t)
	_draw_ambient_fish(t)
	if not open_water:
		_draw_bank()
	_draw_fisher(t)
	_draw_line_and_bobber(t)
	_draw_weather(t)

	draw_set_transform(Vector2.ZERO)

	if state != STATE_MENU:
		_draw_hud()
	if state == STATE_MENU:
		_draw_menu()
	if state == STATE_REEL:
		_draw_reel_meter()
	if state == STATE_CAUGHT:
		_draw_catch_popup()
	if hurt_flash > 0.0:
		draw_rect(Rect2(-40.0, -40.0, view_size.x + 80.0, view_size.y + 80.0),
				Color(1.0, 0.18, 0.28, hurt_flash * 0.32))
	if flash > 0.0:
		draw_rect(Rect2(-40.0, -40.0, view_size.x + 80.0, view_size.y + 80.0),
				Color(1.0, 1.0, 1.0, flash * 0.45))


func _draw_sky() -> void:
	var nf := _night_factor()
	var top := GameTheme.SKY_TOP.lerp(GameTheme.SKY_NIGHT_TOP, nf)
	var mid := GameTheme.SKY_MID.lerp(GameTheme.SKY_NIGHT_MID, nf)
	var low := GameTheme.SKY_LOW.lerp(GameTheme.SKY_NIGHT_LOW, nf)
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

	var sun_c := Color("#fff2cf")
	if is_night:
		sun_c = Color("#e9edf7")
	_draw_pixel_circle(Vector2(view_size.x * 0.74, 96.0), 24.0, sun_c, 4.0)
	if not is_night:
		for i in range(6):
			_draw_pixel_circle(Vector2(view_size.x * 0.74 + 26.0 + float(i) * 3.0, 74.0 + float(i) * 6.0),
					3.0, GameTheme.SKY_MID, 2.0)


func _draw_clouds(t: float) -> void:
	var nf := _night_factor()
	var base := Color("#fdf2f5")
	base.a = 0.8
	base = base.lerp(Color("#232a4a", 0.65), nf)
	for i in range(6):
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
		{"c": GameTheme.MOUNTAIN_FAR, "amp": 58.0, "off": 0.0, "w": 8.0, "f": 0.0026},
		{"c": GameTheme.MOUNTAIN_MID, "amp": 42.0, "off": 1.7, "w": 8.0, "f": 0.0041},
		{"c": GameTheme.MOUNTAIN_NEAR, "amp": 28.0, "off": 3.4, "w": 10.0, "f": 0.0062},
	]
	for l in layers:
		var c: Color = (l["c"] as Color).lerp(Color("#161c30"), nf)
		var x := 0.0
		while x < view_size.x:
			var hgt := _mountain_height(x, float(l["f"]), float(l["amp"]), float(l["off"]))
			draw_rect(Rect2(x, hgt, float(l["w"]) + 1.0, water_line + 70.0 - hgt), c)
			x += float(l["w"])


## Horizon decor for the open-water section: low sand islands with palms.
func _draw_islands(t: float) -> void:
	var nf := _night_factor()
	var sand := GameTheme.SAND.darkened(0.1 + nf * 0.45)
	var sand_l := GameTheme.SAND.lightened(0.05).darkened(nf * 0.5)
	var trunk := GameTheme.WOOD_DARK.lerp(Color("#101522"), nf)
	var leaf := GameTheme.PINE.lerp(Color("#0f1a22"), nf)
	for i in range(3):
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


func _draw_pine(x: float, base_y: float, h: float, w: float, c: Color) -> void:
	var tiers := 4
	for i in range(tiers):
		var tt := float(i) / float(tiers)
		var y := base_y - h + h * tt * 0.78
		var ww := maxf(4.0, w * (1.0 - tt * 0.45))
		_pixel_rect(Rect2(x - ww * 0.5, y, ww, maxf(3.0, h * 0.22)), c)
	_pixel_rect(Rect2(x - 2.0, base_y - h * 0.24, 4.0, h * 0.24), Color("#2a1f1c"))


func _draw_pines() -> void:
	var nf := _night_factor()
	var rows := [
		{"c": GameTheme.PINE.lerp(Color("#0f1721"), nf), "h": 34.0, "w": 13.0, "gap": 27.0, "off": 6.0},
		{"c": GameTheme.PINE_DARK.lerp(Color("#0a1119"), nf), "h": 48.0, "w": 17.0, "gap": 37.0, "off": 18.0},
	]
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
	for i in range(bands):
		var y0 := water_line + depth * float(i) / float(bands)
		var y1 := water_line + depth * float(i + 1) / float(bands)
		var tt := float(i) / float(bands)
		var c := GameTheme.WATER_SHALLOW.lerp(GameTheme.WATER_MID, clampf(tt * 1.8, 0.0, 1.0))
		c = c.lerp(GameTheme.WATER_DEEP.lerp(Color("#0a1120"), nf), clampf(tt * 1.1, 0.0, 1.0))
		draw_rect(Rect2(0.0, y0, view_size.x, y1 - y0 + 1.0), c)

	var surf := GameTheme.WATER_SURFACE.lerp(Color("#9fb6c8"), nf)
	var x := 0.0
	while x < view_size.x:
		var w := 6.0 + absf(sin(x * 0.05 + t * 1.6)) * 10.0
		draw_rect(Rect2(x, water_line - 3.0, w, 4.0), surf)
		x += 14.0

	for i in range(40):
		var cx := fposmod(float(i) * 61.0 + t * 9.0, view_size.x)
		var cy := water_line + 10.0 + sin(t * 1.3 + float(i)) * 4.0
		draw_rect(Rect2(cx, cy, 10.0, 2.0), Color(surf.r, surf.g, surf.b, 0.18))


func _draw_underwater_decor(t: float) -> void:
	var nf := _night_factor()
	var weed := GameTheme.GRASS_DARK.lerp(Color("#0d1c14"), 0.2 + nf * 0.6)
	for i in range(16):
		var sx := 70.0 + float(i) * 38.0
		if sx > view_size.x - 20.0:
			break
		var seg := (view_size.y - water_line) * 0.45
		for k in range(6):
			var y := water_line + seg + float(k) * 13.0
			if y > view_size.y - 8.0:
				break
			var sway := sin(t * 1.2 + float(i) * 0.7 + float(k) * 0.5) * 6.0
			_pixel_rect(Rect2(sx + sway, y, 5.0, 13.0), weed)

	var rock := Color("#2b3446").lerp(Color("#0d1320"), nf)
	for i in range(6):
		var rx := view_size.x - 100.0 + float(i) * 17.0
		var ry := view_size.y - 24.0
		_draw_pixel_circle(Vector2(rx, ry), 12.0 + float(i % 3) * 5.0, rock, 4.0)

	for i in range(6):
		var bx := view_size.x - 220.0 + float(i) * 27.0
		var by := view_size.y - 32.0 - sin(float(i) * 0.9) * 14.0
		_pixel_rect(Rect2(bx, by, 28.0, 5.0), Color("#2c2422"))

	for i in range(12):
		var bx := fposmod(float(i) * 137.0 - t * 10.0, view_size.x)
		var span := maxf(20.0, view_size.y - water_line - 30.0)
		var by := water_line + fposmod(float(i) * 91.0 + t * 26.0, span) + 12.0
		_draw_pixel_circle(Vector2(bx, by), 2.0 + float(i % 3), Color("#cfe6f0", 0.35), 2.0)


func _draw_ambient_fish(t: float) -> void:
	for f in ambient_fish:
		var fish: Dictionary = f["fish"]
		var y := float(f["y"]) + sin(float(f["phase"])) * float(f["amp"])
		var s := float(f["scale"])
		var rect := Rect2(float(f["x"]) - s * 1.5, y - s * 0.55, s * 3.0, s * 1.1)
		# at night they read as soft shadows in the water
		FishArt.draw_fish(self, rect, fish, is_night, float(f["dir"]))


func _draw_bank() -> void:
	var nf := _night_factor()
	var dirt := GameTheme.DIRT.lerp(Color("#14161f"), nf)
	var dirt_l := GameTheme.DIRT_LIGHT.lerp(Color("#1e2028"), nf)
	var h := view_size.y - bank_top
	draw_rect(Rect2(0.0, bank_top, bank_w, h + 2.0), dirt)
	_pixel_rect(Rect2(0.0, bank_top + h * 0.55, bank_w, 6.0), dirt_l)
	for i in range(46):
		var sx := fmod(float(i) * 71.0, bank_w - 12.0)
		var sy := bank_top + 22.0 + fmod(float(i) * 53.0, maxf(1.0, h - 34.0))
		_pixel_rect(Rect2(sx, sy, 6.0, 4.0), dirt_l if i % 2 == 0 else dirt.darkened(0.25))

	_pixel_rect(Rect2(0.0, bank_top - 10.0, bank_w, 14.0), GameTheme.GRASS)
	_pixel_rect(Rect2(0.0, bank_top + 4.0, bank_w, 6.0), GameTheme.GRASS_DARK)
	for i in range(0, int(bank_w), 16):
		var bh := 5.0 + absf(sin(float(i) * 0.37)) * 9.0
		_pixel_rect(Rect2(float(i), bank_top - 10.0 - bh, 4.0, bh), GameTheme.GRASS)

	for i in range(9):
		_pixel_rect(Rect2(bank_w - 2.0 - float(i) * 3.0, bank_top + 16.0 + float(i) * 9.0, 7.0, 7.0),
				GameTheme.ROCK)


func _draw_fisher(t: float) -> void:
	var bob := sin(t * 2.0) * 1.5
	var swing := 0.0
	if walking:
		bob = absf(sin(walk_phase)) * 1.5
		swing = sin(walk_phase) * 3.0
	var o := Vector2(floorf(fisher_x), floorf(bank_top + bob))
	if in_boat:
		bob = sin(t * 1.9) * 2.0
		swing = 0.0
		o = Vector2(floorf(boat_pos.x - 12.0), floorf(boat_pos.y - 2.0 + bob))
		_draw_boat_at(t, boat_pos, false, false)
	else:
		_draw_boat_at(t, Vector2(bank_w + 44.0, _boat_surface_y()), true, false)
	var rod_ready := rod_out or state != STATE_WORLD
	if not rod_ready:
		_draw_rod(o, false)  # stowed across the back
	_pixel_rect(Rect2(o.x - 10.0 - swing, o.y - 24.0, 7.0, 20.0), GameTheme.PANTS)
	_pixel_rect(Rect2(o.x + 3.0 + swing, o.y - 24.0, 7.0, 20.0), GameTheme.PANTS)
	_pixel_rect(Rect2(o.x - 12.0 - swing, o.y - 6.0, 9.0, 6.0), GameTheme.BOOT)
	_pixel_rect(Rect2(o.x + 3.0 + swing, o.y - 6.0, 9.0, 6.0), GameTheme.BOOT)
	_pixel_rect(Rect2(o.x - 11.0, o.y - 46.0, 22.0, 24.0), GameTheme.SHIRT)
	_pixel_rect(Rect2(o.x - 11.0, o.y - 28.0, 22.0, 4.0), GameTheme.BELT)
	_pixel_rect(Rect2(o.x + 7.0, o.y - 45.0, 9.0, 15.0), GameTheme.SHIRT_DARK)
	_pixel_rect(Rect2(o.x - 7.0, o.y - 62.0, 15.0, 16.0), GameTheme.SKIN)
	_pixel_rect(Rect2(o.x - 8.0, o.y - 64.0, 16.0, 7.0), GameTheme.HAIR)
	_pixel_rect(Rect2(o.x - 9.0, o.y - 59.0, 3.0, 10.0), GameTheme.HAIR)
	_pixel_rect(Rect2(o.x + 3.0, o.y - 56.0, 3.0, 3.0), GameTheme.INK)
	if rod_ready:
		_draw_rod(o, true)
	else:
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
	_draw_hull_waterline(b.x, hw, w)


## Water lapping at the hull where it meets the surface, so the boat reads
## as floating on top of the water instead of sinking through it.
func _draw_hull_waterline(bx: float, hw: float, w: float) -> void:
	var surf := GameTheme.WATER_SURFACE
	_pixel_rect(Rect2(bx - hw - 3.0, water_line - 2.0, w + 6.0, 4.0),
			Color(surf.r, surf.g, surf.b, 0.5))
	for i in range(3):
		_pixel_rect(Rect2(bx - hw + 4.0 + float(i) * (w - 16.0) * 0.5, water_line - 3.0,
				10.0, 2.0), Color(surf.r, surf.g, surf.b, 0.35))


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
	var y := view_size.y - 84.0
	_ui_panel(Rect2(x, y, w, h), Color("#141c2c", 0.85), Color("#3b4a63", 0.95))
	var bar_x := x + 16.0
	var bar_w := w - 32.0
	var bar_y := y + 22.0
	_pixel_rect(Rect2(bar_x, bar_y, bar_w, 12.0), Color("#22314a"))
	if _is_big_fish():
		var band := _tug_band()
		_pixel_rect(Rect2(bar_x + bar_w * (0.5 - band), bar_y, bar_w * band * 2.0, 12.0), GameTheme.LEAF)
		_pixel_rect(Rect2(bar_x + bar_w * reel_tension - 2.0, bar_y - 5.0, 4.0, 22.0), GameTheme.CREAM)
		PixFont.draw_text_shadowed(self, Vector2(bar_x, y + 6.0), "TENSION - HOLD TO REEL IN - KEEP IT GREEN",
				Color("#cfe0ec"), Color("#050a12", 0.6), 2, 1, 1)
	else:
		var window := _timing_window()
		var good := window * TIMING_ACCEPT
		_pixel_rect(Rect2(bar_x + bar_w * (0.5 - good), bar_y, bar_w * good * 2.0, 12.0), GameTheme.LEAF)
		_pixel_rect(Rect2(bar_x + bar_w * reel_pos - 2.0, bar_y - 5.0, 4.0, 22.0), GameTheme.CREAM)
		PixFont.draw_text_shadowed(self, Vector2(bar_x, y + 6.0), "REEL - PRESS IN THE GREEN ZONE",
				Color("#cfe0ec"), Color("#050a12", 0.6), 2, 1, 1)


func _draw_hud() -> void:
	_hud_panel("COINS %d" % GameState.coins, true)
	var area_label := "OPEN WATER" if open_water else String(FishDB.REGION_DISPLAY.get(region, region))
	var rt := "%s  %s  %s" % [area_label.to_upper(),
			"NIGHT" if is_night else "DAY", _weather_label()]
	var left_r: Rect2 = _hud_panel("BUCKET %d/%d" % [GameState.inventory_count(), GameState.bucket_capacity()], false)
	PixFont.draw_text_shadowed(self, Vector2(12.0, 54.0), rt,
			Color("#e9d8a8"), Color("#050a12", 0.6), 2, 1, 1)
	PixFont.draw_text_shadowed(self, Vector2(12.0, left_r.position.y + 62.0),
			"SPOTS 1-4 - R ROD - B BOAT - I INDEX - ESC MENU", Color("#aebfd0"), Color("#050a12", 0.6), 2, 1, 1)
	var boat_txt := "BOAT: %s" % String(GameState.current_boat().get("name", "Old Raft")).to_upper()
	PixFont.draw_text_shadowed(self,
			Vector2(view_size.x - PixFont.text_width(boat_txt, 2) - 12.0, 52.0),
			boat_txt, Color("#e9d8a8"), Color("#050a12", 0.6), 2, 1, 1)
	var bait_txt := _bait_hud_text()
	var bait_c := Color("#8fd9a8") if String(GameState.gear.get("bait", "")) != "" else Color("#e0906e")
	PixFont.draw_text_shadowed(self,
			Vector2(view_size.x - PixFont.text_width(bait_txt, 2) - 12.0, 72.0),
			bait_txt, bait_c, Color("#050a12", 0.6), 2, 1, 1)

	if msg_text != "":
		var txt := msg_text
		var tw := PixFont.text_width(txt, 3)
		var mx := (view_size.x - tw) * 0.5
		var my := view_size.y - 150.0
		_ui_panel(Rect2(mx - 14.0, my - 8.0, tw + 28.0, 30.0), Color("#141c2c", 0.72), Color("#3b4a63", 0.8))
		PixFont.draw_text_shadowed(self, Vector2(mx, my), txt, GameTheme.CREAM,
				Color("#050a12", 0.65), 3, 1, 1)

	if state == STATE_WORLD:
		var hint := "A/D WALK - AIM WITH MOUSE - SPACE OR CLICK TO CAST - I INDEX - B BOAT"
		if open_water:
			hint = "OPEN WATER - A/D SAIL - SPACE OR CLICK TO CAST - SAIL WEST TO RETURN"
		elif in_boat:
			hint = "A/D SAIL - AIM WITH MOUSE - SPACE OR CLICK TO CAST - B TO LAND"
		elif not rod_out:
			hint = "ROD AWAY - PRESS R TO TAKE IT OUT - B TO BOARD YOUR BOAT"
		var hw := PixFont.text_width(hint, 2)
		PixFont.draw_text_shadowed(self, Vector2((view_size.x - hw) * 0.5, view_size.y - 26.0), hint,
				Color("#c8d6e2"), Color("#050a12", 0.6), 2, 1, 1)


## Bait is bought at the shop and used up one charge per cast - without
## it rare fish barely bite, so the HUD keeps nudging the player.
func _bait_hud_text() -> String:
	var bait_id := String(GameState.gear.get("bait", ""))
	if bait_id == "":
		return "NO BAIT - RARE FISH BARELY BITE - BUY BAIT IN THE SHOP"
	return "BAIT: %s x%d" % [String(ShopDB.item("baits", bait_id).get("name", "Bait")).to_upper(),
			GameState.bait_count(bait_id)]


func _draw_menu() -> void:
	draw_rect(Rect2(0.0, 0.0, view_size.x, view_size.y), Color("#0b1320", 0.62))
	var pw := 520.0
	var ph := 330.0
	var px := (view_size.x - pw) * 0.5
	var py := (view_size.y - ph) * 0.5
	_ui_panel(Rect2(px, py, pw, ph), Color("#1d2536", 0.96), GameTheme.CREAM)

	var t1 := "COTTAGE CREEK"
	var t2 := "FISHING"
	PixFont.draw_text_centered(self, px + pw * 0.5, py + 30.0, t1, GameTheme.GOLD, 5, 1)
	PixFont.draw_text_centered(self, px + pw * 0.5, py + 78.0, t2, GameTheme.CREAM, 5, 1)
	var sub := "CAST - HOOK - REEL - COLLECT"
	var sw := PixFont.text_width(sub, 2)
	PixFont.draw_text_shadowed(self, Vector2(px + (pw - sw) * 0.5, py + 126.0), sub,
			Color("#aebfd0"), Color("#050a12", 0.6), 2, 1, 1)

	menu_buttons = _menu_button_rects()
	for i in range(menu_buttons.size()):
		var b := menu_buttons[i] as Dictionary
		var r := b["rect"] as Rect2
		var hovered: bool = i == hover_button
		var fill := Color("#3c4a63") if hovered else Color("#2b3648")
		_ui_panel(r, fill, GameTheme.CREAM if hovered else Color("#4b5a70"), 3.0)
		var label := String(b["label"])
		var lw := PixFont.text_width(label, 3)
		PixFont.draw_text_shadowed(self, Vector2(r.position.x + (r.size.x - lw) * 0.5,
				r.position.y + (r.size.y - 24.0) * 0.5), label,
				GameTheme.CREAM, Color("#050a12", 0.6), 3, 1, 1)

	var foot := "SPACE / CLICK TO START - 1-4 SPOTS"
	var fw := PixFont.text_width(foot, 2)
	PixFont.draw_text_shadowed(self, Vector2(px + (pw - fw) * 0.5, py + ph - 34.0), foot,
			Color("#e9d8a8"), Color("#050a12", 0.6), 2, 1, 1)


func _draw_catch_popup() -> void:
	draw_rect(Rect2(0.0, 0.0, view_size.x, view_size.y), Color("#0b1320", 0.55))
	var pw := 440.0
	var ph := 310.0
	var px := (view_size.x - pw) * 0.5
	var py := (view_size.y - ph) * 0.5
	_ui_panel(Rect2(px, py, pw, ph), GameTheme.PAPER, GameTheme.INK, 5.0)

	var name_val := fish_name(catch_fish_id).to_upper()
	var nw := PixFont.text_width(name_val, 4)
	PixFont.draw_text_centered(self, px + pw * 0.5, py + 24.0, name_val, GameTheme.INK, 4, 1)

	var rarity_color := GameTheme.get_rarity_color(catch_rarity)
	var rw := PixFont.text_width(catch_rarity.to_upper(), 3)
	var rx := px + (pw - (rw + 20.0)) * 0.5
	_ui_panel(Rect2(rx, py + 66.0, rw + 20.0, 26.0), rarity_color, GameTheme.INK, 3.0)
	PixFont.draw_text_centered(self, px + pw * 0.5, py + 72.0, catch_rarity.to_upper(),
			Color("#18202c"), 3, 1)

	if catch_new:
		var nw2 := PixFont.text_width("NEW SPECIES!", 3)
		var nx := px + pw * 0.5 + nw2 * 0.5 + 14.0
		PixFont.draw_text_shadowed(self, Vector2(nx, py + 70.0), "NEW SPECIES!", GameTheme.GOLD,
				Color("#050a12", 0.35), 3, 1, 1)

	FishArt.draw_fish(self, Rect2(px + 90.0, py + 104.0, pw - 180.0, 74.0),
			FishDB.fish_data(catch_fish_id), false, 1.0)

	var w_txt := "WEIGHT %.2f KG   WORTH %d COINS - SELL IT" % [catch_weight, catch_coins]
	PixFont.draw_text_centered(self, px + pw * 0.5, py + 200.0, w_txt, GameTheme.WOOD_DARK, 3, 1)

	var f := FishDB.fish_data(catch_fish_id)
	var d_txt := String(f.get("desc", ""))
	var dw := PixFont.text_width(d_txt, 2)
	PixFont.draw_text_centered(self, px + pw * 0.5, py + 234.0, d_txt, Color("#5a4a55"), 2, 1)

	var br := Rect2(px + pw * 0.5 - 110.0, py + 256.0, 220.0, 40.0)
	var bh: bool = br.has_point(mouse_pos)
	_ui_panel(br, GameTheme.LEAF if bh else Color("#5c8a52"), GameTheme.INK, 3.0)
	var lab := "KEEP FISHING"
	var lw := PixFont.text_width(lab, 3)
	PixFont.draw_text_centered(self, px + pw * 0.5, py + 262.0, lab, GameTheme.CREAM, 3, 1)
