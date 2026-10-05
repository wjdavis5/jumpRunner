import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

/// What a PNG's header says about it.
class _Png {
  _Png(this.path) {
    final bytes = File(path).readAsBytesSync();
    // Eight signature bytes, then the IHDR chunk: length, "IHDR", width,
    // height, bit depth, colour type.
    final data = ByteData.sublistView(bytes);
    expect(bytes.sublist(1, 4), equals('PNG'.codeUnits), reason: '$path is not a PNG');
    width = data.getUint32(16);
    height = data.getUint32(20);
    colourType = bytes[25];
    hasTransparencyChunk = latin1.decode(bytes).contains('tRNS');
  }

  final String path;
  late final int width;
  late final int height;
  late final int colourType;
  late final bool hasTransparencyChunk;

  /// Colour types 4 and 6 carry an alpha channel; a tRNS chunk gives the
  /// other types transparent colours.
  bool get hasAlpha => colourType == 4 || colourType == 6 || hasTransparencyChunk;
}

Future<ByteData> _pixels(WidgetTester tester, String path) async {
  final data = await tester.runAsync(() async {
    final codec = await ui.instantiateImageCodec(File(path).readAsBytesSync());
    final frame = await codec.getNextFrame();
    final bytes = await frame.image.toByteData(format: ui.ImageByteFormat.rawStraightRgba);
    frame.image.dispose();
    return bytes;
  });
  return data!;
}

/// The red, green and blue of the pixel at ([x], [y]) in a [size]-wide image.
List<int> _at(ByteData pixels, int size, int x, int y) {
  final offset = (y * size + x) * 4;
  return [pixels.getUint8(offset), pixels.getUint8(offset + 1), pixels.getUint8(offset + 2)];
}

bool _near(List<int> colour, List<int> target, [int tolerance = 12]) {
  for (var i = 0; i < 3; i++) {
    if ((colour[i] - target[i]).abs() > tolerance) return false;
  }
  return true;
}

const _res = 'android/app/src/main/res';
const _iosIcons = 'ios/Runner/Assets.xcassets/AppIcon.appiconset';

// From the courier's jump sprite.
const _skin = [255, 224, 177];
const _shirt = [46, 204, 113];
const _hair = [196, 138, 81];

void main() {
  // Every icon the game ships was the Flutter template's logo: the browser
  // tab, the home-screen install, the Android launcher and the iOS home
  // screen. They are now drawn by tool/generate_icons.py from the courier's
  // own sprite. These tests keep the set complete and correctly shaped; the
  // script is the only thing that should write the files.
  group('Web icons', () {
    test('the manifest lists icons that exist at the size it says', () {
      final manifest =
          jsonDecode(File('web/manifest.json').readAsStringSync()) as Map<String, dynamic>;
      final icons = (manifest['icons'] as List).cast<Map<String, dynamic>>();
      expect(icons, hasLength(4));
      for (final icon in icons) {
        final png = _Png('web/${icon['src']}');
        expect('${png.width}x${png.height}', equals(icon['sizes']), reason: png.path);
      }
    });

    test('maskable icons are full squares; the plain ones have rounded corners', () {
      for (final size in [192, 512]) {
        expect(_Png('web/icons/Icon-maskable-$size.png').hasAlpha, isFalse,
            reason: 'a launcher cuts a maskable icon to shape itself');
        expect(_Png('web/icons/Icon-$size.png').hasAlpha, isTrue);
      }
    });

    test('the tab icon is big enough for a high-density screen', () {
      final favicon = _Png('web/favicon.png');
      expect(favicon.width, equals(favicon.height));
      expect(favicon.width, greaterThanOrEqualTo(32));
    });
  });

  group('Android launcher icons', () {
    const densities = {'mdpi': 1.0, 'hdpi': 1.5, 'xhdpi': 2.0, 'xxhdpi': 3.0, 'xxxhdpi': 4.0};

    test('every density has the 48 dp icon and both 108 dp adaptive layers', () {
      densities.forEach((density, scale) {
        final legacy = _Png('$_res/mipmap-$density/ic_launcher.png');
        expect(legacy.width, equals((48 * scale).round()), reason: legacy.path);
        expect(legacy.height, equals(legacy.width));
        for (final layer in ['background', 'foreground']) {
          final png = _Png('$_res/mipmap-$density/ic_launcher_$layer.png');
          expect(png.width, equals((108 * scale).round()), reason: png.path);
          expect(png.height, equals(png.width));
          // The sky is solid; the courier is cut out on top of it.
          expect(png.hasAlpha, equals(layer == 'foreground'), reason: png.path);
        }
      });
    });

    test('the adaptive icon points at those two layers', () {
      final xml = File('$_res/mipmap-anydpi-v26/ic_launcher.xml').readAsStringSync();
      expect(xml, contains('<adaptive-icon'));
      expect(xml, contains('<background android:drawable="@mipmap/ic_launcher_background"'));
      expect(xml, contains('<foreground android:drawable="@mipmap/ic_launcher_foreground"'));
      final manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
      expect(manifest, contains('android:icon="@mipmap/ic_launcher"'));
    });
  });

  group('iOS icons', () {
    test('every size in the asset catalogue is there, square, with no alpha', () {
      final contents =
          jsonDecode(File('$_iosIcons/Contents.json').readAsStringSync()) as Map<String, dynamic>;
      final entries = (contents['images'] as List).cast<Map<String, dynamic>>();
      expect(entries.length, greaterThanOrEqualTo(15));
      for (final entry in entries) {
        final points = double.parse((entry['size'] as String).split('x').first);
        final scale = int.parse((entry['scale'] as String).replaceAll('x', ''));
        final png = _Png('$_iosIcons/${entry['filename']}');
        expect(png.width, equals((points * scale).round()), reason: png.path);
        expect(png.height, equals(png.width), reason: png.path);
        // App Store Connect refuses an icon with an alpha channel.
        expect(png.hasAlpha, isFalse, reason: png.path);
      }
    });
  });

  group('The icon is the courier, not the Flutter logo', () {
    for (final entry in {
      'web/icons/Icon-512.png': 512,
      'web/icons/Icon-maskable-512.png': 512,
      '$_iosIcons/Icon-App-1024x1024@1x.png': 1024,
      '$_res/mipmap-xxxhdpi/ic_launcher.png': 192,
    }.entries) {
      testWidgets(entry.key, (tester) async {
        final size = entry.value;
        final pixels = await _pixels(tester, entry.key);

        // Dusk sky across the top: dark, and bluer than it is red.
        final sky = _at(pixels, size, size ~/ 2, (size * 0.04).round());
        expect(sky[2], greaterThan(sky[0]), reason: 'top of the icon is $sky');
        expect(sky[0] + sky[1] + sky[2], lessThan(300));

        // Down the middle: the courier's hair, then face, then shirt.
        var hair = 0, skin = 0, shirt = 0;
        for (var y = 0; y < size; y++) {
          for (var x = (size * 0.35).round(); x < (size * 0.65).round(); x++) {
            final colour = _at(pixels, size, x, y);
            if (_near(colour, _hair)) hair++;
            if (_near(colour, _skin)) skin++;
            if (_near(colour, _shirt)) shirt++;
          }
        }
        final middle = size * size * 0.30;
        expect(hair / middle, greaterThan(0.05), reason: 'no hair');
        expect(skin / middle, greaterThan(0.08), reason: 'no face');
        expect(shirt / middle, greaterThan(0.03), reason: 'no shirt');
      });
    }
  });
}
