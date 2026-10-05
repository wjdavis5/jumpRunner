import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jump_runner/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Found on an Android 15 emulator, where no browser could show it: the
  // status bar's clock and icons were drawn across the top of the game and
  // the three-button navigation bar covered its right-hand edge.
  group('The game has the whole screen', () {
    test('hideSystemBars asks for sticky immersive mode', () async {
      final asked = <MethodCall>[];
      final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        asked.add(call);
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(SystemChannels.platform, null));

      await hideSystemBars();

      final modes = asked.where((c) => c.method == 'SystemChrome.setEnabledSystemUIMode').toList();
      expect(modes, hasLength(1));
      expect(modes.single.arguments, equals('SystemUiMode.immersiveSticky'));
    });

    test('the app does it before the first frame, with the orientation lock', () {
      final source = File('lib/main.dart').readAsStringSync();
      final entry = source.substring(source.indexOf('void main() async {'));
      final lock = entry.indexOf('await lockOrientation();');
      final hide = entry.indexOf('await hideSystemBars();');
      final run = entry.indexOf('runApp(');
      expect(lock, greaterThan(0));
      expect(hide, greaterThan(lock));
      expect(run, greaterThan(hide));
    });
  });
}
