/// The font the game paints its own text in: hints, signs, floating scores.
///
/// It is named, not left to the platform's default, so that the game can be
/// looked at without a phone: a test can load a font by name but cannot
/// change the default, and text with no family comes out of every picture a
/// test takes as solid bars. `flutter test tool/screens.dart` takes those
/// pictures.
///
/// It is the font this text was already drawn in: the default on stock
/// Android and in the web build, and the one the cards and the HUD name.
/// Where it is not installed (iOS) the name is not found and the platform's
/// default is used, as it was before.
const String gameFontFamily = 'Roboto';
