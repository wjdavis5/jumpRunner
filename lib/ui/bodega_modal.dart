import 'package:flutter/material.dart';

import '../game/models/run_booster.dart';
import '../services/storage_service.dart';
import 'fit_to_screen.dart';
import 'money.dart';
import 'visible_scrollbar.dart';

/// Modal dialog allowing couriers to purchase single-run consumable boosters
/// from the Corner Bodega and equip them before starting a delivery shift.
class BodegaModal extends StatefulWidget {
  const BodegaModal({
    super.key,
    required this.storageService,
    required this.equippedBoosters,
    required this.onEquippedBoostersChanged,
    required this.onClose,
  });

  final LocalStorageService storageService;
  final Set<RunBooster> equippedBoosters;
  final ValueChanged<Set<RunBooster>> onEquippedBoostersChanged;
  final VoidCallback onClose;

  @override
  State<BodegaModal> createState() => _BodegaModalState();
}

class _BodegaModalState extends State<BodegaModal> {
  late Set<RunBooster> _equipped;

  @override
  void initState() {
    super.initState();
    _equipped = Set<RunBooster>.from(widget.equippedBoosters);
    _validateEquipped();
  }

  void _validateEquipped() {
    _equipped.removeWhere(
      (booster) => widget.storageService.getBoosterCount(booster.id) <= 0,
    );
  }

  Future<void> _handleBuy(RunBooster booster) async {
    final success = await widget.storageService.buyBooster(
      booster.id,
      booster.cost,
      RunBooster.maxInventory,
    );

    if (success && mounted) {
      // Auto-equip if not already equipped and user just bought their first
      if (!_equipped.contains(booster)) {
        _equipped.add(booster);
        widget.onEquippedBoostersChanged(_equipped);
      }
      setState(() {});
    }
  }

  void _toggleEquip(RunBooster booster) {
    setState(() {
      if (_equipped.contains(booster)) {
        _equipped.remove(booster);
      } else {
        if (widget.storageService.getBoosterCount(booster.id) > 0) {
          _equipped.add(booster);
        }
      }
    });
    widget.onEquippedBoostersChanged(_equipped);
  }

  /// The narrowest screen a booster row fits on. Narrower screens get the
  /// card scaled.
  static const double minWidth = 640.0;

  @override
  Widget build(BuildContext context) {
    return NarrowScreenScale(minWidth: minWidth, child: Builder(builder: _buildCard));
  }

  Widget _buildCard(BuildContext context) {
    final careerTips = widget.storageService.careerTips;

    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 680, maxHeight: 480),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF141D26).withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFE67E22), width: 2),
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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Bar
            Row(
              children: [
                const Icon(
                  Icons.storefront,
                  color: Color(0xFFE67E22),
                  size: 26,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CORNER BODEGA',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.0,
                        ),
                      ),
                      Text(
                        'Pre-shift consumable supplies & fuel',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Color(0xFFF39C12),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
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
                  key: const Key('bodega_close_button'),
                  onPressed: widget.onClose,
                  icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white10,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Tip Banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, size: 15, color: Color(0xFF85C1E9)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Equipped supplies activate automatically on your next shift and are consumed on launch.',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Booster Catalog List
            Expanded(
              child: VisibleScrollbar(
                key: const Key('bodega_scrollbar'),
                builder: (context, controller) => ListView.separated(
                controller: controller,
                itemCount: RunBooster.values.length,
                separatorBuilder: (context, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final booster = RunBooster.values[index];
                  final count = widget.storageService.getBoosterCount(booster.id);
                  final isEquipped = _equipped.contains(booster);
                  final isMaxed = count >= RunBooster.maxInventory;
                  final canAfford = careerTips >= booster.cost;

                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: isEquipped
                          ? booster.color.withValues(alpha: 0.12)
                          : Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isEquipped ? booster.color : Colors.white12,
                        width: isEquipped ? 1.5 : 1.0,
                      ),
                    ),
                    child: Row(
                      children: [
                        // Icon Avatar
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: booster.color.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: booster.color, width: 1.5),
                          ),
                          child: Icon(booster.icon, color: booster.color, size: 22),
                        ),
                        const SizedBox(width: 12),

                        // Info Column
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      booster.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: count > 0
                                          ? const Color(0xFF27AE60).withValues(alpha: 0.2)
                                          : Colors.white10,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'Stock: $count/${RunBooster.maxInventory}',
                                      style: TextStyle(
                                        color: count > 0
                                            ? const Color(0xFF2ECC71)
                                            : Colors.white38,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                booster.description,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Action Buttons: Buy and Equip
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Buy Button
                            SizedBox(
                              height: 36,
                              child: ElevatedButton(
                                key: Key('buy_booster_${booster.id}'),
                                onPressed: (!isMaxed && canAfford)
                                    ? () => _handleBuy(booster)
                                    : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFE67E22),
                                  disabledBackgroundColor: Colors.white10,
                                  foregroundColor: Colors.white,
                                  disabledForegroundColor: Colors.white30,
                                  padding: const EdgeInsets.symmetric(horizontal: 10),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: Text(
                                  // "BUY", as in the Locker. A bare
                                  // "+$150" read like a reward.
                                  isMaxed ? 'MAX' : 'BUY \$${booster.cost}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),

                            // Equip / Unequip Toggle Button
                            SizedBox(
                              height: 36,
                              child: OutlinedButton.icon(
                                key: Key('equip_booster_${booster.id}'),
                                onPressed: count > 0 ? () => _toggleEquip(booster) : null,
                                icon: Icon(
                                  isEquipped ? Icons.check_circle : Icons.add_circle_outline,
                                  size: 15,
                                  color: isEquipped
                                      ? const Color(0xFF2ECC71)
                                      : (count > 0 ? Colors.white70 : Colors.white24),
                                ),
                                label: Text(
                                  isEquipped
                                      ? 'EQUIPPED'
                                      : (count > 0 ? 'EQUIP' : 'EMPTY'),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: isEquipped
                                        ? const Color(0xFF2ECC71)
                                        : (count > 0 ? Colors.white : Colors.white24),
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(
                                    color: isEquipped
                                        ? const Color(0xFF2ECC71)
                                        : (count > 0 ? Colors.white24 : Colors.white10),
                                  ),
                                  backgroundColor: isEquipped
                                      ? const Color(0xFF2ECC71).withValues(alpha: 0.15)
                                      : Colors.transparent,
                                  padding: const EdgeInsets.symmetric(horizontal: 10),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
              ),
            ),
            const SizedBox(height: 10),

            // Footer Bar with Equipped Badges and Done Button
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Text(
                        'EQUIPPED FOR RUN:',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (_equipped.isEmpty)
                        const Text(
                          'None',
                          style: TextStyle(
                            color: Colors.white30,
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                          ),
                        )
                      else
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: _equipped.map((b) {
                                return Container(
                                  margin: const EdgeInsets.only(right: 6),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: b.color.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: b.color, width: 1),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(b.icon, color: b.color, size: 12),
                                      const SizedBox(width: 4),
                                      Text(
                                        b.name,
                                        style: TextStyle(
                                          color: b.color,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  height: 38,
                  child: ElevatedButton(
                    key: const Key('bodega_done_button'),
                    onPressed: widget.onClose,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF27AE60),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'READY',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
