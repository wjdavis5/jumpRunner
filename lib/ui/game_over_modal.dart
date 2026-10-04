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
    this.deliveriesCompleted = 0,
    this.grindsCompleted = 0,
    this.vaultsCompleted = 0,
    this.glidesCompleted = 0,
    this.subwayStationsCompleted = 0,
    this.craneSwingsCompleted = 0,
    this.vipDeliveriesCompleted = 0,
    this.bikeDraftSlingshotsCompleted = 0,
    this.pigeonScattersCompleted = 0,
    this.highFivesCompleted = 0,
    this.foodCartBouncesCompleted = 0,
    this.drainGeysersCompleted = 0,
    this.solarSurgesCompleted = 0,
    this.puddleSkimsCompleted = 0,
  });

  final int distance;
  final int tips;
  final bool isNewRecord;
  final int careerTips;
  final int completedContracts;
  final int contractBonusTips;
  final int deliveriesCompleted;
  final int grindsCompleted;
  final int vaultsCompleted;
  final int glidesCompleted;
  final int subwayStationsCompleted;
  final int craneSwingsCompleted;
  final int vipDeliveriesCompleted;
  final int bikeDraftSlingshotsCompleted;
  final int pigeonScattersCompleted;
  final int highFivesCompleted;
  final int foodCartBouncesCompleted;
  final int drainGeysersCompleted;
  final int solarSurgesCompleted;
  final int puddleSkimsCompleted;
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

            if (deliveriesCompleted > 0)
              Container(
                key: const Key('game_over_deliveries_badge'),
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1C40F).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFF1C40F), width: 1.5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.inventory_2, color: Color(0xFFF1C40F), size: 16),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        '$deliveriesCompleted DOORSTEP DROP${deliveriesCompleted > 1 ? 'S' : ''} FULFILLED',
                        style: const TextStyle(
                          color: Color(0xFFF1C40F),
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

            if (grindsCompleted > 0)
              Container(
                key: const Key('game_over_grinds_badge'),
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF00E5FF).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF00E5FF), width: 1.5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.skateboarding, color: Color(0xFF00E5FF), size: 16),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        '$grindsCompleted RAIL GRIND${grindsCompleted > 1 ? 'S' : ''} & STUNTS',
                        style: const TextStyle(
                          color: Color(0xFF00E5FF),
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

            if (vaultsCompleted > 0)
              Container(
                key: const Key('game_over_vaults_badge'),
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF00E5FF).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF00E5FF), width: 1.5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.directions_run, color: Color(0xFF00E5FF), size: 16),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        '$vaultsCompleted PARKOUR VAULT${vaultsCompleted > 1 ? 'S' : ''}',
                        style: const TextStyle(
                          color: Color(0xFF00E5FF),
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

            if (glidesCompleted > 0)
              Container(
                key: const Key('game_over_glides_badge'),
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF9F43).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFF9F43), width: 1.5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.paragliding, color: Color(0xFFFF9F43), size: 16),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        '$glidesCompleted AERIAL GLIDE${glidesCompleted > 1 ? 'S' : ''}',
                        style: const TextStyle(
                          color: Color(0xFFFF9F43),
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

            if (subwayStationsCompleted > 0)
              Container(
                key: const Key('game_over_subway_badge'),
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF9B59B6).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF9B59B6), width: 1.5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.subway, color: Color(0xFF9B59B6), size: 16),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        '$subwayStationsCompleted SUBWAY TRANSIT${subwayStationsCompleted > 1 ? 'S' : ''}',
                        style: const TextStyle(
                          color: Color(0xFF9B59B6),
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

            if (craneSwingsCompleted > 0)
              Container(
                key: const Key('game_over_crane_badge'),
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF39C12).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFF39C12), width: 1.5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.precision_manufacturing, color: Color(0xFFF39C12), size: 16),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        '$craneSwingsCompleted CRANE SWING${craneSwingsCompleted > 1 ? 'S' : ''}',
                        style: const TextStyle(
                          color: Color(0xFFF39C12),
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

            if (vipDeliveriesCompleted > 0)
              Container(
                key: const Key('game_over_vip_badge'),
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD700).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFFD700), width: 1.5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.stars, color: Color(0xFFFFD700), size: 16),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        '$vipDeliveriesCompleted VIP EXPRESS DELIVER${vipDeliveriesCompleted > 1 ? 'IES' : 'Y'} (3X SURGE)',
                        style: const TextStyle(
                          color: Color(0xFFFFD700),
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

            if (bikeDraftSlingshotsCompleted > 0)
              Container(
                key: const Key('game_over_draft_badge'),
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF00E5FF).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF00E5FF), width: 1.5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.pedal_bike, color: Color(0xFF00E5FF), size: 16),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        '$bikeDraftSlingshotsCompleted BIKE SLINGSHOT CATAPULT${bikeDraftSlingshotsCompleted > 1 ? 'S' : ''}',
                        style: const TextStyle(
                          color: Color(0xFF00E5FF),
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

            if (pigeonScattersCompleted > 0)
              Container(
                key: const Key('game_over_pigeons_badge'),
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF80CBC4).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF80CBC4), width: 1.5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.flutter_dash, color: Color(0xFF80CBC4), size: 16),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        '$pigeonScattersCompleted PIGEON FLOCK SCATTER${pigeonScattersCompleted > 1 ? 'S' : ''}',
                        style: const TextStyle(
                          color: Color(0xFF80CBC4),
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

            if (highFivesCompleted > 0)
              Container(
                key: const Key('game_over_high_fives_badge'),
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD54F).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFFD54F), width: 1.5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.pan_tool, color: Color(0xFFFFD54F), size: 16),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        '$highFivesCompleted CROSSWALK HIGH FIVE${highFivesCompleted > 1 ? 'S' : ''}',
                        style: const TextStyle(
                          color: Color(0xFFFFD54F),
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

            if (foodCartBouncesCompleted > 0)
              Container(
                key: const Key('game_over_food_cart_badge'),
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF9800).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFF9800), width: 1.5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.beach_access, color: Color(0xFFFF9800), size: 16),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        '$foodCartBouncesCompleted FOOD CART BOUNCE${foodCartBouncesCompleted > 1 ? 'S' : ''}',
                        style: const TextStyle(
                          color: Color(0xFFFF9800),
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

            if (drainGeysersCompleted > 0)
              Container(
                key: const Key('game_over_drain_geysers_badge'),
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF00E5FF).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF00E5FF), width: 1.5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.waves, color: Color(0xFF00E5FF), size: 16),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        '$drainGeysersCompleted STORM DRAIN GEYSER${drainGeysersCompleted > 1 ? 'S' : ''}',
                        style: const TextStyle(
                          color: Color(0xFF00E5FF),
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

            if (solarSurgesCompleted > 0)
              Container(
                key: const Key('game_over_solar_badge'),
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF00E5FF).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF00E5FF), width: 1.5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.solar_power, color: Color(0xFF00E5FF), size: 16),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        '$solarSurgesCompleted SOLAR SURGE${solarSurgesCompleted > 1 ? 'S' : ''}',
                        style: const TextStyle(
                          color: Color(0xFF00E5FF),
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

            if (puddleSkimsCompleted > 0)
              Container(
                key: const Key('game_over_puddles_badge'),
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF29B6F6).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF29B6F6), width: 1.5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.water_drop, color: Color(0xFF29B6F6), size: 16),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        '$puddleSkimsCompleted PUDDLE SKIM${puddleSkimsCompleted > 1 ? 'S' : ''}',
                        style: const TextStyle(
                          color: Color(0xFF29B6F6),
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
