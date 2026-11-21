import 'package:flutter/material.dart';

import '../game/logic/game_state.dart';
import '../game/models/shift_contract.dart';
import 'money.dart';

/// The shift's contracts with their progress, shared by the pause menu and
/// the results screen.
///
/// This is the only place a courier can read what the contracts ask for:
/// until one completes, nothing else on screen mentions them.
class ShiftContractsPanel extends StatelessWidget {
  const ShiftContractsPanel({
    super.key,
    required this.gameState,
    this.panelKey = 'pause_contracts_panel',
    this.summaryKey = 'pause_contracts_summary',
    this.rowKeyPrefix = 'pause_contract_',
    this.statusKeyPrefix = 'pause_contract_status_',
    this.fitHeight = false,
    this.panelWidth = 300.0,
  });

  final GameState gameState;

  /// Keys follow the pause menu's by default; the results screen passes its
  /// own so its tests can find them.
  final String panelKey;
  final String summaryKey;
  final String rowKeyPrefix;
  final String statusKeyPrefix;

  /// Scales the whole panel down to fit a fixed-height slot (pause menu side
  /// by side layout) instead of letting it size itself.
  final bool fitHeight;

  /// Width the content is laid out to when [fitHeight] is on.
  final double panelWidth;

  static const double _panelPadding = 12.0;

  @override
  Widget build(BuildContext context) {
    final list = _buildContractList();
    return Container(
      key: Key(panelKey),
      padding: const EdgeInsets.symmetric(
        horizontal: _panelPadding,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white12, width: 1),
      ),
      child: fitHeight
          ? FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: panelWidth - _panelPadding * 2,
                child: list,
              ),
            )
          : list,
    );
  }

  Widget _buildContractList() {
    final manager = gameState.contractManager;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'SHIFT CONTRACTS',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                ),
              ),
            ),
            Text(
              '${manager.completedCount} of ${manager.contracts.length} done',
              key: Key(summaryKey),
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
          ],
        ),
        for (final contract in manager.contracts) _buildContractRow(contract),
      ],
    );
  }

  Widget _buildContractRow(ShiftContract contract) {
    final Color accent;
    final IconData icon;
    final String status;
    if (contract.isCompleted) {
      accent = const Color(0xFF2ECC71);
      icon = Icons.check_circle;
      status = 'DONE';
    } else if (contract.isFailed) {
      accent = const Color(0xFFE74C3C);
      icon = Icons.cancel;
      status = 'FAILED';
    } else {
      accent = const Color(0xFF3498DB);
      icon = Icons.radio_button_unchecked;
      status = '${contract.currentProgress}/${contract.targetValue}';
    }
    final isOpen = !contract.isCompleted && !contract.isFailed;

    return Padding(
      key: Key('$rowKeyPrefix${contract.id}'),
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: accent),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        contract.title,
                        style: TextStyle(
                          color: contract.isFailed ? Colors.white38 : Colors.white,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          decoration:
                              contract.isFailed ? TextDecoration.lineThrough : null,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '+${dollars(contract.rewardTips)}',
                      style: TextStyle(
                        color: contract.isFailed
                            ? Colors.white24
                            : const Color(0xFFF1C40F),
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                Text(
                  contract.description,
                  style: const TextStyle(color: Colors.white54, fontSize: 10.5),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: isOpen ? contract.progressRatio : 1.0,
                          minHeight: 4,
                          backgroundColor: Colors.white12,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            contract.isFailed ? Colors.white24 : accent,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      status,
                      key: Key('$statusKeyPrefix${contract.id}'),
                      style: TextStyle(
                        color: accent,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
