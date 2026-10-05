/// The order the street is drawn in, back to front.
///
/// - A subway station's wall is behind everything
///   (`SubwayStationComponent.wallPriority`, -1).
/// - Street pieces, hazards and pickups all sit at the default priority of
///   0, where whichever was built later is drawn on top.
/// - The courier, then the sparks and dust, then the game's words.
/// - The weather is in front of all of it (rain 5, the lightning flash 6).
library;

/// The courier is drawn in front of everything on the street.
///
/// At the default priority the courier, built first, was behind every piece
/// built afterwards, which is all of them: passing a flower kiosk, a bus
/// shelter or a food cart, or run down by a van, the courier could not be
/// seen at all.
const int courierPriority = 2;

/// Sparks, dust and confetti are in front of the courier, as they were when
/// both sat at the default priority (they are always built later).
const int particlePriority = 3;

/// The game's words are in front of everything on the street, behind the
/// weather.
///
/// A hint is built when its hazard is, so a crane built after it stood in
/// front of it: HOLD [mast] LEAP!
const int wordsPriority = 4;
