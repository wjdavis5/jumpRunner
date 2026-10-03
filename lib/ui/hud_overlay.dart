import 'package:flutter/material.dart';

import '../game/logic/game_state.dart';

/// Top HUD overlay displaying carried package HP, current distance, and tip earnings.
class HUDOverlay extends StatelessWidget {
  const HUDOverlay({
    super.key,
    required this.gameState,
    this.isMuted = false,
    this.onToggleMute,
  });

  final GameState gameState;
  final bool isMuted;
  final VoidCallback? onToggleMute;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left: Carried Package Lives (3 boxes)
            _buildPackageLives(),

            const Spacer(),

            // Center: Distance & Next Milestone
            _buildDistanceCounter(),

            const Spacer(),

            // Right: Tips Earned & Mute Toggle
            _buildTipsAndMute(),
          ],
        ),
      ),
    );
  }

  Widget _buildPackageLives() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white24, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'PACKAGES: ',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
          for (var i = 0; i < gameState.maxPackages; i++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3.0),
              child: Icon(
                Icons.inventory_2,
                size: 22,
                color: i < gameState.packages
                    ? const Color(0xFFE67E22) // Active orange parcel
                    : Colors.white24, // Lost package silhouette
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDistanceCounter() {
    final distanceInt = gameState.distanceMeters.floor();
    final nextMilestone = ((distanceInt ~/ 500) + 1) * 500;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white24, width: 1.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$distanceInt m',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                'Shift Goal: ${nextMilestone}m',
                style: const TextStyle(
                  color: Color(0xFF85C1E9),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        if (gameState.isEnergyBoostActive) ...[
          const SizedBox(height: 6),
          Container(
            key: const Key('energy_boost_badge'),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF27AE60), Color(0xFFF1C40F)],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFF1C40F).withValues(alpha: 0.6),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.bolt, color: Colors.black, size: 16),
                const SizedBox(width: 4),
                Text(
                  'BOOST ${gameState.energyDrinkTimer.toStringAsFixed(1)}s (2X TIPS & MAGNET)',
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTipsAndMute() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white24, width: 1.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.monetization_on,
                size: 18,
                color: Color(0xFFF1C40F),
              ),
              const SizedBox(width: 4),
              Text(
                '\$${gameState.tips}',
                style: const TextStyle(
                  color: Color(0xFFF1C40F),
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
        if (onToggleMute != null) ...[
          const SizedBox(width: 8),
          IconButton(
            onPressed: onToggleMute,
            icon: Icon(
              isMuted ? Icons.volume_off : Icons.volume_up,
              color: Colors.white70,
            ),
            style: IconButton.styleFrom(
              backgroundColor: Colors.black.withValues(alpha: 0.6),
            ),
          ),
        ],
      ],
    );
  }
}
