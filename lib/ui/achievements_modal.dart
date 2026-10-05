import 'package:flutter/material.dart';

import '../game/models/achievement.dart';
import 'fit_to_screen.dart';
import 'visible_scrollbar.dart';

/// Modal dialog displaying career trophies, unlock progress, and requirements.
class AchievementsModal extends StatelessWidget {
  const AchievementsModal({
    super.key,
    required this.unlockedAchievementIds,
    required this.onClose,
  });

  final List<String> unlockedAchievementIds;
  final VoidCallback onClose;

  /// Height of one trophy tile: room for a title and a two-line description
  /// beside the badge. The tiles used to take their height from their width
  /// (2.5:1), which left them half empty and pushed the third row off the
  /// card.
  static const double tileHeight = 88.0;

  /// The narrowest screen the header and a trophy tile fit on. Narrower
  /// screens get the card scaled.
  static const double minWidth = 420.0;

  /// The narrowest the list can be and still hold two trophies side by
  /// side with every requirement readable in full. Narrower than this the
  /// trophies go one to a row. Two columns on a phone held upright ended
  /// every requirement with an ellipsis ("Complete a 500m shift delivery
  /// mi..."), and a locked trophy's requirement is the to-do list.
  static const double twoColumnWidth = 500.0;

  @override
  Widget build(BuildContext context) {
    return NarrowScreenScale(minWidth: minWidth, child: Builder(builder: _buildCard));
  }

  Widget _buildCard(BuildContext context) {
    final unlockedSet = unlockedAchievementIds.toSet();
    final totalCount = Achievement.catalog.length;
    final unlockedCount = unlockedSet.length;
    final progress = totalCount > 0 ? unlockedCount / totalCount : 0.0;

    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 520),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        decoration: BoxDecoration(
          color: const Color(0xFF141D26).withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFF1C40F), width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.85),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header Bar
            Row(
              children: [
                const Icon(
                  Icons.emoji_events_rounded,
                  color: Color(0xFFF1C40F),
                  size: 26,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'CAREER TROPHIES',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Progress Pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1C40F).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFFF1C40F).withValues(alpha: 0.4),
                    ),
                  ),
                  child: Text(
                    '$unlockedCount / $totalCount UNLOCKED',
                    style: const TextStyle(
                      color: Color(0xFFF1C40F),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: onClose,
                  icon: const Icon(Icons.close, color: Colors.white70),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white10,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Progress Bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: Colors.white12,
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFF1C40F)),
              ),
            ),

            const SizedBox(height: 16),

            // Grid of Achievement Cards
            Flexible(
              child: LayoutBuilder(
                builder: (context, list) => VisibleScrollbar(
                key: const Key('trophies_scrollbar'),
                builder: (context, controller) => GridView.builder(
                controller: controller,
                shrinkWrap: true,
                itemCount: Achievement.catalog.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: list.maxWidth >= twoColumnWidth ? 2 : 1,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  mainAxisExtent: tileHeight,
                ),
                itemBuilder: (context, index) {
                  final achievement = Achievement.catalog[index];
                  final isUnlocked = unlockedSet.contains(achievement.id);

                  return Container(
                    key: Key('trophy_tile_${achievement.id}'),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isUnlocked
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.black.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isUnlocked
                            ? achievement.badgeColor.withValues(alpha: 0.7)
                            : Colors.white12,
                        width: isUnlocked ? 1.5 : 1.0,
                      ),
                    ),
                    child: Row(
                      children: [
                        // Icon Circle
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isUnlocked
                                ? achievement.badgeColor.withValues(alpha: 0.2)
                                : Colors.white.withValues(alpha: 0.05),
                            border: Border.all(
                              color: isUnlocked
                                  ? achievement.badgeColor
                                  : Colors.white24,
                            ),
                          ),
                          child: Icon(
                            isUnlocked ? achievement.icon : Icons.lock_outline_rounded,
                            color: isUnlocked ? achievement.badgeColor : Colors.white30,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Title & Description
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        achievement.title,
                                        style: TextStyle(
                                          color: isUnlocked ? Colors.white : Colors.white70,
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (isUnlocked)
                                    const Icon(
                                      Icons.check_circle_rounded,
                                      color: Color(0xFF2ECC71),
                                      size: 16,
                                    ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                achievement.description,
                                style: TextStyle(
                                  // A locked trophy's text is the to-do
                                  // list, so it must stay readable.
                                  color: isUnlocked ? Colors.white70 : Colors.white54,
                                  fontSize: 11,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
