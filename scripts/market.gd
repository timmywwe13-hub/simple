class_name FishMarket
extends Interactable

## Fish Market: sells the bucket's catch. Prices get the market premium
## on top of the owned-boat value bonus (GameState.sell_one / sell_all).

const PREMIUM := 1.15

var list: ItemList
var panel_scroll: ScrollContainer
var scroll_pos := 0


func art_height() -> float:
	return 124.0


func prompt_label() -> String:
	return "FISH MARKET"


func interact() -> void:
	if town == null:
		return
	var s := TownUI.screen(town.ui_layer, "FISH MARKET")
	var body: VBoxContainer = s["body"]
	panel_scroll = s["scroll"] as ScrollContainer
	if panel_scroll != null:
		panel_scroll.scroll_vertical = scroll_pos
		panel_scroll.set_deferred("scroll_vertical", scroll_pos)
	s["coins"].text = "COINS %d" % GameState.coins
	var intro := UILib.label(body, "SELL YOUR CATCH - MARKET +15%, BOAT BONUS, DAILY DEMAND AND STREAK BONUSES INCLUDED", 14, GameTheme.SUBTEXT)
	intro.custom_minimum_size = Vector2(0.0, 24.0)
	if GameState.event_active():
		var event_l := UILib.label(body, "2X COIN EVENT: EVERY FISH SELLS FOR DOUBLE FOR %s" % GameState.event_time_text(),
				13, GameTheme.GOLD)
		event_l.custom_minimum_size = Vector2(0.0, 22.0)
	var daily_id := GameState.daily_fish_id()
	if daily_id != "":
		var daily_l := UILib.label(body, "DAILY CATCH: %s PAYS x2   |   HOT DEMAND PAYS +30%%" % String(FishDB.fish_data(daily_id).get("name", daily_id)).to_upper(),
				13, GameTheme.GOLD)
		daily_l.custom_minimum_size = Vector2(0.0, 22.0)
	list = ItemList.new()
	list.custom_minimum_size = Vector2(600.0, 175.0)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(list)
	UILib.style_item_list(list)
	_refresh_list()
	var btns := TownUI.row(body, 50.0)
	var sell_one_btn := UILib.button(btns, "SELL SELECTED", _on_sell_selected, 15, GameTheme.WOOD,
			Color("#a97c52"), Color("#6b4426"), UILib.CREAM, Vector2(180.0, 40.0))
	sell_one_btn.position = Vector2(12.0, 5.0)
	var sell_all_btn := UILib.button(btns, "SELL ALL", _on_sell_all, 15, GameTheme.WOOD,
			Color("#a97c52"), Color("#6b4426"), UILib.CREAM, Vector2(180.0, 40.0))
	sell_all_btn.position = Vector2(206.0, 5.0)
	var total_l := UILib.label(btns, "BUCKET VALUE %d" % _bucket_value(), 16, UILib.GOLD, true, HORIZONTAL_ALIGNMENT_RIGHT)
	total_l.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	total_l.offset_left = -320.0
	total_l.offset_right = -12.0
	total_l.offset_top = -18.0
	total_l.offset_bottom = 18.0
	town.open_panel(s["root"])


func _mult() -> float:
	return PREMIUM * GameState.boat_value_mult()


func _bucket_value() -> int:
	var total := 0
	for item in GameState.inventory:
		var fid := String(item.get("fish_id", ""))
		var w := float(item.get("weight", 0.0))
		var perfect := bool(item.get("perfect", false))
		total += GameState.sale_value(fid, w, _mult(), perfect)
	return total


func _refresh_list() -> void:
	list.clear()
	if GameState.inventory.is_empty():
		list.add_item("BUCKET EMPTY - GO CATCH SOME FISH")
		list.set_item_disabled(0, true)
		return
	for i in range(GameState.inventory.size()):
		var item: Dictionary = GameState.inventory[i]
		var fid := String(item.get("fish_id", ""))
		var w := float(item.get("weight", 0.0))
		var f := FishDB.fish_data(fid)
		var perfect := bool(item.get("perfect", false))
		var value := GameState.sale_value(fid, w, _mult(), perfect)
		var tags: Array[String] = []
		if perfect:
			tags.append("PERFECT")
		if GameState.is_daily_catch(fid):
			tags.append("DAILY x2")
		if GameState.is_hot_demand(fid):
			tags.append("HOT +30%")
		var tag_txt := "" if tags.is_empty() else "  [%s]" % " ".join(tags)
		var idx := list.add_item("%s  %.2f KG  -  %d COINS%s" % [String(f.get("name", fid)), w, value, tag_txt])
		list.set_item_custom_fg_color(idx, GameTheme.get_rarity_color(String(f.get("rarity", "Common"))))


func _on_sell_selected() -> void:
	var sel := list.get_selected_items()
	if GameState.inventory.is_empty() or sel.is_empty():
		GameState.play_sound("buzz")
		town.toast("SELECT A FISH TO SELL")
		return
	var value := GameState.sell_one(int(sel[0]), _mult())
	GameState.play_sound("coin")
	town.toast("SOLD FOR %d COINS" % value)
	_reopen()


func _on_sell_all() -> void:
	if GameState.inventory.is_empty():
		GameState.play_sound("buzz")
		town.toast("BUCKET EMPTY")
		return
	var value := GameState.sell_all(_mult())
	GameState.play_sound("coin")
	town.toast("SOLD ALL FOR %d COINS" % value)
	_reopen()


func _reopen() -> void:
	if is_instance_valid(panel_scroll):
		scroll_pos = panel_scroll.scroll_vertical
	town.close_panel()
	interact()


func _draw() -> void:
	var wood := GameTheme.WOOD
	var wood_dark := GameTheme.WOOD_DARK
	# counter
	_pixel_rect(Rect2(-58.0, -34.0, 116.0, 34.0), wood)
	_pixel_rect(Rect2(-58.0, -34.0, 116.0, 5.0), wood_dark)
	_pixel_rect(Rect2(-58.0, -8.0, 116.0, 8.0), wood_dark)
	_pixel_rect(Rect2(-52.0, -14.0, 10.0, 14.0), wood_dark)
	_pixel_rect(Rect2(42.0, -14.0, 10.0, 14.0), wood_dark)
	# posts + awning
	_pixel_rect(Rect2(-64.0, -78.0, 6.0, 44.0), wood_dark)
	_pixel_rect(Rect2(58.0, -78.0, 6.0, 44.0), wood_dark)
	for i in range(7):
		var c := Color("#4f7f9c") if i % 2 == 0 else UILib.CREAM
		_pixel_rect(Rect2(-68.0 + float(i) * 19.4, -92.0, 19.4, 12.0), c)
	_pixel_rect(Rect2(-68.0, -96.0, 136.0, 5.0), wood_dark)
	# fish on the counter (procedural, tiny)
	FishArt.draw_fish(self, Rect2(-46.0, -28.0, 26.0, 12.0), FishDB.fish_data("minnow"), false, 1.0)
	FishArt.draw_fish(self, Rect2(-12.0, -26.0, 28.0, 14.0), FishDB.fish_data("sunfish"), false, -1.0)
	FishArt.draw_fish(self, Rect2(22.0, -28.0, 30.0, 13.0), FishDB.fish_data("trout"), false, 1.0)
	# hanging scale
	_pixel_rect(Rect2(0.0, -78.0, 3.0, 12.0), Color("#3a3f4a"))
	_pixel_rect(Rect2(-8.0, -66.0, 16.0, 10.0), Color("#c9a13b"))
	# crates
	_pixel_rect(Rect2(-90.0, -20.0, 22.0, 20.0), wood)
	_pixel_rect(Rect2(-90.0, -20.0, 22.0, 4.0), wood_dark)
	_pixel_rect(Rect2(68.0, -20.0, 22.0, 20.0), wood)
	_pixel_rect(Rect2(68.0, -20.0, 22.0, 4.0), wood_dark)
	# sign
	_pixel_rect(Rect2(-40.0, -118.0, 80.0, 20.0), UILib.PANEL_LIGHT)
	PixFont.draw_text_centered(self, 0.0, -114.0, "MARKET", GameTheme.GOLD, 2, 1)
	draw_prompt()