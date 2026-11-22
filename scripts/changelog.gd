class_name Changelog
extends RefCounted

## The in-game "What's New" screen. The patch notes live here in one place
## so the main menu, the pause menu and the Town can all show the same
## list. Bump VERSION and add a new entry on every release; the menu shows
## a "!" badge until the player opens the screen once (GameState.seen_version).

const VERSION := "1.9.1"

const ENTRIES := [
	{
		"version": "1.9.1",
		"title": "THE QUEEN'S WAKE",
		"items": [
			"THE HARVEST QUEEN, UPGRADED - the event hull is now the best boat in the creek: speed 260, fish value +45%, and open-water rare, epic and legendary fish bite 35% more often. She also wears a striped festival canopy, twin lanterns, a pumpkin prow and a trail of golden leaves.",
			"MORE OPEN WATER - the open sea is now a three-zone voyage. Sail east at the edge for the KELP SHELF, then again for the MIDNIGHT TRENCH; sail west to work back to shore. Each zone has its own palette, landmarks and fishing pool.",
			"SEVEN NEW OPEN-WATER FISH - Kelp Bass, Garibaldi, Sheephead and Sunset Wrasse in the kelp; Gulper Eel, Vampire Squid and the legendary Abyssal Angler in the trench. The base Open Water pool still bites in every zone.",
			"ADMIN UNLOCK - typing 2222 now completes the Fish Index (including seasonal fish), the 20-card album, awards and equips The Harvest Queen and opens the trophy tab, so every catch and the event boat can be tested immediately.",
			"TOWN + HUD POLISH - only the nearest walk-up draws a prompt, the Quest Giver has more room beside the harvest stall, the harvest token HUD row no longer crowds the bucket, and the boat/bait readout has clear space while sailing.",
		],
	},
	{
		"version": "1.9",
		"title": "THE HARVEST FEAST",
		"items": [
			"THE HARVEST FEAST - a seasonal event runs Nov 22 00:00 to Dec 1 23:59 local time. The pond, river, lake, Deep Sea and Open Water all turn autumn: gold-and-rust skies, orange-red canopies, straw banks, deep umber water, drifting leaves, pumpkins, corn bundles, straw bales, a lit quay lantern and a heavier cabin smoke. Dusk arrives about two in-game hours earlier.",
			"THE LONG TABLE - a sixth Town walk-up. Donate fish to grow the trestle table through four stages; every donation pays Feast tokens, and finishing the table hands out a bonus card pack.",
			"20-CARD ALBUM - 5x4 cards across Fish, Feast, Places and Critters. Packs open immediately: one free pack per event day, or 20 tokens for a three-card pack. Each pack guarantees a new card until the set is complete, duplicates pay 5 tokens and stack as SPARES, and hard pity lands at six packs.",
			"THE HARVEST QUEEN - finish 20/20 and the gilded autumn hull is awarded automatically with a trophy reveal. She is the best hull in the creek (speed 260, value +45%, open-water rare bites +35%), can never be bought, and is saved as a normal owned boat.",
			"FIVE NEW FISH - Pumpkinseed Sunny (pond), Cranberry Darter (river), Maple Leaf Koi (lake), Wattle Grouper (Deep Sea) and The Grand Tom (night, anywhere). The Grand Tom card is also granted on the legendary catch. Three new quests pay tokens: A Full Plate, Potluck and The Grand Tom.",
			"THE AUTUMN UI PASS - one season token table re-skins every screen: chestnut panels with walnut borders and wheat highlights, notched ribbon titles, umber buttons with amber focus rings, leaf corner sprigs, dotted wheat separators, amber progress bars, parchment card faces with rarity ribbons and wax-stamp NEW! stamps. Rarity colours, fish art, water and text sizes are untouched.",
			"DEC 1 DEADLINE - the album header counts down (CARDS CLOSE TONIGHT on Dec 1), the ALBUM tab carries a countdown pill and the HUD chip warns in the final three days. After the close, the album and trophy stay readable forever, empty slots read RETURNS NOV 22, and the palette reverts on the next screen.",
			"NEW GEAR - the Harvest Lantern (40 tokens) speeds night bites and draws rarer night fish. Tokens are a separate currency and never convert to coins; harvest bonuses and the 2X coin event never stack.",
		],
	},
	{
		"version": "1.8.1",
		"title": "A FAIRER GREEN",
		"items": [
			"MINIGAME PICK - every hooked fish now rolls 50/50 between the timing bar and the tug-of-war, no matter the species or rarity, so both minigames stay in rotation.",
			"TIMING GREEN - the timing green now picks one spot when the fish is hooked and stays there for that fish; it no longer jumps every pass. It covers 40% of the bar, and every rod tier widens it by another 4% (40 / 44 / 48 / 52 / 56%), so a normal reaction can hit it.",
			"TUG-OF-WAR GREEN - the tug band starts at 44% wide, but it drifts slowly across the bar, so follow it with the tension marker instead of holding one spot. Better rods and lines widen it further.",
			"SHOP CLARITY - rod cards now show GREEN % instead of the old precision number, and the rod descriptions explain the +4% window per tier.",
		],
	},
	{
		"version": "1.8",
		"title": "ALL IN AT THE LUCKY LILY",
		"items": [
			"THE LUCKY LILY - a toy-coin riverboat has docked in Town. Walk up and press E to play Skipper's Coin (48% pays 2X), Pearl Shells (30% pays 3X) or Lucky Catch (a 12-stop reel with a 5X jackpot). Stakes run from 10 to 500 coins, every payout includes the returned stake, and the house edges are 4%, 10% and 8.3%.",
			"NO REAL MONEY - the Lucky Lily only uses the coins you earn from fishing and selling. There are no purchases, no chips to buy and no real-money gambling anywhere in the game.",
			"FAST, SAFE SETTLING - wagers settle the moment you press the button, so closing the panel during a reveal can never lose or duplicate a payout. Casino winnings never count as fish sales and never receive the 2X coin event.",
			"TWO NEW QUESTS - win any wager for Lucky Lily, and win 300 coins for High Roller. The riverboat ledger tracks your session net plus lifetime wagered, returned, net and biggest win.",
			"TOWN LAYOUT - five walk-ups now share the waterfront (General Store, Fish Market, Lucky Lily, Boat Dealer and Quest Giver), with the buildings easing smaller on narrow phone-sized windows so the awnings still fit.",
		],
	},
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
			"SPECIES VARIETY - the Thunderhead Grouper is now a purple storm fish with cloud banks, one huge yellow bolt, a big jaw and spikes. The Isle Electric Ray is sand-coloured with cyan electricity, broad swept wings and a whip tail. They no longer read as the same fish.",
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
		event_color = GameTheme.FAINT
	var banner := UILib.label(body, event_text, 17, event_color, true)
	banner.custom_minimum_size = Vector2(0.0, 30.0)

	for entry in ENTRIES:
		var head := UILib.label(body, "V%s - %s" % [String(entry["version"]),
				String(entry["title"])], 19, GameTheme.CREAM, true)
		head.custom_minimum_size = Vector2(0.0, 30.0)
		for item in entry["items"]:
			var line := UILib.label(body, "  " + String(item), 14, GameTheme.SUBTEXT)
			line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			line.custom_minimum_size = Vector2(0.0, 22.0)
		var gap := Control.new()
		gap.custom_minimum_size = Vector2(0.0, 8.0)
		body.add_child(gap)
