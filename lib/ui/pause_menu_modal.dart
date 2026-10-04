import 'package:flutter/material.dart';

import '../game/logic/game_state.dart';

/// Modal dialog presented when a shift run is paused.
class PauseMenuModal extends StatelessWidget {
  const PauseMenuModal({
    super.key,
    required this.gameState,
    required this.onResume,
    required this.onQuit,
    this.isReduceFlash = false,
    this.onToggleReduceFlash,
  });

  final GameState gameState;
  final VoidCallback onResume;
  final VoidCallback onQuit;
  final bool isReduceFlash;
  final ValueChanged<bool>? onToggleReduceFlash;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 420,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        decoration: BoxDecoration(
          color: const Color(0xFF1C2833).withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF3498DB), width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.8),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'SHIFT ON HOLD',
              style: TextStyle(
                color: Color(0xFF3498DB),
                fontSize: 24,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Break Time, Courier',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),

            // Stats grid
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildStatItem(
                  'Distance',
                  '${gameState.distanceMeters.floor()} m',
                  Icons.straighten,
                ),
                _buildStatItem(
                  'Packages',
                  '${gameState.packages} / ${gameState.maxPackages}',
                  Icons.inventory_2,
                ),
                _buildStatItem(
                  'Tips Banked',
                  '\$${gameState.tips}',
                  Icons.monetization_on,
                ),
              ],
            ),

            // Photosensitivity flash reduction toggle
            InkWell(
              key: const Key('reduce_flash_toggle'),
              onTap: () => onToggleReduceFlash?.call(!isReduceFlash),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isReduceFlash ? const Color(0xFF00E5FF) : Colors.white12,
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isReduceFlash ? Icons.flash_off : Icons.flash_on,
                      size: 18,
                      color: isReduceFlash ? const Color(0xFF00E5FF) : Colors.white70,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Reduce Lightning Flash',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Switch(
                      value: isReduceFlash,
                      activeThumbColor: const Color(0xFF00E5FF),
                      onChanged: onToggleReduceFlash,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Resume Button
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton.icon(
                key: const Key('resume_shift_button'),
                onPressed: onResume,
                icon: const Icon(Icons.play_arrow, size: 22),
                label: const Text(
                  'RESUME SHIFT',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF27AE60),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 10),

            // Quit Button
            SizedBox(
              width: double.infinity,
              height: 42,
              child: OutlinedButton.icon(
                key: const Key('quit_to_depot_button'),
                onPressed: onQuit,
                icon: const Icon(Icons.storefront, size: 18, color: Colors.white70),
                label: const Text(
                  'RETURN TO DEPOT',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white24, width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),
            const Text(
              'Press [P] or [Esc] to resume',
              style: TextStyle(
                color: Colors.white38,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white54, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}
