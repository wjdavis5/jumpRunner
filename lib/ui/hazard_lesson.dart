import '../game/components/obstacle_component.dart';

/// What the results card says about the hazard that ended a shift: what it
/// was, and the one thing that gets a courier past it.
///
/// The card used to say "Shift Concluded". A new player who has just lost
/// three packages to vans by tapping at them is told nothing, and the game
/// has nine hazards that want three different answers.
class HazardLesson {
  const HazardLesson(this.what, this.how);

  /// "A van got you."
  final String what;

  /// "Hold the jump to leap it."
  final String how;

  /// Both halves, as the results card shows them.
  String get line => '$what $how';

  static const String _hop = 'A short jump clears it.';
  static const String _leap = 'Hold the jump to leap it.';

  static HazardLesson forType(ObstacleType type) {
    switch (type) {
      case ObstacleType.scooter:
        return const HazardLesson('A scooter got you.', _hop);
      case ObstacleType.dog:
        return const HazardLesson('A dog got you.', _hop);
      case ObstacleType.hydrant:
        return const HazardLesson('A hydrant got you.', _hop);
      case ObstacleType.mailbox:
        return const HazardLesson('A mailbox got you.', _hop);
      case ObstacleType.van:
        return const HazardLesson('A van got you.', _leap);
      case ObstacleType.skateMessenger:
        return const HazardLesson('A skater got you.', 'Jump early: they roll toward you.');
      case ObstacleType.pigeonFlock:
        return const HazardLesson('Pigeons got you.', 'Stay on the ground and run under them.');
      case ObstacleType.thirdRail:
        return const HazardLesson('The third rail got you.', _hop);
      case ObstacleType.subwayTrain:
        return const HazardLesson('The subway train got you.', _leap);
    }
  }
}
