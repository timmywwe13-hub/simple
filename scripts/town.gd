class_name Town
extends Node2D

## Town scene: four walk-up interactions (General Store, Fish Market,
## Boat Dealer, Quest Giver), a walking player and the tunnel back to the
## fishing scene.
##
## Scene structure (all children are built in _ready(); town.tscn holds
## only the root node + this script):
##   Town (Node2D, town.gd)
##   ├─ GeneralStore (Interactable, store.gd)
##   ├─ FishMarket (Interactable, market.gd)
##   ├─ BoatDealer (Interactable, boat_dealer.gd)
##   ├─ QuestGiver (Interactable, quest_giver.gd)
##   ├─ TownPlayer (CharacterBody2D, town_player.gd)
##   └─ Tunnel (Node2D, tunnel.gd -> res://main.tscn)

const PixFont := preload("res://scripts/pixel_font.gd")
const TouchControls := preload("res://scripts/touch_controls.gd")

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
## Physical-key edges for the typed `2222` testing cheat (Town has no
## number-key shortcuts of its own, so the digits are free here).
var digit_prev := {}


func _ready() -> void:
	GameState._load_game()
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
	GameState.play_sound("ui")


func _relayout() -> void:
	view_size = get_viewport_rect().size
	ground_y = view_size.y * 0.78
	for entry in layout:
		var node: Interactable = entry["node"]
		node.position = Vector2(view_size.x * float(entry["x"]), ground_y + float(entry["y"]))
	player.position = Vector2(view_size.x * 0.45, ground_y + 42.0)
	tunnel.position = Vector2(70.0, ground_y + 42.0)


func _spawn_interactables() -> void:
	interactables.clear()
	layout.clear()
	_add("GeneralStore", GeneralStore.new(), 0.20, 0.0)
	_add("FishMarket", FishMarket.new(), 0.47, 0.0)
	_add("BoatDealer", BoatDealer.new(), 0.72, 0.0)
	_add("QuestGiver", QuestGiver.new(), 0.92, 18.0)


func _add(name_str: String, node: Interactable, x_frac: float, y_off: float) -> void:
	node.name = name_str
	node.position = Vector2(view_size.x * x_frac, ground_y + y_off)
	node.setup(self)
	add_child(node)
	interactables.append(node)
	layout.append({"node": node, "x": x_frac, "y": y_off})


func _spawn_player() -> void:
	player = TownPlayer.new()
	player.name = "TownPlayer"
	player.position = Vector2(view_size.x * 0.45, ground_y + 42.0)
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
	if toast_timer > 0.0:
		toast_timer = maxf(0.0, toast_timer - dt)
		if toast_timer == 0.0:
			toast_text = ""
	if touch != null:
		touch.set_context("panel" if active_panel != null else "world")
	if active_panel != null:
		if Input.is_action_just_pressed("ui_cancel") or _touch_tap("menu"):
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
	_draw_hud()
	if toast_text != "":
		var tw := PixFont.text_width(toast_text, 3)
		var tx := (view_size.x - tw) * 0.5
		var ty := view_size.y - 120.0
		_pixel_rect(Rect2(tx - 14.0, ty - 8.0, tw + 28.0, 30.0), Color("#141c2c", 0.8))
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
	_draw_pixel_circle(Vector2(view_size.x * 0.16, 76.0), 24.0, Color("#fff2cf"), 4.0)


func _draw_clouds(t: float) -> void:
	var base := Color("#fdf2f5")
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
		_pixel_rect(Rect2(fx, fy, 3.0, 3.0), Color("#e8d0a0") if i % 2 == 0 else Color("#d98cb0"))


func _draw_fence() -> void:
	var y := ground_y - 2.0
	var x := 0.0
	while x < view_size.x:
		_pixel_rect(Rect2(x, y - 22.0, 5.0, 22.0), GameTheme.WOOD_DARK)
		x += 34.0
	_pixel_rect(Rect2(0.0, y - 18.0, view_size.x, 4.0), GameTheme.WOOD)
	_pixel_rect(Rect2(0.0, y - 10.0, view_size.x, 4.0), GameTheme.WOOD)


func _draw_hud() -> void:
	_hud_line("COINS %d" % GameState.coins, 12.0, 12.0, GameTheme.GOLD)
	_hud_line("BUCKET %d/%d" % [GameState.inventory_count(), GameState.bucket_capacity()], 12.0, 40.0, UILib.CREAM)
	var hint := "WASD / ARROWS - WALK    E - INTERACT    ESC - CLOSE"
	PixFont.draw_text_shadowed(self, Vector2((view_size.x - PixFont.text_width(hint, 2)) * 0.5, view_size.y - 24.0),
			hint, Color("#c8d6e2"), Color("#050a12", 0.6), 2, 1, 1)


func _hud_line(txt: String, x: float, y: float, c: Color) -> void:
	var w := PixFont.text_width(txt, 3) + 24.0
	_pixel_rect(Rect2(x, y, w, 30.0), Color("#141c2c", 0.8))
	_pixel_rect(Rect2(x, y, w, 3.0), Color("#3b4a63", 0.9))
	PixFont.draw_text_shadowed(self, Vector2(x + 12.0, y + 7.0), txt, c, Color("#050a12", 0.65), 3, 1, 1)