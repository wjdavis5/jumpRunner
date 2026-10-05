import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jump_runner/game/game_font.dart';

/// The code of every Dart file under lib/, comments left out.
Map<String, String> _code() {
  final code = <String, String>{};
  final files = Directory('lib').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));
  for (final file in files) {
    final lines = file.readAsLinesSync().where((line) => !line.trimLeft().startsWith('//'));
    code[file.path.replaceAll(r'\', '/')] = lines.join('\n');
  }
  return code;
}

void main() {
  // The web build fetched a font from a font server the first time a
  // character came up that Roboto does not have, and showed an empty box
  // until it arrived (for good, with no network). The star was the only
  // one: on the Daily button, the station signs, the delivery ratings, the
  // record banner.
  const style = TextStyle(fontFamily: gameFontFamily, fontSize: 15, color: Colors.white);

  test('Text without a star is left as it is', () {
    final span = withStars('3x STREAK +\$120', style);
    expect(span.text, equals('3x STREAK +\$120'));
    expect(span.children, isNull);
    expect(span.style, equals(style));
  });

  test('Each star is drawn from the icon font, and the words around it are not', () {
    final span = withStars('$starCharacter$starCharacter 3x STREAK $starCharacter', style);
    final parts = span.children!.cast<TextSpan>();
    expect(parts, hasLength(4));

    final icon = String.fromCharCode(Icons.star_rounded.codePoint);
    for (final i in const [0, 1, 3]) {
      expect(parts[i].text, equals(icon));
      expect(parts[i].style!.fontFamily, equals('MaterialIcons'));
    }
    expect(parts[2].text, equals(' 3x STREAK '));
    expect(parts[2].style, isNull, reason: 'the words keep the style of the whole');
    expect(span.toPlainText(), isNot(contains(starCharacter)));
  });

  test('The stars can be given a colour of their own', () {
    const gold = Color(0xFFF1C40F);
    final span = withStars('14 $starCharacter', style, starColor: gold);
    final parts = span.children!.cast<TextSpan>();
    expect(parts.last.style!.color, equals(gold));
    expect(span.style!.color, equals(Colors.white));
  });

  test('The app writes nothing the font lacks, except the star', () {
    // The bullet is in Roboto. Anything else new has to be checked against
    // the font before it is added here.
    const allowed = {'•', starCharacter};
    final strangers = <String>[];
    _code().forEach((path, code) {
      for (final rune in code.runes) {
        final char = String.fromCharCode(rune);
        if (rune > 0x7E && !allowed.contains(char)) {
          strangers.add('$path: "$char" (U+${rune.toRadixString(16).toUpperCase()})');
        }
      }
    });
    expect(strangers, isEmpty);
  });

  test('Every star the app writes goes through withStars', () {
    // The floating scores and the speech bubbles put any text they are
    // given through it, so the strings handed to them may hold stars.
    const drawnByTheirComponent = {'lib/game/courier_game.dart', 'lib/game/audio_controller.dart'};
    final bare = <String>[];
    _code().forEach((path, code) {
      if (drawnByTheirComponent.contains(path) || path == 'lib/game/game_font.dart') return;
      for (final match in starCharacter.allMatches(code)) {
        final before = code.substring((match.start - 400).clamp(0, match.start), match.start);
        if (!before.contains('withStars(')) {
          bare.add('$path:${'\n'.allMatches(code.substring(0, match.start)).length + 1}');
        }
      }
    });
    expect(bare, isEmpty, reason: 'a star written as plain text');
  });
}
