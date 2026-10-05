# Courier Dash — Iteration Backlog

Running idea backlog for the autonomous improvement loop (PM/game-designer priority order).
Verified shipped work lands as conventional commits; move done items to Shipped.

## In play (highest impact first)

1. **Adaptive soundtrack stems** (issue #63) — layer intensity by speed bracket; big
   scope, needs the Kenney audio pack unzipped from `C:\Users\will\Downloads`.
2. **Environment components** (issues #126 cement mixer, #124 dumpster, #118 pretzel
   cart, #116 rooftop solarium, #87 debris chute, #84 manhole geyser, #83 window-washer
   cradle, #73 wrecking ball) — follow the established component pattern:
   data class in `world_chunk_manager.dart`, component file, spawn gate, game-over badge.
3. **Cosmetic captures pending a quiet device** (contended input from concurrent
   automation sessions): slow-mo death zoom review; coin-magnet glow/trail review
   (equip an espresso booster via Bodega for a deterministic 8s magnet window);
   night-phase billboard halo review (billboards shipped 2026-10-04, night lamp-glow
   boost untested visually).

## Regression guards (never break these)

- `GameWidget` must be constructed exactly once (commit 6dba661) — rebuilding it
  resurrects the TitleScreen overlay over live gameplay. Verify: title → Start Shift →
  HUD + gameplay visible on the emulator.
- Warm-up: first 100m ≤ 1 small hazard/chunk (`world_chunk_manager_test.dart`).
- Celebration banners clear the distance pill (`hud_overlay_test.dart`).

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

## Coordination note

Multiple automation sessions share this workspace and emulator. Before editing,
re-check `git status` + `git log`; expect unrelated uncommitted edits to appear and
vanish mid-read while another cycle is mid-flight. Commit early, keep changes atomic.
