import 'package:flutter/material.dart';

/// Categories of career shift achievements.
enum AchievementCategory {
  distance,
  stunts,
  contracts,
  economy,
  special,
}

/// A vanity career shift achievement or trophy in Courier Dash.
class Achievement {
  const Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.icon,
    this.badgeColor = const Color(0xFFF1C40F),
  });

  final String id;
  final String title;
  final String description;
  final AchievementCategory category;
  final IconData icon;
  final Color badgeColor;

  /// Official catalog of career shift trophies.
  static const List<Achievement> catalog = [
    Achievement(
      id: 'first_delivery',
      title: 'First Delivery',
      description: 'Complete a 500m shift delivery milestone.',
      category: AchievementCategory.distance,
      icon: Icons.directions_bike_rounded,
      badgeColor: Color(0xFF2ECC71),
    ),
    Achievement(
      id: 'shift_veteran',
      title: 'Shift Veteran',
      description: 'Reach 2,500m into the Midnight City skyline.',
      category: AchievementCategory.distance,
      icon: Icons.nights_stay_rounded,
      badgeColor: Color(0xFF9B59B6),
    ),
    Achievement(
      id: 'master_acrobat',
      title: 'Master Acrobat',
      description: 'Achieve a 4x stunt combo streak in a single shift.',
      category: AchievementCategory.stunts,
      icon: Icons.bolt_rounded,
      badgeColor: Color(0xFF00E5FF),
    ),
    Achievement(
      id: 'contract_specialist',
      title: 'Contract Specialist',
      description: 'Fulfill 10 career shift delivery contracts.',
      category: AchievementCategory.contracts,
      icon: Icons.assignment_turned_in_rounded,
      badgeColor: Color(0xFFE67E22),
    ),
    Achievement(
      id: 'big_tipper',
      title: 'Big Tipper',
      description: 'Accumulate \$25,000 in lifetime career tips.',
      category: AchievementCategory.economy,
      icon: Icons.monetization_on_rounded,
      badgeColor: Color(0xFFF1C40F),
    ),
    Achievement(
      id: 'rain_rider',
      title: 'Rain Rider',
      description: 'Clear 5 street hazards during torrential storm weather.',
      category: AchievementCategory.special,
      icon: Icons.water_drop_rounded,
      badgeColor: Color(0xFF3498DB),
    ),
    // Four more, each on something the game already counted: the step
    // between the 500 m and 2,500 m trophies, the subway, doorstep
    // deliveries and the daily goal.
    Achievement(
      id: 'long_haul',
      title: 'Long Haul',
      description: 'Reach 1,000m in a single shift.',
      category: AchievementCategory.distance,
      icon: Icons.route_rounded,
      badgeColor: Color(0xFF1ABC9C),
    ),
    Achievement(
      id: 'straphanger',
      title: 'Straphanger',
      description: 'Take a shortcut through a subway station.',
      category: AchievementCategory.special,
      icon: Icons.subway_rounded,
      badgeColor: Color(0xFF2980B9),
    ),
    Achievement(
      id: 'door_to_door',
      title: 'Door to Door',
      description: 'Make 25 doorstep deliveries over your career.',
      category: AchievementCategory.contracts,
      icon: Icons.home_rounded,
      badgeColor: Color(0xFFE74C3C),
    ),
    Achievement(
      id: 'daily_regular',
      title: 'Regular',
      description: 'Complete 5 daily shift goals.',
      category: AchievementCategory.special,
      icon: Icons.event_available_rounded,
      badgeColor: Color(0xFFAF7AC5),
    ),
  ];

  /// Finds an achievement definition by its unique identifier.
  static Achievement? findById(String id) {
    try {
      return catalog.firstWhere((a) => a.id == id);
    } catch (_) {
      return null;
    }
  }
}
