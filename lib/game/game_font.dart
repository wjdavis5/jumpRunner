import 'package:flutter/material.dart';

/// The font the game paints its own text in: hints, signs, floating scores.
///
/// It is named, not left to the platform's default, so that the game can be
/// looked at without a phone: a test can load a font by name but cannot
/// change the default, and text with no family comes out of every picture a
/// test takes as solid bars. `flutter test tool/screens.dart` takes those
/// pictures.
///
/// It is the font the cards and the HUD name too, and the app carries it
/// (`assets/fonts/`), so every platform draws the same letters.
const String gameFontFamily = 'Roboto';

/// Where the game's words are drawn: in front of everything on the street,
/// behind the weather.
///
/// Street pieces all sit at the default priority of 0, where whichever was
/// built later is drawn on top. A hint is built when its hazard is, so a
/// crane built after it stood in front of it: HOLD [mast] LEAP!
const int wordsPriority = 4;

/// The character a string uses for a star.
const String starCharacter = '\u2605';

/// [text] in [style], with each star drawn from the Material icon font.
///
/// Roboto has no star. Left as text, a star is filled in from whatever
/// other font the device has, and the web build has none: it fetched one
/// from a font server the first time a star came up, showing an empty box
/// until it arrived. The icon font is carried in the app.
///
/// [starColor] paints the stars a colour of their own.
TextSpan withStars(String text, TextStyle style, {Color? starColor}) {
  if (!text.contains(starCharacter)) return TextSpan(text: text, style: style);
  const icon = Icons.star_rounded;
  final starStyle = style.copyWith(
    fontFamily: icon.fontFamily,
    package: icon.fontPackage,
    fontWeight: FontWeight.normal,
    letterSpacing: 0.0,
    color: starColor,
  );
  final glyph = String.fromCharCode(icon.codePoint);
  final parts = text.split(starCharacter);
  final spans = <InlineSpan>[];
  for (var i = 0; i < parts.length; i++) {
    if (parts[i].isNotEmpty) spans.add(TextSpan(text: parts[i]));
    if (i < parts.length - 1) spans.add(TextSpan(text: glyph, style: starStyle));
  }
  return TextSpan(style: style, children: spans);
}
