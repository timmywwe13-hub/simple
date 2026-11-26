# Cottage Creek Fishing v1.10 - QA Matrix

Build: Godot 4.7.2 Web export. Version `1.10` / `THE ANGLER ALMANAC`.

| # | Area | Case and expected result | Result | Evidence |
|---|---|---|---|---|
| 1 | Boot | Cold boot to the main menu at 1280x800; canvas fills the page and START FISHING responds. | PASS | `qa_menu.png`, Edge `qa_edge.png` |
| 2 | Version | What's New reads `V1.10 - THE ANGLER ALMANAC`; all seven bullets fit with BACK visible. | PASS | `qa_whatsnew_final2.png` |
| 3 | Almanac | Open from menu and pause; rank header, full 68-species grid in four columns, legend, daily board, records, field notes and wheel scrolling work. | PASS | `qa_alm_final.png`, `qa_alm_scroll.png` |
| 4 | Angler Rank | Derived points total 204 at 68 Gold species; titles are Novice 0, Apprentice 20, Angler 50, Veteran 90, Master 130, Legend 170. | PASS | Stats and Almanac `LEGEND - 204 PTS` screenshots; headless smoke |
| 5 | Mastery | Bronze/Silver/Gold at 5/15/40 catches, paying 25/100/300 once; a first catch at 40 pays the full cascade. | PASS | Headless smoke (51 checks) |
| 6 | Mastery bonus | Each Gold species adds +0.5% to sales, capped at +15%; applied after perfect and before the event/money multiplier. | PASS | Stats `GOLD SALE BONUS +15.0%`; code/order audit |
| 7 | Old saves | A save without mastery/daily/set-line fields loads with defaults and no retroactive medal payout; rank derives from saved catch counts. | PASS | Headless smoke |
| 8 | Species | Fish Index holds 68 species; Amber Dace (river/day), Moonlit Tench (lake/night) and Gale Smelt (ocean/storm) are present and catchable. | PASS | `FishDB.gd`; smoke count 68 |
| 9 | Quests | Eight v1.10 quests are registered; 39 total definitions; progress and claim paths still work. | PASS | `GameState.gd`; quest board screenshots |
| 10 | Daily board | Exactly 3 of 14 definitions are chosen per local day; claim, streak-scaled payout, third-claim +150 bonus and forward-only rollover work. | PASS | `qa_board4.png`, `qa_board4_scroll.png`; headless smoke |
| 11 | Daily timezone | Board rolls at local midnight (UTC-5 test), not 19:00. | PASS | Headless smoke after `day_index()` fix |
| 12 | Set Lines shop | Willow 300 / 1 slot, Braided 800 / 2 slots, Trotline Rack 1,600 / 3 slots; locked tiers show LOCKED and owned tiers show capacity. | PASS | `qa_shop_lines.png` |
| 13 | Set Lines use | `P` (desktop) and `LINE` (touch) place one line per bank spot, show an 8:00 timer, and reject open water, Coconut Isle, boats and duplicates. | PASS | `qa_mobile_line_set.png`, `qa_mobile_line3.png` |
| 14 | Set Lines edge cases | Collecting requires a ready line; a full bucket leaves the catch on the line; line catches do not increase the sale streak. | PASS | Deterministic smoke; code audit |
| 15 | HUD desktop | Bucket, weather, daily, boat, bait, `LINES n/3` and the blinking `LINE READY - P` hint fit at 1280x800. | PASS | `qa_mobile_line3.png`, `qa_edge_mobile.png` |
| 16 | HUD touch | At 844x390 the six actions `ROD BOAT AXE LINE IDX MENU` sit in one row above CAST; guidance text clears the row. | PASS | `qa_mobile_line3.png`, `qa_edge_mobile.png` |
| 17 | Touch cast | Tap water to aim/cast; large action button changes CAST/HOOK/REEL/HOLD; multi-touch works. | PASS | `qa_mobile_world3.png`, `qa_catch.png` |
| 18 | Touch index | `IDX` opens the Index with medals and `MASTERY: GOLD (MAX)`; back returns to fishing. | PASS | `qa_mobile_index.png` |
| 19 | Portrait | A 390x844 portrait viewport shows the rotate-device overlay and readable subtitle without clipping. | PASS | `qa_portrait_final.png` |
| 20 | Pause | Escape pause shows RESUME, SETTINGS, WHAT'S NEW, ALMANAC, MAIN MENU at 420x468; ALMANAC opens, back returns to pause, main menu releases pause. | PASS | `qa_pause.png` |
| 21 | Menu | Eight buttons plus rank line (`LEGEND - 204 PTS  GOLD 68`) fit the panel; START/INDEX/SHOP/HARVEST/STATS/SETTINGS/WHAT'S NEW/ALMANAC hit targets verified. | PASS | `qa_menu.png`, click tests |
| 22 | Save/reload | Cheat then reload keeps mastery, rank, 68 Gold, coins and set lines; a second load does not duplicate medal coins. | PASS | `qa_save_runtime.png`, `qa_save_after2.png` |
| 23 | Cache reset | `/reset.html` clears the PWA/service-worker cache; current worker tag is `ccf-d0e309784f3e` and a reload picks up the new PCK. | PASS | HTTP checks; PWA reload |
| 24 | Browsers | Chromium 158 (Chrome engine) and Edge 158 desktop + 844x390 touch pass with no console/page errors. | PASS | `qa_edge.png`, `qa_edge_mobile.png`, console logs |

## Export fingerprint

- `index.pck`: 2,090,964 bytes
- SHA-256: `D64D4FCDA8750175D0724F57E611488FEC143423A65BED7165D21DC608573B34`
- PWA cache tag: `ccf-d0e309784f3e`
- QA artifacts live in `C:/Users/Conner/Downloads/simple2_qa`, outside the Godot project, so they are not packed into the PCK.

## Notes

- Tests were run headless against the exported build served from `http://127.0.0.1:8123`.
- The 8-minute wait was verified from the live countdown; the ready/collect/full-bucket branches were exercised by the deterministic smoke harness rather than by waiting eight real minutes.
- The temporary smoke harness and its fixtures were removed after the run so they cannot leak into `index.pck`.
## Live v1.10 endpoints

All four return HTTP 200, the same `index.pck` (2,090,964 bytes / `D64D4FCDA8750175D0724F57E611488FEC143423A65BED7165D21DC608573B34`), the same cache tag `ccf-d0e309784f3e`, and a working `/reset.html`:

- <https://cottage-creek-fishing-v110.surge.sh>
- <https://cottage-creek-v110.surge.sh>
- <https://cottagecreek-v110.surge.sh>
- <https://creekfishing-v110.surge.sh>
- GitHub Pages mirror: <https://timmywwe13-hub.github.io/simple/build/web/>

The four originally named domains (`cottage-creek-fishing.surge.sh`, `cottage-creek.surge.sh`, `cottagecreek.surge.sh`, `creekfishing.surge.sh`) are owned by a different Surge account. Publishing returns 403, so they still serve the v1.9.2 PCK (`1E558681CCEE1120246DB63B86367DDFF5A35C2E21D04FCA761C51C668E08A76`). They need the owning account's token to receive this build.
