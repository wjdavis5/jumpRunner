import 'package:flutter/material.dart';

/// Modal dialog presented when all carried packages are dropped (Game Over).
class GameOverModal extends StatelessWidget {
  const GameOverModal({
    super.key,
    required this.distance,
    required this.tips,
    required this.isNewRecord,
    required this.careerTips,
    required this.onRestart,
    this.completedContracts = 0,
    this.contractBonusTips = 0,
  });

  final int distance;
  final int tips;
  final bool isNewRecord;
  final int careerTips;
  final int completedContracts;
  final int contractBonusTips;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 440,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        decoration: BoxDecoration(
          color: const Color(0xFF1C2833).withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE74C3C), width: 2),
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
              'PACKAGES DROPPED!',
              style: TextStyle(
                color: Color(0xFFE74C3C),
                fontSize: 24,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Shift Concluded',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),

            if (isNewRecord)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1C40F),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  '★ NEW DISTANCE RECORD! ★',
                  style: TextStyle(
                    color: Color(0xFF1C2833),
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),

            if (completedContracts > 0)
              Container(
                key: const Key('game_over_contracts_badge'),
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF2ECC71).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF2ECC71), width: 1.5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.task_alt, color: Color(0xFF2ECC71), size: 16),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        '$completedContracts CONTRACT${completedContracts > 1 ? 'S' : ''} (+\$$contractBonusTips BONUS)',
                        style: const TextStyle(
                          color: Color(0xFF2ECC71),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          letterSpacing: 0.5,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

            // Stats grid
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildStatItem('Distance', '$distance m', Icons.straighten),
                _buildStatItem('Run Tips', '\$$tips', Icons.monetization_on),
                _buildStatItem('Career Tips', '\$$careerTips', Icons.savings),
              ],
            ),

            const SizedBox(height: 20),

            // Restart Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: onRestart,
                icon: const Icon(Icons.replay, size: 20),
                label: const Text(
                  'START NEXT SHIFT',
                  style: TextStyle(
                    fontSize: 16,
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
