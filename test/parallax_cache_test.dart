import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jump_runner/game/components/parallax_city.dart';

const _width = 960;
const _height = 540;

/// The city as drawn right now, as raw RGBA.
Future<ByteData> _frame(ParallaxCityComponent city) async {
  final recorder = ui.PictureRecorder();
  city.render(ui.Canvas(recorder));
  final picture = recorder.endRecording();
  final image = await picture.toImage(_width, _height);
  final bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
  picture.dispose();
  image.dispose();
  return bytes;
}

List<int> _at(ByteData frame, int x, int y) {
  final offset = (y * _width + x) * 4;
  return [frame.getUint8(offset), frame.getUint8(offset + 1), frame.getUint8(offset + 2)];
}

List<int> _rgb(ui.Color c) => [(c.r * 255).round(), (c.g * 255).round(), (c.b * 255).round()];

bool _within(List<int> a, List<int> b, int tolerance) {
  for (var i = 0; i < 3; i++) {
    if ((a[i] - b[i]).abs() > tolerance) return false;
  }
  return true;
}

ParallaxCityComponent _city() => ParallaxCityComponent(size: Vector2(960, 540));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // The skyline and the facades are about two hundred rectangles, the same
  // ones every frame. Drawing them one by one was a third of all the drawing
  // the web build did per frame. One repeat of each layer is now recorded and
  // replayed.
  group('The skyline and facades are recorded, not redrawn', () {
    test('a steady stretch of street records each layer once', () async {
      final city = _city()..updateLighting(300.0);
      for (var frame = 0; frame < 120; frame++) {
        city.update(1 / 60);
        city.updateLighting(300.0 + frame * 0.3, 1 / 60);
        await _frame(city);
      }
      expect(city.sliceRecordings, equals(2));
    });

    test('a slow fade re-records now and then, not every frame', () async {
      final city = _city();
      // Day into dusk: 900 m to 1,600 m, about 35 seconds of running.
      const frames = 2100;
      for (var frame = 0; frame < frames; frame++) {
        city.updateLighting(900.0 + 700.0 * frame / frames, 1 / 60);
        city.update(1 / 60);
        final recorder = ui.PictureRecorder();
        city.render(ui.Canvas(recorder));
        recorder.endRecording().dispose();
      }
      expect(city.sliceRecordings, greaterThan(10), reason: 'the fade has to show');
      expect(city.sliceRecordings, lessThan(frames ~/ 8));
    });

    test('what is on screen is never more than two levels from the true colour', () async {
      final city = _city();
      // Facade 1 spans x = 120..220 and is 119 px tall; (125, 450) is wall,
      // below its last row of windows. No sign hangs on that facade.
      for (var meters = 900.0; meters <= 1600.0; meters += 3.5) {
        city.updateLighting(meters);
        final frame = await _frame(city);
        expect(_within(_at(frame, 125, 450), _rgb(city.currentPalette.building), 3), isTrue,
            reason: 'facade at ${meters.round()} m: ${_at(frame, 125, 450)} vs '
                '${_rgb(city.currentPalette.building)}');
        // The far skyline shows above the facades: building 0 is 140 px tall.
        expect(_within(_at(frame, 30, 330), _rgb(city.currentPalette.skyline), 3), isTrue,
            reason: 'skyline at ${meters.round()} m');
      }
    });

    test('a different street height is a different recording', () async {
      final city = _city()..updateLighting(300.0);
      await _frame(city);
      expect(city.sliceRecordings, equals(2));
      city.size = Vector2(960, 600);
      await _frame(city);
      expect(city.sliceRecordings, equals(4));
    });

    test('removing the city lets go of the recordings and it can draw again', () async {
      final city = _city()..updateLighting(300.0);
      await _frame(city);
      city.onRemove();
      await _frame(city);
      expect(city.sliceRecordings, equals(4));
    });
  });

  // Whether a window was lit used to be computed from its pixel position on
  // screen. The facades scroll at 60 to 165 px a second, so every window in
  // the city blinked off for a frame every 5 px: a shimmer over the whole
  // backdrop.
  group('Lit windows stay lit as the street scrolls', () {
    test('four windows in five are lit, and which ones is fixed', () {
      var lit = 0;
      var total = 0;
      for (var building = 0; building < 8; building++) {
        for (var row = 0; row < 5; row++) {
          for (var column = 0; column < 3; column++) {
            total++;
            if (ParallaxCityComponent.isWindowLit(building, row, column)) lit++;
            expect(ParallaxCityComponent.isWindowLit(building, row, column),
                equals(ParallaxCityComponent.isWindowLit(building, row, column)));
          }
        }
      }
      expect(lit / total, closeTo(0.8, 0.05));
    });

    test('scrolling a pixel at a time never changes a window\'s light', () async {
      final city = _city()..updateLighting(3000.0); // night: lit and unlit differ most
      final litColour = _rgb(city.currentPalette.windowLit);
      final unlitColour = _rgb(city.currentPalette.windowUnlit);
      expect(_within(litColour, unlitColour, 20), isFalse);

      // Facade 1's first window is at x = 132..147, y = 356..371 before any
      // scrolling. Follow its middle as the facades slide left.
      bool? wasLit;
      for (var scrolled = 0; scrolled <= 40; scrolled++) {
        city.midgroundOffset = scrolled.toDouble();
        final frame = await _frame(city);
        final pixel = _at(frame, 139 - scrolled, 363);
        final isLit = _within(pixel, litColour, 4);
        final isUnlit = _within(pixel, unlitColour, 4);
        expect(isLit || isUnlit, isTrue, reason: 'not a window at offset $scrolled: $pixel');
        wasLit ??= isLit;
        expect(isLit, equals(wasLit), reason: 'the window changed after $scrolled px');
      }
    });

    test('the same holds for every window of a facade across a full repeat', () async {
      final city = _city()..updateLighting(3000.0);
      final litColour = _rgb(city.currentPalette.windowLit);
      // Facade 4 (x = 480..580, 146 px tall): rows from y = 329 every 25 px.
      List<bool> lights(ByteData frame, int shift) => [
            for (var row = 0; row < 4; row++)
              for (var column = 0; column < 3; column++)
                _within(_at(frame, 480 + 12 + column * 25 + 7 - shift, 329 + row * 25 + 7), litColour, 4),
          ];
      // A streetlamp stands in front of this facade and its glow tints two
      // of the windows. The lamps are slid along with the facade here, so
      // the same two stay tinted and the rest can be compared.
      city.midgroundOffset = 0;
      city.sidewalkOffset = 0;
      final before = lights(await _frame(city), 0);
      expect(before.where((lit) => lit).length, inInclusiveRange(7, 12));
      for (final shift in [1, 2, 3, 4, 5, 13, 100, 300]) {
        city.midgroundOffset = shift.toDouble();
        city.sidewalkOffset = shift.toDouble();
        expect(lights(await _frame(city), shift), equals(before), reason: 'after $shift px');
      }
    });
  });
}
