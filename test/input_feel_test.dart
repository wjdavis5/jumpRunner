import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jump_runner/game/components/courier_player.dart';
import 'package:jump_runner/game/components/obstacle_component.dart';
import 'package:jump_runner/game/courier_game.dart';
import 'package:jump_runner/game/logic/game_state.dart';
import 'package:jump_runner/game/logic/jump_physics.dart';
import 'package:jump_runner/game/logic/world_chunk_manager.dart';

const double _dt = 1.0 / 60.0;

/// Advances [player] one frame at a time until [done] holds or [maxSeconds] elapse.
void _advanceUntil(
  CourierPlayer player,
  bool Function() done, {
  double maxSeconds = 3.0,
}) {
  double elapsed = 0.0;
  while (!done() && elapsed < maxSeconds) {
    player.update(_dt);
    elapsed += _dt;
  }
  expect(done(), isTrue, reason: 'Condition not reached within ${maxSeconds}s');
}

Future<CourierGame> _loadedGame() async {
  final game = CourierGame();
  await game.onLoad();
  for (final name in const ['TitleScreen', 'GameOver', 'LockerModal']) {
    game.overlays.addEntry(name, (context, game) => const SizedBox.shrink());
  }
  return game;
}

KeyEventResult _keyDown(
  CourierGame game,
  LogicalKeyboardKey logical,
  PhysicalKeyboardKey physical,
) {
  return game.onKeyEvent(
    KeyDownEvent(
      physicalKey: physical,
      logicalKey: logical,
      timeStamp: Duration.zero,
    ),
    {logical},
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Minimum hop: every tap is a real hop', () {
    test('A flick shorter than 80ms still reaches the short-hop height', () {
      for (final hold in const [0.0, 0.016, 0.033, 0.050]) {
        final peak = JumpPhysicsSimulator.simulateJumpPeak(holdDuration: hold);
        expect(
          peak,
          inInclusiveRange(65.0, 75.0),
          reason: 'A ${(hold * 1000).round()}ms flick peaked at ${peak}px',
        );
      }
    });

    test('A same-frame flick clears a scooter at base scroll speed', () {
      final scooter = ObstacleComponent.defaultSizeForType(ObstacleType.scooter);
      // The torso hitbox is 32px wide and its bottom edge sits 4px above the feet.
      const torsoWidth = 32.0;
      const torsoFootGap = 4.0;
      final requiredFootHeight = scooter.y - torsoFootGap;
      final requiredSeconds =
          (scooter.x + torsoWidth) / WorldChunkManager.baseSpeed;

      final sim = JumpPhysicsSimulator();
      sim.startJump();
      sim.stopJump();

      double secondsAboveScooter = 0.0;
      double elapsed = 0.0;
      while (!sim.isGrounded && elapsed < 3.0) {
        sim.update(_dt);
        elapsed += _dt;
        if (sim.heightAboveGround > requiredFootHeight) {
          secondsAboveScooter += _dt;
        }
      }

      expect(
        secondsAboveScooter,
        greaterThanOrEqualTo(requiredSeconds),
        reason: 'A flick must stay above the scooter for its whole width',
      );
    });

    test('Holding still produces the full leap', () {
      final peak = JumpPhysicsSimulator.simulateJumpPeak(holdDuration: 0.250);
      expect(peak, inInclusiveRange(175.0, 185.0));
    });
  });

  group('Coyote time', () {
    JumpPhysicsSimulator simOnLedge() {
      final sim = JumpPhysicsSimulator(groundY: 460.0);
      sim.setSurfaceY(380.0);
      sim.currentY = 380.0;
      expect(sim.isGrounded, isTrue);
      return sim;
    }

    test('A jump still registers just after running off a ledge', () {
      final sim = simOnLedge();
      sim.resetSurfaceY();
      expect(sim.isGrounded, isFalse);

      sim.update(0.05);
      expect(sim.canJump, isTrue);
      expect(sim.startJump(), isTrue);
      expect(sim.verticalVelocity, greaterThan(0.0));
    });

    test('The grace window expires', () {
      final sim = simOnLedge();
      sim.resetSurfaceY();

      for (var i = 0; i < 9; i++) {
        sim.update(_dt); // 150ms, past the 100ms window
      }
      expect(sim.canJump, isFalse);
      expect(sim.startJump(), isFalse);
    });

    test('Only one jump is granted per ledge', () {
      final sim = simOnLedge();
      sim.resetSurfaceY();
      expect(sim.startJump(), isTrue);
      expect(sim.startJump(), isFalse);
    });

    test('Being launched into the air grants no grace jump', () {
      final sim = JumpPhysicsSimulator();
      sim.launch(300.0);
      expect(sim.canJump, isFalse);

      final updraft = JumpPhysicsSimulator();
      updraft.applyUpdraft(200.0);
      expect(updraft.canJump, isFalse);
    });
  });

  group('Landing estimate', () {
    test('timeToLanding matches the simulated free fall within a frame', () {
      final sim = JumpPhysicsSimulator(groundY: 460.0);
      sim.launch(180.0);
      sim.update(_dt);
      final estimate = sim.timeToLanding;

      double elapsed = 0.0;
      while (!sim.isGrounded && elapsed < 3.0) {
        sim.update(_dt);
        elapsed += _dt;
      }
      expect(elapsed, closeTo(estimate, _dt * 1.5));
    });

    test('timeToLanding is zero on the ground', () {
      expect(JumpPhysicsSimulator().timeToLanding, equals(0.0));
    });
  });

  group('Jump buffering', () {
    Future<CourierPlayer> airbornePlayer({required void Function() onJump}) async {
      final player = CourierPlayer(groundY: 460.0, onJump: onJump);
      await player.onLoad();
      player.pressJump();
      player.releaseJump();
      return player;
    }

    bool isAboutToLand(CourierPlayer player) =>
        player.simulator.verticalVelocity < 0 &&
        player.simulator.timeToLanding <= 0.06;

    test('A press just before touchdown fires on landing instead of gliding', () async {
      int jumps = 0;
      final player = await airbornePlayer(onJump: () => jumps++);
      expect(jumps, equals(1));

      _advanceUntil(player, () => isAboutToLand(player));
      player.pressJump();

      expect(player.hasBufferedJump, isTrue);
      expect(player.isGliding, isFalse);

      _advanceUntil(player, () => jumps == 2, maxSeconds: 0.25);
      expect(player.hasBufferedJump, isFalse);
      expect(player.simulator.isGrounded, isFalse);
      expect(player.simulator.verticalVelocity, greaterThan(0.0));
      expect(player.state, equals(CourierState.jumping));
    });

    test('A buffered tap that was already released still yields a short hop', () async {
      int jumps = 0;
      final player = await airbornePlayer(onJump: () => jumps++);

      _advanceUntil(player, () => isAboutToLand(player));
      player.pressJump();
      player.releaseJump();
      _advanceUntil(player, () => jumps == 2, maxSeconds: 0.25);

      double peak = 0.0;
      double elapsed = 0.0;
      while (!player.simulator.isGrounded && elapsed < 3.0) {
        player.update(_dt);
        elapsed += _dt;
        if (player.simulator.heightAboveGround > peak) {
          peak = player.simulator.heightAboveGround;
        }
      }
      expect(peak, inInclusiveRange(65.0, 75.0));
    });

    test('A buffered press that is still held leaps higher than a tap', () async {
      int jumps = 0;
      final player = await airbornePlayer(onJump: () => jumps++);

      _advanceUntil(player, () => isAboutToLand(player));
      player.pressJump(); // held through touchdown
      _advanceUntil(player, () => jumps == 2, maxSeconds: 0.25);

      double peak = 0.0;
      double elapsed = 0.0;
      while (!player.simulator.isGrounded && elapsed < 3.0) {
        player.update(_dt);
        elapsed += _dt;
        if (player.simulator.heightAboveGround > peak) {
          peak = player.simulator.heightAboveGround;
        }
      }
      expect(peak, greaterThan(150.0));
    });

    test('A press high in the air still deploys the glide chute', () async {
      int jumps = 0;
      final player = CourierPlayer(groundY: 460.0, onJump: () => jumps++);
      await player.onLoad();
      player.pressJump(); // hold for a full leap

      _advanceUntil(player, () => player.simulator.verticalVelocity <= 0);
      player.releaseJump();
      player.pressJump();

      expect(player.isGliding, isTrue);
      expect(player.hasBufferedJump, isFalse);
      expect(jumps, equals(1));
    });

    test('resetForRun drops a queued jump and leftover hit invulnerability', () async {
      int jumps = 0;
      final player = await airbornePlayer(onJump: () => jumps++);
      _advanceUntil(player, () => isAboutToLand(player));
      player.pressJump();
      expect(player.hasBufferedJump, isTrue);

      player.takeDamage();
      expect(player.isInvulnerable, isTrue);

      player.resetForRun();
      expect(player.hasBufferedJump, isFalse);
      expect(player.isInvulnerable, isFalse);
    });
  });

  group('Keyboard confirm on title and results screens', () {
    test('Space and Enter start a shift from the bare title screen', () async {
      final game = await _loadedGame();
      int starts = 0;
      game.onStartRequested = () => starts++;
      game.overlays.add('TitleScreen');

      expect(game.gameState.status, equals(GameStatus.idle));
      expect(
        _keyDown(game, LogicalKeyboardKey.space, PhysicalKeyboardKey.space),
        equals(KeyEventResult.handled),
      );
      expect(starts, equals(1));

      _keyDown(game, LogicalKeyboardKey.enter, PhysicalKeyboardKey.enter);
      expect(starts, equals(2));
    });

    test('Space does not start a shift while a modal covers the title screen', () async {
      final game = await _loadedGame();
      int starts = 0;
      game.onStartRequested = () => starts++;
      game.overlays.add('TitleScreen');
      game.overlays.add('LockerModal');

      _keyDown(game, LogicalKeyboardKey.space, PhysicalKeyboardKey.space);
      expect(starts, equals(0));
    });

    test('Space restarts from the results screen only after the lockout', () async {
      final game = await _loadedGame();
      int restarts = 0;
      game.onRestartRequested = () => restarts++;

      game.gameState.startRun();
      for (var i = 0; i < 10 && game.gameState.status != GameStatus.gameOver; i++) {
        game.gameState.applyHazardDamage();
      }
      expect(game.gameState.status, equals(GameStatus.gameOver));
      game.overlays.add('GameOver');

      // One frame never simulates more than maxFrameStep, so time is passed
      // the way it passes in play: a frame at a time.
      void wait(double seconds) {
        for (var t = 0.0; t < seconds; t += 1 / 60) {
          game.update(1 / 60);
        }
      }

      // Mashing jump as the crash lands must not skip the results screen.
      _keyDown(game, LogicalKeyboardKey.space, PhysicalKeyboardKey.space);
      wait(CourierGame.restartInputLockout / 2);
      _keyDown(game, LogicalKeyboardKey.space, PhysicalKeyboardKey.space);
      expect(restarts, equals(0));

      wait(CourierGame.restartInputLockout);
      _keyDown(game, LogicalKeyboardKey.space, PhysicalKeyboardKey.space);
      expect(restarts, equals(1));
    });

    test('Space during a live run jumps and never starts or restarts', () async {
      final game = await _loadedGame();
      int starts = 0;
      int restarts = 0;
      game.onStartRequested = () => starts++;
      game.onRestartRequested = () => restarts++;

      game.gameState.startRun();
      _keyDown(game, LogicalKeyboardKey.space, PhysicalKeyboardKey.space);

      expect(game.player.simulator.isGrounded, isFalse);
      expect(starts, equals(0));
      expect(restarts, equals(0));
    });
  });
}
