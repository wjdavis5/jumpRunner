import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Web shell', () {
    final html = File('web/index.html').readAsStringSync();
    final manifest =
        jsonDecode(File('web/manifest.json').readAsStringSync()) as Map<String, dynamic>;

    test('The page is branded as the game, not the Flutter template', () {
      expect(html, contains('<title>Courier Dash</title>'));
      expect(html, isNot(contains('A new Flutter project')));
      expect(html, isNot(contains('jump_runner')));
      expect(manifest['name'], equals('Courier Dash'));
      expect(manifest['short_name'], equals('Courier Dash'));
      expect(manifest['description'], isNot(contains('Flutter project')));
    });

    test('An installed copy opens in landscape, like the game itself', () {
      expect(manifest['orientation'], equals('landscape'));
    });

    test('Something is on screen while the engine loads, and it gets removed', () {
      expect(html, contains('id="loading"'));
      expect(html, contains("'flutter-first-frame'"));
    });

    test('The loading screen shows the app icon, from a file that is shipped', () {
      final image = RegExp(r'<div id="loading"[^>]*>\s*<img src="([^"]+)" alt="" width="(\d+)" height="(\d+)">')
          .firstMatch(html);
      expect(image, isNotNull, reason: 'no icon at the top of the loading screen');
      expect(File('web/${image!.group(1)}').existsSync(), isTrue);
      // A fixed size, so the title does not jump when the image arrives.
      expect(image.group(2), equals(image.group(3)));
    });

    test('Phones held upright are asked to rotate and can decline', () {
      expect(html, contains('id="rotate"'));
      expect(html, contains('(orientation: portrait)'));
      expect(html, contains('id="rotate-dismiss"'));
    });

    test('Phones get a real viewport before the engine has loaded', () {
      // Without it the page is laid out 980 px wide until the engine swaps in
      // its own tag: a tiny loading screen, and no rotate prompt, for the
      // first seconds on a phone.
      final meta = RegExp(r'<meta name="viewport" content="([^"]*)"').firstMatch(html);
      expect(meta, isNotNull);
      expect(meta!.group(1), contains('width=device-width'));
      expect(meta.group(1), contains('initial-scale=1'));
      // It must come before the rotate prompt's width rule can matter.
      expect(html.indexOf('name="viewport"'), lessThan(html.indexOf('<style>')));
    });

    test('Holding a finger down gets the game, not the browser', () {
      expect(html, contains('user-select: none'));
      expect(html, contains('-webkit-touch-callout: none'));
      expect(html, contains('overscroll-behavior: none'));
      final menu = html.substring(html.indexOf("addEventListener('contextmenu'"));
      expect(menu.substring(0, 120), contains('preventDefault()'));
    });

    test('Declining the rotate prompt hands the keyboard back to the game', () {
      // The dismiss button is hidden while it holds focus, which would leave
      // key presses going to the page body instead of the game.
      final handler = html.substring(html.indexOf("getElementById('rotate-dismiss')"));
      expect(handler, contains("querySelector('flutter-view')"));
      expect(handler, contains('view.focus()'));
    });

    test('The Flutter bootstrap and base href placeholders are intact', () {
      expect(html, contains(r'<base href="$FLUTTER_BASE_HREF">'));
      expect(html, contains('<script src="flutter_bootstrap.js" async></script>'));
    });
  });
}
