import 'package:flutter/material.dart';

import '../logic/outfit_tailor.dart';

/// Specification of an unlockable cosmetic courier outfit.
///
/// Prices are set against what shifts actually pay. Measured over autoplayed
/// shifts, tips come in at roughly $5,000-$6,000 per 1,000 m; a random
/// button-masher's median shift ends near 190 m with about $400, and a
/// decent 500-800 m shift pays $2,500-$4,500. At the original prices ($150,
/// $300, $500) every outfit was affordable after the first shift or two,
/// which left tips with nothing to buy.
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
    this.outfit = const OutfitColors(),
  });

  final String id;
  final String name;
  final String description;
  final int price;
  final Color primaryColor;
  final Color accentColor;
  final Color glowColor;
  final bool hasSpeedTrail;

  /// The garments this outfit recolours on the courier sprite.
  final OutfitColors outfit;

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
    description: 'Luminous cyan reflective jacket with electric magenta kicks.',
    // A few ordinary shifts.
    price: 2000,
    primaryColor: Color(0xFF00E5FF),
    accentColor: Color(0xFFD500F9),
    glowColor: Color(0xFF00E5FF),
    hasSpeedTrail: false,
    // The cyan jacket, with the magenta picked up on the shoes.
    outfit: OutfitColors(shirt: Color(0xFF00E5FF), shoes: Color(0xFFD500F9)),
  );

  /// High-top sneakers with trailing speed spark VFX.
  static const CourierSkin highTops = CourierSkin(
    id: 'high_tops',
    name: 'High-Top Kicks',
    description: 'Aerodynamic crimson running shoes with trailing speed spark VFX.',
    // A session or two of decent shifts.
    price: 6000,
    primaryColor: Color(0xFFE74C3C),
    accentColor: Color(0xFFF1C40F),
    glowColor: Color(0xFFFF5252),
    hasSpeedTrail: true,
    // It is all about the shoes.
    outfit: OutfitColors(shoes: Color(0xFFE74C3C)),
  );

  /// Prestigious 24-karat gold courier suit for veteran messengers.
  static const CourierSkin goldenCourier = CourierSkin(
    id: 'golden_courier',
    name: 'Golden Courier',
    description: 'Prestigious 24k shimmering gold jumpsuit for elite rush-hour veterans.',
    // The long-term goal: one great shift, or many good ones.
    price: 15000,
    primaryColor: Color(0xFFFFD700),
    accentColor: Color(0xFFFFF9C4),
    glowColor: Color(0xFFFFD700),
    hasSpeedTrail: true,
    // A gold jumpsuit: top and bottom, with pale gold shoes.
    outfit: OutfitColors(
      shirt: Color(0xFFFFD700),
      pants: Color(0xFFD4A017),
      shoes: Color(0xFFFFF9C4),
    ),
  );

  /// Complete list of unlockable vanity courier outfits.
  static const List<CourierSkin> catalog = [
    standard,
    nightShiftNeon,
    highTops,
    goldenCourier,
  ];

  /// The cheapest outfit not yet in [unlockedIds]: what a courier is saving
  /// for. Null once the Locker is complete.
  static CourierSkin? nextToUnlock(Iterable<String> unlockedIds) {
    final owned = unlockedIds.toSet();
    CourierSkin? next;
    for (final skin in catalog) {
      // The free uniform is nobody's goal, even on a save that lacks it.
      if (skin.price <= 0 || owned.contains(skin.id)) continue;
      if (next == null || skin.price < next.price) next = skin;
    }
    return next;
  }

  /// Finds a skin by its unique identifier, returning [standard] as fallback.
  static CourierSkin findById(String id) {
    for (final skin in catalog) {
      if (skin.id == id) return skin;
    }
    return standard;
  }
}
