import 'package:flutter/material.dart';

import '../game/logic/input_hints.dart';
import '../game/models/courier_skin.dart';
import '../game/models/run_booster.dart';
import 'fit_to_screen.dart';
import 'key_hint.dart';
import 'money.dart';

/// Title screen welcoming players with career statistics, instructions, and launch button.
class TitleScreen extends StatelessWidget {
  const TitleScreen({
    super.key,
    required this.highDistance,
    required this.careerTips,
    required this.onStartGame,
    this.isMuted = false,
    this.onToggleMute,
    this.onOpenLocker,
    this.onOpenBodega,
    this.onOpenAchievements,
    this.onOpenDailyShift,
    this.unlockedAchievementsCount = 0,
    this.totalAchievementsCount = 6,
    this.dailyStars = 0,
    this.equippedBoosters = const {},
    this.nextOutfit,
  });

  final int highDistance;
  final int careerTips;
  final VoidCallback onStartGame;
  final bool isMuted;
  final VoidCallback? onToggleMute;
  final VoidCallback? onOpenLocker;
  final VoidCallback? onOpenBodega;
  final VoidCallback? onOpenAchievements;
  final VoidCallback? onOpenDailyShift;
  final int unlockedAchievementsCount;
  final int totalAchievementsCount;
  final int dailyStars;
  final Set<RunBooster> equippedBoosters;

  /// The outfit the courier is saving for, if any is left to buy. Shown
  /// beside the tips so they visibly lead somewhere.
  final CourierSkin? nextOutfit;

  /// The one-line control guide, in the words of the input the device has.
  static String controlGuide({required bool keyboard}) => keyboard
      ? 'Space or Click = Hop (Scooters, Dogs)  •  Hold = Leap (Vans)  •  P = Pause\n'
          'Press again in the air = Glide'
      : 'Short Tap = Hop (Scooters, Dogs)  •  Hold = Leap (Vans)\n'
          'Tap again in the air = Glide';

  @override
  Widget build(BuildContext context) {
    return FitToScreen(
      child: Container(
        width: 640,
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 22),
        decoration: BoxDecoration(
          color: const Color(0xFF1C2833).withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFF2980B9), width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.8),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Title & Badge
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.local_shipping,
                  color: Color(0xFFE67E22),
                  size: 32,
                ),
                const SizedBox(width: 12),
                const Text(
                  'COURIER DASH',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2.0,
                  ),
                ),
                if (onToggleMute != null) ...[
                  const Spacer(),
                  IconButton(
                    onPressed: onToggleMute,
                    icon: Icon(
                      isMuted ? Icons.volume_off : Icons.volume_up,
                      color: Colors.white70,
                    ),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white10,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Urban Parcel Delivery Sprint',
              style: TextStyle(
                color: Color(0xFF85C1E9),
                fontSize: 15,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 20),

            // Career statistics
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      const Text(
                        'PERSONAL BEST',
                        style: TextStyle(color: Colors.white54, fontSize: 11),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        meters(highDistance),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Container(width: 1, height: 32, color: Colors.white24),
                  Column(
                    children: [
                      const Text(
                        'CAREER TIPS',
                        style: TextStyle(color: Colors.white54, fontSize: 11),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        dollars(careerTips),
                        style: const TextStyle(
                          color: Color(0xFFF1C40F),
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  if (nextOutfit != null) ...[
                    Container(width: 1, height: 32, color: Colors.white24),
                    // Tapping the goal opens the Locker it points at.
                    InkWell(
                      key: const Key('next_outfit_goal'),
                      onTap: onOpenLocker,
                      borderRadius: BorderRadius.circular(8),
                      child: Column(
                        children: [
                          Text(
                            'NEXT: ${nextOutfit!.name.toUpperCase()}',
                            style: const TextStyle(color: Colors.white54, fontSize: 11),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            outfitGoalText(nextOutfit!, careerTips),
                            key: const Key('next_outfit_goal_text'),
                            style: TextStyle(
                              color: careerTips >= nextOutfit!.price
                                  ? const Color(0xFF2ECC71)
                                  : Colors.white,
                              fontSize: careerTips >= nextOutfit!.price ? 15 : 20,
                              height: careerTips >= nextOutfit!.price ? 1.6 : null,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 18),

            // Control Guide
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                controlGuide(keyboard: expectsKeyboard),
                key: const Key('control_guide'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Equipped Loadout Preview if any boosters active
            if (equippedBoosters.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white12),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'LOADOUT: ',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      ...equippedBoosters.map(
                        (b) => Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(b.icon, color: b.color, size: 13),
                              const SizedBox(width: 3),
                              Text(
                                b.name,
                                style: TextStyle(
                                  color: b.color,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Primary Launch Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: onStartGame,
                icon: const Icon(Icons.play_arrow, size: 28),
                label: const KeyHintLabel(
                  label: 'START SHIFT',
                  keyLabel: 'SPACE',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.0,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF27AE60),
                  foregroundColor: Colors.white,
                  elevation: 6,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Secondary Navigation Buttons
            Row(
              children: [
                if (onOpenLocker != null) ...[
                  Expanded(
                    child: SizedBox(
                      height: 44,
                      child: OutlinedButton.icon(
                        key: const Key('open_locker_button'),
                        onPressed: onOpenLocker,
                        icon: const Icon(Icons.checkroom, size: 18, color: Color(0xFF00E5FF)),
                        label: const Text(
                          'LOCKER',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF00E5FF), width: 1.5),
                          backgroundColor: const Color(0xFF00E5FF).withValues(alpha: 0.1),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                        ),
                      ),
                    ),
                  ),
                ],
                if (onOpenBodega != null) ...[
                  if (onOpenLocker != null) const SizedBox(width: 8),
                  Expanded(
                    child: SizedBox(
                      height: 44,
                      child: OutlinedButton.icon(
                        key: const Key('open_bodega_button'),
                        onPressed: onOpenBodega,
                        icon: const Icon(Icons.storefront, size: 18, color: Color(0xFFE67E22)),
                        label: const Text(
                          'BODEGA',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFE67E22), width: 1.5),
                          backgroundColor: const Color(0xFFE67E22).withValues(alpha: 0.1),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                        ),
                      ),
                    ),
                  ),
                ],
                if (onOpenAchievements != null) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: SizedBox(
                      height: 44,
                      child: OutlinedButton.icon(
                        key: const Key('open_trophies_button'),
                        onPressed: onOpenAchievements,
                        icon: const Icon(Icons.emoji_events, size: 18, color: Color(0xFFF1C40F)),
                        label: Text(
                          'TROPHIES ($unlockedAchievementsCount/$totalAchievementsCount)',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFF1C40F), width: 1.5),
                          backgroundColor: const Color(0xFFF1C40F).withValues(alpha: 0.1),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                        ),
                      ),
                    ),
                  ),
                ],
                if (onOpenDailyShift != null) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: SizedBox(
                      height: 44,
                      child: OutlinedButton.icon(
                        key: const Key('open_daily_shift_button'),
                        onPressed: onOpenDailyShift,
                        icon: const Icon(Icons.event_available, size: 18, color: Color(0xFF3498DB)),
                        label: Text(
                          dailyStars > 0 ? 'DAILY ($dailyStars ⭐)' : 'DAILY',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF3498DB), width: 1.5),
                          backgroundColor: const Color(0xFF3498DB).withValues(alpha: 0.1),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
