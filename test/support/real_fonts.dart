import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// The Flutter SDK's own copies of Roboto and the Material icons.
Directory _sdkFonts() {
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root != null) return Directory('$root/bin/cache/artifacts/material_fonts');
  // flutter_tester lives in bin/cache/artifacts/engine/<platform>/.
  return Directory('${File(Platform.resolvedExecutable).parent.parent.parent.path}/material_fonts');
}

/// Gives a test the fonts a phone draws the app with.
///
/// A test draws every letter as a square one em wide (the Ahem font), so a
/// label is far wider than on a phone and nothing about whether text fits
/// can be learned from it. With Roboto loaded the app's text measures and
/// draws as it does on Android: the cards and the HUD, and what the game
/// paints on its own canvas, which names the font for this reason
/// (`gameFontFamily`). A test cannot change the font used for text that
/// names none.
///
/// Call from `setUpAll`: loading a font needs real time, which the body of
/// a `testWidgets` does not have.
Future<void> loadRealFonts() async {
  final dir = _sdkFonts();
  ByteData bytes(String name) => ByteData.view(Uint8List.fromList(File('${dir.path}/$name').readAsBytesSync()).buffer);
  final roboto = FontLoader('Roboto');
  for (final weight in const ['regular', 'medium', 'bold', 'black', 'light', 'italic', 'bolditalic']) {
    roboto.addFont(Future.value(bytes('roboto-$weight.ttf')));
  }
  await roboto.load();
  final icons = FontLoader('MaterialIcons')..addFont(Future.value(bytes('materialicons-regular.otf')));
  await icons.load();
}

String _plain(RenderParagraph paragraph) => paragraph.text.toPlainText().replaceAll('\n', ' / ');

TextPainter _painterFor(RenderParagraph p) => TextPainter(
      text: p.text,
      textDirection: p.textDirection,
      textAlign: p.textAlign,
      textScaler: p.textScaler,
      strutStyle: p.strutStyle,
      locale: p.locale,
      textWidthBasis: p.textWidthBasis,
      textHeightBehavior: p.textHeightBehavior,
    );

/// Every piece of text on the screen that is shown with part of it missing:
/// ended with an ellipsis, cut at a line limit, or clipped at its box.
///
/// Only means something after [loadRealFonts].
List<String> cutOffText(WidgetTester tester) {
  final cut = <String>[];
  for (final element in find.byType(RichText).evaluate()) {
    final paragraph = element.renderObject! as RenderParagraph;
    if (!paragraph.attached || !paragraph.hasSize || paragraph.size.isEmpty) continue;
    // All of it, wrapped to the width it was given: taller than what is
    // shown means some of it is not shown.
    final whole = _painterFor(paragraph)..layout(maxWidth: paragraph.size.width + 1.0);
    if (whole.height > paragraph.size.height + 1.0) cut.add(_plain(paragraph));
    whole.dispose();
  }
  return cut;
}

/// Every button label on the screen that has wrapped onto a second line.
/// A button is one line tall, so the rest of the label is clipped.
List<String> wrappedButtonLabels(WidgetTester tester) {
  final wrapped = <String>[];
  final labels = find.descendant(
    of: find.bySubtype<ButtonStyleButton>(),
    matching: find.byType(RichText),
  );
  for (final element in labels.evaluate()) {
    final paragraph = element.renderObject! as RenderParagraph;
    if (!paragraph.attached || !paragraph.hasSize || paragraph.size.isEmpty) continue;
    final oneLine = _painterFor(paragraph)..layout();
    if (paragraph.size.height > oneLine.height + 1.0) wrapped.add(_plain(paragraph));
    oneLine.dispose();
  }
  return wrapped;
}
