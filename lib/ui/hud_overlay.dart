import 'package:flutter/material.dart';

import '../game/logic/game_state.dart';
import '../game/models/shift_contract.dart';

/// Top HUD overlay displaying carried package HP, current distance, and tip earnings.
class HUDOverlay extends StatelessWidget {
  const HUDOverlay({
    super.key,
    required this.gameState,
    this.isMuted = false,
    this.onToggleMute,
    this.onPause,
  });

  final GameState gameState;
  final bool isMuted;
  final VoidCallback? onToggleMute;
  final VoidCallback? onPause;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Stack(
        children: [
          Padding(
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
          if (gameState.isMilestoneBannerVisible && gameState.activeMilestone != null)
            Positioned(
              top: 72.0,
              left: 0,
              right: 0,
              child: Center(
                child: _buildMilestoneBanner(gameState.activeMilestone!),
              ),
            ),
          if (gameState.isContractCelebrationVisible && gameState.activeContractCelebration != null)
            Positioned(
              top: gameState.isMilestoneBannerVisible ? 142.0 : 72.0,
              left: 0,
              right: 0,
              child: Center(
                child: _buildContractBanner(gameState.activeContractCelebration!),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMilestoneBanner(MilestoneEvent milestone) {
    return IgnorePointer(
      child: AnimatedOpacity(
        opacity: gameState.isMilestoneBannerVisible ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 300),
        child: Container(
          key: const Key('milestone_celebration_banner'),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xEE1E272C),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFFF1C40F),
              width: 2.0,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFF1C40F).withValues(alpha: 0.5),
                blurRadius: 18,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.emoji_events,
                color: Color(0xFFF1C40F),
                size: 32,
              ),
              const SizedBox(width: 12),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SHIFT #${milestone.milestoneIndex} COMPLETED! (${milestone.distanceMeters.toInt()}m)',
                    style: const TextStyle(
                      color: Color(0xFFF1C40F),
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 2),
                  if (milestone.restoredPackage)
                    const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.inventory_2,
                          size: 16,
                          color: Color(0xFFE67E22),
                        ),
                        SizedBox(width: 6),
                        Text(
                          'PACKAGE RESTORED! (+1 Delivery Box)',
                          style: TextStyle(
                            color: Color(0xFF85C1E9),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    )
                  else
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.monetization_on,
                          size: 16,
                          color: Color(0xFFF1C40F),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'FLAWLESS SHIFT BONUS: +\$${milestone.bonusTips} TIPS!',
                          style: const TextStyle(
                            color: Color(0xFF2ECC71),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContractBanner(ShiftContract contract) {
    return IgnorePointer(
      child: AnimatedOpacity(
        opacity: gameState.isContractCelebrationVisible ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 300),
        child: Container(
          key: const Key('contract_celebration_banner'),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xEE1A252F),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: const Color(0xFF2ECC71),
              width: 2.0,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2ECC71).withValues(alpha: 0.45),
                blurRadius: 16,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.task_alt,
                color: Color(0xFF2ECC71),
                size: 26,
              ),
              const SizedBox(width: 10),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CONTRACT COMPLETED: ${contract.title.toUpperCase()}!',
                    style: const TextStyle(
                      color: Color(0xFF2ECC71),
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '+${contract.rewardTips} BONUS CAREER TIPS EARNED',
                    style: const TextStyle(
                      color: Color(0xFFF1C40F),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
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
                gameState.isDailyShiftActive
                    ? 'DAILY GOAL: ${gameState.activeDailyShift!.targetDistanceMeters}m (${gameState.activeDailyShift!.modifier.title})'
                    : 'Shift Goal: ${nextMilestone}m',
                style: TextStyle(
                  color: gameState.isDailyShiftActive
                      ? gameState.activeDailyShift!.modifier.color
                      : const Color(0xFF85C1E9),
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
        if (gameState.isDroneActive) ...[
          const SizedBox(height: 6),
          Container(
            key: const Key('drone_assist_badge'),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF00B4DB), Color(0xFF00E5FF)],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00E5FF).withValues(alpha: 0.6),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.flight, color: Colors.black, size: 16),
                const SizedBox(width: 4),
                Text(
                  'DRONE HARVEST ${gameState.droneTimer.toStringAsFixed(1)}s',
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
        if (gameState.isComboActive) ...[
          const SizedBox(height: 6),
          Container(
            key: const Key('stunt_combo_badge'),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFE67E22), Color(0xFFE74C3C)],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFE74C3C).withValues(alpha: 0.6),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.local_fire_department, color: Colors.white, size: 16),
                const SizedBox(width: 4),
                Text(
                  'STUNT COMBO ${gameState.stuntMultiplier}x (${gameState.stuntStreak})',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
        if (gameState.deliveryStreak > 1) ...[
          const SizedBox(height: 6),
          Container(
            key: const Key('delivery_streak_badge'),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFF39C12), Color(0xFFF1C40F)],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFF1C40F).withValues(alpha: 0.55),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.star, color: Colors.black, size: 16),
                const SizedBox(width: 4),
                Text(
                  'DELIVERY STREAK ${gameState.deliveryMultiplier}x (${gameState.deliveryStreak})',
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
        if (gameState.isVipMissionActive) ...[
          const SizedBox(height: 6),
          Container(
            key: const Key('vip_mission_badge'),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: gameState.vipTimer < 3.5
                    ? const [Color(0xFFE74C3C), Color(0xFFC0392B)]
                    : const [Color(0xFFFFD700), Color(0xFFFFA500)],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: (gameState.vipTimer < 3.5
                          ? const Color(0xFFE74C3C)
                          : const Color(0xFFFFD700))
                      .withValues(alpha: 0.7),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.stars,
                  color: gameState.vipTimer < 3.5 ? Colors.white : Colors.black,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  'VIP EXPRESS: ${gameState.vipTimer.toStringAsFixed(1)}s (3.0x SURGE)',
                  style: TextStyle(
                    color: gameState.vipTimer < 3.5 ? Colors.white : Colors.black,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
        if (gameState.isDrafting) ...[
          const SizedBox(height: 6),
          Container(
            key: const Key('drafting_stream_badge'),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF00E5FF), Color(0xFF00B4DB)],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00E5FF).withValues(alpha: 0.65),
                  blurRadius: 9,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.air, color: Colors.black, size: 16),
                SizedBox(width: 4),
                Text(
                  'DRAFTING 1.2X (+SLINGSHOT READY)',
                  style: TextStyle(
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
        if (onPause != null) ...[
          const SizedBox(width: 8),
          IconButton(
            key: const Key('pause_button'),
            tooltip: 'Pause Shift (P)',
            onPressed: onPause,
            icon: const Icon(
              Icons.pause,
              color: Colors.white70,
            ),
            style: IconButton.styleFrom(
              backgroundColor: Colors.black.withValues(alpha: 0.6),
            ),
          ),
        ],
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
