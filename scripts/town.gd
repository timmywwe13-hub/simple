class_name Town
extends Node2D

## Town scene: five walk-up interactions (General Store, Fish Market,
## Lucky Lily riverboat, Boat Dealer, Quest Giver), a walking player and
## the tunnel back to the fishing scene.
##
## Scene structure (all children are built in _ready(); town.tscn holds
## only the root node + this script):
##   Town (Node2D, town.gd)
##   ├─ GeneralStore (Interactable, store.gd)
##   ├─ FishMarket (Interactable, market.gd)
##   ├─ LuckyLily (Interactable, casino.gd)
##   ├─ BoatDealer (Interactable, boat_dealer.gd)
##   ├─ QuestGiver (Interactable, quest_giver.gd)
##   ├─ TownPlayer (CharacterBody2D, town_player.gd)
##   └─ Tunnel (Node2D, tunnel.gd -> res://main.tscn)

const PixFont := preload("res://scripts/pixel_font.gd")
const ChangelogLib := preload("res://scripts/changelog.gd")
const TouchControls := preload("res://scripts/touch_controls.gd")
const CasinoScript := preload("res://scripts/casino.gd")

var view_size := Vector2(960.0, 540.0)
var ground_y := 430.0

var ui_layer: CanvasLayer
var player: TownPlayer
var touch: TouchControls
var tunnel: Tunnel
var interactables: Array[Interactable] = []
var layout: Array[Dictionary] = []
var current: Interactable = null
var active_panel: Control
var toast_text := ""
var toast_timer := 0.0
var updates_btn: Button
var updates_prev := false
## Physical-key edges for the typed `2222` testing cheat (Town has no
## number-key shortcuts of its own, so the digits are free here).
var digit_prev := {}


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		GameState.flush_save()
		get_tree().quit()


func _ready() -> void:
	view_size = get_viewport_rect().size
	ground_y = view_size.y * 0.78
	get_viewport().size_changed.connect(_relayout)
	ui_layer = CanvasLayer.new()
	ui_layer.name = "UI"
	add_child(ui_layer)
	touch = TouchControls.new()
	add_child(touch)
	touch.setup("town")
	_spawn_interactables()
	_spawn_player()
	_spawn_tunnel()
	_build_updates_button()
	GameState.play_sound("ui")


## Always-visible What's New button in the top-right corner, plus the U key
## for keyboard players. The badge marks notes this version has not shown
## yet.
func _build_updates_button() -> void:
	updates_btn = UILib.button(null, _updates_label(), _on_updates, 14,
			GameTheme.PANEL_LIGHT, UILib.BUTTON_HOVER, UILib.BUTTON_PRESS, UILib.CREAM,
			Vector2(166.0, 34.0))
	ui_layer.add_child(updates_btn)
	updates_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	updates_btn.offset_left = -190.0
	updates_btn.offset_top = 52.0
	updates_btn.offset_right = -24.0
	updates_btn.offset_bottom = 86.0


func _updates_label() -> String:
	return "WHAT'S NEW!" if ChangelogLib.is_unseen() else "WHAT'S NEW"


func _on_updates() -> void:
	GameState.play_sound("ui")
	ChangelogLib.mark_seen()
	if updates_btn != null:
		updates_btn.text = _updates_label()
	var s := TownUI.screen(ui_layer, "WHAT'S NEW")
	var body: VBoxContainer = s["body"]
	s["coins"].text = "V%s" % ChangelogLib.VERSION
	ChangelogLib.fill(body)
	open_panel(s["root"])


func _relayout() -> void:
	view_size = get_viewport_rect().size
	ground_y = view_size.y * 0.78
	var art_scale := _art_scale()
	for entry in layout:
		var node: Interactable = entry["node"]
		node.position = Vector2(view_size.x * float(entry["x"]), ground_y + float(entry["y"]))
		node.scale = Vector2(art_scale, art_scale)
	# Keep the walker where it is when the window resizes (the old code
	# teleported it back to the middle of town) and only clamp it into the
	# new walkable lane.
	if player != null:
		player.set_bounds(_walk_bounds())
	else:
		_spawn_player()
	tunnel.position = Vector2(70.0, ground_y + 42.0)


func _walk_bounds() -> Rect2:
	return Rect2(28.0, ground_y + 20.0, maxf(40.0, view_size.x - 56.0), 54.0)


func _spawn_interactables() -> void:
	interactables.clear()
	layout.clear()
	_add("GeneralStore", GeneralStore.new(), 0.12, 0.0)
	_add("FishMarket", FishMarket.new(), 0.28, 0.0)
	_add("LuckyLily", CasinoScript.new(), 0.44, 0.0)
	_add("BoatDealer", BoatDealer.new(), 0.60, 0.0)
	_add("HarvestTable", HarvestTable.new(), 0.76, 0.0)
	_add("QuestGiver", QuestGiver.new(), 0.89, 18.0)


## Buildings shrink a little on narrow windows (640x360 phones) so five
## walk-ups still fit side by side without their awnings overlapping.
func _art_scale() -> float:
	return clampf(view_size.x / 1000.0, 0.70, 0.96)


func _add(name_str: String, node: Interactable, x_frac: float, y_off: float) -> void:
	node.name = name_str
	node.position = Vector2(view_size.x * x_frac, ground_y + y_off)
	node.scale = Vector2(_art_scale(), _art_scale())
	node.setup(self)
	add_child(node)
	interactables.append(node)
	layout.append({"node": node, "x": x_frac, "y": y_off})


func _spawn_player() -> void:
	player = TownPlayer.new()
	player.name = "TownPlayer"
	player.position = Vector2(view_size.x * 0.45, ground_y + 42.0)
	player.set_bounds(_walk_bounds())
	add_child(player)


func _spawn_tunnel() -> void:
	tunnel = Tunnel.new()
	tunnel.name = "Tunnel"
	tunnel.sign = "HOME"
	tunnel.target_scene = "res://main.tscn"
	tunnel.position = Vector2(70.0, ground_y + 42.0)
	add_child(tunnel)


func _process(dt: float) -> void:
	_track_cheat_digits()
	if touch != null:
		touch.sync_settings()
	GameState.set_music("town", false)
	GameState.set_ambience_region("town", false)
	# U opens the patch notes from anywhere in town (not while typing a code
	# or a panel is already open).
	var u_now := Input.is_physical_key_pressed(KEY_U)
	if u_now and not updates_prev and active_panel == null:
		_on_updates()
	updates_prev = u_now
	if toast_timer > 0.0:
		toast_timer = maxf(0.0, toast_timer - dt)
		if toast_timer == 0.0:
			toast_text = ""
	if touch != null:
		touch.set_context("panel" if active_panel != null else "world")
	if active_panel != null:
		var esc := Input.is_action_just_pressed("ui_cancel")
		var consumed: bool = esc and active_panel.has_method("handle_escape") and active_panel.handle_escape()
		if not consumed and (esc or _touch_tap("menu")):
			close_panel()
		queue_redraw()
		return
	current = null
	var best_d := 0.0
	for c in interactables:
		var d := player.global_position.distance_to(c.global_position)
		if d < c.zone_radius and (current == null or d < best_d):
			current = c
			best_d = d
	if current != null and (Input.is_action_just_pressed("interact") or _touch_tap("interact")):
		GameState.play_sound("ui")
		current.interact()
	queue_redraw()


func _touch_tap(id: String) -> bool:
	return touch != null and touch.consume_tap(id)


## Type 2222 in town to unlock the whole game (see GameState.grant_everything).
## Any open shop panel is closed so it rebuilds with the new coins and stock.
func _track_cheat_digits() -> void:
	for code in [KEY_0, KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9]:
		var now := Input.is_physical_key_pressed(code)
		var was: bool = bool(digit_prev.get(code, false))
		digit_prev[code] = now
		if not now or was:
			continue
		if not GameState.cheat_digit(code - KEY_0):
			continue
		GameState.grant_everything()
		close_panel()
		GameState.play_sound("rare")
		toast("CHEAT ACCEPTED - EVERYTHING UNLOCKED")


func open_panel(panel: Control) -> void:
	if active_panel != null:
		close_panel()
	active_panel = panel
	if player:
		player.can_move = false


func close_panel() -> void:
	if active_panel != null:
		active_panel.queue_free()
		active_panel = null
	if player:
		player.can_move = true


func toast(text: String) -> void:
	toast_text = text
	toast_timer = 3.0


func _pixel_rect(r: Rect2, c: Color) -> void:
	if r.size.x <= 0.0 or r.size.y <= 0.0:
		return
	draw_rect(Rect2(snapped(r.position.x, 2.0), snapped(r.position.y, 2.0),
			maxf(2.0, snapped(r.size.x, 2.0)), maxf(2.0, snapped(r.size.y, 2.0))), c)


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


func _draw() -> void:
	var t := Time.get_ticks_msec() / 1000.0
	_draw_sky()
	_draw_clouds(t)
	_draw_hills()
	_draw_ground(t)
	_draw_fence()
	if GameState.harvest_season_open():
		_draw_harvest_dressing(t)
	_draw_hud()
	_draw_event_banner()
	if toast_text != "":
		var tw := PixFont.text_width(toast_text, 3)
		var tx := (view_size.x - tw) * 0.5
		var ty := view_size.y - 120.0
		_pixel_rect(Rect2(tx - 14.0, ty - 8.0, tw + 28.0, 30.0), Color(GameTheme.PANEL.darkened(0.15), 0.8))
		_pixel_rect(Rect2(tx - 14.0, ty - 8.0, tw + 28.0, 3.0), GameTheme.GOLD)
		PixFont.draw_text_shadowed(self, Vector2(tx, ty), toast_text, GameTheme.CREAM,
				Color("#050a12", 0.65), 3, 1, 1)


func _draw_sky() -> void:
	var top := GameTheme.SKY_TOP
	var mid := GameTheme.SKY_MID
	var low := GameTheme.SKY_LOW
	var horizon := ground_y
	var bands := 20
	for i in range(bands):
		var y0 := horizon * float(i) / float(bands)
		var y1 := horizon * float(i + 1) / float(bands)
		var tt := float(i) / float(bands - 1)
		var c: Color
		if tt < 0.5:
			c = top.lerp(mid, clampf(tt / 0.5, 0.0, 1.0))
		else:
			c = mid.lerp(low, clampf((tt - 0.5) / 0.5, 0.0, 1.0))
		_pixel_rect(Rect2(0.0, y0, view_size.x, y1 - y0 + 2.0), c)
	_draw_pixel_circle(Vector2(view_size.x * 0.16, 76.0), 24.0, GameTheme.WHEAT, 4.0)


func _draw_clouds(t: float) -> void:
	var base := GameTheme.CLOUD
	base.a = 0.8
	for i in range(5):
		var y := 36.0 + float(i) * 26.0
		var x := fposmod(float(i) * 197.0 + t * (4.0 + float(i) * 2.0), view_size.x + 320.0) - 160.0
		var w := 150.0 + float(i) * 45.0
		_pixel_rect(Rect2(x, y, w, 8.0), base)
		_pixel_rect(Rect2(x + w * 0.22, y - 8.0, w * 0.45, 8.0), base)
		_pixel_rect(Rect2(x + w * 0.6, y - 4.0, w * 0.32, 4.0), base)


func _draw_hills() -> void:
	var layers := [
		{"c": GameTheme.MOUNTAIN_FAR, "amp": 40.0, "off": 0.0, "w": 10.0, "f": 0.0031},
		{"c": GameTheme.MOUNTAIN_MID, "amp": 28.0, "off": 1.7, "w": 10.0, "f": 0.0052},
	]
	for l in layers:
		var x := 0.0
		while x < view_size.x:
			var hgt := ground_y - 70.0 - absf(sin(x * float(l["f"]) + float(l["off"]))) * float(l["amp"])
			_pixel_rect(Rect2(x, hgt, float(l["w"]) + 2.0, ground_y + 60.0 - hgt), l["c"])
			x += float(l["w"])


func _draw_ground(t: float) -> void:
	_pixel_rect(Rect2(0.0, ground_y, view_size.x, view_size.y - ground_y + 2.0), GameTheme.GRASS)
	_pixel_rect(Rect2(0.0, ground_y, view_size.x, 5.0), GameTheme.GRASS_DARK)
	for i in range(70):
		var sx := fmod(float(i) * 71.0, view_size.x)
		var sy := ground_y + 8.0 + fmod(float(i) * 53.0, maxf(1.0, view_size.y - ground_y - 12.0))
		var sway := sin(t * 1.4 + float(i) * 0.6) * 2.0
		_pixel_rect(Rect2(sx + sway, sy, 3.0, 7.0), GameTheme.GRASS_DARK if i % 3 == 0 else GameTheme.GRASS.lightened(0.08))
	# dirt path the player walks
	_pixel_rect(Rect2(0.0, ground_y + 30.0, view_size.x, 34.0), GameTheme.DIRT)
	_pixel_rect(Rect2(0.0, ground_y + 30.0, view_size.x, 4.0), GameTheme.DIRT_LIGHT)
	for i in range(48):
		var px := fmod(float(i) * 61.0, view_size.x)
		var py := ground_y + 40.0 + fmod(float(i) * 29.0, 20.0)
		_pixel_rect(Rect2(px, py, 8.0, 5.0), GameTheme.DIRT_LIGHT if i % 2 == 0 else GameTheme.DIRT.darkened(0.2))
	# flowers
	for i in range(10):
		var fx := fmod(float(i) * 137.0 + 40.0, view_size.x)
		var fy := ground_y + 12.0 + fmod(float(i) * 61.0, 14.0)
		if GameState.harvest_season_open():
			_pixel_rect(Rect2(fx, fy, 3.0, 3.0), GameTheme.PUMPKIN if i % 2 == 0 else GameTheme.GOLD)
		else:
			_pixel_rect(Rect2(fx, fy, 3.0, 3.0), Color("#e8d0a0") if i % 2 == 0 else Color("#d98cb0"))


func _draw_fence() -> void:
	var y := ground_y - 2.0
	var x := 0.0
	while x < view_size.x:
		_pixel_rect(Rect2(x, y - 22.0, 5.0, 22.0), GameTheme.WOOD_DARK)
		x += 34.0
	_pixel_rect(Rect2(0.0, y - 18.0, view_size.x, 4.0), GameTheme.WOOD)
	_pixel_rect(Rect2(0.0, y - 10.0, view_size.x, 4.0), GameTheme.WOOD)


## Autumn festival dressing: string lights between the awnings, bunting,
## hay bales, corn stalks, a scarecrow, pumpkin stacks and drifting leaves.
## The trestle table itself is the HarvestTable walk-up's own art.
func _draw_harvest_dressing(t: float) -> void:
	var wire := GameTheme.WHEAT.darkened(0.28)
	var x0 := view_size.x * 0.09
	var x1 := view_size.x * 0.94
	var ly := ground_y - 146.0
	# sagging string lights
	for i in range(1, 33):
		var f := float(i) / 32.0
		var p := Vector2(lerpf(x0, x1, f), ly + sin(f * PI) * 26.0)
		_pixel_rect(Rect2(p.x - 3.0, p.y, 6.0, 2.0), wire)
	for i in range(1, 20):
		var f := float(i) / 20.0
		var p := Vector2(lerpf(x0, x1, f), ly + sin(f * PI) * 26.0 + 5.0)
		var warm := GameTheme.GOLD if i % 3 != 0 else GameTheme.PUMPKIN
		_pixel_rect(Rect2(p.x - 3.0, p.y, 6.0, 7.0), warm)
		if GameState.quality_level() >= 1:
			_draw_pixel_circle(p + Vector2(0.0, 3.0), 10.0, Color(warm.r, warm.g, warm.b, 0.12), 4.0)
	# bunting triangles under the lights
	for i in range(9):
		var f := float(i) / 8.0
		var bx := lerpf(x0, x1, f)
		var by := ly + sin(f * PI) * 26.0 + 9.0
		var bc: Color = [GameTheme.PUMPKIN, GameTheme.GOLD, GameTheme.CRANBERRY, GameTheme.LEAF][i % 4]
		_pixel_rect(Rect2(bx - 5.0, by, 10.0, 2.0), wire)
		_pixel_rect(Rect2(bx - 4.0, by + 2.0, 8.0, 7.0), bc)
	# hay bales at the edges of the square
	for i in range(2):
		var hx := 18.0 + float(i) * (view_size.x - 96.0)
		var hy := ground_y + 46.0
		_pixel_rect(Rect2(hx, hy, 58.0, 26.0), GameTheme.WHEAT)
		_pixel_rect(Rect2(hx, hy, 58.0, 4.0), GameTheme.WHEAT.lightened(0.16))
		for j in range(4):
			_pixel_rect(Rect2(hx + 6.0 + float(j) * 13.0, hy + 6.0, 2.0, 16.0), GameTheme.HUSK)
	# corn-stalk bundles
	for i in range(4):
		var cx := 84.0 + float(i) * 74.0
		var top := ground_y - 54.0 - float(i % 2) * 8.0
		_pixel_rect(Rect2(cx, top, 3.0, ground_y + 22.0 - top), GameTheme.LEAF.darkened(0.2))
		_pixel_rect(Rect2(cx + 6.0, top + 6.0, 3.0, ground_y + 18.0 - top), GameTheme.LEAF.darkened(0.2))
		_pixel_rect(Rect2(cx - 7.0, top + 18.0, 14.0, 3.0), GameTheme.LEAF)
		_pixel_rect(Rect2(cx - 3.0, top + 4.0, 7.0, 10.0), GameTheme.GOLD)
	# scarecrow
	var sx := view_size.x * 0.035
	var sy := ground_y + 22.0
	_pixel_rect(Rect2(sx, sy - 54.0, 3.0, 54.0), GameTheme.WOOD_DARK)
	_pixel_rect(Rect2(sx - 22.0, sy - 38.0, 48.0, 3.0), GameTheme.WOOD_DARK)
	_pixel_rect(Rect2(sx - 10.0, sy - 40.0, 23.0, 22.0), GameTheme.CRANBERRY)
	_draw_pixel_circle(Vector2(sx + 1.0, sy - 48.0), 8.0, GameTheme.WHEAT, 3.0)
	_pixel_rect(Rect2(sx - 12.0, sy - 58.0, 28.0, 5.0), GameTheme.PUMPKIN)
	_pixel_rect(Rect2(sx - 2.0, sy - 50.0, 2.0, 2.0), GameTheme.INK)
	_pixel_rect(Rect2(sx + 5.0, sy - 50.0, 2.0, 2.0), GameTheme.INK)
	# pumpkin stacks beside the shops
	for i in range(5):
		var px := view_size.x * (0.20 + float(i) * 0.16)
		var py := ground_y + 58.0
		_draw_pixel_circle(Vector2(px, py), 9.0, GameTheme.PUMPKIN, 3.0)
		_draw_pixel_circle(Vector2(px + 14.0, py - 3.0), 7.0, GameTheme.EMBER, 3.0)
		_pixel_rect(Rect2(px - 2.0, py - 12.0, 3.0, 4.0), GameTheme.HUSK)
	# leaf drift (static dressing only when reduce motion is on)
	if GameState.reduce_motion():
		return
	for i in range(12):
		var lx := fposmod(float(i) * 97.0 + t * (10.0 + float(i) * 2.0), view_size.x + 80.0) - 40.0
		var ly2 := ground_y - 90.0 + fposmod(float(i) * 53.0 + t * 14.0,
				view_size.y - ground_y + 60.0)
		var lc: Color = [GameTheme.PUMPKIN, GameTheme.GOLD, GameTheme.EMBER, GameTheme.CRANBERRY][i % 4]
		lc.a = 0.85
		_pixel_rect(Rect2(lx, ly2, 6.0, 3.0), lc)
		_pixel_rect(Rect2(lx + 2.0, ly2 - 2.0, 3.0, 2.0), lc.lightened(0.16))


func _draw_hud() -> void:
	_hud_line("COINS %d" % GameState.coins, 12.0, 12.0, GameTheme.GOLD)
	var row := 50.0
	if GameState.harvest_season_open():
		_hud_line("%d HARVEST TOKENS  %s" % [GameState.harvest_tokens(), GameState.harvest_time_text()],
				12.0, row, GameTheme.GOLD)
		row += 40.0
	_hud_line("BUCKET %d/%d" % [GameState.inventory_count(), GameState.bucket_capacity()], 12.0, row, UILib.CREAM)
	row += 38.0
	GameState.ensure_daily()
	var daily_done := (GameState.daily.get("claimed", []) as Array).size()
	var daily_ready := GameState.daily_claimable_count()
	var daily_txt := "DAILIES %d/3" % daily_done
	if daily_ready > 0:
		daily_txt += " - %d READY" % daily_ready
	_hud_line(daily_txt, 12.0, row, GameTheme.GOLD if daily_ready > 0 else UILib.CREAM)
	var hint := "WASD / ARROWS - WALK    E - INTERACT    U - WHAT'S NEW    ESC - CLOSE"
	if touch != null and touch.enabled:
		hint = "DRAG THE STICK TO WALK - TAP TALK NEAR A BUILDING - CLOSE TO LEAVE A SHOP"
	PixFont.draw_text_shadowed(self, Vector2((view_size.x - PixFont.text_width(hint, 2)) * 0.5, view_size.y - 24.0),
			hint, GameTheme.SUBTEXT, Color("#050a12", 0.6), 2, 1, 1)


func _hud_line(txt: String, x: float, y: float, c: Color) -> void:
	var w := PixFont.text_width(txt, 3) + 24.0
	_pixel_rect(Rect2(x, y, w, 30.0), Color(GameTheme.PANEL.darkened(0.15), 0.8))
	_pixel_rect(Rect2(x, y, w, 3.0), Color(GameTheme.PANEL_LIGHT, 0.9))
	PixFont.draw_text_shadowed(self, Vector2(x + 12.0, y + 7.0), txt, c, Color("#050a12", 0.65), 3, 1, 1)


## Gold countdown strip for the 2x coin launch event.
func _draw_event_banner() -> void:
	# modal panels dim the world; don't leave a grey banner floating behind them
	if active_panel != null:
		return
	if GameState.harvest_season_open():
		var htxt := "HARVEST FEAST - %s LEFT" % GameState.harvest_time_text()
		var hw := PixFont.text_width(htxt, 2) + 22.0
		var hx := (view_size.x - hw) * 0.5
		_pixel_rect(Rect2(hx, 12.0, hw, 26.0), Color(GameTheme.PANEL.darkened(0.15), 0.85))
		_pixel_rect(Rect2(hx, 12.0, hw, 3.0), GameTheme.PUMPKIN)
		_pixel_rect(Rect2(hx, 35.0, hw, 3.0), GameTheme.EMBER)
		PixFont.draw_text_centered(self, view_size.x * 0.5, 18.0, htxt, GameTheme.WHEAT, 2, 1)
		return
	if not GameState.event_active():
		return
	var txt := "2X COINS - %s LEFT" % GameState.event_time_text()
	var w := PixFont.text_width(txt, 2) + 22.0
	var x := (view_size.x - w) * 0.5
	_pixel_rect(Rect2(x, 12.0, w, 26.0), Color(GameTheme.PANEL.darkened(0.15), 0.85))
	_pixel_rect(Rect2(x, 12.0, w, 3.0), GameTheme.GOLD)
	_pixel_rect(Rect2(x, 35.0, w, 3.0), GameTheme.GOLD.darkened(0.35))
	PixFont.draw_text_centered(self, view_size.x * 0.5, 18.0, txt, GameTheme.GOLD, 2, 1)