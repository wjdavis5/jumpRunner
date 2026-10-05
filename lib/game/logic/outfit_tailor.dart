import 'dart:typed_data';
import 'dart:ui';

/// Which garments an outfit recolours. A null garment is left as drawn.
class OutfitColors {
  const OutfitColors({this.shirt, this.pants, this.shoes});

  final Color? shirt;
  final Color? pants;
  final Color? shoes;

  /// True when the outfit changes nothing, like the standard uniform.
  bool get isPlain => shirt == null && pants == null && shoes == null;
}

/// The parts of the courier sprite an outfit can dress.
enum Garment { shirt, pants, shoes }

/// Recolours the courier sprite garment by garment.
///
/// The courier art is flat-shaded: the shirt is green, the shorts blue, the
/// shoes the same brown as the hair but always low in the frame. That makes
/// the garments easy to find by colour, so an outfit can change the clothes
/// and leave the face, hair and hands alone. (The first attempt washed one
/// colour over the whole sprite, which turned the courier into a tinted
/// ghost.)
class OutfitTailor {
  /// The shirt's own brightness in the source art. A recoloured shirt keeps
  /// the art's light and dark relative to this.
  static const double _shirtValue = 0.80;
  static const double _pantsValue = 0.86;
  static const double _shoeValue = 0.72;

  /// Shoes are brown pixels below this fraction of the frame height; the
  /// same brown higher up is hair.
  static const double shoeLine = 0.60;

  /// Which garment a pixel of straight (not premultiplied) [r], [g], [b]
  /// belongs to, [yFraction] being its row as a fraction of the frame
  /// height. Null for skin, hair, eyes and outline.
  static Garment? garmentAt(int r, int g, int b, double yFraction) {
    final maxC = r > g ? (r > b ? r : b) : (g > b ? g : b);
    final minC = r < g ? (r < b ? r : b) : (g < b ? g : b);
    if (maxC == 0) return null;
    final delta = maxC - minC;
    final saturation = delta / maxC;
    if (delta == 0) return null;

    double hue;
    if (maxC == r) {
      hue = 60.0 * (((g - b) / delta) % 6);
    } else if (maxC == g) {
      hue = 60.0 * (((b - r) / delta) + 2);
    } else {
      hue = 60.0 * (((r - g) / delta) + 4);
    }
    if (hue < 0) hue += 360.0;

    if (hue >= 110.0 && hue <= 175.0 && saturation >= 0.35) return Garment.shirt;
    if (hue >= 185.0 && hue <= 225.0 && saturation >= 0.40) return Garment.pants;
    if (hue >= 18.0 && hue <= 42.0 && saturation >= 0.45 && yFraction >= shoeLine) {
      return Garment.shoes;
    }
    return null;
  }

  /// Returns a recoloured copy of [premultipliedRgba], a [width] x [height]
  /// image in the layout `Image.toByteData` produces by default.
  static Uint8List dress(
    Uint8List premultipliedRgba,
    int width,
    int height,
    OutfitColors colors,
  ) {
    final out = Uint8List.fromList(premultipliedRgba);
    if (colors.isPlain) return out;

    for (var y = 0; y < height; y++) {
      final yFraction = y / height;
      for (var x = 0; x < width; x++) {
        final i = (y * width + x) * 4;
        final alpha = out[i + 3];
        if (alpha == 0) continue;

        // Classify on the true colour, then write back premultiplied.
        final r = (out[i] * 255 / alpha).round().clamp(0, 255);
        final g = (out[i + 1] * 255 / alpha).round().clamp(0, 255);
        final b = (out[i + 2] * 255 / alpha).round().clamp(0, 255);

        final garment = garmentAt(r, g, b, yFraction);
        if (garment == null) continue;

        final Color? target;
        final double baseValue;
        switch (garment) {
          case Garment.shirt:
            target = colors.shirt;
            baseValue = _shirtValue;
          case Garment.pants:
            target = colors.pants;
            baseValue = _pantsValue;
          case Garment.shoes:
            target = colors.shoes;
            baseValue = _shoeValue;
        }
        if (target == null) continue;

        // Keep the art's shading: a darker fold stays a darker fold.
        final maxC = r > g ? (r > b ? r : b) : (g > b ? g : b);
        final shade = ((maxC / 255.0) / baseValue).clamp(0.55, 1.15);
        final a = alpha / 255.0;
        out[i] = (target.r * 255.0 * shade).clamp(0.0, 255.0) * a ~/ 1;
        out[i + 1] = (target.g * 255.0 * shade).clamp(0.0, 255.0) * a ~/ 1;
        out[i + 2] = (target.b * 255.0 * shade).clamp(0.0, 255.0) * a ~/ 1;
      }
    }
    return out;
  }
}
