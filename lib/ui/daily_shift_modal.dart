import 'package:flutter/material.dart';

import '../game/game_font.dart';
import '../game/models/daily_shift.dart';
import '../services/storage_service.dart';
import 'fit_to_screen.dart';
import 'money.dart';

/// Modal dialog presenting the current day's Daily Gig Shift challenge,
/// active gameplay modifiers, distance target, bonus tips reward, and completion status.
class DailyShiftModal extends StatelessWidget {
  const DailyShiftModal({
    super.key,
    required this.storageService,
    required this.onStartDailyShift,
    this.onClose,
    this.customDate,
  });

  final LocalStorageService storageService;
  final ValueChanged<DailyShift> onStartDailyShift;

  /// Dismisses the card. The card is shown as a game overlay, not a route, so
  /// the owner removes it; popping the Navigator here would pop the app's
  /// only screen and leave a blank page.
  final VoidCallback? onClose;
  final DateTime? customDate;

  @override
  Widget build(BuildContext context) {
    final now = customDate ?? DateTime.now().toUtc();
    final shift = DailyShift.forDate(now);
    final isCompleted = storageService.isDailyShiftCompleted(shift.dateString);
    final modifier = shift.modifier;

    return FitToScreen(
      child: Container(
        width: 480,
        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFA1E272C),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: modifier.color, width: 2.0),
          boxShadow: [
            BoxShadow(
              color: modifier.color.withValues(alpha: 0.35),
              blurRadius: 24,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.event_available, color: modifier.color, size: 28),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'DAILY GIG SHIFT',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                            ),
                          ),
                          Text(
                            shift.dateLabel,
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    key: const Key('close_daily_shift_button'),
                    onPressed: onClose,
                    icon: const Icon(Icons.close, color: Colors.white70),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Modifier Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: modifier.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: modifier.color.withValues(alpha: 0.4)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: modifier.color.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(modifier.icon, color: modifier.color, size: 30),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            modifier.title.toUpperCase(),
                            style: TextStyle(
                              color: modifier.color,
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            modifier.description,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Objective & Payout Row
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          const Text(
                            'DISTANCE GOAL',
                            style: TextStyle(color: Colors.white54, fontSize: 10),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${shift.targetDistanceMeters}m',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(width: 1, height: 28, color: Colors.white12),
                    Expanded(
                      child: Column(
                        children: [
                          const Text(
                            'BONUS TIP',
                            style: TextStyle(color: Colors.white54, fontSize: 10),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '+ ${dollars(shift.completionBonusTips)}',
                            style: const TextStyle(
                              color: Color(0xFFF1C40F),
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(width: 1, height: 28, color: Colors.white12),
                    Expanded(
                      child: Column(
                        children: [
                          const Text(
                            'STARS',
                            style: TextStyle(color: Colors.white54, fontSize: 10),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text.rich(
                            withStars(
                              '${storageService.dailyStars} ★',
                              const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                              starColor: const Color(0xFFF1C40F),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),

              // Action button or completed badge
              if (isCompleted) ...[
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF27AE60).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF27AE60), width: 1.5),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle, color: Color(0xFF2ECC71), size: 22),
                      SizedBox(width: 8),
                      Text(
                        'SHIFT COMPLETED TODAY!',
                        style: TextStyle(
                          color: Color(0xFF2ECC71),
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                SizedBox(
                  height: 50,
                  child: ElevatedButton.icon(
                    key: const Key('start_daily_shift_button'),
                    onPressed: () => onStartDailyShift(shift),
                    icon: const Icon(Icons.flash_on, size: 24),
                    label: const Text(
                      'CLOCK IN FOR DAILY SHIFT',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.0,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: modifier.color,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 4,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
