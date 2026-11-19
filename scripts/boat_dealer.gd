class_name BoatDealer
extends Interactable

## Boat Dealer: buy and equip boats. Better boats move faster and raise
## the Fish Market payout (GameState.buy_boat / boat_value_mult).

func art_height() -> float:
	return 138.0

var panel_scroll: ScrollContainer
var scroll_pos := 0


func prompt_label() -> String:
	return "BOAT DEALER"


func interact() -> void:
	if town == null:
		return
	var s := TownUI.screen(town.ui_layer, "BOAT DEALER")
	var body: VBoxContainer = s["body"]
	panel_scroll = s["scroll"] as ScrollContainer
	if panel_scroll != null:
		panel_scroll.scroll_vertical = scroll_pos
		panel_scroll.set_deferred("scroll_vertical", scroll_pos)
	s["coins"].text = "COINS %d" % GameState.coins
	var intro := UILib.label(body, "BUY A BOAT - BETTER BOATS FETCH MORE AT THE FISH MARKET", 14, Color("#a8c0cc"))
	intro.custom_minimum_size = Vector2(0.0, 24.0)
	var cur := GameState.current_boat()
	var cur_l := UILib.label(body, "CURRENT: %s" % String(cur.get("name", "Old Raft")).to_upper(), 16, UILib.GOLD, true)
	cur_l.custom_minimum_size = Vector2(0.0, 26.0)
	var db: Dictionary = ShopDB.category("boats")
	for id in db.keys():
		var d: Dictionary = db[id]
		var owned := GameState.has_boat(id)
		var equipped := String(GameState.gear.get("boat", "")) == String(id)
		var row := TownUI.row(body, 50.0)
		var name_l := UILib.label(row, String(d.get("name", id)), 16, UILib.CREAM, true)
		name_l.position = Vector2(12.0, 5.0)
		var desc_l := UILib.label(row, String(d.get("desc", "")), 12, Color("#a8c0cc"))
		desc_l.position = Vector2(12.0, 26.0)
		var stat_l := UILib.label(row, "SPEED %.0f  VALUE +%.0f%%" % [float(d.get("speed", 90.0)),
				(float(d.get("value_mult", 1.0)) - 1.0) * 100.0], 12, GameTheme.LEAF)
		stat_l.position = Vector2(300.0, 10.0)
		var text := "EQUIPPED" if equipped else ("EQUIP" if owned else "BUY %d" % int(d.get("cost", 0)))
		TownUI.row_button(row, text, _on_buy.bind(String(id)))
	town.open_panel(s["root"])


func _on_buy(id: String) -> void:
	if GameState.buy_boat(id):
		GameState.play_sound("coin")
		_reopen()
	else:
		GameState.play_sound("buzz")
		town.toast("NOT ENOUGH COINS!")


func _reopen() -> void:
	if is_instance_valid(panel_scroll):
		scroll_pos = panel_scroll.scroll_vertical
	town.close_panel()
	interact()


func _draw() -> void:
	var wall := Color("#5f7d8c")
	var wall_dark := Color("#41596a")
	# shop body
	_pixel_rect(Rect2(-64.0, -96.0, 128.0, 96.0), wall)
	_pixel_rect(Rect2(-64.0, -96.0, 128.0, 4.0), wall_dark)
	_pixel_rect(Rect2(-64.0, -14.0, 128.0, 14.0), wall_dark)
	_pixel_rect(Rect2(-64.0, -96.0, 6.0, 96.0), wall_dark)
	_pixel_rect(Rect2(58.0, -96.0, 6.0, 96.0), wall_dark)
	# roof
	_pixel_rect(Rect2(-72.0, -110.0, 144.0, 8.0), Color("#33607a"))
	_pixel_rect(Rect2(-68.0, -102.0, 136.0, 8.0), Color("#41788f"))
	# wide door + portholes
	_pixel_rect(Rect2(-16.0, -62.0, 32.0, 48.0), Color("#243442"))
	_pixel_rect(Rect2(-13.0, -59.0, 26.0, 42.0), Color("#3d5a70"))
	_pixel_rect(Rect2(-40.0, -66.0, 20.0, 20.0), Color("#9fc0cc"))
	_pixel_rect(Rect2(20.0, -66.0, 20.0, 20.0), Color("#9fc0cc"))
	# displayed rowboat on a stand
	_pixel_rect(Rect2(-40.0, -12.0, 80.0, 5.0), Color("#6b543a"))
	_pixel_rect(Rect2(-34.0, -7.0, 68.0, 7.0), Color("#8a5a3b"))
	_pixel_rect(Rect2(-40.0, -7.0, 10.0, 7.0), GameTheme.WOOD_DARK)
	_pixel_rect(Rect2(30.0, -7.0, 10.0, 7.0), GameTheme.WOOD_DARK)
	_pixel_rect(Rect2(-2.0, -24.0, 4.0, 12.0), GameTheme.WOOD_DARK)
	_pixel_rect(Rect2(-2.0, -26.0, 14.0, 4.0), UILib.CREAM)
	# sign
	_pixel_rect(Rect2(-44.0, -134.0, 88.0, 20.0), UILib.PANEL_LIGHT)
	PixFont.draw_text_centered(self, 0.0, -130.0, "BOATS", GameTheme.GOLD, 2, 1)
	draw_prompt()