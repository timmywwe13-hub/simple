# Cottage Creek Fishing

A simple, polished 2D fishing game with a collection-and-progression loop, built in **Godot 4.7** (GDScript, Canvas 2D rendering, no external assets).

**Play in your browser:** https://timmywwe13-hub.github.io/simple/build/web/

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
| What's New / patch notes | menu or pause button `WHAT'S NEW`, `U` in Town |
| Quit | close window |

**On touchscreens** (phones/tablets) an on-screen pad and buttons appear:
move with the left thumb, tap the water to aim and cast, and use the big
button to cast / hook / reel / hold tension (its label changes with the
situation). The small buttons cover rod, boat, spots `1`–`4`, index and
menu, and multi-touch works.

## Gameplay loop

1. **Cast** — aim with the mouse, press `SPACE`/click to cast the bobber.
2. **Wait for a bite** — a `!` indicator flashes over the bobber with a bite sound. Click quickly to hook.
3. **Reel** — small fish: timing bar (press in the green zone; the gold centre is a perfect catch for +15%). Big fish: physics tug-of-war (hold `SPACE` to reel in and keep the tension marker in the green band).
4. **Catch popup** — fish name, weight, rarity, coin value, plus a `NEW SPECIES!` badge on first catch and tags for perfect / daily / hot-demand bonuses.
5. **Sell / Index** — open the Fish Index (`I`, also mid-fishing: collection log with silhouettes until caught, plus region and uncaught filters) or the Tackle Shop (sell all fish for coins).
6. **Upgrade** — buy better rods (faster reeling, wider timing window), lines (fewer escapes), bait (attracts rarer fish), lanterns (faster night bites), and bigger buckets (more inventory).
7. **Progress** — unlock the River, Lake, and Deep Sea regions by coins; each has its own fish table. Day/night, weather, daily catches and daily market demand change which fish are worth chasing.
8. **Coconut Isle** — sail east from the Deep Sea to a tropical beach. Buy the axe in the shop, chop the palms for coconuts (each palm regrows in 20 minutes, with a timer over the stump), then spend the coconuts in **Coconut Isle Crafting** to build rods 25% better than every shop rod. The isle's own fish only bite with bait.

## Save system

Progress (coins, inventory, fish index, gear, unlocked regions, quests) auto-saves to `user://save.json` and resumes on restart.

## Project structure

```
res://main.tscn          # Main scene (Node2D)
res://scripts/main.gd    # Game loop: cast/bite/reel, rendering, UI screens
res://scripts/GameState.gd # Save/load, inventory, index, gear, quests, audio SFX
res://scripts/FishDB.gd  # All fish data + regional tables
res://scripts/ShopDB.gd  # Rods / lines / baits / buckets data
res://scripts/GameTheme.gd # Cottagecore color palette + rarity tiers
res://scripts/ui_lib.gd  # Tiny code-only UI toolkit
res://scripts/touch_controls.gd # On-screen touch controls for phones/tablets
res://scripts/fish_art.gd # Procedural pixel-ish fish drawing (shared)
```

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
- **New gear tiers** - Carbon Rod (3.2x reel, 0.42 window), Fluorocarbon Line (94% keep) and Deck Cooler (72 fish)
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

## Web export (Netlify)

Build the web version (Godot 4.7.x with Web export templates installed):

```
godot --headless --path . --export-release Web build/web/index.html
```

This produces the static site in `build/web/` (already built in this repo). To deploy on Netlify:

- **Fastest:** drag-and-drop the `build/web` folder onto <https://app.netlify.com/drop>.
- **CLI:** `npx netlify-cli deploy --dir=build/web --prod` (picks up `netlify.toml`).
- **Git:** connect the repo in Netlify; `netlify.toml` publishes `build/web` (commit the folder after rebuilding).

Saves work in the browser via `user://` (persisted in IndexedDB), so no backend is needed.

## Web deploy (Cloudflare Workers)

Cloudflare Workers static assets (and Pages) reject any single file over **25 MiB**,
and Godot's release `index.wasm` is ~38 MiB, so it cannot be uploaded as one
asset. The repo works around that:

- `scripts/cf-build.sh` copies `build/web/` to `dist/` and splits `index.wasm`
  into `index.wasm.part0..N` (~16 MiB each) plus `index.wasm.parts.json`.
- `worker/index.js` answers `/index.wasm` by streaming those parts back in order
  as a single `application/wasm` response; every other path goes straight to
  static assets.
- `wrangler.jsonc` points `assets.directory` at `dist/`, wires the Worker, and
  runs the build script through `build.command`.

Deploy from the Cloudflare dashboard (GitHub-connected Worker):

1. **Settings → Build**: Deploy command `npx wrangler deploy`, Build command
   empty (wrangler runs `scripts/cf-build.sh` itself). Root directory = repo root.
2. If the Worker is named something other than `simple`, set `name` in
   `wrangler.jsonc` to match.
3. Commit the rebuilt `build/web/` with your changes — CI deploys the committed
   export, it does not run Godot.

Locally:

```
bash ./scripts/cf-build.sh   # assemble dist/
npx wrangler dev             # http://127.0.0.1:8787
```

Notes: game content lives in `index.pck`, so normal updates only change that
~1.6 MiB file — the wasm parts change only when you upgrade Godot's web export
templates. Do **not** try to ship the wasm gzipped with a `Content-Encoding`
header: Cloudflare's edge compresses Worker responses itself, which yields a
double-encoded body that fails to instantiate.
