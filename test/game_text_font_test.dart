import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  // Text with no font family is drawn as solid bars in every picture a test
  // takes (tool/screens.dart), because a test cannot change the default
  // font. That is how the coaching hints went unseen until they were named.
  // The cards and the HUD inherit a named font from the theme; what the
  // game paints on its canvas has to name it itself.
  test('Everything the game paints text with names the game font', () {
    final unnamed = <String>[];
    final files = Directory('lib/game')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'));
    for (final file in files) {
      final source = file.readAsStringSync();
      for (final match in RegExp(r'TextStyle\(').allMatches(source)) {
        // The family is the style's first argument wherever it is set.
        final args = source.substring(match.end, (match.end + 120).clamp(0, source.length));
        if (!args.trimLeft().startsWith('fontFamily: gameFontFamily')) {
          final line = '\n'.allMatches(source.substring(0, match.start)).length + 1;
          unnamed.add('${file.path.replaceAll(r'\', '/')}:$line');
        }
      }
    }
    expect(unnamed, isEmpty, reason: 'TextStyle without fontFamily: gameFontFamily');
  });
}
