import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jump_runner/game/logic/outfit_tailor.dart';
import 'package:jump_runner/game/models/courier_skin.dart';
import 'package:jump_runner/ui/locker_modal.dart';
import 'package:jump_runner/ui/outfit_preview.dart';

Widget _locker() => MaterialApp(
      home: Scaffold(
        body: LockerModal(
          careerTips: 2000,
          unlockedSkins: const ['standard'],
          equippedSkin: 'standard',
          onEquipSkin: (_) {},
          onUnlockSkin: (_, __) async {},
          onClose: () {},
        ),
      ),
    );

Finder _preview(CourierSkin skin) => find.byKey(Key('outfit_preview_${skin.id}'));

/// Decoding and recolouring the art needs real time, which a widget test
/// only gives inside runAsync.
Future<void> _letPreviewsLoad(WidgetTester tester) async {
  for (var i = 0; i < 40; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 25)));
    await tester.pump();
    if (CourierSkin.catalog.every((s) => _preview(s).evaluate().isNotEmpty)) return;
  }
}

Future<Uint8List> _pixelsOf(WidgetTester tester, CourierSkin skin) async {
  final raw = tester.widget<RawImage>(
    find.descendant(of: _preview(skin), matching: find.byType(RawImage)),
  );
  final data = await tester.runAsync(() => raw.image!.toByteData());
  return data!.buffer.asUint8List();
}

void main() {
  group('The Locker shows the courier wearing each outfit', () {
    testWidgets('every outfit gets a picture, not just a colour swatch', (tester) async {
      await tester.pumpWidget(_locker());
      await _letPreviewsLoad(tester);

      for (final skin in CourierSkin.catalog) {
        expect(_preview(skin), findsOneWidget, reason: skin.name);
        final raw = tester.widget<RawImage>(
          find.descendant(of: _preview(skin), matching: find.byType(RawImage)),
        );
        expect(raw.image, isNotNull);
        expect(raw.image!.width, equals(80));
        expect(raw.image!.height, equals(110));
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('the pictures wear what the outfits say', (tester) async {
      await tester.pumpWidget(_locker());
      await _letPreviewsLoad(tester);

      final standard = await _pixelsOf(tester, CourierSkin.standard);
      final neon = await _pixelsOf(tester, CourierSkin.nightShiftNeon);
      final highTops = await _pixelsOf(tester, CourierSkin.highTops);
      final golden = await _pixelsOf(tester, CourierSkin.goldenCourier);

      // Find one pixel of each garment, and one of the face, in the plain art.
      int pixelOf(Garment? garment, {bool face = false}) {
        for (var i = 0; i < 80 * 110; i++) {
          if (standard[i * 4 + 3] != 255) continue;
          final r = standard[i * 4];
          final g = standard[i * 4 + 1];
          final b = standard[i * 4 + 2];
          if (face) {
            if (r == 0xff && g == 0xe0 && b == 0xb1) return i;
            continue;
          }
          if (OutfitTailor.garmentAt(r, g, b, (i ~/ 80) / 110) == garment) return i;
        }
        fail('no such pixel');
      }

      List<int> rgb(Uint8List image, int i) =>
          [image[i * 4], image[i * 4 + 1], image[i * 4 + 2]];

      final shirt = pixelOf(Garment.shirt);
      final pants = pixelOf(Garment.pants);
      final shoes = pixelOf(Garment.shoes);
      final face = pixelOf(null, face: true);

      // Standard: the art's own green, blue and brown.
      expect(rgb(standard, shirt)[1], greaterThan(150));
      // Neon: a cyan jacket (no red, strong blue), shorts untouched.
      expect(rgb(neon, shirt)[0], lessThan(60));
      expect(rgb(neon, shirt)[2], greaterThan(180));
      expect(rgb(neon, pants), equals(rgb(standard, pants)));
      // High-Tops: only the shoes change, to crimson.
      expect(rgb(highTops, shirt), equals(rgb(standard, shirt)));
      expect(rgb(highTops, shoes)[0], greaterThan(150));
      expect(rgb(highTops, shoes)[1], lessThan(110));
      // Golden: gold top and bottom (red and green high, blue low).
      expect(rgb(golden, shirt)[0], greaterThan(180));
      expect(rgb(golden, shirt)[2], lessThan(80));
      expect(rgb(golden, pants)[0], greaterThan(150));
      // Nobody's face changes colour.
      for (final image in [neon, highTops, golden]) {
        expect(rgb(image, face), equals(const [0xff, 0xe0, 0xb1]));
      }
    });

    testWidgets('the swatch stands in until the picture is ready', (tester) async {
      // An outfit no earlier test has shown, so nothing is cached for it.
      const fresh = CourierSkin(
        id: 'preview_test_only',
        name: 'Test',
        description: 'Test',
        price: 1,
        primaryColor: Color(0xFF123456),
        accentColor: Color(0xFF654321),
        glowColor: Color(0xFF123456),
        outfit: OutfitColors(shirt: Color(0xFFFF00FF)),
      );
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: OutfitPreview(skin: fresh, placeholder: Text('swatch')),
            ),
          ),
        ),
      );
      // No real time has passed, so nothing can have been decoded yet.
      expect(find.text('swatch'), findsOneWidget);
      expect(find.byType(RawImage), findsNothing);

      for (var i = 0; i < 40 && find.byType(RawImage).evaluate().isEmpty; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 25)));
        await tester.pump();
      }
      expect(find.byType(RawImage), findsOneWidget);
      expect(find.text('swatch'), findsNothing);
    });

    for (final size in const [Size(667, 375), Size(844, 390), Size(960, 540)]) {
      testWidgets('the Locker still fits at ${size.width.toInt()}x${size.height.toInt()} with pictures in it',
          (tester) async {
        tester.view.devicePixelRatio = 1.0;
        tester.view.physicalSize = size;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(_locker());
        await _letPreviewsLoad(tester);
        expect(tester.takeException(), isNull);

        final close = tester.getRect(find.byKey(const Key('locker_close_button')));
        expect(close.top, greaterThanOrEqualTo(0.0));
        expect(close.right, lessThanOrEqualTo(size.width));
        // The first row's picture is on screen.
        final first = tester.getRect(_preview(CourierSkin.standard));
        expect(first.top, greaterThanOrEqualTo(0.0));
        expect(first.bottom, lessThanOrEqualTo(size.height));
      });
    }
  });

  test('the Neon outfit is described the way it is drawn', () {
    // The art has no visor to colour; the magenta is on the shoes.
    expect(CourierSkin.nightShiftNeon.description, isNot(contains('visor')));
    expect(CourierSkin.nightShiftNeon.outfit.shoes, isNotNull);
  });
}
