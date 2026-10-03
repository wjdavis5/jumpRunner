import 'package:flutter/material.dart';

/// Unique gameplay modifiers that rotate daily.
enum DailyModifier {
  rainyRush(
    title: 'Rainy Rush',
    description: 'Relentless torrential downpour and slick sidewalks. 1.2x courier speed, double tip rewards!',
    icon: Icons.water_drop,
    color: Color(0xFF3498DB),
  ),
  fragileFreight(
    title: 'Fragile Freight',
    description: 'High-value crystal glassware. Only 1 package carrying capacity, but 3x tip earnings!',
    icon: Icons.warning_amber,
    color: Color(0xFFE74C3C),
  ),
  skateCommute(
    title: 'Skate Commute',
    description: 'Heavy oncoming skateboard traffic during peak rush hour. Stunt combo leaps grant 2x bonus tips!',
    icon: Icons.skateboarding,
    color: Color(0xFFF39C12),
  ),
  nightDash(
    title: 'Neon Midnight',
    description: 'Pitch-black city under cyberpunk neon lighting. Cold brew energy drinks last 50% longer!',
    icon: Icons.nightlight_round,
    color: Color(0xFF9B59B6),
  );

  const DailyModifier({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
  });

  final String title;
  final String description;
  final IconData icon;
  final Color color;
}

/// A structured daily gig shift with deterministic parameters tied to the calendar date.
class DailyShift {
  const DailyShift({
    required this.dateString,
    required this.modifier,
    required this.targetDistanceMeters,
    required this.completionBonusTips,
  });

  final String dateString;
  final DailyModifier modifier;
  final int targetDistanceMeters;
  final int completionBonusTips;

  /// Deterministically derives the daily shift parameters for any given [date].
  factory DailyShift.forDate(DateTime date) {
    final year = date.year;
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    final dateString = '$year-$month-$day';

    // Deterministic pseudo-random seed from calendar date
    final seed = (date.year * 372) + (date.month * 31) + date.day;

    final modifierIndex = seed % DailyModifier.values.length;
    final modifier = DailyModifier.values[modifierIndex];

    // Distance targets: 1000m, 1250m, 1500m, or 1750m
    final targetDistance = 1000 + ((seed ~/ 4) % 4) * 250;

    // Bonus tips payout: $100 to $200
    final bonusTips = 100 + ((seed ~/ 2) % 3) * 50;

    return DailyShift(
      dateString: dateString,
      modifier: modifier,
      targetDistanceMeters: targetDistance,
      completionBonusTips: bonusTips,
    );
  }
}
