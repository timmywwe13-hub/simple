class_name Changelog
extends RefCounted

## The in-game "What's New" screen. The patch notes live here in one place
## so the main menu, the pause menu and the Town can all show the same
## list. Bump VERSION and add a new entry on every release; the menu shows
## a "!" badge until the player opens the screen once (GameState.seen_version).

const VERSION := "1.6"

const ENTRIES := [
	{
		"version": "1.6",
		"title": "SMOOTH WALKING + 2X COINS",
		"items": [
			"2X COIN EVENT - every coin you earn (fish sales and quest rewards) is doubled for 12 hours from your first launch of this update. The HUD, Fish Market and catch popup all show the boosted prices.",
			"NEW WALK CYCLE - both the fisher and the town walker ease into a walk instead of snapping, alternate their feet with a proper foot lift, swing their arms, bob with each step and kick up little dust puffs.",
			"DIRECTION - the town walker now turns to face the way you are walking, and eases to a stop instead of freezing mid-stride.",
			"SHADOWS - the walker has a soft pixel shadow, and the fishing fisher finally gets one too.",
			"WHAT'S NEW SCREEN - this page. Open it from the main menu, the pause menu, or press U while walking around Town.",
			"BUG FIXES - the town walker can no longer walk off the screen or get teleported when the window resizes; opening the Fish Index no longer risks starting a cast; selling an empty bucket says so instead of paying 0; the General Store region passes and stat rows are formatted correctly.",
		],
	},
	{
		"version": "1.5",
		"title": "STORMY NIGHTS",
		"items": [
			"6 new fish (48 species): day-only, night-only and rain/storm-only species.",
			"Lanterns light the dark and improve night bites, plus Carbon Rod, Fluorocarbon Line and Deck Cooler tiers.",
			"Perfect catches, catch streaks, daily catch x2 and hot market demand.",
			"Weather forecast, stats screen, Fish Index filters and a proper ESC pause menu.",
		],
	},
]


## True until the player opens this version's notes.
static func is_unseen() -> bool:
	return String(GameState.seen_version) != VERSION


## Remember that the notes were read. Saved with the rest of the progress.
static func mark_seen() -> void:
	if not is_unseen():
		return
	GameState.seen_version = VERSION
	if GameState.AUTO_SAVE:
		GameState.save_game()


## Build the scrolling patch-note body inside any VBoxContainer.
static func fill(body: VBoxContainer) -> void:
	var event_text := "2X COIN EVENT - 12 HOURS OF DOUBLE COINS"
	var event_color := GameTheme.GOLD
	if GameState.event_active():
		event_text = "2X COIN EVENT IS LIVE - %s LEFT" % GameState.event_time_text()
	else:
		event_text = "THE 2X COIN EVENT HAS ENDED - THANKS FOR PLAYING"
		event_color = Color("#8d9aa6")
	var banner := UILib.label(body, event_text, 17, event_color, true)
	banner.custom_minimum_size = Vector2(0.0, 30.0)

	for entry in ENTRIES:
		var head := UILib.label(body, "V%s - %s" % [String(entry["version"]),
				String(entry["title"])], 19, GameTheme.CREAM, true)
		head.custom_minimum_size = Vector2(0.0, 30.0)
		for item in entry["items"]:
			var line := UILib.label(body, "  " + String(item), 14, Color("#c2d2dc"))
			line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			line.custom_minimum_size = Vector2(0.0, 22.0)
		var gap := Control.new()
		gap.custom_minimum_size = Vector2(0.0, 8.0)
		body.add_child(gap)
