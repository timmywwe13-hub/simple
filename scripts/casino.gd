class_name Casino
extends Interactable

## The Lucky Lily, a toy-coin riverboat moored in Town. Three fixed-odds
## games, a persistent stake, a short reveal and a ledger. There is no real
## money and no chip store: only coins earned by fishing can be wagered.
##
## The wager is settled immediately when the button is pressed, so closing
## the panel during the reveal can never duplicate or lose a payout. The
## animation then lands on the result that CasinoDB already resolved.

const CasinoDBLib := preload("res://scripts/casino_db.gd")

## The reel is drawn as three copies of its twelve stops so the strip can
## fill the window on both sides of the pointer. The first copy passes
## during a spin; the result lands in the middle copy and the last copy
## supplies the cells to its right.
const REEL_CELL_W := 124.0
const REEL_WINDOW_W := 620.0
const REEL_LOOPS := 2
const REEL_H := 58.0

var game_id := "coin"
var current_stake := 10
var busy := false
var session_wagered := 0
var session_returned := 0
var loss_streak := 0
var scroll_pos := 0

var panel_scroll: ScrollContainer
var coins_label: Label
var stake_hint: Label
var game_box: VBoxContainer
var result_label: Label
var ledger_label: Label
var nudge_label: Label
var stake_buttons: Array[Button] = []
var tab_buttons: Array[Button] = []
var action_buttons: Array[Button] = []
var reel_window: Control
var reel_strip: HBoxContainer


func _ready() -> void:
	# The riverboat is wider than the other stalls, so keep its walk-up
	# bubble from reaching across the Fish Market next door.
	zone_radius = 68.0


func art_height() -> float:
	return 118.0


func prompt_label() -> String:
	return "LUCKY LILY"


func interact() -> void:
	if town == null or busy:
		return
	session_wagered = 0
	session_returned = 0
	loss_streak = 0
	stake_buttons.clear()
	tab_buttons.clear()
	action_buttons.clear()
	current_stake = _safe_stake(GameState.casino_bet)
	GameState.casino_bet = current_stake
	var s := TownUI.screen(town.ui_layer, "THE LUCKY LILY", Vector2(760.0, 480.0))
	panel_scroll = s["scroll"] as ScrollContainer
	coins_label = s["coins"] as Label
	var body: VBoxContainer = s["body"]
	body.add_theme_constant_override("separation", 4)
	var subtitle := UILib.label(body,
			"TOY COINS ONLY - NO REAL MONEY, NO PURCHASES, NO CHIPS TO BUY",
			13, GameTheme.SUBTEXT)
	subtitle.custom_minimum_size = Vector2(0.0, 20.0)
	_build_stake_row(body)
	stake_hint = UILib.label(body, "", 12, GameTheme.SUBTEXT)
	stake_hint.custom_minimum_size = Vector2(0.0, 18.0)
	_build_tabs(body)
	game_box = VBoxContainer.new()
	game_box.add_theme_constant_override("separation", 6)
	game_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(game_box)
	result_label = UILib.label(body, "", 15, UILib.CREAM)
	result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result_label.custom_minimum_size = Vector2(0.0, 22.0)
	ledger_label = UILib.label(body, "", 13, Color("#c8b89f"))
	ledger_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ledger_label.custom_minimum_size = Vector2(0.0, 32.0)
	nudge_label = UILib.label(body, "", 12, GameTheme.GOLD)
	nudge_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nudge_label.visible = false
	_rebuild_game()
	_refresh()
	if panel_scroll != null:
		panel_scroll.scroll_vertical = scroll_pos
		panel_scroll.set_deferred("scroll_vertical", scroll_pos)
	town.open_panel(s["root"])


func _safe_stake(value: int) -> int:
	for bet in CasinoDBLib.BETS:
		if int(bet) == value:
			return value
	return int(CasinoDBLib.BETS[0])


func _max_mult() -> int:
	match game_id:
		"coin":
			return 2
		"shells":
			return 3
		"reel":
			return 5
	return 2


func _build_stake_row(body: VBoxContainer) -> void:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 4)
	hb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(hb)
	for bet in CasinoDBLib.BETS:
		var b := UILib.button(hb, str(int(bet)), _on_stake.bind(int(bet)), 15,
				UILib.PANEL_LIGHT, GameTheme.BUTTON_HOVER, GameTheme.BUTTON_PRESS,
				UILib.CREAM, Vector2(102.0, 32.0))
		b.set_meta("stake", int(bet))
		stake_buttons.append(b)


func _build_tabs(body: VBoxContainer) -> void:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	hb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(hb)
	for entry in CasinoDBLib.GAMES:
		var id := String(entry.get("id", ""))
		var b := UILib.button(hb, String(entry.get("name", id)), _on_tab.bind(id), 15,
				UILib.PANEL_LIGHT, GameTheme.BUTTON_HOVER, GameTheme.BUTTON_PRESS,
				UILib.CREAM, Vector2(222.0, 38.0))
		b.set_meta("game", id)
		tab_buttons.append(b)


func _on_stake(value: int) -> void:
	if busy:
		return
	current_stake = _safe_stake(value)
	GameState.casino_bet = current_stake
	GameState.request_save()
	GameState.play_sound("ui")
	_refresh()


func _on_tab(id: String) -> void:
	if busy or id == game_id:
		return
	game_id = id
	GameState.play_sound("ui")
	if is_instance_valid(panel_scroll):
		scroll_pos = panel_scroll.scroll_vertical
	if is_instance_valid(result_label):
		result_label.text = ""
	_rebuild_game()
	_refresh()


func _rebuild_game() -> void:
	if not is_instance_valid(game_box):
		return
	var keep := 0
	if is_instance_valid(panel_scroll):
		keep = panel_scroll.scroll_vertical
	for child in game_box.get_children():
		game_box.remove_child(child)
		child.queue_free()
	action_buttons.clear()
	reel_window = null
	reel_strip = null
	var entry := CasinoDBLib.game(game_id)
	var odds := UILib.label(game_box, String(entry.get("odds", "")), 13, GameTheme.SUBTEXT)
	odds.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	odds.custom_minimum_size = Vector2(0.0, 26.0)
	match game_id:
		"coin":
			var hb := HBoxContainer.new()
			hb.add_theme_constant_override("separation", 10)
			hb.alignment = BoxContainer.ALIGNMENT_CENTER
			game_box.add_child(hb)
			var heads := UILib.button(hb, "HEADS", _play.bind("HEADS"), 18,
					UILib.PANEL_LIGHT, GameTheme.BUTTON_HOVER, GameTheme.BUTTON_PRESS,
					UILib.CREAM, Vector2(180.0, 44.0))
			var tails := UILib.button(hb, "TAILS", _play.bind("TAILS"), 18,
					UILib.PANEL_LIGHT, GameTheme.BUTTON_HOVER, GameTheme.BUTTON_PRESS,
					UILib.CREAM, Vector2(180.0, 44.0))
			action_buttons.append(heads)
			action_buttons.append(tails)
		"shells":
			var hb := HBoxContainer.new()
			hb.add_theme_constant_override("separation", 10)
			hb.alignment = BoxContainer.ALIGNMENT_CENTER
			game_box.add_child(hb)
			for i in range(1, 4):
				var b := UILib.button(hb, "SHELL %d" % i, _play.bind(str(i)), 17,
						UILib.PANEL_LIGHT, GameTheme.BUTTON_HOVER, GameTheme.BUTTON_PRESS,
						UILib.CREAM, Vector2(180.0, 50.0))
				action_buttons.append(b)
		"reel":
			_build_reel()
			var spin := UILib.button(game_box, "SPIN THE REEL", _play.bind("SPIN"), 18,
					GameTheme.GOLD, Color("#ffe08a"), Color("#c99a2e"),
					UILib.INK, Vector2(230.0, 40.0))
			spin.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			action_buttons.append(spin)
	if is_instance_valid(panel_scroll):
		panel_scroll.scroll_vertical = keep
		panel_scroll.set_deferred("scroll_vertical", keep)


func _build_reel() -> void:
	reel_window = Control.new()
	reel_window.custom_minimum_size = Vector2(REEL_WINDOW_W, REEL_H)
	reel_window.clip_contents = true
	reel_window.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reel_window.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	game_box.add_child(reel_window)
	reel_strip = HBoxContainer.new()
	reel_strip.add_theme_constant_override("separation", 0)
	reel_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reel_window.add_child(reel_strip)
	var stops := CasinoDBLib.reel_stops()
	for _cycle in range(REEL_LOOPS + 1):
		for i in range(stops.size()):
			var stop: Dictionary = stops[i]
			var cell := ColorRect.new()
			cell.color = UILib.PANEL_LIGHT.darkened(0.25) if i % 2 == 0 else UILib.PANEL
			cell.custom_minimum_size = Vector2(REEL_CELL_W, REEL_H)
			cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
			reel_strip.add_child(cell)
			var mult := float(stop.get("mult", 0.0))
			var col := GameTheme.GOLD if mult >= 5.0 else (Color("#a8e6b8") if mult >= 2.0 else UILib.CREAM)
			var l := UILib.label(cell, String(stop.get("label", "MISS")), 16, col, true,
					HORIZONTAL_ALIGNMENT_CENTER)
			l.position = Vector2.ZERO
			l.size = Vector2(REEL_CELL_W, REEL_H)
	# A plain Control does not lay out a Container child, so give the strip
	# its explicit full width once; the HBox then positions all the cells.
	reel_strip.size = Vector2(REEL_CELL_W * float(stops.size()) * float(REEL_LOOPS + 1), REEL_H)
	var pointer := Control.new()
	pointer.set_anchors_preset(Control.PRESET_FULL_RECT)
	pointer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reel_window.add_child(pointer)
	pointer.draw.connect(_draw_reel_pointer.bind(pointer))
	reel_strip.position = Vector2.ZERO


func _draw_reel_pointer(pointer: Control) -> void:
	# Small triangles at the top and bottom edges mark the winning cell
	# without drawing a line through its label.
	var x := pointer.size.x * 0.5
	var h := pointer.size.y
	pointer.draw_colored_polygon(PackedVector2Array([
		Vector2(x - 8.0, 0.0), Vector2(x + 8.0, 0.0), Vector2(x, 9.0),
	]), GameTheme.GOLD)
	pointer.draw_colored_polygon(PackedVector2Array([
		Vector2(x - 8.0, h), Vector2(x + 8.0, h), Vector2(x, h - 9.0),
	]), GameTheme.GOLD)


func _play(choice: String) -> void:
	if busy or town == null:
		return
	if GameState.coins < int(CasinoDBLib.BETS[0]):
		GameState.play_sound("buzz")
		town.toast("NOT ENOUGH COINS - SELL SOME FISH FIRST")
		_refresh()
		return
	if current_stake > GameState.coins:
		GameState.play_sound("buzz")
		town.toast("PICK A SMALLER STAKE")
		_refresh()
		return
	busy = true
	_refresh()
	var result := CasinoDBLib.resolve(game_id, current_stake, choice)
	var stake := int(result["stake"])
	var payout := int(result["payout"])
	var profit := GameState.casino_settle(stake, payout, game_id)
	session_wagered += stake
	session_returned += payout
	if profit < 0:
		loss_streak += 1
	else:
		loss_streak = 0
	if is_instance_valid(result_label):
		result_label.text = "DEALING..."
		result_label.add_theme_color_override("font_color", GameTheme.GOLD)
	_refresh()
	match game_id:
		"coin":
			await _reveal_coin(result)
		"shells":
			await _reveal_shells(result)
		"reel":
			await _animate_reel(int(result["index"]))
	busy = false
	if is_instance_valid(result_label):
		_show_result(result)
	if int(result["multiplier"]) >= 5.0:
		GameState.play_sound("rare")
	_refresh()


func _reveal_coin(result: Dictionary) -> void:
	if GameState.reduce_motion():
		await get_tree().create_timer(0.12).timeout
		return
	var t := 0.0
	while t < 0.5:
		if not is_instance_valid(result_label):
			return
		result_label.text = "FLIPPING... %s" % ("HEADS" if int(t * 20.0) % 2 == 0 else "TAILS")
		await get_tree().create_timer(0.07).timeout
		t += 0.07
	if is_instance_valid(result_label):
		result_label.text = "THE COIN LANDS ON %s..." % String(result["landed"])
	await get_tree().create_timer(0.12).timeout


func _reveal_shells(result: Dictionary) -> void:
	if GameState.reduce_motion():
		await get_tree().create_timer(0.10).timeout
		return
	if is_instance_valid(result_label):
		result_label.text = "SHUFFLING THE SHELLS..."
	await get_tree().create_timer(0.22).timeout
	if is_instance_valid(result_label):
		result_label.text = "LIFTING SHELL %s..." % String(result["landed"])
	await get_tree().create_timer(0.18).timeout


func _animate_reel(stop_index: int) -> void:
	if not is_instance_valid(reel_strip):
		await get_tree().create_timer(0.10).timeout
		return
	var stops := CasinoDBLib.reel_stops()
	var target_index := stop_index + stops.size()
	var target := REEL_WINDOW_W * 0.5 - (float(target_index) + 0.5) * REEL_CELL_W
	reel_strip.position = Vector2.ZERO
	if GameState.reduce_motion():
		reel_strip.position.x = target
		await get_tree().create_timer(0.12).timeout
		return
	var tw := create_tween()
	tw.tween_property(reel_strip, "position:x", target, 1.0) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	for _i in range(7):
		await get_tree().create_timer(0.13).timeout
		if not is_instance_valid(reel_strip):
			tw.kill()
			return
		GameState.play_sound("reel")
	await get_tree().create_timer(0.10).timeout
	if is_instance_valid(reel_strip):
		reel_strip.position.x = target
	else:
		tw.kill()


func _show_result(result: Dictionary) -> void:
	var payout := int(result["payout"])
	var stake := int(result["stake"])
	var net := payout - stake
	var detail := String(result["detail"])
	var text := ""
	var color := GameTheme.GOLD
	if net > 0:
		text = "%s - WON %d COINS" % [detail, net]
		color = Color("#8fe6a8")
	elif net == 0:
		text = "%s - STAKE RETURNED" % detail
	else:
		if payout > 0:
			text = "%s - RETURNED %d (NET %s)" % [detail, payout, _signed(net)]
		else:
			text = "%s - LOST %d COINS" % [detail, -net]
		color = Color("#ff9a9a")
	result_label.text = text
	result_label.add_theme_color_override("font_color", color)


func _refresh() -> void:
	if is_instance_valid(coins_label):
		coins_label.text = "COINS %d" % GameState.coins
	var can_bet := GameState.coins >= int(CasinoDBLib.BETS[0])
	for b in stake_buttons:
		if not is_instance_valid(b):
			continue
		var value := int(b.get_meta("stake", 10))
		b.disabled = busy or value > GameState.coins
		_style_pick(b, value == current_stake)
	for b in tab_buttons:
		if not is_instance_valid(b):
			continue
		b.disabled = busy
		_style_pick(b, String(b.get_meta("game", "")) == game_id)
	for b in action_buttons:
		if is_instance_valid(b):
			b.disabled = busy or not can_bet or current_stake > GameState.coins
	if is_instance_valid(stake_hint):
		if not can_bet:
			stake_hint.text = "NOT ENOUGH COINS - SELL SOME FISH FIRST"
			stake_hint.add_theme_color_override("font_color", Color("#ff9a9a"))
		elif current_stake > GameState.coins:
			stake_hint.text = "STAKE %d IS ABOVE YOUR %d COINS - PICK A SMALLER STAKE" % [current_stake, GameState.coins]
			stake_hint.add_theme_color_override("font_color", Color("#ffd27a"))
		else:
			stake_hint.text = "STAKE %d  -  WIN UP TO %d COINS AT %dX" % [
				current_stake, current_stake * _max_mult(), _max_mult()]
			stake_hint.add_theme_color_override("font_color", GameTheme.SUBTEXT)
	if is_instance_valid(ledger_label):
		var lifetime_w := int(GameState.stats.get("casino_wagered", 0))
		var lifetime_r := int(GameState.stats.get("casino_returned", 0))
		ledger_label.text = "SESSION %s  |  WAGERED %d  |  RETURNED %d\nLIFETIME NET %s  |  BIGGEST WIN %d" % [
			_signed(session_returned - session_wagered), session_wagered, session_returned,
			_signed(lifetime_r - lifetime_w), int(GameState.stats.get("casino_biggest_win", 0))]
	if is_instance_valid(nudge_label):
		if loss_streak >= 3:
			var lines := [
				"THE FISH ARE BITING - MAYBE TAKE A WALK?",
				"LUCK LOVES A BREAK, DARLING.",
				"THE HOUSE IS PATIENT. YOUR COINS CAN WAIT.",
			]
			nudge_label.text = "THE LILY SAYS: %s" % lines[(loss_streak - 3) % lines.size()]
			nudge_label.visible = true
		else:
			nudge_label.visible = false


func _style_pick(b: Button, selected: bool) -> void:
	var base := GameTheme.GOLD if selected else UILib.PANEL_LIGHT
	var hover := Color("#ffe08a") if selected else GameTheme.BUTTON_HOVER
	var pressed := Color("#c99a2e") if selected else GameTheme.BUTTON_PRESS
	var styles := UILib.sfx_btn(base, hover, pressed)
	b.add_theme_stylebox_override("normal", styles["normal"])
	b.add_theme_stylebox_override("hover", styles["hover"])
	b.add_theme_stylebox_override("pressed", styles["pressed"])
	b.add_theme_stylebox_override("disabled", styles["disabled"])
	b.add_theme_stylebox_override("focus", styles["focus"])
	b.add_theme_color_override("font_color", UILib.INK if selected else UILib.CREAM)
	b.add_theme_color_override("font_color_hover", UILib.INK if selected else Color("#ffffff"))
	b.add_theme_color_override("font_color_pressed", UILib.INK if selected else Color("#ffe9b0"))


func _signed(value: int) -> String:
	if value > 0:
		return "+%d" % value
	return str(value)


func _draw() -> void:
	var wood := GameTheme.WOOD
	var wood_dark := GameTheme.WOOD_DARK
	# Waterline shadow, a short dock and the hull.
	_pixel_rect(Rect2(-70.0, -6.0, 140.0, 6.0), Color("#274252", 0.45))
	_pixel_rect(Rect2(-68.0, -8.0, 136.0, 6.0), Color("#6b4426"))
	for i in range(12):
		_pixel_rect(Rect2(-66.0 + float(i) * 11.0, -8.0, 2.0, 6.0), Color("#4b2e1e"))
	_pixel_rect(Rect2(-58.0, -34.0, 116.0, 28.0), wood_dark)
	_pixel_rect(Rect2(-54.0, -30.0, 108.0, 22.0), Color("#7b4b2e"))
	_pixel_rect(Rect2(-64.0, -28.0, 8.0, 18.0), wood_dark)
	_pixel_rect(Rect2(56.0, -28.0, 8.0, 18.0), wood_dark)
	_pixel_rect(Rect2(-68.0, -22.0, 6.0, 10.0), Color("#4b2e1e"))
	_pixel_rect(Rect2(62.0, -22.0, 6.0, 10.0), Color("#4b2e1e"))
	_pixel_rect(Rect2(-54.0, -10.0, 108.0, 4.0), Color("#3b2519"))
	for i in range(6):
		_pixel_rect(Rect2(-50.0 + float(i) * 19.0, -30.0, 3.0, 20.0), Color("#5a3623"))
	# Deck posts and striped canopy.
	_pixel_rect(Rect2(-48.0, -84.0, 4.0, 52.0), wood_dark)
	_pixel_rect(Rect2(44.0, -84.0, 4.0, 52.0), wood_dark)
	var stripe_cols := [Color("#b85443"), UILib.CREAM, Color("#4f7f9c"), UILib.CREAM]
	for i in range(8):
		_pixel_rect(Rect2(-56.0 + float(i) * 14.0, -96.0, 14.0, 16.0),
				stripe_cols[i % stripe_cols.size()])
	_pixel_rect(Rect2(-58.0, -100.0, 116.0, 5.0), wood_dark)
	# Scalloped canopy edge.
	for i in range(14):
		var c := UILib.CREAM if i % 2 == 0 else Color("#b85443")
		_pixel_rect(Rect2(-56.0 + float(i) * 8.0, -80.0, 8.0, 5.0), c)
	# Bunting and lanterns.
	for i in range(8):
		var x := -50.0 + float(i) * 14.0
		var c := GameTheme.GOLD if i % 2 == 0 else Color("#d96c5a")
		draw_colored_polygon(PackedVector2Array([
			Vector2(x, -82.0), Vector2(x + 11.0, -82.0), Vector2(x + 5.5, -74.0),
		]), c)
	for x in [-42.0, 42.0]:
		_pixel_rect(Rect2(x - 1.0, -78.0, 2.0, 7.0), wood_dark)
		_pixel_rect(Rect2(x - 5.0, -72.0, 10.0, 10.0), GameTheme.GOLD)
		_pixel_rect(Rect2(x - 3.0, -70.0, 6.0, 6.0), Color("#fff1a8"))
	# Signboard.
	_pixel_rect(Rect2(-50.0, -118.0, 100.0, 20.0), wood_dark)
	_pixel_rect(Rect2(-46.0, -114.0, 92.0, 12.0), UILib.PANEL)
	PixFont.draw_text_centered(self, 0.0, -111.0, "LUCKY LILY", GameTheme.GOLD, 2, 1)
	# Paddlewheel on the river side.
	var wheel_c := Vector2(49.0, -49.0)
	draw_circle(wheel_c, 13.0, Color("#d9b26a"))
	draw_circle(wheel_c, 10.0, Color("#8a6339"))
	draw_circle(wheel_c, 3.0, Color("#3b2519"))
	for i in range(8):
		var a := float(i) * PI / 4.0
		draw_line(wheel_c, wheel_c + Vector2(cos(a), sin(a)) * 11.0, Color("#3b2519"), 2.0)
	# Card table and dice.
	_pixel_rect(Rect2(-30.0, -24.0, 26.0, 5.0), Color("#4b2e1e"))
	_pixel_rect(Rect2(-26.0, -36.0, 16.0, 13.0), UILib.CREAM)
	_pixel_rect(Rect2(-23.0, -33.0, 10.0, 7.0), Color("#c94b4b"))
	_pixel_rect(Rect2(-8.0, -34.0, 12.0, 12.0), UILib.CREAM)
	_pixel_rect(Rect2(-6.0, -32.0, 3.0, 3.0), UILib.INK)
	_pixel_rect(Rect2(3.0, -26.0, 3.0, 3.0), UILib.INK)
	draw_prompt()
