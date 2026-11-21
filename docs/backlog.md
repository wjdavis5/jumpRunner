# Courier Dash — Iteration Backlog

Running idea backlog for the autonomous improvement loop (PM/game-designer priority order).
Verified shipped work lands as conventional commits; move done items to Shipped.

## In play (highest impact first)

1. **Adaptive soundtrack, last slice** (issue #63) — night-phase crossfade and the
   streak-driven intensity layer shipped; what is left is the rain-weighted
   lowpass/mood, and it is blocked at the lowpass half: audioplayers 6.x exposes
   no filter/equalizer API (grepped the pub cache), so a true lowpass needs a
   new audio dependency (an epic), and the mood half would add a third target
   to the day/night swap machine.
2. (Environment components: the last queued piece, #116 rooftop solarium,
   shipped as redundant with the glass skylight - see the 2026-11-20 note
   below. New pieces now need a design reason of their own.)
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
   landing, #136 whether street pieces are introduced gradually: all 34
   kinds unlock by 240 m). File new decisions there rather than in this file.

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
  (`hazard_fairness_floor_test.dart`). A van behind a scaffold, rail or
  solar array stands back by the drop from it as well (`roomAfterDrop`,
  `drop_room_test.dart`); a new raised piece records its height with
  `_pieceEndsAt`.
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
  `results_screen_fit_test.dart`, `menu_scrollbar_test.dart`), and below
  that it scales instead of overflowing, down to 320 px wide
  (`NarrowScreenScale`, `narrow_screen_test.dart`): a new HUD row or card
  goes inside the scaler, and a row that shows a tip total has to hold six
  figures.
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
- No text is shown with part of it missing (`text_fits_test.dart`). Tests
  draw every letter as a wide square, so an ordinary layout test cannot
  tell whether a label fits: this one loads the real fonts
  (`test/support/real_fonts.dart`) and reads every screen at eight sizes
  for text that ends in an ellipsis, stops at a line limit, or is a button
  label that has wrapped. A button label is one line, scaled down
  (`KeyHintLabel`); the Trophies list is one column under 500 px.
- The web build asks no server but its own for anything: build with
  `--no-web-resources-cdn`, keep Roboto in `assets/fonts/`, and write a star
  with `withStars` (a character Roboto lacks is fetched from a font server
  on the web, and is an empty box until it arrives). Check in a browser
  that the page makes no request to another host.
- The street is drawn in a fixed order (`lib/game/draw_order.dart`): street
  pieces, then the courier, then sparks and dust, then the game's words,
  then the weather. A new street piece stays at the default priority. At
  one shared priority the courier, built first, was hidden behind every
  piece they overlapped, and a crane built after a hint stood in front of
  it (`draw_order_test.dart`, `hazard_coaching_test.dart`).
- A shift is banked when it ends and also when the app is put away in the
  middle of it (`_checkpointShift` in `main.dart`): a phone may close an
  app it has put away, and a tab can be closed. Each banking adds only what
  the shift has earned since the last, and the tally belongs to the run
  (`GameState.runNumber`), so nothing is counted twice and nothing carries
  into the next shift (`app_put_away_mid_shift_test.dart`; the random walk
  keeps its own tally of tips earned against tips banked).
- A saved value that is missing or of the wrong kind reads as never saved
  (`LocalStorageService._read`). The plugin's typed getters throw, and every
  value is read while the app starts (`damaged_save_test.dart`).
- `soak_test.dart` also plays the street with random presses and holds. A
  street piece that moves the courier (a rail, a hook, a launch) has to
  give them back: running again within 6 s, at their own spot, never
  wholly off the screen.

## Shipped

- 2026-11-21: QA builds go storage-blind — a QA run (immortal, seeded,
  starting at 2,600 m) used to bank into the player save on quit: the
  shared emulator's save had grown a 4,378 m personal best, $14,957 of
  career tips and 8/10 trophies purely from unattended QA sessions. Every
  StorageService mutation is now a no-op when the build is QA (qaBlind
  flag; reads stay live), main.dart constructs it with QaFlags.any, and
  the on-device proof cleared the save, ran 2,680 m with $1,301 banked,
  quit and relaunch showed 0 m / $0 / 0-10 trophies. 2 tests in
  test/storage_service_test.dart. Explains the mid-run return-to-title
  mystery's sibling: the low-memory killer was killing a process whose
  save kept being rewritten by QA.
- 2026-11-21: shift contract progress on the results screen — the pause
  menu's contract panel is now the shared ShiftContractsPanel widget and the
  results screen mounts it inside the badge scroll (first on a fresh run,
  below the badges when the list is full; the record banner keeps its
  see-it-without-scrolling guarantee on all three phone sizes). 4 tests in
  test/results_contracts_test.dart; pause tests untouched.
- 2026-11-20: music and sound effects channel toggles — the pause menu gains
  Music and Sound Effects switches (on = audible) beside the accessibility
  toggles, backed by two storage keys and two GameAudioController channel
  flags beside the master mute (which still overrides both). The music
  channel gates the soundtrack machine, streak layer and rain ambience
  (21 gate sites through _musicGated/_sfxGated helpers); setMusicMuted
  applies live with the same stop/restart dance as the master mute.
  7 tests in test/sound_channels_test.dart; verified on the emulator.
- 2026-11-20: reduce screen shake toggle — the pause menu gains a third
  accessibility switch ('Reduce Screen Shake') beside the lightning flash
  one: with it on, every impact lands at a quarter of the trauma (all 59
  shake call sites funnel through one storage-backed gate), enough to
  register the hit without lurching the street. Persists across sessions
  like reduce-flash and haptics. 4 tests in test/reduce_shake_test.dart;
  verified on the emulator through a force-stop and relaunch.
- 2026-11-20: top-speed feel — the courier's run stride used to cycle at one
  fixed 0.12 s no matter how fast the street scrolled (moonwalking at 550
  px/s); it now ticks with the scroll speed (up to 2.4x at the cap), and a
  new viewport SpeedLinesComponent streams thin air smears leftward above the
  sidewalk whenever the ramp lifts past ~380 px/s, full at 550. Calm streets
  draw nothing. The draw-order and housekeeping guards exempt it as viewport
  weather. 10 tests in test/top_speed_feel_test.dart. Issue #116 (rooftop
  solarium) was examined and dropped: the glass skylight already covers
  'glass dome the courier interacts with aerially', and issue #136 asks
  whether the piece count should stop growing.
- 2026-11-20: window-washer cradle rides (issue #83) — a davit boom on a slim
  mast suspends a steel platform on two cables, bobbing between floors with a
  washer aboard sweeping a squeegee over soap-sud drips. A courier who leaps
  aboard rides the moving deck (followSlideSurface pins them to the bob),
  crossing the apex after a seen rise pays 'CRADLE RIDE!' tips scaled by the
  stunt chain, jumping bails, landing back re-rides, rising couriers pass
  under untouched, and the deck never crowds the sidewalk. Rigs keep clear of
  scaffold routes, wrecking balls and stations; two tips float at the apex
  height. Results badge 'game_over_cradle_badge' (41st kind); QA tooling
  gains QA_FORCE_CRADLE. 15 tests in test/window_washer_cradle_test.dart
  (bare-street land/ride/apex/bail/walk-under) plus station-chunk and
  results-fit guards updated.
- 2026-11-20: construction debris chute slides (issue #87) — a corrugated
  blue chute hangs off the scaffolding deck's trailing edge, angling down to
  the sidewalk with yellow mounting straps, rib rings, plaster chunks sliding
  inside, and a tarp-covered debris bin at the bottom mouth. A courier who
  runs off the deck rides the tube to street level: the hopper mouth catches
  them into a grind-style slide, followSlideSurface pins them to the
  descending line each frame (setTargetSurfaceY would un-ground a courier
  whose surface just dropped), the bottom mouth pays 'CHUTE SLIDE! +$12'
  (energy boost doubles it) and dust, and jumping mid-slide bails out the
  ordinary way while a street-level courier walks under the bottom sliver
  untouched. Spawns on aerial routes past 150 m in the branch order rail,
  chute, solar, plain drop, lined with three tips collected mid-descent,
  declutter-registered as an anchor, never in a station chunk (inherits the
  scaffold gate). Results badge 'game_over_chute_badge' (CHUTE SLIDE/SLIDES);
  results-fit scroll test now lights 40 kinds. QA tooling gains QA_SEED and
  QA_FORCE_CHUTE dart-defines for deterministic recording. 18 tests in
  test/debris_chute_test.dart plus station-chunk, declutter, results-fit and
  coaching (van window widened to 800 m) guards updated.
- 2026-10-09: hot pretzel and chestnut vendor carts (issue #118) — a wheeled
  steel cart under a blue-and-yellow striped canopy with brass poles, a glass
  warming display of twisted pretzels, and a copper chestnut cauldron over
  glowing charcoals. An airborne courier hurdle-vaulting the counter gets a
  +195 px/s parkour boost, a "Nothing beats fresh street pretzels!" bark, a
  PRETZEL SPRINT! tip float ($34 base, streak-scaled), 26 buoyant roast-aroma
  particles, and the new Hot Snack Sprint buff (+16% scroll speed for 3.5 s,
  its own timer alongside the caffeine surge in the speed multiplier).
  Spawns past 90 m, never in a station chunk, clear of every vendor stand,
  fixture and hazard, declutter-registered. Results badge
  `game_over_pretzel_badge` (PRETZEL SPRINT/SPRINTS); results-fit scroll test
  now lights 39 kinds. 23 tests in test/street_vendor_cart_test.dart plus
  the station-chunk, declutter and results-fit guards updated.
- 2026-10-09: demolition wrecking balls (issue #73) — a lattice crane mast
  stands in the street background with a heavy steel ball swinging on a boom
  cable in a metronomic pendulum arc (54 degrees each way, 2.4 s period,
  per-spawn phase so consecutive balls swing out of step). The low point
  mows across a grounded courier's upper body: time the run through while
  the ball is on the far side, or hop the arc. Contact flows through the
  player's standard damage path (one hit per swing; invulnerability gates
  the rest). The mast is background structure and shares street space like
  the crane masts; spawns past 140 m, never in a station chunk, and two
  balls never share a chunk. No tips and no badge: it is the first pure
  moving hazard. 15 tests in test/wrecking_ball_test.dart (pendulum math,
  phase stagger, circle-vs-rect contact at the low point and at max
  deflection, recycle boundary, spawn gate pins at 139/140 m, station
  exclusion, game integration for the hit, invulnerability hold, and the
  swung-away miss) plus the station-chunk guard updated.
- 2026-10-09: manhole cover geysers (issue #84) — a cast-iron street plate on
  a pressurized sewer main rattles when the courier draws within 180 px
  (synthesized metallic rattle, `tool/generate_audio.py`, deterministic like
  the rest), then erupts when the buildup completes or the courier steps onto
  the lid: the lid blasts off spinning, a 30-particle buoyant steam column
  rises, an 8-coin ring rides the blast, and a courier standing in the column
  (grounded or airborne, below 150 px) is launched +480 px/s with a
  "Riding the tube!" bark and a MANHOLE GEYSER! tip float ($40 base,
  streak-scaled). One eruption per manhole; a courier off the column gets the
  show and the coins but pays nothing. Spawns past 130 m, never in a station
  chunk, clear of hazards, fixtures and storm drains, declutter-registered.
  Results badge `game_over_manhole_badge` (GEYSER RIDE/RIDES); results-fit
  scroll test now lights 38 kinds. 25 tests in test/manhole_geyser_test.dart
  plus the station-chunk, declutter and results-fit guards updated.
- 2026-10-09: curbside dumpsters (issue #124) — a forest-green steel bin on
  caster wheels with ribbed walls, hazard chevrons, a stenciled serial and
  dual spring-loaded rubber lids resting 15° open; an airborne courier who
  lands on the lids compresses the hinges and is catapulted +240 px/s,
  showering 24 aluminum/lime/rubber sparks from the hinge, with a
  "Trash to treasure!" bark and a DUMPSTER LID LAUNCH! tip float ($35 base,
  streak-scaled). The lids fling wide for 0.35 s on the bounce. Spawns past
  70 m, never in a station chunk, clear of hazards, vendor carts and other
  fixtures, and thinned by `declutterStreet`; a grounded run-past earns
  nothing and leaves the bin fresh. Results badge `game_over_dumpster_badge`
  (1 DUMPSTER LAUNCH / N LAUNCHES); results-fit scroll test now uses 37 lit
  kinds. 22 tests in test/dumpster_test.dart plus housekeeping,
  station-chunk, declutter and results-fit guards updated.
- 2026-10-08: street construction cement mixers (issue #126, a43cc48) — a
  portable rotary mixer on a safety-yellow tripod chassis churns its
  corrugated drum every frame; an airborne courier bounding onto it gets a
  +230 px/s rotational mortar hop (through `JumpPhysicsSimulator.launch`, so a
  held leap is never cut short) and 26 wet-cement splatter particles, with a
  "Still setting!" bark and a CEMENT MIXER HOP! tip float ($34 base,
  streak-scaled). Spawns past 85 m, never in a station chunk, clear of
  hazards and other fixtures, and thinned by `declutterStreet`; the results
  card counts hops with `game_over_cement_mixer_badge`. 23 tests in
  `test/cement_mixer_test.dart` plus the housekeeping, station-chunk,
  declutter and results-fit guards. Implemented in worktree
  `feat/cement-mixer`.
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
- 2026-10-06: streak-driven intensity layer (issue #63 slice, 4d1805c) — a synthesized
  high-tempo arp (tool/generate_audio.py, one loop per music track,
  sample-matched to its BGM so the two stay beat-locked) fades in over half a
  second at a 3x stunt streak and back out when it ends; a restarted streak
  rides the same loop, the layer swaps with the day/night crossfade at
  silence and comes back while the streak is live, and pause/milestone
  ducking and mute/backgrounding scale or hold it exactly like the BGM.
  Mock-backend tests (streak_music_test.dart, duck tests in
  audio_controller_test.dart) and a sample-match guard in
  audio_assets_test.dart. Shipped through the dynamic-workflow iteration
  pipeline (implement → integrate → analyze/test gates → cold read → commit
  → emulator verify); implemented in worktree feat/streak-intensity-layer
  (7945eea) and landed on main as 4d1805c.
- 2026-10-05: game-feel series (5c361e5 app icon, 363cb00 everything else,
  836a957 Android full screen). The commit messages carry the list. In short:
  the street generator was building almost no hazards and is fixed; subway
  stations never scrolled and now work; trains, skaters and pigeons were
  unfair at speed and are not; the economy, contracts and trophies were
  retuned; every screen fits a phone; Android back, vibration and full screen;
  the web build's frame rate under a slow CPU went from about 20 to about
  27-30 fps mid-shift. Checked in tests, a phone-sized browser and an Android
  15 emulator. Not checked on a physical phone.

## Performance baseline (measured 2026-11-20)

The emulator cannot answer frame-rate questions: its virtual display
composites at ~10 Hz for EVERY app - the system launcher's own swipe
animations measured 7.5 fps with a bugreport recording, while the guest
reports a 60 Hz vsync (via `dumpsys display`: renderFrameRate 60.0). Host-side
throttling, not game cost. Methods that work: `screenrecord --bugreport` +
ffprobe frame gaps (contaminated slightly by the recorder), and
`dumpsys SurfaceFlinger --latency '<layer>'` on the app's SurfaceView layer
from `dumpsys SurfaceFlinger --list` (broke after a guest reboot: zero-filled
buffer). `dumpsys gfxinfo` never works on Flutter apps (no HWUI path).

Findings from the hunt anyway:
- The audio controller's `attemptedPlays` diagnostic list grew forever (a
  coin every few seconds for 6,500 m) - now capped at 100 entries.
- Guest memory is tight (61 lowmemorykiller kills in the history; the game
  held 1.6 GB RSS after a two-hour immortal run) but a fresh run plateaus
  at ~236 MB within two minutes. Long-horizon growth across many shifts is
  unproven - worth re-checking after a long unattended session.
- A mid-run return-to-title with old save values seen on 2026-11-20 was
  almost certainly the guest low-memory killer, not a game crash (no
  AndroidRuntime fatal in logcat).

Real phones (issue #133) remain the only honest frame-rate measurement.

## QA build

Late content can be reached without playing to it:

```sh
flutter build web --release --no-web-resources-cdn --dart-define=QA_IMMORTAL=true --output build/web_qa
```

and open it with `?qa_start=2600` (start distance), `&qa_subway=1` (every
chunk that can be a subway station is one) and `&qa_seed=7` (the same street
on every load). The flags are compiled out of a normal build. Details are in
the README.

## Pictures of every screen

```sh
flutter test tool/screens.dart
```

writes a PNG of the title card, the four depot cards, the HUD, the pause menu
and the results card at eight screen sizes to `build/screens/`, in about half
a minute and with no phone or browser. It also takes the street itself
(`street-*.png`): each coaching hint over its hazard, and a minute of a
seeded street, one picture every five seconds. All of it is drawn in the
real fonts. Look at these before reaching for a browser or an emulator.

Text the game paints on its canvas must name its font (`gameFontFamily` in
`lib/game/game_font.dart`), or it comes out of these pictures as solid bars.

## Coordination note

Multiple automation sessions share this workspace and emulator. Before editing,
re-check `git status` + `git log`; expect unrelated uncommitted edits to appear and
vanish mid-read while another cycle is mid-flight. Commit early, keep changes atomic.

The 2026-10-05 series was made in a separate worktree and pushed straight to
`origin/main`. A checkout that was on `main` before it is behind the remote:
`git pull --ff-only` before committing there.
