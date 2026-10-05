import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// Gives a test the fonts the app is drawn with.
///
/// A test draws every letter as a square one em wide (the Ahem font), so a
/// label is far wider than on a phone and nothing about whether text fits
/// can be learned from it. This loads the app's own Roboto and the Material
/// icons, after which text measures and draws as it does on a device: the
/// cards and the HUD, and what the game paints on its own canvas, which
/// names the font for this reason (`gameFontFamily`). A test cannot change
/// the font used for text that names none.
///
/// Call from `setUpAll`: loading a font needs real time, which the body of
/// a `testWidgets` does not have.
Future<void> loadRealFonts() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final roboto = FontLoader('Roboto');
  for (final weight in const ['Regular', 'Medium', 'Bold', 'Black']) {
    roboto.addFont(rootBundle.load('assets/fonts/Roboto-$weight.ttf'));
  }
  await roboto.load();
  final icons = FontLoader('MaterialIcons')..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
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
