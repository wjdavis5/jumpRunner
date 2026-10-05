# Courier Dash — Iteration Backlog

Running idea backlog for the autonomous improvement loop (PM/game-designer priority order).
Verified shipped work lands as conventional commits; move done items to Shipped.

## In play (highest impact first)

1. **Adaptive soundtrack, next slices** (issue #63) — night-phase crossfade shipped;
   remaining slices: rain-weighted lowpass/mood, streak-driven intensity layer.
2. **Environment components** (issues #126 cement mixer, #124 dumpster, #118 pretzel
   cart, #116 rooftop solarium, #87 debris chute, #84 manhole geyser, #83 window-washer
   cradle, #73 wrecking ball) — follow the established component pattern:
   data class in `world_chunk_manager.dart`, component file, spawn gate, game-over badge.
   **A new street piece also needs**, or a test will fail:
   - its `active*` list in the scroll section of `CourierGame._step`, in the
     recycle pass and in the restart cleanup (`world_housekeeping_test.dart`
     watches every component in the world for one that stands still or is
     never removed);
   - `subwayStations.isEmpty` in its spawn condition (`subway_station_chunk_test.dart`);
   - a place in `declutterStreet` so it is not built on top of something else;
   - if it moves relative to the street, its gap built through
     `closingDistance` (`oncoming_hazard_spacing_test.dart`).
3. **Waiting on the owner** — open decisions are GitHub issues labelled
   `needs-human` (#127 difficulty past 2,000 m, #128 prices and rewards, #129
   vault window, #130 the synthesized sounds, #131 the app icon, #132 sprite
   sheets for older phones, #133 a phone playtest, #134 the deploy that never
   publishes, #135 whether a courier the street has thrown is safe until
   landing). File new decisions there rather than in this file.

The cosmetic captures that used to be item 3 are done: the death zoom showed a
black void beside the street and was fixed; the coin magnet and the billboards
render correctly. Late content no longer needs a long survived run: see QA
build below.

## Regression guards (never break these)

- `GameWidget` must be constructed exactly once (commit 6dba661) — rebuilding it
  resurrects the TitleScreen overlay over live gameplay. Verify: title → Start Shift →
  HUD + gameplay visible on the emulator.
- Warm-up: first 100m ≤ 1 small hazard/chunk (`world_chunk_manager_test.dart`).
- Celebration banners clear the distance pill (`hud_overlay_test.dart`) and
  the status badges under it (`hud_banner_badges_test.dart`).
- Hazards on the open street come from `WorldChunkManager.streetHazards`, never
  `ObstacleType.values`: third rails and subway trains belong to stations.
- A subway station chunk holds the third rail, the train and pickups, nothing
  else (`subway_station_chunk_test.dart`).
- Clearance between hazards is judged where the courier meets them, not where
  they are built. Anything that rolls toward the courier (train, skater) is
  set back by the ground it will make up (`closingDistance`,
  `subwayTrainSetback`).
- Behind a hazard that only a full leap clears (van, subway train) the street
  stays clear to where that leap can land plus a quarter second
  (`clearanceAfter`, `clearanceBetween`). A new hazard that cannot be hopped
  goes in `needsFullLeap`. A van also gets a run-up in front of it, and a
  station's third rail the usual clearance from the hazard before it (the
  rail moves within 220-300 px or the chunk stays a street). Every hazard
  keeps a floor of room for error: 200 ms of tap timings, 300 ms for a leap
  (`hazard_fairness_floor_test.dart`).
- A launch or an updraft never costs height: `JumpPhysicsSimulator.launch`
  and `applyUpdraft` leave alone a jump that will climb higher by itself
  (`launch_never_costs_height_test.dart`). A street piece that launches the
  courier calls those, never sets `verticalVelocity` itself. The slingshot
  out of a draft is an ordinary jump, so a hold is still a leap.
- A test that needs an empty street uses `test/support/bare_street.dart`.
  Removing the hazards from a generated street leaves its energy drinks, and
  one run in twelve picked one up and ran a fifth faster.
- Hazard behaviour that depends on the courier's approach is timed in seconds,
  not pixels: the pigeon flock takes off 1.2 s ahead at any speed
  (`pigeon_flock_fairness_test.dart`).
- Every `tips +=` in `GameState` reports the same amount to
  `contractManager.onTipCollected`: the tips contract must match the HUD
  (`contract_ladder_test.dart` checks it every frame of a shift).
- One frame simulates at most 0.1 s, in steps of at most 1/60 s
  (`frame_step_test.dart`). A test that asserts an exact per-frame value should
  step at 1/60.
- The HUD overlay is rebuilt at most every 80 ms (`ThrottledListenableBuilder`
  in `main.dart`). Do not put it back inside an `AnimatedBuilder` on the game
  state: that was a sixth of each frame on the web
  (`hud_refresh_rate_test.dart`).
- The skyline and facades are recorded once and replayed
  (`parallax_cache_test.dart`); a window's light is a property of the window,
  not of its position on screen.
- Every overlay fits 667x375 and up (`overlay_fit_test.dart`,
  `results_screen_fit_test.dart`, `menu_scrollbar_test.dart`).
- Prices, rewards and trophy thresholds are sized against measured income
  (`economy_test.dart`, `contract_ladder_test.dart`); change them together.
- Icons and three sounds are generated: edit `tool/generate_icons.py` or
  `tool/generate_audio.py` and re-run, never the files.
- Android: back is handled by `_handleSystemBack` (pause, close a card, leave
  results; exit only from the title) and the app runs in sticky immersive
  mode (`app_back_button_test.dart`, `immersive_mode_test.dart`).
- The street reads a touch as a press and a release
  (`PressHoldGestureRecognizer`), never as a tap. Do not put `TapCallbacks`
  back on the game: a tap recognizer drops a touch that slides 18 px and a
  held jump comes down as the smallest hop. The hold belongs to the latest
  press only (`touch_hold_test.dart`).
- The app draws its text at its designed sizes whatever the phone's
  text-size setting is (the clamp in `MaterialApp.builder`,
  `system_text_size_test.dart`). Without it the cards overflow from 115%.
- `app_monkey_test.dart` walks the whole app at random; a new overlay or
  button belongs in its action list.

## Shipped

- 2026-10-04: P0 overlay fix (6dba661), banner clearance (25f91d7).
- 2026-10-04: first-run warm-up spawn ramp (677e04b).
- 2026-10-04: slow-motion death beat (0b8922b) — 0.55s @ 30% tree speed, ease-out
  camera zoom to 1.3x on the fallen courier, then modal. Unit-tested (DeathSlowmoController);
  verified on-device across three observed deaths (151m/152m/152m): beat always
  completed into the modal, restarts and PR/Persistence all clean.
- 2026-10-04: coin magnet visuals (b2e5cdf) — radial-pull fix (bobbing no longer
  cancels the vertical pull), pulsing gold halo, snap-in glint, comet-trail
  sparkles. Unit-tested position ownership; emulator flow verified on the build.
- 2026-10-04: first-run coaching hint (bddf765) — persistent "TAP & HOLD TO LEAP!"
  above the opening hazard for zero-PB players; dismisses on first tap, 7s
  failsafe. Unit-tested; emulator-verified both gates (shown when wiped save,
  hidden once a PB exists).
- 2026-10-04: neon billboards (bf77462) — seven courier-themed glowing headlines
  on every third midground facade with shimmer/dropout flicker, glitch shear,
  and night lamp-glow scaling. Unit-tested glow math; emulator-verified live.
- 2026-10-04: adaptive night music (fecb3aa) — Kenney "Night at the Beach" loop
  crossfades in at the night phase (2500-4300m of each 5000m cycle) and back at
  dawn; fade-at-silence swaps, duck-aware multiplier, restart snap. Five
  mock-backend tests; asset bundled and day path verified error-free on device.
- 2026-10-05: game-feel series (5c361e5 app icon, 363cb00 everything else,
  836a957 Android full screen). The commit messages carry the list. In short:
  the street generator was building almost no hazards and is fixed; subway
  stations never scrolled and now work; trains, skaters and pigeons were
  unfair at speed and are not; the economy, contracts and trophies were
  retuned; every screen fits a phone; Android back, vibration and full screen;
  the web build's frame rate under a slow CPU went from about 20 to about
  27-30 fps mid-shift. Checked in tests, a phone-sized browser and an Android
  15 emulator. Not checked on a physical phone.

## QA build

Late content can be reached without playing to it:

```sh
flutter build web --release --dart-define=QA_IMMORTAL=true --output build/web_qa
```

and open it with `?qa_start=2600` (start distance), `&qa_subway=1` (every
chunk that can be a subway station is one) and `&qa_seed=7` (the same street
on every load). The flags are compiled out of a normal build. Details are in
the README.

## Coordination note

Multiple automation sessions share this workspace and emulator. Before editing,
re-check `git status` + `git log`; expect unrelated uncommitted edits to appear and
vanish mid-read while another cycle is mid-flight. Commit early, keep changes atomic.

The 2026-10-05 series was made in a separate worktree and pushed straight to
`origin/main`. A checkout that was on `main` before it is behind the remote:
`git pull --ff-only` before committing there.
