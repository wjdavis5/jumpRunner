/// The stretch of street one generated set piece occupies.
class StreetPiece {
  const StreetPiece({
    required this.x,
    required this.width,
    required this.baseY,
    this.remove,
  });

  /// Left edge in world space.
  final double x;

  /// Horizontal extent in pixels.
  final double width;

  /// Y of the piece's bottom edge. A piece whose base sits above the sidewalk
  /// (rooftop, aerial) takes no part in the pass.
  final double baseY;

  /// Drops the piece from its chunk list. Null for anchors, which always stay.
  final void Function()? remove;

  double get end => x + width;
}

/// Keeps street-level set pieces from being drawn on top of each other.
///
/// Every feature in a chunk picks its own spot independently, so a busy chunk
/// used to stack a barricade on a food cart on a mailbox and the street read
/// as noise. This pass keeps the [anchors] (hazards and delivery targets,
/// which gameplay depends on) and removes any optional piece whose footprint
/// comes within [minGap] pixels of an anchor or of an optional piece already
/// kept.
///
/// [optionalByPriority] is visited in order: earlier pieces claim their spot
/// first, later ones are the ones removed when space runs out.
///
/// Draws no random numbers, so seeded generation stays reproducible.
/// Returns the number of pieces removed.
int declutterStreet({
  required double groundY,
  required Iterable<StreetPiece> anchors,
  required Iterable<StreetPiece> optionalByPriority,
  double minGap = 20.0,
}) {
  bool reachesStreet(StreetPiece piece) =>
      piece.baseY >= groundY - _streetTolerance;

  final kept = anchors.where(reachesStreet).toList();

  int removed = 0;
  for (final piece in optionalByPriority.where(reachesStreet)) {
    final crowded = kept.any(
      (other) => piece.x < other.end + minGap && other.x < piece.end + minGap,
    );
    if (crowded) {
      piece.remove?.call();
      removed++;
    } else {
      kept.add(piece);
    }
  }
  return removed;
}

/// How far above the sidewalk a piece's base may sit and still count as
/// standing on the street.
const double _streetTolerance = 6.0;
