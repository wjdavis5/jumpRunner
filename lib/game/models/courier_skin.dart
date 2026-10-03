import 'package:flutter/material.dart';

/// Specification of an unlockable cosmetic courier outfit.
class CourierSkin {
  const CourierSkin({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.primaryColor,
    required this.accentColor,
    required this.glowColor,
    this.hasSpeedTrail = false,
  });

  final String id;
  final String name;
  final String description;
  final int price;
  final Color primaryColor;
  final Color accentColor;
  final Color glowColor;
  final bool hasSpeedTrail;

  /// Default courier starter uniform.
  static const CourierSkin standard = CourierSkin(
    id: 'standard',
    name: 'Standard Courier',
    description: 'Classic urban messenger hoodie and durable canvas delivery backpack.',
    price: 0,
    primaryColor: Color(0xFF2980B9),
    accentColor: Color(0xFFE67E22),
    glowColor: Colors.transparent,
    hasSpeedTrail: false,
  );

  /// Luminous neon cyberpunk delivery skin.
  static const CourierSkin nightShiftNeon = CourierSkin(
    id: 'night_shift_neon',
    name: 'Night Shift Neon',
    description: 'Luminous cyan reflective jacket with electric magenta visor.',
    price: 150,
    primaryColor: Color(0xFF00E5FF),
    accentColor: Color(0xFFD500F9),
    glowColor: Color(0xFF00E5FF),
    hasSpeedTrail: false,
  );

  /// High-top sneakers with trailing speed spark VFX.
  static const CourierSkin highTops = CourierSkin(
    id: 'high_tops',
    name: 'High-Top Kicks',
    description: 'Aerodynamic crimson running shoes with trailing speed spark VFX.',
    price: 300,
    primaryColor: Color(0xFFE74C3C),
    accentColor: Color(0xFFF1C40F),
    glowColor: Color(0xFFFF5252),
    hasSpeedTrail: true,
  );

  /// Prestigious 24-karat gold courier suit for veteran messengers.
  static const CourierSkin goldenCourier = CourierSkin(
    id: 'golden_courier',
    name: 'Golden Courier',
    description: 'Prestigious 24k shimmering gold jumpsuit for elite rush-hour veterans.',
    price: 500,
    primaryColor: Color(0xFFFFD700),
    accentColor: Color(0xFFFFF9C4),
    glowColor: Color(0xFFFFD700),
    hasSpeedTrail: true,
  );

  /// Complete list of unlockable vanity courier outfits.
  static const List<CourierSkin> catalog = [
    standard,
    nightShiftNeon,
    highTops,
    goldenCourier,
  ];

  /// Finds a skin by its unique identifier, returning [standard] as fallback.
  static CourierSkin findById(String id) {
    for (final skin in catalog) {
      if (skin.id == id) return skin;
    }
    return standard;
  }
}
