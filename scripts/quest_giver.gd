class_name QuestGiver
extends Interactable

## Quest Giver: the town NPC with a quest board. Lists every quest with
## live progress and pays out coin rewards (GameState.claim_quest).

func art_height() -> float:
	return 118.0

var panel_scroll: ScrollContainer
var scroll_pos := 0


func prompt_label() -> String:
	var n := GameState.quest_unclaimed_count()
	return "QUEST BOARD" if n == 0 else "QUESTS %d" % n


func interact() -> void:
	if town == null:
		return
	var s := TownUI.screen(town.ui_layer, "QUEST BOARD")
	var body: VBoxContainer = s["body"]
	panel_scroll = s["scroll"] as ScrollContainer
	if panel_scroll != null:
		panel_scroll.scroll_vertical = scroll_pos
		panel_scroll.set_deferred("scroll_vertical", scroll_pos)
	s["coins"].text = "COINS %d" % GameState.coins
	var intro := UILib.label(body, "FINISH QUESTS - RETURN HERE TO CLAIM REWARDS", 14, GameTheme.SUBTEXT)
	intro.custom_minimum_size = Vector2(0.0, 24.0)
	if GameState.harvest_season_open():
		var hl := UILib.label(body, "HARVEST FEAST QUESTS PAY FEAST TOKENS - %s" % GameState.harvest_deadline_text(),
				13, GameTheme.GOLD)
		hl.custom_minimum_size = Vector2(0.0, 22.0)
	if GameState.event_active():
		var event_l := UILib.label(body, "2X COIN EVENT: REWARDS ARE DOUBLED FOR %s" % GameState.event_time_text(),
				13, GameTheme.GOLD)
		event_l.custom_minimum_size = Vector2(0.0, 22.0)
	for q in GameState.visible_quests():
		var done := bool(q.get("done", false))
		var claimed := bool(q.get("claimed", false))
		var row := TownUI.row(body, 58.0)
		var title_l := UILib.label(row, String(q.get("title", "Quest")).to_upper(), 16,
				GameTheme.FAINT if claimed else UILib.CREAM, true)
		title_l.position = Vector2(12.0, 3.0)
		var desc_l := UILib.label(row, String(q.get("desc", "")), 12, GameTheme.SUBTEXT)
		desc_l.position = Vector2(12.0, 23.0)
		var need := GameState.quest_need(q)
		var prog_text := "DONE" if done else "PROGRESS %d / %d" % [int(q.get("progress", 0)), need]
		var prog_l := UILib.label(row, prog_text, 12, GameTheme.LEAF if done else GameTheme.WHEAT)
		prog_l.position = Vector2(12.0, 41.0)
		var reward_txt := "REWARD %d" % GameState.quest_reward(q)
		if bool(q.get("token_reward", false)):
			reward_txt = "REWARD %d TOKENS" % GameState.quest_reward(q)
		var reward_l := UILib.label(row, reward_txt, 13, UILib.GOLD, true)
		reward_l.position = Vector2(300.0, 8.0)
		var state_l := UILib.label(row, "CLAIMED" if claimed else ("READY!" if done else "ACTIVE"), 12,
				GameTheme.FAINT if claimed else GameTheme.SUBTEXT)
		state_l.position = Vector2(300.0, 28.0)
		if done and not claimed:
			TownUI.row_button(row, "CLAIM", _on_claim.bind(String(q.get("id", ""))), 100.0)
	town.open_panel(s["root"])


func _on_claim(qid: String) -> void:
	var token_quest := false
	for q in GameState.quests:
		if String(q.get("id", "")) == qid and bool(q.get("token_reward", false)):
			token_quest = true
	var reward := GameState.claim_quest(qid)
	if reward > 0:
		GameState.play_sound("bell" if token_quest else "coin")
		town.toast("CLAIMED %d %s" % [reward, "TOKENS" if token_quest else "COINS"])
		_reopen()
	else:
		GameState.play_sound("buzz")


func _reopen() -> void:
	if is_instance_valid(panel_scroll):
		scroll_pos = panel_scroll.scroll_vertical
	town.close_panel()
	interact()


func _draw() -> void:
	# quest board
	_pixel_rect(Rect2(26.0, -78.0, 5.0, 78.0), GameTheme.WOOD_DARK)
	_pixel_rect(Rect2(76.0, -78.0, 5.0, 78.0), GameTheme.WOOD_DARK)
	_pixel_rect(Rect2(20.0, -88.0, 67.0, 14.0), GameTheme.WOOD)
	_pixel_rect(Rect2(20.0, -88.0, 67.0, 3.0), GameTheme.WOOD_DARK)
	for i in range(3):
		_pixel_rect(Rect2(26.0 + float(i) * 21.0, -84.0, 16.0, 8.0), UILib.PAPER)
		_pixel_rect(Rect2(28.0 + float(i) * 21.0, -82.0, 8.0, 2.0), Color("#8a7a5a"))
		_pixel_rect(Rect2(28.0 + float(i) * 21.0, -79.0, 10.0, 2.0), Color("#8a7a5a"))
	# NPC: robed quest master with a staff
	var bob := sin(Time.get_ticks_msec() / 1000.0 * 2.0) * 1.5
	var o := Vector2(-16.0, bob)
	_pixel_rect(Rect2(o.x - 11.0, o.y - 40.0, 22.0, 40.0), Color("#3f5f7a"))
	_pixel_rect(Rect2(o.x - 13.0, o.y - 40.0, 26.0, 5.0), Color("#324b60"))
	_pixel_rect(Rect2(o.x - 9.0, o.y - 56.0, 18.0, 16.0), GameTheme.SKIN)
	_pixel_rect(Rect2(o.x - 10.0, o.y - 60.0, 20.0, 6.0), Color("#c8ccd2"))
	_pixel_rect(Rect2(o.x - 8.0, o.y - 50.0, 16.0, 8.0), Color("#c8ccd2"))
	_pixel_rect(Rect2(o.x - 6.0, o.y - 54.0, 3.0, 3.0), GameTheme.INK)
	_pixel_rect(Rect2(o.x + 3.0, o.y - 54.0, 3.0, 3.0), GameTheme.INK)
	_pixel_rect(Rect2(o.x + 12.0, o.y - 54.0, 4.0, 54.0), GameTheme.WOOD_DARK)
	_pixel_rect(Rect2(o.x + 10.0, o.y - 60.0, 8.0, 8.0), GameTheme.GOLD)
	draw_prompt()