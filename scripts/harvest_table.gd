class_name HarvestTable
extends Interactable

## The sixth Town walk-up and the FEAST / ALBUM board (v1.9).
##
## `interact()` opens the board from Town; `open_board()` is also used by the
## main menu so the album stays reachable after the season closes. The board
## is a Control overlay built in code, with pack flips and the Harvest Queen
## reveal; reduce_motion skips the animation and shows every card at once.



func art_height() -> float:
	return 96.0


func prompt_label() -> String:
	return "SOMETHING SMELLS GOOD"


func interact() -> void:
	if town == null:
		return
	var b := open_board(town.ui_layer, func() -> void:
		if is_instance_valid(town):
			town.close_panel()
	)
	town.open_panel(b)


static func open_board(layer: Node, on_close := Callable()) -> Control:
	var b := Board.new()
	b.on_close = on_close
	b.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(b)
	return b


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
	var stage := GameState.harvest_table_stage()
	var wood := GameTheme.WOOD
	var dark := GameTheme.WOOD_DARK
	var bob := sin(Time.get_ticks_msec() / 1000.0 * 1.7) * 1.0
	var top_y := -34.0 + bob
	# trestle legs and plank top
	_pixel_rect(Rect2(-58.0, top_y + 12.0, 7.0, 40.0), dark)
	_pixel_rect(Rect2(51.0, top_y + 12.0, 7.0, 40.0), dark)
	_pixel_rect(Rect2(-52.0, top_y + 26.0, 104.0, 4.0), dark)
	_pixel_rect(Rect2(-62.0, top_y, 124.0, 12.0), wood)
	_pixel_rect(Rect2(-62.0, top_y, 124.0, 3.0), wood.lightened(0.16))
	if stage >= 1:
		_pixel_rect(Rect2(-64.0, top_y - 1.0, 128.0, 5.0), GameTheme.WHEAT)
	if stage >= 2:
		for i in range(3):
			_draw_pixel_circle(Vector2(-32.0 + float(i) * 32.0, top_y - 4.0), 6.0, GameTheme.PAPER, 2.0)
	if stage >= 3:
		_draw_pixel_circle(Vector2(0.0, top_y - 10.0), 9.0, GameTheme.GOLD, 3.0)
		_pixel_rect(Rect2(-2.0, top_y - 22.0, 4.0, 10.0), GameTheme.CREAM)
		_pixel_rect(Rect2(-5.0, top_y - 26.0, 10.0, 4.0), GameTheme.EMBER)
	if stage >= 4:
		_draw_pixel_circle(Vector2(-44.0, top_y - 10.0), 7.0, GameTheme.PUMPKIN, 2.0)
		_draw_pixel_circle(Vector2(44.0, top_y - 10.0), 7.0, GameTheme.PUMPKIN, 2.0)
		_pixel_rect(Rect2(-42.0, top_y - 30.0, 2.0, 20.0), GameTheme.GOLD)
		_pixel_rect(Rect2(40.0, top_y - 30.0, 2.0, 20.0), GameTheme.GOLD)
	# bunting over the table
	for i in range(5):
		var fx := -56.0 + float(i) * 28.0
		var fc: Color = [GameTheme.PUMPKIN, GameTheme.GOLD, GameTheme.CRANBERRY, GameTheme.LEAF][i % 4]
		_pixel_rect(Rect2(fx, top_y - 46.0 + absf(float(i) - 2.0) * 2.0, 12.0, 8.0), fc)
	# signpost
	_pixel_rect(Rect2(-2.0, top_y - 84.0, 4.0, 40.0), dark)
	_pixel_rect(Rect2(-50.0, top_y - 90.0, 100.0, 18.0), GameTheme.PANEL_LIGHT)
	_pixel_rect(Rect2(-50.0, top_y - 90.0, 100.0, 3.0), GameTheme.WHEAT)
	PixFont.draw_text_centered(self, 0.0, top_y - 87.0, "HARVEST", GameTheme.WHEAT, 2, 1)
	draw_prompt()


## ---------------------------------------------------------------------------
## The board overlay
## ---------------------------------------------------------------------------
class Board extends Control:
	const CARD_W := 900.0
	const CARD_H := 560.0

	var on_close: Callable
	var tab := "feast"
	var card: Control
	var content: Control
	var selected_card := ""
	var hovered_card := ""
	var status_text := ""
	var reveal: Dictionary = {}
	var reveal_t := 0.0
	var reveal_overlay: Control
	var award_overlay: Control
	var award_t := 0.0
	var album_art: Control
	var album_name: Label
	var album_rarity: Label
	var album_desc: Label
	var album_group: Label
	var donate_list: ItemList

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		selected_card = String(HarvestCards.ALL_IDS[0])
		_build()

	func _process(dt: float) -> void:
		if not reveal.is_empty():
			if GameState.reduce_motion():
				reveal_t = 1.0
			else:
				reveal_t = minf(1.0, reveal_t + dt * 1.35)
			if reveal_overlay != null:
				reveal_overlay.queue_redraw()
		if award_overlay != null:
			award_t = 1.0 if GameState.reduce_motion() else minf(1.0, award_t + dt * 2.2)
			award_overlay.queue_redraw()
		if Input.is_action_just_pressed("ui_cancel"):
			if award_overlay != null:
				_close_award()
			elif reveal_overlay != null:
				_close_reveal()
			else:
				_close()
	func _close() -> void:
		if on_close.is_valid():
			on_close.call()
		if is_instance_valid(self):
			queue_free()

	func _clear(node: Node) -> void:
		for c in node.get_children():
			node.remove_child(c)
			c.queue_free()

	func _build() -> void:
		_clear(self)
		var dim := ColorRect.new()
		var dc := UILib.DIM
		dc.a = 0.80
		dim.color = dc
		dim.set_anchors_preset(Control.PRESET_FULL_RECT)
		dim.mouse_filter = Control.MOUSE_FILTER_STOP
		add_child(dim)
		card = Control.new()
		card.size = Vector2(CARD_W, CARD_H)
		add_child(card)
		var vp := get_viewport_rect().size
		var sc := clampf(minf((vp.x - 20.0) / CARD_W, (vp.y - 20.0) / CARD_H), 0.42, 1.0)
		card.scale = Vector2(sc, sc)
		card.position = (vp - Vector2(CARD_W, CARD_H) * sc) * 0.5
		var bg := Panel.new()
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		bg.add_theme_stylebox_override("panel", UILib.sfx_bg())
		card.add_child(bg)
		var wheat := ColorRect.new()
		wheat.color = UILib.WHEAT
		wheat.position = Vector2(14.0, 3.0)
		wheat.size = Vector2(CARD_W - 28.0, 1.0)
		card.add_child(wheat)
		TownUI.leaf_sprigs(card, Vector2(CARD_W, CARD_H))
		TownUI.ribbon(card, "THE HARVEST FEAST", Vector2(18.0, 10.0), 400.0, 42.0)
		var tok := UILib.label(card, "TOKENS %d" % GameState.harvest_tokens(), 20,
				UILib.GOLD, true, HORIZONTAL_ALIGNMENT_RIGHT)
		tok.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		tok.offset_left = -330.0
		tok.offset_right = -24.0
		tok.offset_top = 18.0
		tok.offset_bottom = 48.0
		var tabs := HBoxContainer.new()
		tabs.position = Vector2(20.0, 60.0)
		tabs.add_theme_constant_override("separation", 8)
		card.add_child(tabs)
		_add_tab(tabs, "FEAST", "feast")
		_add_tab(tabs, "ALBUM", "album")
		if bool(GameState.harvest.get("boat_claimed", false)):
			_add_tab(tabs, "TROPHY", "trophy")
		var close := UILib.button(card, "CLOSE", _close, 15, UILib.PANEL_LIGHT,
				UILib.BUTTON_HOVER, UILib.BUTTON_PRESS, UILib.CREAM, Vector2(110.0, 36.0))
		close.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		close.offset_left = -130.0
		close.offset_right = -20.0
		close.offset_top = -50.0
		close.offset_bottom = -14.0
		content = Control.new()
		content.position = Vector2(20.0, 104.0)
		content.size = Vector2(CARD_W - 40.0, CARD_H - 104.0 - 60.0)
		card.add_child(content)
		match tab:
			"feast":
				_build_feast()
			"album":
				_build_album()
			"trophy":
				_build_trophy()
			"donate":
				_build_donate()

	func _add_tab(parent: Control, text: String, id: String) -> void:
		var active := tab == id
		var b := UILib.button(parent, text, _set_tab.bind(id), 14,
				UILib.GOLD if active else UILib.PANEL_LIGHT,
				UILib.BUTTON_HOVER, UILib.BUTTON_PRESS,
				UILib.INK if active else UILib.CREAM, Vector2(128.0, 34.0))
		b.custom_minimum_size = Vector2(128.0, 34.0)

	func _set_tab(id: String) -> void:
		tab = id
		status_text = ""
		GameState.play_sound("ui")
		_build()

	func _lab(parent: Control, text: String, size: int, color: Color,
			pos: Vector2, width := -1.0) -> Label:
		var l := UILib.label(parent, text, size, color, true, HORIZONTAL_ALIGNMENT_LEFT)
		l.position = pos
		if width > 0.0:
			l.size = Vector2(width, float(size) + 8.0)
		return l

	func _bar(parent: Control, pos: Vector2, size: Vector2, filled: int, total: int,
			markers: bool) -> void:
		var bar := Control.new()
		bar.position = pos
		bar.size = size
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(bar)
		bar.draw.connect(func() -> void:
			var trough := Rect2(2.0, size.y * 0.25, size.x - 4.0, size.y * 0.5)
			bar.draw_rect(trough, UILib.HUSK)
			var f := clampf(float(filled) / float(maxi(1, total)), 0.0, 1.0)
			bar.draw_rect(Rect2(trough.position, Vector2(trough.size.x * f, trough.size.y)), UILib.GOLD)
			if markers:
				for i in range(5, total + 1, 5):
					var x := trough.position.x + trough.size.x * float(i) / float(total)
					bar.draw_rect(Rect2(x - 2.0, trough.position.y - 3.0, 4.0, trough.size.y + 6.0),
							UILib.PUMPKIN)
			# leaf tick at the end of the trough
			bar.draw_colored_polygon(PackedVector2Array([
				Vector2(trough.end.x + 1.0, trough.position.y + 1.0),
				Vector2(trough.end.x + 8.0, trough.position.y + trough.size.y * 0.5),
				Vector2(trough.end.x + 1.0, trough.end.y - 1.0)]), UILib.LEAF)
		)

	func _build_feast() -> void:
		var closed := not GameState.harvest_season_open()
		var deadline_c := UILib.EMBER if GameState.harvest_final_days() else UILib.GOLD
		if closed:
			deadline_c = UILib.FAINT
		_lab(content, GameState.harvest_deadline_text(), 16, deadline_c, Vector2(0.0, 0.0), 520.0)
		var stage := GameState.harvest_table_stage()
		_lab(content, "THE LONG TABLE - STAGE %d / 4" % stage, 22, UILib.CREAM,
				Vector2(0.0, 28.0))
		_lab(content, "DONATED %d FISH" % int(GameState.harvest.get("donated", 0)), 14,
				UILib.SUBTEXT, Vector2(520.0, 32.0), 300.0)
		var next := GameState.harvest_next_stage_donation()
		var stage_txt := "FULL FEAST" if next < 0 else "NEXT STAGE AT %d DONATIONS" % next
		_lab(content, stage_txt, 13, UILib.WHEAT, Vector2(520.0, 50.0), 320.0)
		_bar(content, Vector2(0.0, 66.0), Vector2(820.0, 18.0),
				int(GameState.harvest.get("donated", 0)),
				int(GameState.HARVEST_TABLE_STAGES[GameState.HARVEST_TABLE_STAGES.size() - 1]),
				false)
		_lab(content, "One free pack every event day, or 20 tokens each. Packs open immediately - no pack sits unopened at the Dec 1 close.",
				13, UILib.SUBTEXT, Vector2(0.0, 94.0), 820.0)
		var free_ok := GameState.harvest_free_pack_available() and not closed
		var free_b := UILib.button(content, "FREE PACK" if free_ok else "FREE PACK USED",
				_on_free_pack, 16, UILib.LEAF, UILib.LEAF.lightened(0.12), UILib.LEAF.darkened(0.25),
				UILib.CREAM, Vector2(190.0, 46.0))
		free_b.position = Vector2(0.0, 132.0)
		free_b.disabled = not free_ok
		var buy_label := "OPEN PACK - %d TOKENS" % GameState.HARVEST_PACK_COST
		if closed:
			buy_label = "PACKS CLOSED UNTIL NOV 22"
		var buy_b := UILib.button(content, buy_label,
				_on_buy_pack, 16, UILib.PUMPKIN, UILib.PUMPKIN.lightened(0.12), UILib.EMBER,
				UILib.CREAM, Vector2(300.0, 46.0))
		buy_b.position = Vector2(202.0, 132.0)
		buy_b.disabled = closed or GameState.harvest_tokens() < GameState.HARVEST_PACK_COST
		var donate_b := UILib.button(content, "DONATE A FISH", _on_donate_tab, 16,
				UILib.PANEL_LIGHT, UILib.BUTTON_HOVER, UILib.BUTTON_PRESS,
				UILib.CREAM, Vector2(200.0, 46.0))
		donate_b.position = Vector2(514.0, 132.0)
		donate_b.disabled = closed or GameState.inventory.is_empty()
		_lab(content, "ODDS PER CARD - COMMON 55%  UNCOMMON 28%  RARE 13%  EPIC 3.5%  LEGENDARY 0.5%",
				13, UILib.WHEAT, Vector2(0.0, 192.0), 820.0)
		_lab(content, "ALBUM %d / 20   -   SPARES %d   -   PACKS OPENED %d" % [
				GameState.harvest_owned_count(), GameState.harvest_spares_count(),
				int(GameState.harvest.get("packs_opened", 0))],
				15, UILib.CREAM, Vector2(0.0, 218.0), 820.0)
		if bool(GameState.harvest.get("completed", false)):
			_lab(content, "ALBUM COMPLETE - THE HARVEST QUEEN IS IN YOUR FLEET. THE TROPHY TAB HAS HER PLAQUE.",
					14, UILib.GOLD, Vector2(0.0, 246.0), 820.0)
		elif GameState.harvest_cards_left() == 1:
			_lab(content, "ONE CARD LEFT - A PACK IS GUARANTEED TO FINISH THE SET.",
					14, UILib.GOLD, Vector2(0.0, 246.0), 820.0)
		if closed:
			_lab(content, "THE FEAST IS CLOSED FOR THIS YEAR. THE ALBUM AND TROPHY STAY READ-ONLY UNTIL NEXT NOVEMBER.",
					14, UILib.EMBER, Vector2(0.0, 276.0), 820.0)
		if status_text != "":
			_lab(content, status_text, 14, UILib.GOLD, Vector2(0.0, 306.0), 820.0)

	func _on_free_pack() -> void:
		var res := GameState.harvest_claim_free_pack()
		_open_reveal(res)

	func _on_buy_pack() -> void:
		var res := GameState.harvest_buy_pack()
		_open_reveal(res)

	func _on_donate_tab() -> void:
		tab = "donate"
		_build()

	func _build_donate() -> void:
		var closed := not GameState.harvest_season_open()
		_lab(content, "DONATE A FISH TO THE LONG TABLE", 22, UILib.CREAM, Vector2(0.0, 0.0))
		_lab(content, "Every donation pays tokens and grows the table. Stage 4 hands out a bonus pack.",
				13, UILib.SUBTEXT, Vector2(0.0, 30.0), 820.0)
		donate_list = ItemList.new()
		donate_list.position = Vector2(0.0, 58.0)
		donate_list.size = Vector2(500.0, 210.0)
		donate_list.add_theme_font_size_override("font_size", 14)
		content.add_child(donate_list)
		UILib.style_item_list(donate_list)
		if GameState.inventory.is_empty():
			donate_list.add_item("BUCKET EMPTY - CATCH SOMETHING FIRST")
			donate_list.set_item_disabled(0, true)
		else:
			for i in range(GameState.inventory.size()):
				var item: Dictionary = GameState.inventory[i]
				var fid := String(item.get("fish_id", ""))
				var value := GameState.coin_value(fid, float(item.get("weight", 0.0)))
				var tok := clampi(int(round(float(value) * 0.12)), 2, 18)
				donate_list.add_item("%s  %.2f KG  -  %d TOKENS" % [
						String(FishDB.fish_data(fid).get("name", fid)),
						float(item.get("weight", 0.0)), tok])
				donate_list.set_item_custom_fg_color(i,
						GameTheme.get_rarity_color(String(FishDB.fish_data(fid).get("rarity", "Common"))))
		var donate := UILib.button(content, "DONATE SELECTED", _on_donate_selected, 16,
				UILib.PUMPKIN, UILib.PUMPKIN.lightened(0.12), UILib.EMBER,
				UILib.CREAM, Vector2(200.0, 46.0))
		donate.position = Vector2(520.0, 58.0)
		donate.disabled = closed or GameState.inventory.is_empty()
		var back := UILib.button(content, "BACK TO FEAST", _set_tab.bind("feast"), 16,
				UILib.PANEL_LIGHT, UILib.BUTTON_HOVER, UILib.BUTTON_PRESS,
				UILib.CREAM, Vector2(200.0, 46.0))
		back.position = Vector2(520.0, 114.0)
		if status_text != "":
			_lab(content, status_text, 14, UILib.GOLD, Vector2(520.0, 178.0), 300.0)

	func _on_donate_selected() -> void:
		if donate_list == null:
			return
		var sel := donate_list.get_selected_items()
		if sel.is_empty():
			status_text = "SELECT A FISH FIRST."
			_build_donate()
			return
		var res := GameState.donate_fish(int(sel[0]))
		if not bool(res.get("ok", false)):
			status_text = "CAN'T DONATE THAT RIGHT NOW."
			GameState.play_sound("buzz")
			_build_donate()
			return
		status_text = "DONATED FOR %d TOKENS - TABLE STAGE %d" % [int(res.get("tokens", 0)),
				int(res.get("stage", 0))]
		GameState.play_sound("bell")
		if bool(res.get("bonus_pack", false)):
			var pack := GameState.harvest_open_pack(0)
			tab = "feast"
			_build()
			_open_reveal(pack)
			return
		_build_donate()

	func _build_album() -> void:
		var closed := not GameState.harvest_season_open()
		_lab(content, "ALBUM %d / 20" % GameState.harvest_owned_count(), 22, UILib.CREAM,
				Vector2(0.0, 0.0))
		var spares := UILib.pill(content, "SPARES %d" % GameState.harvest_spares_count(),
				UILib.PUMPKIN, 13, UILib.CREAM)
		spares.position = Vector2(170.0, 4.0)
		spares.size = Vector2(110.0, 24.0)
		var pill_c := UILib.PUMPKIN
		if closed:
			pill_c = UILib.FAINT
		elif GameState.harvest_final_days():
			pill_c = UILib.EMBER
		var deadline_pill := UILib.pill(content, GameState.harvest_deadline_text(), pill_c, 13,
				UILib.CREAM)
		deadline_pill.position = Vector2(300.0, 4.0)
		deadline_pill.size = Vector2(230.0, 24.0)
		_bar(content, Vector2(0.0, 30.0), Vector2(820.0, 16.0),
				GameState.harvest_owned_count(), 20, true)
		# 5x4 grid
		var grid := GridContainer.new()
		grid.columns = 5
		grid.position = Vector2(0.0, 58.0)
		grid.add_theme_constant_override("h_separation", 6)
		grid.add_theme_constant_override("v_separation", 6)
		content.add_child(grid)
		for i in range(HarvestCards.ALL_IDS.size()):
			var cid := String(HarvestCards.ALL_IDS[i])
			var slot := Control.new()
			slot.custom_minimum_size = Vector2(64.0, 90.0)
			slot.size = Vector2(64.0, 90.0)
			slot.mouse_filter = Control.MOUSE_FILTER_STOP
			slot.tooltip_text = String(HarvestCards.card(cid).get("name", cid))
			grid.add_child(slot)
			slot.draw.connect(func() -> void:
				var owned := GameState.harvest_has_card(cid)
				HarvestCards.draw_card(slot, Rect2(Vector2.ZERO, slot.size),
						HarvestCards.card(cid), owned, false, hovered_card == cid,
						"" if GameState.harvest_season_open() else "RETURNS NOV 22")
			)
			slot.mouse_entered.connect(func() -> void:
				hovered_card = cid
				selected_card = cid
				_update_album_detail()
				slot.queue_redraw()
			)
			slot.mouse_exited.connect(func() -> void:
				if hovered_card == cid:
					hovered_card = ""
				slot.queue_redraw()
			)
			slot.gui_input.connect(func(ev: InputEvent) -> void:
				var mb := ev as InputEventMouseButton
				if mb != null and mb.pressed:
					selected_card = cid
					_update_album_detail()
					GameState.play_sound("ui")
			)
		# detail pane
		var detail := Control.new()
		detail.position = Vector2(370.0, 58.0)
		detail.size = Vector2(450.0, 290.0)
		content.add_child(detail)
		album_art = Control.new()
		album_art.position = Vector2(0.0, 0.0)
		album_art.size = Vector2(150.0, 210.0)
		album_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		detail.add_child(album_art)
		album_art.draw.connect(func() -> void:
			HarvestCards.draw_card(album_art, Rect2(Vector2.ZERO, album_art.size),
					HarvestCards.card(selected_card), GameState.harvest_has_card(selected_card),
					false, false, "" if GameState.harvest_season_open() else "RETURNS NOV 22")
		)
		album_name = _lab(detail, "", 20, UILib.CREAM, Vector2(164.0, 0.0), 286.0)
		album_rarity = _lab(detail, "", 13, UILib.GOLD, Vector2(164.0, 30.0), 286.0)
		album_group = _lab(detail, "", 12, UILib.SUBTEXT, Vector2(164.0, 52.0), 286.0)
		album_desc = _lab(detail, "", 13, UILib.SUBTEXT, Vector2(164.0, 76.0), 286.0)
		album_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		album_desc.size = Vector2(286.0, 120.0)
		album_desc.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		if bool(GameState.harvest.get("boat_claimed", false)):
			_lab(detail, "TROPHY - THE HARVEST QUEEN", 13, UILib.GOLD,
					Vector2(164.0, 210.0), 286.0)
		_update_album_detail()

	func _update_album_detail() -> void:
		if album_name == null:
			return
		var owned := GameState.harvest_has_card(selected_card)
		var d := HarvestCards.card(selected_card)
		var rarity := String(d.get("rarity", "Common"))
		if owned:
			album_name.text = String(d.get("name", selected_card)).to_upper()
			album_rarity.text = rarity.to_upper()
			album_rarity.add_theme_color_override("font_color", GameTheme.get_rarity_color(rarity))
			album_group.text = HarvestCards.group_label(selected_card)
			if String(d.get("group", "")) == "fish":
				album_desc.text = String(FishDB.fish_data(selected_card).get("desc",
						"A Harvest Feast collectible."))
			else:
				album_desc.text = "A Harvest Feast collectible card."
		else:
			album_name.text = "???"
			album_rarity.text = rarity.to_upper()
			album_rarity.add_theme_color_override("font_color", UILib.FAINT)
			album_group.text = HarvestCards.group_label(selected_card)
			if not GameState.harvest_season_open():
				album_desc.text = "Not collected yet. Packs are closed until Nov 22."
			else:
				album_desc.text = "Not collected yet. Open a pack for a guaranteed new card."
		if album_art != null:
			album_art.queue_redraw()

	func _build_trophy() -> void:
		var art := Control.new()
		art.position = Vector2(220.0, 0.0)
		art.size = Vector2(380.0, 260.0)
		content.add_child(art)
		art.draw.connect(func() -> void:
			HarvestCards.draw_trophy(art, Rect2(Vector2.ZERO, art.size))
		)
		_lab(content, "THE HARVEST QUEEN", 24, UILib.GOLD, Vector2(0.0, 276.0), 820.0)
		_lab(content, "Awarded automatically at 20 / 20 cards. Exactly the Sea Trawler's stats: speed 215, value +20%. Saved as a normal owned boat, so she is sailable from any dock.",
				14, UILib.SUBTEXT, Vector2(0.0, 306.0), 820.0)

	func _open_reveal(res: Dictionary) -> void:
		if String(res.get("error", "")) == "closed":
			status_text = "PACKS ARE CLOSED UNTIL NOV 22."
			tab = "feast"
			_build()
			return
		if String(res.get("error", "")) == "tokens":
			status_text = "NOT ENOUGH TOKENS - YOU NEED 20."
			GameState.play_sound("buzz")
			_build()
			return
		if String(res.get("error", "")) == "daily_used":
			status_text = "THE FREE PACK IS ALREADY CLAIMED TODAY."
			_build()
			return
		reveal = res
		reveal_t = 1.0 if GameState.reduce_motion() else 0.0
		status_text = ""
		_build_reveal()

	func _build_reveal() -> void:
		if reveal_overlay != null:
			reveal_overlay.queue_free()
		reveal_overlay = Control.new()
		reveal_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
		reveal_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
		card.add_child(reveal_overlay)
		reveal_overlay.gui_input.connect(func(ev: InputEvent) -> void:
			var mb := ev as InputEventMouseButton
			if mb != null and mb.pressed:
				_close_reveal()
		)
		reveal_overlay.draw.connect(func() -> void:
			_draw_reveal()
		)
		GameState.play_sound("leaf")

	func _draw_reveal() -> void:
		var o := reveal_overlay
		if o == null:
			return
		o.draw_rect(Rect2(Vector2.ZERO, Vector2(CARD_W, CARD_H)), Color(UILib.DIM, 0.88))
		var title := "THE PACK OPENS"
		PixFont.draw_text_centered(o, CARD_W * 0.5, 46.0, title, UILib.GOLD, 4, 1)
		var cards: Array = reveal.get("cards", [])
		var cw := 170.0
		var ch := 238.0
		var gap := 26.0
		var total := float(cards.size()) * cw + float(maxi(0, cards.size() - 1)) * gap
		var x0 := (CARD_W - total) * 0.5
		var new_ids: Array = reveal.get("new_ids", [])
		for i in range(cards.size()):
			var data: Dictionary = cards[i]
			var t := clampf(reveal_t * 1.55 - float(i) * 0.18, 0.0, 1.0)
			var flip := 1.0
			if not GameState.reduce_motion():
				flip = maxf(0.03, absf(cos((1.0 - t) * PI * 0.5)))
			var pos := Vector2(x0 + float(i) * (cw + gap) + (1.0 - flip) * cw * 0.5, 128.0)
			var r := Rect2(pos, Vector2(maxf(4.0, cw * flip), ch))
			if flip > 0.40:
				var rc := GameTheme.get_rarity_color(String(data.get("rarity", "Common")))
				rc.a = 0.20 * flip
				o.draw_circle(r.get_center(), cw * 0.62, rc)
			if flip > 0.08:
				var is_new := new_ids.has(String(data.get("id", "")))
				HarvestCards.draw_card(o, r, data, true, is_new, false, "")
			else:
				o.draw_rect(r, UILib.PAPER)
		if reveal_t >= 1.0:
			var line := "CLICK TO CONTINUE"
			if int(reveal.get("refund", 0)) > 0:
				line = "+%d TOKENS FROM SPARES   -   CLICK TO CONTINUE" % int(reveal.get("refund", 0))
			PixFont.draw_text_centered(o, CARD_W * 0.5, CARD_H - 54.0, line, UILib.CREAM, 2, 1)
		if bool(reveal.get("completed", false)):
			PixFont.draw_text_centered(o, CARD_W * 0.5, CARD_H - 84.0,
					"ALBUM COMPLETE!", UILib.GOLD, 3, 1)

	func _close_reveal() -> void:
		var awarded := bool(reveal.get("awarded", false))
		reveal = {}
		reveal_t = 0.0
		_build()
		if awarded:
			_show_award()

	func _show_award() -> void:
		award_t = 1.0 if GameState.reduce_motion() else 0.0
		award_overlay = Control.new()
		award_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
		award_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
		card.add_child(award_overlay)
		var go := UILib.button(award_overlay, "SET SAIL", _close_award, 18,
				UILib.LEAF, UILib.LEAF.lightened(0.12), UILib.LEAF.darkened(0.25),
				UILib.CREAM, Vector2(220.0, 48.0))
		go.set_anchors_preset(Control.PRESET_CENTER)
		go.offset_left = -110.0
		go.offset_top = 200.0
		go.offset_right = 110.0
		go.offset_bottom = 248.0
		award_overlay.draw.connect(func() -> void:
			award_overlay.draw_rect(Rect2(Vector2.ZERO, Vector2(CARD_W, CARD_H)),
					Color(UILib.DIM, 0.90))
			var slide := (1.0 - award_t) * 60.0
			var r := Rect2((CARD_W - 420.0) * 0.5, 60.0 + slide, 420.0, 280.0)
			HarvestCards.draw_trophy(award_overlay, r)
			PixFont.draw_text_centered(award_overlay, CARD_W * 0.5, 24.0 + slide,
					"20 / 20 - THE ALBUM IS COMPLETE", UILib.GOLD, 3, 1)
			PixFont.draw_text_centered(award_overlay, CARD_W * 0.5, 362.0,
					"THE HARVEST QUEEN JOINS YOUR FLEET", UILib.CREAM, 2, 1)
			PixFont.draw_text_centered(award_overlay, CARD_W * 0.5, 388.0,
					"SPEED 215   VALUE +20%   SAILABLE FROM ANY DOCK", UILib.WHEAT, 2, 1)
		)
		GameState.play_sound("fanfare")

	func _close_award() -> void:
		if award_overlay != null:
			award_overlay.queue_free()
			award_overlay = null
		_build()
