// The game is mounted by hand (no flame_test dependency), which needs Flame's
// internal load/mount entry points.
// ignore_for_file: invalid_use_of_internal_member
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jump_runner/game/audio_controller.dart';
import 'package:jump_runner/game/courier_game.dart';
import 'package:jump_runner/game/logic/outfit_tailor.dart';
import 'package:jump_runner/game/models/courier_skin.dart';

const _frames = ['run_1', 'run_2', 'run_3', 'run_4', 'jump', 'hurt'];

/// A courier frame's pixels, straight from the asset file.
Future<(Uint8List, int, int)> _art(String frame) async {
  final codec = await ui.instantiateImageCodec(
    File('assets/images/courier/$frame.png').readAsBytesSync(),
  );
  final image = (await codec.getNextFrame()).image;
  final data = (await image.toByteData())!;
  final result = (data.buffer.asUint8List(), image.width, image.height);
  image.dispose();
  return result;
}

Future<Uint8List> _pixels(ui.Image image) async =>
    (await image.toByteData())!.buffer.asUint8List();

/// Garment of each fully opaque pixel of [rgba], or null.
List<Garment?> _garments(Uint8List rgba, int width, int height) {
  return [
    for (var i = 0; i < width * height; i++)
      rgba[i * 4 + 3] == 255
          ? OutfitTailor.garmentAt(
              rgba[i * 4],
              rgba[i * 4 + 1],
              rgba[i * 4 + 2],
              (i ~/ width) / height,
            )
          : null,
  ];
}

Future<CourierGame> _mountedGame() async {
  final game = CourierGame(
    audioController: GameAudioController()..isMuted = true,
  );
  game.onGameResize(Vector2(960, 540));
  await game.load();
  game.mount();
  game.update(0);
  await game.ready();
  game.gameState.startRun();
  game.restartRun();
  game.update(1.0 / 60.0);
  return game;
}

/// Renders the frame and returns the average colour of the courier's box.
Future<List<double>> _courierColour(CourierGame game) async {
  final recorder = ui.PictureRecorder();
  game.render(ui.Canvas(recorder));
  final image = await recorder.endRecording().toImage(960, 540);
  final ByteData data = (await image.toByteData())!;
  image.dispose();

  final player = game.player;
  final left = player.position.x.round();
  final top = player.position.y.round();
  double r = 0, g = 0, b = 0;
  int n = 0;
  for (var y = top; y < top + player.size.y; y++) {
    for (var x = left; x < left + player.size.x; x++) {
      final i = (y * 960 + x) * 4;
      r += data.getUint8(i);
      g += data.getUint8(i + 1);
      b += data.getUint8(i + 2);
      n++;
    }
  }
  return [r / n, g / n, b / n];
}

double _distance(List<double> a, List<double> b) =>
    (a[0] - b[0]).abs() + (a[1] - b[1]).abs() + (a[2] - b[2]).abs();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('The tailor finds the clothes in the courier art', () {
    for (final frame in _frames) {
      test('$frame has a shirt, shorts and shoes', () async {
        final (rgba, width, height) = await _art(frame);
        final garments = _garments(rgba, width, height);
        int count(Garment g) => garments.where((x) => x == g).length;
        expect(count(Garment.shirt), greaterThan(500), reason: 'shirt');
        expect(count(Garment.pants), greaterThan(120), reason: 'shorts');
        expect(count(Garment.shoes), greaterThan(20), reason: 'shoes');
      });
    }

    test('skin, hair and eyes are nobody’s garment', () {
      // The art's own flat colours.
      expect(OutfitTailor.garmentAt(0xff, 0xe0, 0xb1, 0.5), isNull, reason: 'skin');
      expect(OutfitTailor.garmentAt(0xff, 0xe0, 0xb1, 0.9), isNull, reason: 'a hand held low');
      expect(OutfitTailor.garmentAt(0xc4, 0x8a, 0x51, 0.2), isNull, reason: 'hair');
      expect(OutfitTailor.garmentAt(0xb8, 0x82, 0x4d, 0.3), isNull, reason: 'hair shade');
      expect(OutfitTailor.garmentAt(0xff, 0xff, 0xff, 0.5), isNull, reason: 'eye white');
      expect(OutfitTailor.garmentAt(0x7f, 0x70, 0x58, 0.5), isNull, reason: 'outline');
      // And the clothes.
      expect(OutfitTailor.garmentAt(0x2e, 0xcc, 0x71, 0.7), Garment.shirt);
      expect(OutfitTailor.garmentAt(0x25, 0xa8, 0x5c, 0.7), Garment.shirt);
      expect(OutfitTailor.garmentAt(0x34, 0x98, 0xdb, 0.85), Garment.pants);
      expect(OutfitTailor.garmentAt(0xb8, 0x82, 0x4d, 0.95), Garment.shoes);
    });

    test('dressing changes the clothes and nothing else', () async {
      const loud = OutfitColors(
        shirt: ui.Color(0xFFFF00FF),
        pants: ui.Color(0xFFFF00FF),
        shoes: ui.Color(0xFFFF00FF),
      );
      for (final frame in _frames) {
        final (rgba, width, height) = await _art(frame);
        final garments = _garments(rgba, width, height);
        final dressed = OutfitTailor.dress(rgba, width, height, loud);

        for (var i = 0; i < width * height; i++) {
          if (rgba[i * 4 + 3] != 255) continue;
          final changed = dressed[i * 4] != rgba[i * 4] ||
              dressed[i * 4 + 1] != rgba[i * 4 + 1] ||
              dressed[i * 4 + 2] != rgba[i * 4 + 2];
          expect(changed, equals(garments[i] != null), reason: '$frame pixel $i');
          expect(dressed[i * 4 + 3], equals(255));
        }
      }
    });

    test('the plain uniform is returned untouched', () async {
      final (rgba, width, height) = await _art('run_1');
      expect(OutfitTailor.dress(rgba, width, height, const OutfitColors()), equals(rgba));
    });

    test('a fold in the cloth stays darker than the cloth around it', () {
      // Two shirt pixels from the art: the flat green and its shadow.
      final art = Uint8List.fromList([0x2e, 0xcc, 0x71, 255, 0x25, 0xa8, 0x5c, 255]);
      final dressed = OutfitTailor.dress(
        art,
        2,
        1,
        const OutfitColors(shirt: ui.Color(0xFF00E5FF)),
      );
      // Cyan: the blue channel carries it.
      expect(dressed[2], greaterThan(dressed[6]));
      expect(dressed[2], greaterThan(200));
      expect(dressed[0], lessThan(40));
    });
  });

  group('Locker outfits show on the courier', () {
    test('The standard uniform changes nothing', () {
      expect(CourierSkin.standard.outfit.isPlain, isTrue);
    });

    test('Every outfit that costs tips recolours at least one garment', () {
      for (final skin in CourierSkin.catalog.where((s) => s.price > 0)) {
        expect(skin.outfit.isPlain, isFalse, reason: '${skin.name} would be invisible');
      }
    });

    test('Each outfit dresses its own garments and leaves the face alone', () async {
      final game = await _mountedGame();
      final player = game.player;
      final bases = [...player.runSprites!, player.jumpSprite!, player.hurtSprite!];

      for (final skin in CourierSkin.catalog.where((s) => s.price > 0)) {
        game.setPlayerSkin(skin);
        await player.outfitReady;

        for (final base in bases) {
          final worn = player.wornSprite(base);
          expect(worn, isNot(same(base)), reason: skin.name);

          final before = await _pixels(base.image);
          final after = await _pixels(worn.image);
          final width = base.image.width;
          final garments = _garments(before, width, base.image.height);

          final sums = <Garment, List<double>>{};
          final counts = <Garment, int>{};
          for (var i = 0; i < garments.length; i++) {
            if (before[i * 4 + 3] != 255) continue;
            final garment = garments[i];
            final same = before[i * 4] == after[i * 4] &&
                before[i * 4 + 1] == after[i * 4 + 1] &&
                before[i * 4 + 2] == after[i * 4 + 2];
            if (garment == null) {
              // Face, hair, hands, outline.
              expect(same, isTrue, reason: '${skin.name}: pixel $i is not clothing');
              continue;
            }
            final sum = sums.putIfAbsent(garment, () => [0, 0, 0]);
            sum[0] += after[i * 4];
            sum[1] += after[i * 4 + 1];
            sum[2] += after[i * 4 + 2];
            counts[garment] = (counts[garment] ?? 0) + 1;
          }

          void check(Garment garment, ui.Color? target, List<int> original) {
            final n = counts[garment]!;
            final mean = [for (final v in sums[garment]!) v / n];
            if (target == null) {
              // Not part of this outfit: still the art's own colour.
              expect(
                _distance(mean, [for (final v in original) v.toDouble()]),
                lessThan(40.0),
                reason: '${skin.name} should not touch the ${garment.name}',
              );
            } else {
              final want = [target.r * 255.0, target.g * 255.0, target.b * 255.0];
              expect(
                _distance(mean, want),
                lessThan(90.0),
                reason: '${skin.name} ${garment.name}: ${mean.map((v) => v.round())}',
              );
            }
          }

          check(Garment.shirt, skin.outfit.shirt, const [0x2e, 0xcc, 0x71]);
          check(Garment.pants, skin.outfit.pants, const [0x34, 0x98, 0xdb]);
          check(Garment.shoes, skin.outfit.shoes, const [0xb8, 0x82, 0x4d]);
        }
      }
    });

    test('Each purchased outfit visibly changes the courier on screen', () async {
      final game = await _mountedGame();
      game.setPlayerSkin(CourierSkin.standard);
      await game.player.outfitReady;
      final standard = await _courierColour(game);

      final seen = <String, List<double>>{'standard': standard};
      for (final skin in CourierSkin.catalog.where((s) => s.price > 0)) {
        game.setPlayerSkin(skin);
        await game.player.outfitReady;
        final colour = await _courierColour(game);
        for (final other in seen.entries) {
          expect(
            _distance(colour, other.value),
            greaterThan(8.0),
            reason: '${skin.name} looks the same as ${other.key} '
                '(${colour.map((c) => c.round())} vs ${other.value.map((c) => c.round())})',
          );
        }
        seen[skin.id] = colour;
      }
    });

    test('Going back to the standard uniform restores the original art', () async {
      final game = await _mountedGame();
      final player = game.player;
      game.setPlayerSkin(CourierSkin.goldenCourier);
      await player.outfitReady;
      expect(player.wornSprite(player.jumpSprite!), isNot(same(player.jumpSprite)));

      game.setPlayerSkin(CourierSkin.standard);
      await player.outfitReady;
      expect(player.wornSprite(player.jumpSprite!), same(player.jumpSprite));
    });

    test('Changing outfit twice in a row ends in the second one', () async {
      final game = await _mountedGame();
      final player = game.player;
      // Cyan jacket, then at once the gold jumpsuit.
      game.setPlayerSkin(CourierSkin.nightShiftNeon);
      game.setPlayerSkin(CourierSkin.goldenCourier);
      await player.outfitReady;
      // Let the superseded job finish and stand down.
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final base = player.jumpSprite!;
      final before = await _pixels(base.image);
      final after = await _pixels(player.wornSprite(base).image);
      final garments = _garments(before, base.image.width, base.image.height);
      final shirt = garments.indexOf(Garment.shirt);
      // Gold: strong red and green, little blue. Cyan would be the reverse.
      expect(after[shirt * 4], greaterThan(180));
      expect(after[shirt * 4 + 2], lessThan(80));
    });
  });
}
