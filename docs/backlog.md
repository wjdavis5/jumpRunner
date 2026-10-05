# Courier Dash — Iteration Backlog

Running idea backlog for the autonomous improvement loop (PM/game-designer priority order).
Verified shipped work lands as conventional commits; move done items to Shipped.

## In play (highest impact first)

1. **Coin magnet visual feedback** — energy drink grants a magnet; draw a subtle arc/trail
   from attracted coins so the buff reads on screen, not just in the HUD badge.
2. **First-run tip coaching** — one-time floating hint ("TAP & HOLD TO LEAP!") at the first
   warm-up hazard, only when `storage.highDistance == 0`.
3. **Adaptive soundtrack stems** (issue #63) — layer intensity by speed bracket; big
   scope, needs the Kenney audio pack unzipped from `C:\Users\will\Downloads`.
4. **Neon billboard ads** (issue #66) — parallax decoration with courier headlines;
   procedurally drawn, no new assets required.
5. **Environment components** (issues #126 cement mixer, #124 dumpster, #118 pretzel
   cart, #116 rooftop solarium, #87 debris chute, #84 manhole geyser, #83 window-washer
   cradle, #73 wrecking ball) — follow the established component pattern:
   data class in `world_chunk_manager.dart`, component file, spawn gate, game-over badge.
6. **Slow-mo death beat: cosmetic zoom capture** — shipped and functionally verified
   (see below); pending a quiet-device video capture of the 1.3x camera ease for
   cosmetic tuning. Emulator input events were contended by a concurrent automation
   session during verification attempts.

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

## Coordination note

Multiple automation sessions share this workspace and emulator. Before editing,
re-check `git status` + `git log`; expect unrelated uncommitted edits to appear and
vanish mid-read while another cycle is mid-flight. Commit early, keep changes atomic.
