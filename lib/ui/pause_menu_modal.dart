import 'package:flutter/material.dart';

import '../game/logic/game_state.dart';
import '../game/logic/input_hints.dart';
import '../game/models/shift_contract.dart';
import 'fit_to_screen.dart';
import 'money.dart';

/// Modal dialog presented when a shift run is paused.
class PauseMenuModal extends StatelessWidget {
  const PauseMenuModal({
    super.key,
    required this.gameState,
    required this.onResume,
    required this.onQuit,
    this.isReduceFlash = false,
    this.onToggleReduceFlash,
    this.isHapticsOn = true,
    this.onToggleHaptics,
  });

  /// Width of the stats and buttons column.
  static const double controlsWidth = 372.0;

  /// Width of the contracts panel when it sits beside the controls.
  static const double contractsPanelWidth = 300.0;

  /// The contracts move beside the controls once the screen is this much
  /// wider than it is tall. A phone held sideways has width to spare and no
  /// height, so stacking them there would shrink the whole card.
  static const double sideBySideAspect = 1.3;

  static const double _cardPadding = 24.0;
  static const double _panelGap = 20.0;
  static const double _panelPadding = 12.0;

  final GameState gameState;
  final VoidCallback onResume;
  final VoidCallback onQuit;
  final bool isReduceFlash;
  final ValueChanged<bool>? onToggleReduceFlash;

  /// Whether the phone vibrates on hits and milestones.
  final bool isHapticsOn;

  /// Called when the player flips the vibration switch. The switch is only
  /// offered on a device that can vibrate, and only when this is given.
  final ValueChanged<bool>? onToggleHaptics;

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final sideBySide = screen.width >= screen.height * sideBySideAspect;
    final cardWidth = sideBySide
        ? controlsWidth + _panelGap + contractsPanelWidth + _cardPadding * 2
        : controlsWidth + _cardPadding * 2;

    return FitToScreen(
      child: Container(
        width: cardWidth,
        padding: const EdgeInsets.symmetric(horizontal: _cardPadding, vertical: 20),
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
        child: sideBySide
            ? IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(width: controlsWidth, child: _buildControls()),
                    const SizedBox(width: _panelGap),
                    // A Stack ignores positioned children when it reports its
                    // own height, so the controls alone decide how tall the
                    // card is and the contracts fit themselves to that.
                    Expanded(
                      child: Stack(
                        children: [
                          Positioned.fill(child: _buildContracts(fitHeight: true)),
                        ],
                      ),
                    ),
                  ],
                ),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildControls(),
                  const SizedBox(height: 14),
                  _buildContracts(),
                ],
              ),
      ),
    );
  }

  Widget _buildControls() {
    return Column(
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

        const SizedBox(height: 12),

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

        // Vibration, on a phone or tablet. A computer has nothing to shake.
        if (onToggleHaptics != null && !expectsKeyboard) ...[
          const SizedBox(height: 8),
          InkWell(
            key: const Key('haptics_toggle'),
            onTap: () => onToggleHaptics?.call(!isHapticsOn),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isHapticsOn ? const Color(0xFF00E5FF) : Colors.white12,
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isHapticsOn ? Icons.vibration : Icons.smartphone,
                    size: 18,
                    color: isHapticsOn ? const Color(0xFF00E5FF) : Colors.white70,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Vibration',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Switch(
                    key: const Key('haptics_switch'),
                    value: isHapticsOn,
                    activeThumbColor: const Color(0xFF00E5FF),
                    onChanged: onToggleHaptics,
                  ),
                ],
              ),
            ),
          ),
        ],

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

        // Phones have no P or Esc to press.
        if (expectsKeyboard) ...[
          const SizedBox(height: 12),
          const Text(
            'Press [P] or [Esc] to resume',
            key: Key('pause_keyboard_hint'),
            style: TextStyle(
              color: Colors.white38,
              fontSize: 11,
            ),
          ),
        ],
      ],
    );
  }

  /// The shift's contracts with their progress.
  ///
  /// This is the only place a courier can read what the contracts ask for:
  /// until one completes, nothing else on screen mentions them.
  Widget _buildContracts({bool fitHeight = false}) {
    final list = _buildContractList();
    return Container(
      key: const Key('pause_contracts_panel'),
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
                width: contractsPanelWidth - _panelPadding * 2,
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
              key: const Key('pause_contracts_summary'),
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
      key: Key('pause_contract_${contract.id}'),
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
                      key: Key('pause_contract_status_${contract.id}'),
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
