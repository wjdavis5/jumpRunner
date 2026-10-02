import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jump_runner/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Landscape Orientation Lock', () {
    late List<MethodCall> platformCalls;

    setUp(() {
      platformCalls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
        platformCalls.add(call);
        return null;
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    test('requests exactly the landscape orientations', () async {
      await lockOrientation();

      final call = platformCalls.singleWhere(
        (c) => c.method == 'SystemChrome.setPreferredOrientations',
      );

      expect(call.arguments, <String>[
        'DeviceOrientation.landscapeLeft',
        'DeviceOrientation.landscapeRight',
      ]);
    });

    test('requests no portrait orientation', () async {
      await lockOrientation();

      final call = platformCalls.singleWhere(
        (c) => c.method == 'SystemChrome.setPreferredOrientations',
      );

      expect(
        (call.arguments as List).where((o) => '$o'.contains('portrait')),
        isEmpty,
      );
    });

    test('supportedOrientations contains exactly landscape entries', () {
      expect(
        supportedOrientations,
        containsAll(<DeviceOrientation>[
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]),
      );
      expect(
        supportedOrientations.where(
          (o) =>
              o == DeviceOrientation.portraitUp ||
              o == DeviceOrientation.portraitDown,
        ),
        isEmpty,
      );
    });
  });
}
