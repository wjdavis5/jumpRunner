import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Returns the `<string>` value that follows `<key>[key]</key>` in a plist.
String? _plistString(String plist, String key) {
  final match = RegExp('<key>$key</key>\\s*<string>([^<]*)</string>').firstMatch(plist);
  return match?.group(1);
}

/// Returns the `<string>` entries of the array that follows `<key>[key]</key>`.
List<String> _plistArray(String plist, String key) {
  final match = RegExp('<key>$key</key>\\s*<array>(.*?)</array>', dotAll: true).firstMatch(plist);
  if (match == null) return const [];
  return RegExp('<string>([^<]*)</string>')
      .allMatches(match.group(1)!)
      .map((m) => m.group(1)!)
      .toList();
}

void main() {
  group('Installed app identity', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    final plist = File('ios/Runner/Info.plist').readAsStringSync();

    test('Android shows the game name under its icon, not the package name', () {
      expect(manifest, contains('android:label="Courier Dash"'));
    });

    test('iOS shows the game name under its icon', () {
      expect(_plistString(plist, 'CFBundleDisplayName'), equals('Courier Dash'));
      expect(_plistString(plist, 'CFBundleName'), equals('Courier Dash'));
    });
  });

  group('Launch orientation', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    final plist = File('ios/Runner/Info.plist').readAsStringSync();

    // The Dart side locks to landscape once it is running. Declaring it
    // natively as well stops the app opening upright and then spinning round.
    test('Android activity is declared landscape', () {
      expect(manifest, contains('android:screenOrientation="sensorLandscape"'));
    });

    test('iPhone supports only the two landscape orientations', () {
      expect(
        _plistArray(plist, 'UISupportedInterfaceOrientations'),
        unorderedEquals([
          'UIInterfaceOrientationLandscapeLeft',
          'UIInterfaceOrientationLandscapeRight',
        ]),
      );
    });

    test('iPad keeps every orientation, as App Store multitasking rules require', () {
      expect(_plistArray(plist, 'UISupportedInterfaceOrientations~ipad'), hasLength(4));
    });
  });

  group('Launch screen', () {
    // The game is dark; a white native launch screen flashes before it.
    test('Android starts on the dark launch colour in every theme', () {
      const res = 'android/app/src/main/res';
      expect(
        File('$res/values/colors.xml').readAsStringSync(),
        contains('<color name="launch_background">#10151C</color>'),
      );
      for (final drawable in const ['drawable', 'drawable-v21']) {
        final xml = File('$res/$drawable/launch_background.xml').readAsStringSync();
        expect(xml, contains('@color/launch_background'), reason: drawable);
        expect(xml, isNot(contains('color/white')), reason: drawable);
      }
      for (final values in const ['values', 'values-night']) {
        final xml = File('$res/$values/styles.xml').readAsStringSync();
        expect(xml, isNot(contains('?android:colorBackground')), reason: values);
      }
    });

    test('iOS launch screen is not white', () {
      final storyboard = File('ios/Runner/Base.lproj/LaunchScreen.storyboard').readAsStringSync();
      expect(storyboard, isNot(contains('key="backgroundColor" red="1" green="1" blue="1"')));
    });
  });
}
