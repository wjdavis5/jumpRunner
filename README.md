# Courier Dash

Courier Dash is a 2D side-scrolling endless runner about an on-foot delivery
courier, built with Flutter and the Flame engine (package name `jump_runner`).
One input does everything: tap to hop, hold to leap, tap again in the air to
open a glide chute. The three packages you carry are your lives. The game is
offline and ad-free; progress is stored on the device only.

**Status:** active hobby project. Every push to `main` builds the web bundle;
publishing it to Cloudflare Pages is set up in the workflow but not switched on
yet (issue #134). iOS and Android builds are produced from version tags.

## Playing

| Input | Action |
|---|---|
| Tap / click, or `Space` / `Up` / `W` | Hop over low hazards (scooters, dogs, hydrants, mailboxes, the third rail) |
| Hold | Leap over tall hazards (vans, subway trains) |
| Press again while airborne | Open or stow the glide chute |
| `P` / `Esc`, or Back on Android | Pause, resume, or back out of a menu card |
| `Space` / `Enter` on the title or results screen | Start the shift / the next shift |

A press lasts from the moment a finger goes down until that finger lifts,
however far it slides in between.

- A shift starts at 200 px/s and ramps to 550 px/s over the first 2,000 m. The
  first 100 m is a warm-up with one small hazard at a time.
- Hitting a hazard drops a package. Losing all three ends the shift, and the
  results card says what took the last one and how to get past it.
- A flock of pigeons is the one hazard not to leap at: the birds take off as
  you arrive, and a courier who keeps running passes under them.
- Street set pieces (carts, rails, cranes, mailboxes and many more) are never
  harmful. Using them well pays tips and builds a stunt multiplier.
- Tips buy courier skins in the Locker and one-shot boosters in the Bodega.
  Daily Shifts and ten trophies give longer-term goals.

## Build, run, test

Requires the Flutter SDK (stable channel).

```sh
flutter pub get
flutter run -d chrome          # or any connected device
flutter analyze --fatal-infos  # CI treats infos as failures
flutter test
flutter build web --release --no-web-resources-cdn
```

The web build asks no server but its own for anything. The flag keeps the
drawing engine (CanvasKit) in the build instead of loading it from a CDN,
the font is in `assets/fonts/`, and the stars in the game's text are drawn
from the icon font the app already carries (`withStars`), because a
character the font lacks is otherwise fetched from a font server.

To look at late-game scenes without playing to them, a QA build can start
every shift part-way in and keep the courier alive. Both switches are
compile-time (`lib/game/logic/qa_flags.dart`) and off in a normal build:

```sh
flutter run -d chrome --dart-define=QA_START_METERS=2600 --dart-define=QA_IMMORTAL=true
```

In a QA build on the web, `?qa_start=1200` on the page address overrides the
starting distance without a rebuild, and `&qa_subway=1` turns every chunk
that can be a subway station into one (they are otherwise about 1.3 per
1,000 m). `&qa_seed=7` builds the same street on every load, which is what
makes two frame-rate measurements comparable.

## Project layout

| Path | What lives there |
|---|---|
| `lib/main.dart` | App shell: storage, audio, and the Flutter overlays wired onto the game |
| `lib/game/courier_game.dart` | The Flame game: update loop, scrolling, spawning, scoring hooks |
| `lib/game/logic/` | Engine-free logic: jump physics, chunk generation, run state, weather, camera |
| `lib/game/components/` | One Flame component per hazard, pickup, or set piece |
| `lib/game/models/` | Skins, boosters, achievements, contracts, daily shifts |
| `lib/ui/` | Title screen, HUD, pause, results, and shop overlays |
| `lib/services/storage_service.dart` | On-device persistence (`shared_preferences`) |
| `test/` | Unit and component tests, generally one file per feature |
| `tool/` | Asset generators (the synthesized weather sounds, the app icons) |
| `docs/` | The original plan and the running backlog |

The street is 540 units tall and 960 wide on a 16:9 screen. Wider screens show
more of it ahead (up to 2.4:1) rather than side bars; squarer ones are
letterboxed.

The world is generated one 960 px chunk at a time by
`WorldChunkManager.generateChunk`. It returns plain data, and `CourierGame`
turns that data into components, so generation can be tested without the
engine.

## Deployment

| Target | Trigger | Workflow |
|---|---|---|
| Web (Cloudflare Pages) | Push to `main` touching `lib/`, `web/`, `assets/` or `pubspec.*`. Builds today; the publish step is skipped until the Cloudflare secrets are set (issue #134) | `.github/workflows/web-deploy.yml` |
| Android APK and App Bundle | Tag `v*.*.*` | `.github/workflows/android-release.yml` |
| iOS (TestFlight via fastlane) | Tag `v*.*.*` | `.github/workflows/ios-release.yml` |

Pull requests to `main` run analysis, the test suite, a web release build and
an unsigned iOS build (`.github/workflows/pr-checks.yml`).

## Configuration and credentials

The game itself has no configuration, accounts, or network calls. Credentials
exist only as GitHub Actions secrets used by the workflows above:

- Cloudflare Pages deploy: an API token and the account ID.
- iOS release: App Store Connect API key (key ID, issuer ID, private key), the
  distribution certificate with its password, and the provisioning profile.

No secret values belong in this repository.

## Assets

Sprites and audio are curated from Kenney's CC0 packs and bundled under
`assets/`; see `assets/LICENSE_KENNEY.txt`.

The font is Roboto in four weights (Regular, Medium, Bold, Black), under the
Apache License 2.0: `assets/fonts/LICENSE_ROBOTO.txt`.

Three sounds are not samples: the rain loop, the thunderclap and the near-miss
whoosh are synthesized by `tool/generate_audio.py` (Python with numpy, plus
ffmpeg). Re-run it from the repository root after changing its numbers; the
output is deterministic.

The app icon (browser tab, home-screen install, Android launcher, iOS) is the
courier's own jump sprite on a dusk skyline. Every size is written by
`tool/generate_icons.py` (Python with Pillow and numpy); never edit the PNGs
by hand. `--preview <folder>` also writes the 1024 px masters to look at.
