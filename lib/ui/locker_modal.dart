import 'package:flutter/material.dart';

import '../game/models/courier_skin.dart';
import 'fit_to_screen.dart';
import 'money.dart';
import 'outfit_preview.dart';
import 'visible_scrollbar.dart';

/// Modal dialog allowing players to browse, purchase, and equip cosmetic courier outfits.
class LockerModal extends StatelessWidget {
  const LockerModal({
    super.key,
    required this.careerTips,
    required this.unlockedSkins,
    required this.equippedSkin,
    required this.onEquipSkin,
    required this.onUnlockSkin,
    required this.onClose,
  });

  final int careerTips;
  final List<String> unlockedSkins;
  final String equippedSkin;
  final ValueChanged<String> onEquipSkin;
  final Future<void> Function(String skinId, int price) onUnlockSkin;
  final VoidCallback onClose;

  /// The narrowest screen an outfit row fits on: picture, name, description
  /// and its button side by side. Narrower screens get the card scaled.
  static const double minWidth = 640.0;

  @override
  Widget build(BuildContext context) {
    return NarrowScreenScale(minWidth: minWidth, child: Builder(builder: _buildCard));
  }

  Widget _buildCard(BuildContext context) {
    return Center(
      child: Container(
        // Tall enough for all four outfits with their pictures on a
        // desktop-size screen; smaller screens scroll the list.
        constraints: const BoxConstraints(maxWidth: 680, maxHeight: 520),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        decoration: BoxDecoration(
          color: const Color(0xFF141D26).withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFF00E5FF), width: 2),
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
                  Icons.checkroom,
                  color: Color(0xFF00E5FF),
                  size: 26,
                ),
                const SizedBox(width: 8),
                const Text(
                  'COURIER LOCKER',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.0,
                  ),
                ),
                const Spacer(),
                // Career Tips Balance Chip
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1C40F).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFF1C40F), width: 1.5),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.monetization_on,
                        color: Color(0xFFF1C40F),
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${dollars(careerTips)} TIPS',
                        style: const TextStyle(
                          color: Color(0xFFF1C40F),
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  key: const Key('locker_close_button'),
                  onPressed: onClose,
                  icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white10,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Skin Grid
            Flexible(
              child: VisibleScrollbar(
                key: const Key('locker_scrollbar'),
                builder: (context, controller) => ListView.separated(
                controller: controller,
                shrinkWrap: true,
                itemCount: CourierSkin.catalog.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final skin = CourierSkin.catalog[index];
                  final isUnlocked = unlockedSkins.contains(skin.id);
                  final isEquipped = equippedSkin == skin.id;
                  final canAfford = careerTips >= skin.price;

                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isEquipped
                          ? const Color(0xFF00E5FF).withValues(alpha: 0.08)
                          : Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isEquipped
                            ? const Color(0xFF00E5FF)
                            : Colors.white12,
                        width: isEquipped ? 1.5 : 1.0,
                      ),
                    ),
                    child: Row(
                      children: [
                        // The courier wearing the outfit. The colour swatch
                        // it replaces stands in until the picture is ready.
                        OutfitPreview(
                          skin: skin,
                          placeholder: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: skin.primaryColor,
                              border: Border.all(
                                color: skin.accentColor,
                                width: 3,
                              ),
                              boxShadow: skin.glowColor != Colors.transparent
                                  ? [
                                      BoxShadow(
                                        color: skin.glowColor.withValues(alpha: 0.6),
                                        blurRadius: 8,
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Icon(
                              skin.hasSpeedTrail ? Icons.electric_bolt : Icons.person,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),

                        // Title & Description
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  // Flexible: a five-figure price makes the
                                  // buy button wide, and on a narrow card
                                  // the name gives way rather than overflow.
                                  Flexible(
                                    child: Text(
                                      skin.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  if (skin.hasSpeedTrail) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE74C3C).withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: const Color(0xFFE74C3C), width: 1),
                                      ),
                                      child: const Text(
                                        'TRAIL VFX',
                                        style: TextStyle(
                                          color: Color(0xFFE74C3C),
                                          fontSize: 9,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                skin.description,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.65),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Action Button (Equipped / Equip / Buy)
                        if (isEquipped)
                          Container(
                            key: Key('equipped_badge_${skin.id}'),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF27AE60).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFF27AE60), width: 1.5),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.check, color: Color(0xFF2ECC71), size: 16),
                                SizedBox(width: 4),
                                Text(
                                  'EQUIPPED',
                                  style: TextStyle(
                                    color: Color(0xFF2ECC71),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else if (isUnlocked)
                          ElevatedButton(
                            key: Key('equip_button_${skin.id}'),
                            onPressed: () => onEquipSkin(skin.id),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2980B9),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                            ),
                            child: const Text(
                              'EQUIP',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          )
                        else
                          ElevatedButton.icon(
                            key: Key('unlock_button_${skin.id}'),
                            onPressed: canAfford ? () => onUnlockSkin(skin.id, skin.price) : null,
                            icon: const Icon(Icons.lock_open, size: 16),
                            label: Text(
                              'BUY ${dollars(skin.price)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFF1C40F),
                              foregroundColor: Colors.black,
                              disabledBackgroundColor: Colors.white12,
                              disabledForegroundColor: Colors.white38,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
