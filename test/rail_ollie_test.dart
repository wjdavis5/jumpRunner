import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jump_runner/game/components/grind_rail_component.dart';
import 'package:jump_runner/game/components/solar_panel_component.dart';
import 'package:jump_runner/game/courier_game.dart';

Future<CourierGame> _game() async {
  final game = CourierGame();
  await game.onLoad();
  game.gameState.startRun();
  return game;
}

/// Puts the courier on [surfaceY] at x = 230 and lets one frame settle them
/// into the grind.
void _standOn(CourierGame game, double surfaceY, double dt) {
  game.player.position.x = 230.0;
  game.player.simulator.currentY = surfaceY;
  game.player.simulator.isGrounded = true;
  game.update(dt);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A rail or panel "catches" a courier whose feet are within 14 px above it.
  // That used to include a courier on the way up, so at any ordinary frame
  // rate a jump off a rail was cancelled before it had risen clear: the
  // courier stayed glued on while the game still paid the ollie tips. The
  // older tests stepped 50 ms at a time, which is the one case that escaped.
  const frameRates = {'30 fps': 1 / 30, '60 fps': 1 / 60, '120 fps': 1 / 120};

  group('Jumping off a grind rail leaves the rail', () {
    for (final rate in frameRates.entries) {
      test('at ${rate.key}', () async {
        final game = await _game();
        final rail = GrindRailComponent(
          position: Vector2(200.0, 420.0),
          size: Vector2(900.0, 8.0),
          groundY: 460.0,
        );
        game.activeGrindRails.add(rail);
        game.world.add(rail);
        _standOn(game, rail.surfaceY, rate.value);
        expect(game.player.isGrinding, isTrue);

        game.player.jump();
        var peak = 0.0;
        var framesOff = 0;
        for (var t = 0.0; t < 0.3; t += rate.value) {
          game.update(rate.value);
          final lift = rail.surfaceY - game.player.simulator.currentY;
          if (lift > peak) peak = lift;
          if (!game.player.isGrinding) framesOff++;
        }
        // A 340 px/s launch tops out about 59 px up.
        expect(peak, greaterThan(40.0), reason: 'the ollie never left the rail');
        expect(framesOff, greaterThan(0.25 / rate.value));
      });
    }

    test('coming back down onto the same rail, the courier grinds again', () async {
      final game = await _game();
      final rail = GrindRailComponent(
        position: Vector2(-2000.0, 420.0),
        size: Vector2(6000.0, 8.0),
        groundY: 460.0,
      );
      game.activeGrindRails.add(rail);
      game.world.add(rail);
      _standOn(game, rail.surfaceY, 1 / 60);

      game.player.jump();
      var left = false;
      var landedBack = false;
      for (var i = 0; i < 120; i++) {
        game.update(1 / 60);
        if (!game.player.isGrinding) left = true;
        if (left && game.player.isGrinding) {
          landedBack = true;
          break;
        }
      }
      expect(left, isTrue);
      expect(landedBack, isTrue, reason: 'a falling courier is still caught');
    });
  });

  group('Jumping off a charged solar panel sets off the surge', () {
    for (final rate in frameRates.entries) {
      test('at ${rate.key}', () async {
        final game = await _game();
        final panel = SolarPanelComponent(
          position: Vector2(200.0, 396.0),
          size: Vector2(220.0, 18.0),
          groundY: 460.0,
        );
        game.activeSolarPanels.add(panel);
        game.world.add(panel);
        _standOn(game, panel.surfaceY, rate.value);
        expect(game.player.isGrinding, isTrue);
        panel.addCharge(0.6);

        game.player.jump();
        game.update(rate.value);

        expect(game.player.isGrinding, isFalse);
        expect(panel.hasDischarged, isTrue);
        expect(game.gameState.solarSurgesInRun, equals(1));
      });
    }
  });

  group('What the catch rule is', () {
    test('a rail ignores a courier moving up through its reach', () async {
      final game = await _game();
      final rail = GrindRailComponent(
        position: Vector2(200.0, 420.0),
        size: Vector2(260.0, 8.0),
        groundY: 460.0,
      );
      game.player.position.x = 230.0;
      game.player.simulator
        ..currentY = rail.surfaceY - 5.0
        ..isGrounded = false;

      game.player.simulator.verticalVelocity = 200.0; // rising
      expect(rail.checkCollisionWith(game.player), isFalse);
      game.player.simulator.verticalVelocity = -200.0; // falling
      expect(rail.checkCollisionWith(game.player), isTrue);
      game.player.simulator.verticalVelocity = 0.0; // riding
      expect(rail.checkCollisionWith(game.player), isTrue);
    });
  });
}
