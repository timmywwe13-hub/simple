class_name Changelog
extends RefCounted

## The in-game "What's New" screen. The patch notes live here in one place
## so the main menu, the pause menu and the Town can all show the same
## list. Bump VERSION and add a new entry on every release; the menu shows
## a "!" badge until the player opens the screen once (GameState.seen_version).

const VERSION := "1.7"

const ENTRIES := [
	{
		"version": "1.7",
		"title": "PLACES, SETTINGS AND TOUCH",
		"items": [
			"EVERY PLACE LOOKS LIKE ITSELF - the Pond has a cottagecore pink sky, lily pads, reeds, willows, ducks and dragonflies; the River runs cold blue-grey with current streaks, a gravel bar, birches, a plank bridge and white water; the Lake is a wide blue afternoon with slow glassy ripples, a dock and rowboat, a forested island with a smoking cabin, mist and loons; the Deep Sea is golden hour with big swells, a stone quay, a lighthouse, gulls and a distant sailboat. Open Water and Coconut Isle are in the same table so nothing looks out of place.",
			"SMOOTH PLACE CHANGES - switching spots crossfades the whole palette over about 0.8s with a short water wipe, and a banner announces the place and its flavour line (THE RIVER - FAST CURRENT, SHARP ROCKS, COLD BLUE LIGHT).",
			"SETTINGS - music and SFX sliders on real audio buses, fullscreen (also F11) restored on boot, reduce motion (turns off shakes, flashes and lightning strobes), touch UI Auto/On/Off, quality Auto/Low/Medium/High, and a two-step reset progress. Reachable from the start menu and the pause menu and saved with your game.",
			"SAVE SAFETY - saves are written to a temp file, checksummed, swapped in atomically and the previous save is kept as a .bak. Autosave is debounced (at most once a second), flushed on travel/quit/focus loss, and a small SAVED toast confirms it. Old saves gain the new settings automatically.",
			"ROD TIMING - higher-tier rods reel faster, but their green target is smaller and relocates every time the marker bounces, so autoclicking one spot can no longer land fish.",
			"TOUCH OVERHAUL - an analog thumb-stick with a dead zone and variable strength, safe-area-aware controls that keep clear of notches, large finger-sized targets, only the buttons the current moment needs, touch-specific HUD hints, an aim reticle at the cast target, and a rotate-device overlay in portrait.",
			"FISH INDEX 2.0 - select, hover, click, tap or key through the list for a detail pane with coloured FishArt (or a silhouette), rarity pill, description, where and when it bites, personal best, catch count and per-region completion.",
			"FISH ART POLISH - every species gets a tapered, shaded body, a flared forked tail, dorsal/pelvic/pectoral fins with rays, a lighter belly and dorsal sheen, a lateral line, gills, a round eye with a glint, a mouth and cleaner scales, spots, stripes and checker patterns. Long bills, whiskers and streamers now fit inside their panel, and the fish no longer has its tail hidden behind its own body.",
			"VOLT SERPENT REDESIGN - a dedicated serpent renderer draws a long S-curved, tapered body with a real head, yellow slit eye, fangs and a forked tongue, a spined dorsal crest, a forked electric tail, and lightning bolts that cross the body instead of smearing over it.",
			"JUICE + AUDIO - splash bursts and ripple rings at the bobber, coins flying to the HUD on a sale, a catch card that scales in, scene fades on travel, region ambient particles (fireflies, dragonflies, gulls, mist, spray) and a procedural audio director that crossfades a different music loop and ambience for each place and time of day.",
			"DISTRIBUTION - Windows Desktop and Android export presets, and the Web build is now an installable PWA that opens as its own app on a phone.",
		],
	},
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
