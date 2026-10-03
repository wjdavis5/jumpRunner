import 'package:flutter/material.dart';

/// Single-run consumable supplies purchasable at the Corner Bodega.
enum RunBooster {
  espresso(
    id: 'espresso',
    name: 'Cold Brew Double-Shot',
    cost: 150,
    description: 'Start the shift energized with 8s speed boost & coin magnet.',
    icon: Icons.local_cafe,
    color: Color(0xFFF39C12),
  ),
  satchel(
    id: 'satchel',
    name: 'Reinforced Satchel',
    cost: 250,
    description: 'Reinforced cargo padding grants 4 packages capacity instead of 3.',
    icon: Icons.inventory_2,
    color: Color(0xFF27AE60),
  ),
  droneBeacon(
    id: 'drone_beacon',
    name: 'Express Drone Beacon',
    cost: 350,
    description: 'Immediately launches the Companion Delivery Drone for automated pickup retrieval.',
    icon: Icons.flight_takeoff,
    color: Color(0xFF00E5FF),
  );

  const RunBooster({
    required this.id,
    required this.name,
    required this.cost,
    required this.description,
    required this.icon,
    required this.color,
  });

  final String id;
  final String name;
  final int cost;
  final String description;
  final IconData icon;
  final Color color;

  /// Maximum number of this booster a player can stock in their inventory.
  static const int maxInventory = 5;

  /// Finds a booster by its identifier, or returns null if not found.
  static RunBooster? findById(String id) {
    for (final booster in RunBooster.values) {
      if (booster.id == id) {
        return booster;
      }
    }
    return null;
  }
}
