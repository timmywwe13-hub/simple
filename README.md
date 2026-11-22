# Cottage Creek Fishing

A simple, polished 2D fishing game with a collection-and-progression loop, built in **Godot 4.7** (GDScript, Canvas 2D rendering, no external assets).

**Play in your browser:** https://cottage-creek-fishing.surge.sh/ · https://cottage-creek.surge.sh/ · https://cottagecreek.surge.sh/ · https://creekfishing.surge.sh/
**GitHub Pages mirror:** https://timmywwe13-hub.github.io/simple/build/web/

## How to run

1. Open **Godot 4.x** and click **Import** → select this folder (`simple2/`) → choose `project.godot`.
2. Press **Play** (or `F5`). The game boots to the main menu.
3. Alternatively, run a quick headless check: `godot --headless --path . --quit-after 60`.

To rebuild the browser version after changing scripts:

```bash
godot --headless --path . --export-release Web build/web/index.html
```

## Controls

| Action | Key / Mouse |
|---|---|
| Start game (menu) | `SPACE`, `Enter`, or left-click "START FISHING" |
| Aim cast | Move mouse |
| Cast / hook / reel | `SPACE` or left-click |
| Walk along the bank | `A` / `D` (or arrows) |
| Take out / put away fishing rod | `R` |
| Board / land boat | `B` |
| Sail the boat (while aboard) | `A` / `D` (or left/right arrows) |
| Reach Open Water | sail past the east edge of the water in the boat |
| Return from Open Water | sail west past the edge |
| Visit Coconut Isle | sail east from the Deep Sea shore |
| Leave Coconut Isle | walk west off the end of the beach |
| Take out / put away the axe (island) | `G` |
| Chop a palm / craft (island) | `E` or click near a palm; `Escape` opens the shop |
| Switch fishing spot | `1`–`4` |
| Open the Fish Index | `I` (from the menu or right on the water) |
| Pause / back | `Escape` (pauses while fishing; closes menus) |
| Stats and sound | menu button `STATS & SOUND` |
| Settings | menu or pause button `SETTINGS`, or `F11` for fullscreen |
| What's New / patch notes | menu or pause button `WHAT'S NEW`, `U` in Town |
| Play the Lucky Lily (Town) | walk to the riverboat and press `E` |
| Harvest Feast board (Town) | walk to the long table and press `E`; also the menu's `HARVEST FEAST` / `FEAST & ALBUM` button |
| Cycle fishing spots (gamepad) | shoulder buttons |
| Everything else (gamepad) | left stick / D-pad, `A`/`X`, `B` to pause/back |
| Quit | close window |

**On touchscreens** (phones/tablets) the game switches to a thumb-stick and
context buttons: an analog stick with a dead zone for walking and sailing,
tap the water to aim, and a large action button that becomes CAST / HOOK /
REEL / HOLD / CHOP. Only the buttons you need right now stay on screen
(rod, boat, axe, spots `1`–`4`, index and menu), sized for thumbs and inset for notches and rounded corners. Multi-touch works: walk with the
left thumb while fishing with the right. Set **TOUCH UI** to `ON` to use the
controls on a desktop, or `OFF` to hide them on a tablet; `AUTO` follows the
device.

## Gameplay loop

1. **Cast** — aim with the mouse, press `SPACE`/click to cast the bobber.
2. **Wait for a bite** — a `!` indicator flashes over the bobber with a bite sound. Click quickly to hook.
3. **Reel** — each hooked fish rolls 50/50 between two minigames. Timing bar: the green is set once when the fish is hooked, covers 40% of the bar and gets 4% wider per rod tier (the gold centre is a perfect catch for +15%). Tug-of-war: hold `SPACE` to reel in and keep the tension marker inside the slowly drifting green band.
4. **Catch popup** — fish name, weight, rarity, coin value, plus a `NEW SPECIES!` badge on first catch and tags for perfect / daily / hot-demand bonuses.
5. **Sell / Index** — open the Fish Index (`I`, also mid-fishing: collection log with silhouettes until caught, plus region and uncaught filters) or the Tackle Shop (sell all fish for coins).
6. **Upgrade** — buy better rods (faster tug reeling and a 4% wider green window), lines (fewer escapes), bait (attracts rarer fish), lanterns (faster night bites), and bigger buckets (more inventory).
7. **Progress** — unlock the River, Lake, and Deep Sea regions by coins; each has its own fish table. Day/night, weather, daily catches and daily market demand change which fish are worth chasing.
8. **Coconut Isle** — sail east from the Deep Sea to a tropical beach. Buy the axe in the shop, chop the palms for coconuts (each palm regrows in 20 minutes, with a timer over the stump), then spend the coconuts in **Coconut Isle Crafting** to build rods 25% better than every shop rod. The isle's own fish only bite with bait.
9. **The Lucky Lily** — walk to the toy-coin riverboat in Town and press `E`. Pick a stake from 10 to 500 coins, then call **Skipper's Coin**, pick a **Pearl Shell**, or spin the **Lucky Catch** reel. Every payout includes the returned stake; the ledger tracks your session and lifetime results.
10. **The Harvest Feast (Nov 22 – Dec 1)** — the whole world turns autumn and a sixth Town walk-up appears: the long table. Catch the five seasonal fish, donate fish to grow the table through four stages, and spend Feast tokens on 3-card packs. A free pack lands every event day. Collect all 20 cards to be awarded **The Harvest Queen**, a gilded hull with the Sea Trawler's stats. Packs and earning close on Dec 1 at 23:59; the album, spares, trophy and boat stay forever, and a 19/20 near-miss finishes next November.

**Gambling is toy-coins only.** The Lucky Lily never takes real money, never sells chips and cannot be topped up with a purchase. Its fixed odds carry a house edge, and casino coins are kept separate from fish sales and the 2X coin event.

## Settings

Open **SETTINGS** from the start menu or the pause menu:

- **Music / SFX** volume sliders (separate audio buses). The mute button still works independently.
- **Fullscreen** toggle, also `F11`; the choice is restored on the next launch.
- **Reduce motion** — disables screen shake, hurt flashes and lightning strobes while keeping the sounds.
- **Touch UI** — `AUTO` (show on touch devices), `ON`, or `OFF`.
- **Quality** — `AUTO`, `LOW`, `MEDIUM` or `HIGH`; controls ambient fish, particles, mist and spray.
- **Reset progress** — two clicks to confirm; keeps your settings but clears coins, fish, gear and unlocks.

Settings are saved with your progress and old saves pick up the defaults.

## Save system

Progress (coins, inventory, fish index, gear, unlocked regions, quests,
settings, and the selected Lucky Lily stake) auto-saves to `user://save.json` and resumes on restart. Saves
are debounced (at most once a second) and written atomically: a temp file
with a checksum, then the old save is kept as `save.bak`. A corrupt or
truncated save falls back to the backup instead of wiping progress, and
travel/quit/focus-loss flush immediately. In the browser, `user://` lives
in IndexedDB.

## Project structure

```
res://main.tscn          # Main scene (Node2D)
res://scripts/main.gd    # Game loop: cast/bite/reel, rendering, UI screens
res://scripts/GameState.gd # Save/load, inventory, index, gear, quests, audio SFX
res://scripts/casino_db.gd # Lucky Lily fixed odds, payouts and reel stops
res://scripts/casino.gd    # Lucky Lily riverboat art and toy-coin panel
res://scripts/FishDB.gd  # All fish data + regional tables
res://scripts/ShopDB.gd  # Rods / lines / baits / buckets data
res://scripts/GameTheme.gd # Cottagecore color palette + rarity tiers
res://scripts/season_theme.gd # Seasonal palette token tables (autumn UI pass)
res://scripts/harvest_cards.gd # 20-card Harvest album data + code-drawn card art
res://scripts/harvest_table.gd # Town long table, FEAST/ALBUM board, pack reveals
res://scripts/region_art.gd # Per-place palettes, props, music/ambience keys
res://scripts/ui_lib.gd  # Tiny code-only UI toolkit
res://scripts/touch_controls.gd # On-screen touch controls for phones/tablets
res://scripts/fish_art.gd # Procedural pixel-ish fish drawing (shared)
```

## Updates (v1.9)

- **The Harvest Feast** - a seasonal event from **Nov 22 00:00 to Dec 1 23:59 local time**. The season gate is one explicit range check (it straddles the month change), `2222` forces it on for testing, and the whole palette applies at boot and reverts when the window closes
- **Autumn everywhere** - a single `SeasonTheme` token table re-skins the start menu, pause, settings, stats, What's New, Fish Index, both shops, Fish Market, Boat Dealer, Quest Board, Lucky Lily and the new feast board. Chestnut panels, walnut borders, wheat top highlights, notched ribbon titles, umber buttons with amber focus rings, leaf corner sprigs, dotted wheat separators, parchment card faces and wax-stamp `NEW!` stamps. Rarity colours, fish art, water, sky, text sizes and hit targets are untouched
- **World dressing** - per-region autumn palette overrides crossfade in on load, with drifting leaves, pumpkins, corn bundles, straw bales, a lit Deep Sea quay lantern, heavier cabin smoke and dusk about two in-game hours earlier
- **The long table** - a sixth Town walk-up with four growth stages. Donate fish for tokens; completing the table hands out a bonus pack
- **20-card album** - Fish, Feast, Places and Critters. Packs open immediately (never stranded at close), 3 cards each, no dupes inside a pack, guaranteed new card until complete, hard pity at six packs, duplicates pay 5 tokens as `SPARES`, and The Grand Tom card is also granted on the legendary catch
- **The Harvest Queen** - awarded automatically at 20/20, exactly the Sea Trawler's stats (speed 215, value +20%), award-only, saved as a normal owned boat, with a gilded autumn renderer
- **Five seasonal fish + three quests** - Pumpkinseed Sunny, Cranberry Darter, Maple Leaf Koi, Wattle Grouper and The Grand Tom (night, anywhere). A Full Plate, Potluck and The Grand Tom pay tokens. The Harvest Lantern is 40 tokens and draws rarer night fish
- **Deadline clarity** - album header, countdown pill, HUD chip warning in the final three days, `CARDS CLOSE TONIGHT` on Dec 1, then a permanent read-only album with `RETURNS NOV 22` slots and `PACKS CLOSED UNTIL NOV 22`
- **Web rebuild** - the v1.9 Web export replaces `build/web/`

## Updates (v1.8.1)

- **50/50 minigame pick** - every hooked fish now rolls between the timing bar and the tug-of-war, regardless of species or rarity
- **Fairer timing green** - the target now picks one spot per fish instead of jumping every pass, covers 40% of the bar, and each rod tier makes it 4% wider (40 / 44 / 48 / 52 / 56%)
- **Moving tug green** - the tug band starts at 44% width and drifts slowly across the bar, so follow it with the tension marker. Better rods and lines widen it
- **Rod shop stats** - rod cards now show `GREEN %` instead of the old precision number

## Updates (v1.8)

- **The Lucky Lily** - a toy-coin riverboat in Town with three games: Skipper's Coin (48% pays 2X), Pearl Shells (30% pays 3X) and the 12-stop Lucky Catch reel (5% jackpot at 5X). Stakes of 10, 25, 50, 100, 250 or 500 coins, a persistent selected stake, short reveals that can be skipped with Reduce Motion, and a ledger for session and lifetime wagered/returned/net/biggest win
- **Toy coins only** - no real money, no chip purchases and no top-ups. Casino payouts bypass the 2X coin event and never count as fish sales, so the only way in is coins earned by fishing
- **Two new quests** - win any wager for **Lucky Lily** and win 300 coins for **High Roller**
- **Town layout** - five walk-ups now share the waterfront and scale down slightly on narrow windows so the riverboat, market, store, boat dealer and quest board all fit

## Updates (v1.7)

- **Every place looks like itself** - each region has its own sky, water, banks, treeline and set pieces, and the palette crossfades over ~0.8s when you change spots. The Pond has lilies, reeds, willows, ducks and dragonflies; the River has current streaks, a gravel bar, birches, a plank bridge and white water; the Lake has a dock, rowboat, island cabin with chimney smoke, mist and loons; the Deep Sea has swells, a stone quay, lighthouse, gulls and a sailboat. Spot changes show an arrival banner with the place's name and tagline
- **Settings** - music/SFX sliders, fullscreen (`F11`), reduce motion, touch UI Auto/On/Off, quality and a confirmed reset progress, from the menu or pause menu. Saved with your game; old saves gain the defaults
- **Save safety** - atomic temp-file writes with a checksum, a `.bak` fallback when the main save is corrupt, debounced autosave (once a second max) and an on-screen `SAVED` toast. Travel, quit and focus-loss flush immediately, so a browser tab close no longer loses a catch
- **Rod timing** - higher rods reel faster but the green target is smaller and jumps to a new spot every pass, so holding a click on one spot no longer works. The shop now shows `PRECISION: 0-4` per rod
- **Touch overhaul** - analog thumb-stick, safe-area insets, large touch targets, context-only buttons, a portrait rotate overlay, touch HUD hints and an aim reticle. The small buttons no longer cover the water while you fish
- **Fish Index 2.0** - pick any species (hover, click, tap or arrow keys) for a detail pane with art, rarity, description, where/when it bites, personal best, catch count and per-region completion
- **Fish art polish** - tapered, shaded bodies with a lighter belly and dorsal sheen, flared forked tails, fin rays, gills, lateral lines, glinting eyes and cleaner pattern work. Bills, whiskers and streamers fit inside the card, and tails are no longer hidden behind the body
- **Distinct legendary/epic fish** - the Thunderhead Grouper is a purple storm fish with cloud banks and one huge bolt; the Isle Electric Ray is sand-coloured with cyan electricity, swept wings and a whip tail
- **Volt Serpent redesign** - the legendary sea serpent gets its own renderer: a long sinuous body, a jawed head with a slit eye, fangs and a forked tongue, a spined dorsal crest, an electric forked tail and lightning that crosses its body
- **Juice and audio** - splash rings at the bobber, coins that fly to the HUD on a sale, a catch card that scales in, scene fades on travel, region ambience (fireflies, gulls, spray, loons) and procedural music that crossfades per place and time of day
- **Distribution** - Windows and Android presets, and the web build is an installable PWA with icons, an offline page and a landscape orientation

## Updates (v1.6)

- **2x coin event (12 hours)** - every coin you earn is doubled: fish sold at the Tackle Shop and Fish Market, plus quest rewards. The window starts on your first launch of this update and is saved, so it keeps counting down between sessions. The HUD, start screen, Town, market, quest board and catch popup all show the doubled values and the time left
- **Smoother walking** - the fisher and the Town walker now ease into a walk and ease back to a stop, alternate their feet with a proper foot lift, swing their arms, bob on each step and kick up small dust puffs. Both characters finally have a soft ground shadow
- **Facing fixed** - the Town walker turns to face the direction of travel, and the fisher's head/eye follows the walk instead of always staring right
- **What's New screen** - a proper patch-notes panel with the current update, reachable from the main menu, the pause menu, or `U` in Town. The menu shows a `WHAT'S NEW!` badge until the notes have been read once (saved with your progress)
- **Walking bug fixes** - the Town walker can no longer wander off-screen, drift behind buildings, or get teleported back to the middle of town when the browser window resizes. Casting now plants the feet instead of freezing mid-stride
- **Other fixes** - opening the Fish Index no longer risks starting a cast with the same click; selling an empty bucket explains itself instead of paying 0 coins; the General Store's region-pass and stat rows are correctly indented; the Fisher Market and quest board show the event-boosted payouts

## Updates (v1.5)

- **6 new fish (48 species total)** - Sunrise Bream and Dawn Gar bite only by day, Moonfin Eel and Ghost Carp only at night, and Mist Herring / Thunderhead Grouper only in rain or storms. Fish pools now filter by hour as well as weather
- **Lantern gear** - No Lantern, Oil Lamp and Storm Lantern; better lanterns speed up night bites and make rare night fish more likely. Equipped lanterns cast a warm light around the fisher after dark
- **New gear tiers** - Carbon Rod (3.2x reel, 56% green), Fluorocarbon Line (94% keep) and Deck Cooler (72 fish)
- **Moon Bait and Storm Bait** - Moon Bait boosts night rarity odds; Storm Bait boosts fish in rain and thunderstorms
- **Perfect catches** - hit the gold centre of the timing bar for a 15% value bonus (the tug-of-war can earn one too)
- **Catch streaks** - land fish back to back for up to +20% sale value; an escape or monster shock resets the streak
- **Daily catch & hot demand** - one species pays double each real day, and two species are in demand for +30%. Both rotate by date and are shown in the HUD and Fish Market
- **Weather forecast** - the HUD shows the next front and how long until it arrives
- **Stats screen** - lifetime catches, coins earned, fish sold, perfect catches, streaks, biggest fish, species completion and today's daily/hot fish
- **Fish Index filters** - cycle region filters and hide already-caught species
- **Pause menu** - ESC now pauses instead of dropping an active cast; resume, toggle sound or return to the menu
- **Persistent sound setting** - mute is saved with the rest of the progress
- **4 new quests (25 total)** - night catches, bad-weather catches, perfect catches and a 6-catch streak
- **Fixes** - town shops keep their scroll position after buying or claiming, the General Store can switch owned bait for free, bucket capacity reads shop data, and catch/market values include all bonuses

## Updates (v1.4)

- **Volt Serpent & weather (42 species at the time)** - a roaming Legendary Volt Serpent can bite in any water; 95% of the time it goes in the bucket to keep and sell, but 5% of the time it shocks you for 20 coins and escapes. Rain and thunderstorms now roll in on a timer with slanted rain, splashes, lightning and thunder, faster bites, and weather-only fish (Rain Dace in the rain; Rainbow Trout, Thunder Pike and Storm Herring in the wet weather). The HUD shows the current weather
- **20 new fish (42 species at the time)** - Bluegill, Golden Koi, Dusky Carp, Puddle Puffer, Rainbow Darter, Emerald Eel, Northern Pike, Crimson Gar, Kelp Grouper, Tiger Muskie, Lake Sturgeon, Opaline Cichlid, Hammerhead Shark, Manta Ray, Deep Sea Angler, Viperfish, Goblin Shark, Giant Oarfish, Wahoo and Sailfish, plus the weather/roaming additions above, across all five waters. New body shapes (puffer, shark, ray, deep-sea, ribbon, serpent), new patterns (checker, speckle, scales, glow veins, lightning) and species features (whiskers, bills, sails, spikes, fangs, lanterns, wings, crests, streamers, hammerhead bar) make every fish read as itself - including whiskers on the catfish and arowana, a bill on the marlin and swordfish, and a lantern on the lanternfish
- **Bait is now a real consumable** - buy bait packs (Worm / Minnow / Glow) at the Tackle Shop or the General Store; each pack holds several casts and every cast uses one. Rare fish barely bite without it (their odds are cut hard when fishing bare) and matching bait boosts them instead, so rare fish means a trip to the shop. The HUD shows the equipped bait and casts left
- **15 new quests (21 total)** - bait shopping, baited casts, night catches, a 15 kg trophy, Rare/Epic/Legendary hunts, per-region catch quests (River, Lake, Deep Sea, Open Water), 10/25-species discovery, and sales milestones; claim them all at the Quest Board in Town. Fixed: quest progress for string targets (rarity/region) used to compare against the wrong number, so some quests completed instantly
- **Rare fish fight harder** - Rare / Epic / Legendary catches shrink the green timing zone and the safe tension band a little, and reel tension builds faster
- **Gear swaps are free** - owned rods, lines and buckets can be re-equipped from the shop without re-buying them; owned bait can also be switched for free, and only runs out charge by charge
- **Fishing feel fixes** - green-zone clicks now count if the marker was in the green a frame earlier (input latency no longer eats a good press), and clicking in the green during the big-fish tug acts as a short pump so taps land fish like holding does
- **Shop scroll fixed** - buying near the bottom of the Tackle Shop no longer snaps the list back to the top

## Bug fixes (v1.3)

- **Mobile support**: on phones/tablets the game shows on-screen touch controls - a movement pad, a big CAST/HOOK/REEL/HOLD button, and small buttons for rod, boat, fishing spots `1`–`4`, the Fish Index and the menu. Tap the water to aim and cast; multi-touch works (walk with the left thumb, fish with the right). The buttons feed the normal input actions so the rest of the game is unchanged
- **Fish Index in-game**: press `I` (or the INDEX button) while fishing to open the collection log; BACK returns to the water instead of the start menu
- **Hold minigame fixed**: the big-fish tug-of-war used to fail within half a second whether you held the button or not (tension moved ~1.0/s against a ±0.15 band with an instant fail at the ends). Tension now drifts slowly, the green band is wider (and better lines widen it - the line upgrade finally matters in the fight), the landing progress survives short missteps, and the fish only escapes after the line has been fully slack or fully strained for a moment straight
- **Boats float on the water**: the hull now rides the surface with water lapping at the waterline instead of drifting through the middle of the water (sailing is `A`/`D` along the surface)
- **Fish economy balanced**: catches used to pay twice (once at catch time, again at sale) and heavy fish paid absurd amounts (a marlin was worth ~30,000 coins). A fish now pays its listed value once - scaled 85–130% by where its weight falls inside the species' range - and species values were re-tiered; the Fish Market premium (+15%) and boat bonuses still apply when selling

## Bug fixes (v1.2)

- **All runtime errors fixed** (a full playthrough now runs clean):
  - Tackle Shop rebuilt its rows with double-parented widgets (a flood of `already has a parent` errors on every shop open/refresh)
  - Tunnel travel freed the scene inside `_process`/physics callbacks (`previously freed` errors and `Removing a CollisionObject node during a physics callback`); the scene swap is now deferred to idle time
- **Town round-trip fixed**: returning from the Town now resumes fishing directly instead of showing the start screen again
- **Boats are usable**: press `B` on the shore to board your equipped boat and sail with `WASD`; better boats move faster (their ShopDB `speed` stat) and raise Fish Market payouts; press `B` near the shore to land
- **Open Water section**: sail past the east edge of any fishing spot to load a new body of open sea with its own fish for the index (Mackerel, Flying Fish, Ocean Sunfish, Mahi Mahi, Bluefin Tuna, Swordfish, and a Legendary Coelacanth - 17 species total); sail west to return
- **Boats redrawn**: real hulls with rising bow/stern, plank lines, seats and a water shadow - log raft, wood rowboat, cream skiff, red trawler with wheelhouse - and the fisher stands *inside* behind the gunwale
- **Rods look different**: Twig Rod is a crooked dark stick, Willow Rod a smooth tan blank, Bamboo Rod golden with segment bands, Reed Rod a slim pale composite - each with its own reel color (held or stowed on your back)
- **Fishing rod toggle**: press `R` to take the rod out or put it away (it rides on your back while stowed)
- **Ambient fish**: smaller and deeper, and shadowed at night (no more giant striped blobs at the surface)
- **Menu**: `SPACE`/`Enter` starts the game even without hovering a button
- **Deep Sea gate**: pressing `4` without a seaworthy boat now explains that the Boat Dealer sells one
- **Exit leak fixed**: the audio SFX are baked into cached `AudioStreamWAV` clips instead of an `AudioStreamGenerator`, so no `ObjectDB` instance leaks at exit
- **HUD overlap fixed**: the coins panel no longer hides behind the bucket panel (moved to top-right), and the equipped boat is shown
- **Screen fills the window**: the game opens maximized with `stretch/aspect="expand"`, so there are no more black borders - on wider screens you simply see more of the water

## Bug fixes (v1.1)

- **Click-to-start fixed**: Menu now responds to `SPACE`, `Enter`, and mouse click (not just button signals)
- **Audio crash fixed**: `AudioStreamPlayer.get_stream_playback()` now called after `play()` initializes playback
- **Unused parameter warnings**: `update_bait(_dt)`, `_update_world(_dt)` prefixes added
- **Variable shadowing fixed**: `size` → `view_size`, `name` → `fish_name_val`, `seed` → `fish_seed`
- **Removed unused variable**: `y` in `_refresh_shop()`
- **ItemList color fix**: `set_item_custom_color` → `set_item_custom_fg_color` (correct Godot 4 API)

## Features implemented

- **Fish index** — scrollable grid; silhouettes (`???`) until caught; shows name, rarity, size range, personal-best weight, and collection % per region.
- **Rarity tiers** — Common/Uncommon/Rare/Epic/Legendary with distinct colors, catch rates, and weights. Rarier fish appear in deeper regions / at night.
- **4 fishing spots** — Pond, River, Lake, Deep Sea, unlocked by coins.
- **Boats** — buy at the Boat Dealer in Town; board with `B` and sail the water (raft, rowboat, skiff, trawler; faster speed + better payouts).
- **Rod toggle** — `R` equips / stows the fishing rod.
- **Shop/upgrades** — rods, lines, bait, bigger buckets.
- **Save/load** — `user://save.json`.
- **Progression goals** — region completion %, quests (First Catch, Rare Find, Collector).
- **Polish** — idle bobber bob, water ripple particles, day/night cycle, bite `!` indicator, screen-shake/flash on rare catches, procedural WebAudio beep SFX, cottagecore color palette, all art drawn procedurally (no external assets).

## Desktop, mobile and web builds

`export_presets.cfg` contains three presets:

- **Web** - outputs to `build/web/` (PWA enabled: manifest, icons, service worker and offline page).
- **Windows Desktop** - `build/windows/CottageCreekFishing.exe` (requires the Windows export templates).
- **Android** - `build/android/CottageCreekFishing.apk` (requires the Android SDK, the Android export templates, and a release keystore in the Godot editor's Android settings).

```bash
godot --headless --path . --export-release Web build/web/index.html
godot --headless --path . --export-release "Windows Desktop" build/windows/CottageCreekFishing.exe
godot --headless --path . --export-release Android build/android/CottageCreekFishing.apk
```

## Web deploy (GitHub Pages + Surge + Netlify)

The browser build lives in **`build/web/`** and is committed to the repo. That
folder is the only artifact every host serves — there is no other hosting
config, Worker, or backend.

Rebuild it after changing scripts, scenes, or assets:

```bash
./scripts/export-web.sh
# or, on any machine with Godot 4.7.x + Web export templates:
godot --headless --path . --export-release Web build/web/index.html
```

The script also copies the favicon (`fishing.svg`) and keeps Netlify's
`_headers` file in place. Commit `build/web/` with your change.

### GitHub Pages

The repo root `index.html` redirects to `build/web/`, and `.nojekyll` keeps
GitHub from filtering the export. Pages serves whatever is committed, so:

```bash
git add -A && git commit -m "Rebuild web export" && git push
```

Live at <https://timmywwe13-hub.github.io/simple/build/web/>.

### Surge

The same committed build is mirrored on four Surge subdomains:

- <https://cottage-creek-fishing.surge.sh/>
- <https://cottage-creek.surge.sh/>
- <https://cottagecreek.surge.sh/>
- <https://creekfishing.surge.sh/>

Authenticate once with `npx surge login`, then publish after a rebuild:

```bash
npx surge build/web https://cottage-creek-fishing.surge.sh
npx surge build/web https://cottage-creek.surge.sh
npx surge build/web https://cottagecreek.surge.sh
npx surge build/web https://creekfishing.surge.sh
```

For CI, set `SURGE_TOKEN` instead of logging in interactively. Surge writes a
`build/web/CNAME` file on deploy; it is ignored so the four domains stay
independent.

### Netlify

`netlify.toml` publishes `build/web` and sets no-cache headers for the wasm,
pck, js, and index.html so players get a fresh build after a deploy.

- **Fastest:** drag the `build/web` folder onto <https://app.netlify.com/drop>.
- **CLI:** `npx netlify-cli deploy --dir=build/web --prod`.
- **Git:** connect the repo in Netlify; it publishes `build/web` on every push.

Saves work in the browser via `user://` (persisted in IndexedDB), so no
database, account system, or server is needed.
