class_name GeneralStore
extends Interactable

## General Store: sells gear (rods / lines / bait / buckets) and travel
## passes for the locked fishing regions. Same purchase paths as the
## Tackle Shop in the fishing scene.

func art_height() -> float:
	return 140.0

var panel_scroll: ScrollContainer
var scroll_pos := 0


func prompt_label() -> String:
	return "GENERAL STORE"


func interact() -> void:
	if town == null:
		return
	var s := TownUI.screen(town.ui_layer, "GENERAL STORE")
	var body: VBoxContainer = s["body"]
	panel_scroll = s["scroll"] as ScrollContainer
	if panel_scroll != null:
		panel_scroll.scroll_vertical = scroll_pos
		panel_scroll.set_deferred("scroll_vertical", scroll_pos)
	s["coins"].text = "COINS %d" % GameState.coins
	_gear(body, "Rods", "rods", _on_buy)
	_gear(body, "Lines", "lines", _on_buy)
	_gear(body, "Bait", "baits", _on_buy_bait)
	_gear(body, "Lanterns", "lanterns", _on_buy)
	_gear(body, "Buckets", "buckets", _on_buy)
	TownUI.header(body, "ISLAND CRAFTING")
	_craft_rows(body)
	TownUI.header(body, "TRAVEL PASSES")
	_region_passes(body)
	town.open_panel(s["root"])


func _gear(body: VBoxContainer, title: String, category: String, buy: Callable) -> void:
	TownUI.header(body, title.to_upper())
	var db: Dictionary = ShopDB.category(category)
	for id in db.keys():
		var d: Dictionary = db[id]
		var is_bait := category == "baits"
		var owned := bool(d.get("owned", false)) and not is_bait
		var equipped := String(GameState.gear.get(GameState.gear_key(category), "")) == String(id)
		var row := TownUI.row(body)
		var name_l := UILib.label(row, String(d.get("name", id)), 16, UILib.CREAM, true)
		name_l.position = Vector2(12.0, 4.0)
		var desc_l := UILib.label(row, String(d.get("desc", "")), 12, Color("#a8c0cc"))
		desc_l.position = Vector2(12.0, 24.0)
		var stat_l := UILib.label(row, _stat_line(category, d), 12, GameTheme.LEAF)
		stat_l.position = Vector2(300.0, 8.0)
		# Bait is a consumable: a bag with charges left can be equipped for
		# free, so the player can switch between the baits they own.
		var charges := GameState.bait_count(String(id)) if is_bait else 0
		var text := "BUY %d" % int(d.get("cost", 0))
		if is_bait:
			if equipped and charges > 0:
				text = "BUY %d" % int(d.get("cost", 0))
			elif charges > 0:
				text = "USE x%d" % charges
		else:
			text = "EQUIPPED" if equipped else ("EQUIP" if owned else "BUY %d" % int(d.get("cost", 0)))
		TownUI.row_button(row, text, buy.bind(category, String(id)))


## Coconut Isle gear: the axe and the rods built from coconuts. Same
## crafting path as the Tackle Shop panel in the fishing scene.
func _craft_rows(body: VBoxContainer) -> void:
	var note_row := TownUI.row(body, 24.0)
	var note := UILib.label(note_row, "COCONUTS: %d - CHOP PALMS ON COCONUT ISLE" % GameState.coconuts,
			13, Color("#a8c0cc"))
	note.position = Vector2(12.0, 2.0)
	var axe_text := "OWNED"
	var axe_desc := "Palm axe: 3 coconuts per tree."
	var axe_stat := "AXE LEVEL %d" % GameState.axe_level
	if not GameState.has_axe:
		axe_text = "BUY %d" % ShopDB.AXE_COST
		axe_desc = "Chop palms on Coconut Isle for coconuts."
		axe_stat = "NO AXE"
	elif GameState.axe_level < 2:
		axe_text = "UPGRADE %d" % ShopDB.PALM_AXE_COST
	_craft_row(body, "Axe", axe_desc, axe_stat, axe_text, _on_buy_axe)
	for id in ShopDB.CRAFTED_RODS.keys():
		var d: Dictionary = ShopDB.CRAFTED_RODS[id]
		var rod_id := String(id)
		var owned := ShopDB.owned("rods", rod_id)
		var equipped := String(GameState.gear.get("rod", "")) == rod_id
		var text := "EQUIPPED" if equipped else ("EQUIP" if owned else "CRAFT %d" % int(d.get("cost", 4)))
		_craft_row(body, String(d.get("name", id)),
				"%s - %d COCONUTS" % [String(d.get("desc", "")), int(d.get("cost", 4))],
				"SPEED %.2fx  WIN %.3f" % [float(d.get("reel_speed", 1.0)),
						float(d.get("timing_window", 0.2))],
				text, _on_craft.bind(rod_id))


func _craft_row(body: VBoxContainer, item_name: String, desc: String, stat: String,
		btn_text: String, cb: Callable) -> void:
	var row := TownUI.row(body)
	var name_l := UILib.label(row, item_name, 16, UILib.CREAM, true)
	name_l.position = Vector2(12.0, 4.0)
	var desc_l := UILib.label(row, desc, 12, Color("#a8c0cc"))
	desc_l.position = Vector2(12.0, 24.0)
	var stat_l := UILib.label(row, stat, 12, GameTheme.LEAF)
	stat_l.position = Vector2(360.0, 8.0)
	TownUI.row_button(row, btn_text, cb, 140.0)


func _on_buy_axe() -> void:
	if GameState.buy_axe():
		GameState.play_sound("coin")
		town.toast("AXE READY - PRESS G ON COCONUT ISLE")
		_reopen()
	else:
		GameState.play_sound("buzz")
		town.toast("NOT ENOUGH COINS FOR THE AXE!")


func _on_craft(id: String) -> void:
	var err := GameState.craft_rod(id)
	if err == "":
		GameState.play_sound("coin")
		town.toast("%s BUILT AND EQUIPPED" % String(ShopDB.item("rods", id).get("name", "ROD")).to_upper())
		_reopen()
		return
	GameState.play_sound("buzz")
	if err == "need_coconuts":
		town.toast("NEED %d COCONUTS - CHOP PALMS ON COCONUT ISLE" %
				int(ShopDB.crafted_recipe(id).get("coconuts", 0)))
	else:
		town.toast("CAN'T CRAFT THAT RIGHT NOW")


func _region_passes(body: VBoxContainer) -> void:	for r in ["river", "lake", "ocean"]:
		if GameState.unlocked_regions.has(r):
			continue
		var display := String(FishDB.REGION_DISPLAY.get(r, r))
		var cost := int(FishDB.REGION_UNLOCK_COST.get(r, 0))
		var row := TownUI.row(body)
		var name_l := UILib.label(row, "%s PASS" % display.to_upper(), 16, UILib.CREAM, true)
		name_l.position = Vector2(12.0, 4.0)
		var note := "UNLOCK THE %s FISHING SPOT" % display.to_upper()
		if r == "ocean":
			note = "REQUIRES A REAL BOAT - SEE THE BOAT DEALER"
		var desc_l := UILib.label(row, note, 12, Color("#a8c0cc"))
		desc_l.position = Vector2(12.0, 24.0)
		TownUI.row_button(row, "BUY %d" % cost, _on_unlock.bind(r))


func _stat_line(category: String, d: Dictionary) -> String:	match category:
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
		"lanterns": return "NIGHT BITE x%.2f  NIGHT RARE +%.0f%%" % [
				float(d.get("night_bite", 1.0)), (float(d.get("night_rare", 1.0)) - 1.0) * 100.0]
		_: return ""


func _on_buy(category: String, id: String) -> void:
	if GameState.buy_item(category, id):
		GameState.play_sound("coin")
		_reopen()
	else:
		_fail()


func _on_buy_bait(category: String, id: String) -> void:
	# A bait already in the bag equips for free; otherwise this buys more.
	var equipped := String(GameState.gear.get("bait", "")) == id
	if not equipped and GameState.bait_count(id) > 0:
		GameState.activate_bait(id)
		GameState.play_sound("ui")
		town.toast("%s EQUIPPED - %d CASTS LEFT" % [
				String(ShopDB.item("baits", id).get("name", "BAIT")).to_upper(),
				GameState.bait_count(id)])
		_reopen()
		return
	# buy_item adds the charges to the bag and equips the bait
	if GameState.buy_item(category, id):
		GameState.play_sound("coin")
		_reopen()
	else:
		_fail()


func _on_unlock(region: String) -> void:
	if GameState.unlock_region(region):
		GameState.play_sound("coin")
		_reopen()
	else:
		GameState.play_sound("buzz")
		if region == "ocean" and not GameState.has_seaworthy_boat():
			town.toast("THE DEEP SEA NEEDS A REAL BOAT")
		else:
			town.toast("NOT ENOUGH COINS!")


func _fail() -> void:
	GameState.play_sound("buzz")
	town.toast("NOT ENOUGH COINS!")


## Rebuild the panel so owned / equipped / pass states refresh.
func _reopen() -> void:
	if is_instance_valid(panel_scroll):
		scroll_pos = panel_scroll.scroll_vertical
	town.close_panel()
	interact()


func _draw() -> void:
	var wall := GameTheme.WOOD
	var wall_dark := GameTheme.WOOD_DARK
	var roof := Color("#a8493c")
	var roof_dark := Color("#7c332c")
	# body + corner posts
	_pixel_rect(Rect2(-62.0, -100.0, 124.0, 100.0), wall)
	_pixel_rect(Rect2(-62.0, -100.0, 6.0, 100.0), wall_dark)
	_pixel_rect(Rect2(56.0, -100.0, 6.0, 100.0), wall_dark)
	_pixel_rect(Rect2(-62.0, -14.0, 124.0, 14.0), wall_dark)
	_pixel_rect(Rect2(-62.0, -100.0, 124.0, 4.0), wall_dark)
	# roof
	_pixel_rect(Rect2(-70.0, -116.0, 140.0, 8.0), roof_dark)
	_pixel_rect(Rect2(-66.0, -108.0, 132.0, 8.0), roof)
	# striped awning
	for i in range(6):
		var c := UILib.CREAM if i % 2 == 0 else Color("#c85c4e")
		_pixel_rect(Rect2(-64.0 + float(i) * 21.2, -96.0, 21.2, 10.0), c)
	_pixel_rect(Rect2(-64.0, -88.0, 128.0, 3.0), wall_dark)
	# door + window
	_pixel_rect(Rect2(-40.0, -70.0, 30.0, 56.0), Color("#3a2a24"))
	_pixel_rect(Rect2(-37.0, -67.0, 24.0, 50.0), Color("#54382c"))
	_pixel_rect(Rect2(18.0, -70.0, 40.0, 30.0), Color("#2c3d4d"))
	_pixel_rect(Rect2(21.0, -67.0, 34.0, 24.0), Color("#9fc0cc"))
	_pixel_rect(Rect2(37.0, -70.0, 3.0, 30.0), Color("#2c3d4d"))
	_pixel_rect(Rect2(18.0, -57.0, 40.0, 3.0), Color("#2c3d4d"))
	# sign
	_pixel_rect(Rect2(-34.0, -136.0, 68.0, 20.0), UILib.PANEL_LIGHT)
	PixFont.draw_text_centered(self, 0.0, -132.0, "STORE", GameTheme.GOLD, 2, 1)
	# crates
	_pixel_rect(Rect2(-88.0, -22.0, 22.0, 22.0), wall)
	_pixel_rect(Rect2(-88.0, -22.0, 22.0, 4.0), wall_dark)
	_pixel_rect(Rect2(-86.0, -36.0, 18.0, 14.0), wall)
	_pixel_rect(Rect2(-86.0, -36.0, 18.0, 3.0), wall_dark)
	draw_prompt()
