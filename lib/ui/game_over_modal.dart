import 'package:flutter/material.dart';
import '../game/components/obstacle_component.dart';
import '../game/game_font.dart';
import '../game/models/achievement.dart';
import '../game/models/courier_skin.dart';
import 'fit_to_screen.dart';
import 'hazard_lesson.dart';
import 'key_hint.dart';
import 'money.dart';

/// Modal dialog presented when all carried packages are dropped (Game Over).
class GameOverModal extends StatelessWidget {
  const GameOverModal({
    super.key,
    required this.distance,
    required this.tips,
    required this.isNewRecord,
    this.personalBest = 0,
    this.endedBy,
    required this.careerTips,
    required this.onRestart,
    this.onReturnToDepot,
    this.nextOutfit,
    this.trophies = const [],
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
    this.windTunnelGlidesCompleted = 0,
    this.turnstilesCompleted = 0,
    this.droneCatchesCompleted = 0,
    this.fireEscapesCompleted = 0,
    this.foodTruckDriftsCompleted = 0,
    this.barricadesCompleted = 0,
    this.satelliteLaunchesCompleted = 0,
    this.mailboxesCompleted = 0,
    this.acCondensersCompleted = 0,
    this.skylightsCompleted = 0,
    this.flowerKiosksCompleted = 0,
    this.waterTowersCompleted = 0,
    this.newsstandsCompleted = 0,
    this.cafeBistrosCompleted = 0,
    this.buskersCompleted = 0,
    this.hydrantsCompleted = 0,
    this.clotheslinesCompleted = 0,
    this.subwayGratesCompleted = 0,
    this.ziplinesCompleted = 0,
    this.busSheltersCompleted = 0,
    this.securityShuttersCompleted = 0,
  });

  final int distance;
  final int tips;
  final bool isNewRecord;

  /// The courier's best distance, this shift included. Shown beside the
  /// distance when this shift fell short of it.
  final int personalBest;

  /// The hazard that took the last package, if the shift ended on one.
  final ObstacleType? endedBy;

  /// What the distance figure is labelled: a shift that fell short of the
  /// record says what the record is, because "how close was that?" is the
  /// question that starts the next shift.
  String get distanceLabel => !isNewRecord && personalBest > distance
      ? 'Distance \u00b7 best ${meters(personalBest)}'
      : 'Distance';
  final int careerTips;

  /// The outfit the courier is saving for, if any. The card shows how much
  /// closer this shift brought it.
  final CourierSkin? nextOutfit;

  /// The trophies this shift earned. Some are only judged once the shift is
  /// over (a career's worth of tips, of contracts), and their pop-up on the
  /// street came up behind this card: the only sign of them was a number
  /// going up on the Trophies button.
  final List<Achievement> trophies;
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
  final int windTunnelGlidesCompleted;
  final int turnstilesCompleted;
  final int droneCatchesCompleted;
  final int fireEscapesCompleted;
  final int foodTruckDriftsCompleted;
  final int barricadesCompleted;
  final int satelliteLaunchesCompleted;
  final int mailboxesCompleted;
  final int acCondensersCompleted;
  final int skylightsCompleted;
  final int flowerKiosksCompleted;
  final int waterTowersCompleted;
  final int newsstandsCompleted;
  final int cafeBistrosCompleted;
  final int buskersCompleted;
  final int hydrantsCompleted;
  final int clotheslinesCompleted;
  final int subwayGratesCompleted;
  final int ziplinesCompleted;
  final int busSheltersCompleted;
  final int securityShuttersCompleted;
  final VoidCallback onRestart;

  /// Leaves for the title screen, where the Locker, Bodega and Daily Shift
  /// live. Without it the only way to spend tips after a run was to start
  /// another one and quit from its pause menu.
  final VoidCallback? onReturnToDepot;

  /// Card width on screens with room for it: wide enough that most badges
  /// sit two to a row.
  static const double maxCardWidth = 520.0;

  /// Screens shorter than this get the compact header and spacing.
  static const double compactBelowHeight = 430.0;

  /// Height of the fade at the bottom of the badge list; matches the gap
  /// under each badge row.
  static const double _badgeFadeHeight = 12.0;

  @override
  Widget build(BuildContext context) {
    return NarrowScreenScale(minWidth: minWidth, child: Builder(builder: _buildCard));
  }

  /// The narrowest screen the card's two buttons fit on with their labels
  /// at full size. Narrower screens get the card scaled: at 320 px the
  /// START NEXT SHIFT label was squeezed to 5.5 px tall.
  static const double minWidth = 420.0;

  Widget _buildCard(BuildContext context) {
    // The card never grows past the screen: the badge list in the middle
    // scrolls instead, so the restart button is always reachable.
    final screen = MediaQuery.sizeOf(context);
    // A phone held sideways has under 400 px of height: drop the subtitle and
    // tighten the spacing there so the badge list keeps a usable window.
    final compact = screen.height < compactBelowHeight;
    return Center(
      child: Container(
        width: screen.width < maxCardWidth + 32 ? screen.width - 32 : maxCardWidth,
        constraints: BoxConstraints(maxHeight: screen.height - 24),
        padding: EdgeInsets.symmetric(horizontal: 24, vertical: compact ? 12 : 20),
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
            // What ended the shift and how to get past it next time. Shown
            // on a phone held sideways too, where the old "Shift Concluded"
            // was dropped for room: this line earns its 20 px.
            if (endedBy != null) ...[
              const SizedBox(height: 4),
              Text(
                HazardLesson.forType(endedBy!).line,
                key: const Key('game_over_lesson'),
                textAlign: TextAlign.center,
                maxLines: 2,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ] else if (!compact) ...[
              const SizedBox(height: 4),
              const Text(
                'Shift Concluded',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
            SizedBox(height: compact ? 8 : 16),

            if (isNewRecord)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1C40F),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text.rich(
                  withStars(
                    '★ NEW DISTANCE RECORD! ★',
                    const TextStyle(
                      color: Color(0xFF1C2833),
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),

            // Every badge below lives in one scrolling, wrapping list. A strong
            // run earns a dozen or more, which used to push the stats and the
            // restart button off the bottom of the screen. The badge blocks
            // keep their original indentation to keep this change small.
            Flexible(
              // Fade the bottom edge so a cut-off row reads as "more below".
              // The fade only spans the gap under a row, so it is invisible
              // when every badge fits.
              child: ShaderMask(
                blendMode: BlendMode.dstIn,
                shaderCallback: (bounds) => LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: const [Colors.white, Colors.white, Colors.transparent],
                  stops: [
                    0.0,
                    bounds.height <= _badgeFadeHeight ? 0.0 : 1.0 - (_badgeFadeHeight / bounds.height),
                    1.0,
                  ],
                ).createShader(bounds),
              child: _BadgeScroller(
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  children: [
            for (final trophy in trophies)
              Container(
                key: Key('game_over_trophy_${trophy.id}'),
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1C40F),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.emoji_events_rounded, color: Color(0xFF1C2833), size: 16),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'TROPHY: ${trophy.title.toUpperCase()}',
                        style: const TextStyle(
                          color: Color(0xFF1C2833),
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
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
                        '$completedContracts CONTRACT${completedContracts > 1 ? 'S' : ''} (+${dollars(contractBonusTips)} BONUS)',
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

            if (windTunnelGlidesCompleted > 0)
              Container(
                key: const Key('game_over_wind_tunnel_badge'),
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
                    const Icon(Icons.air, color: Color(0xFF00E5FF), size: 16),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        '$windTunnelGlidesCompleted WIND TUNNEL GLIDE${windTunnelGlidesCompleted > 1 ? 'S' : ''}',
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

            if (turnstilesCompleted > 0)
              Container(
                key: const Key('game_over_turnstiles_badge'),
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF00E676).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF00E676), width: 1.5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.transit_enterexit, color: Color(0xFF00E676), size: 16),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        '$turnstilesCompleted METRO TURNSTILE${turnstilesCompleted > 1 ? 'S' : ''}',
                        style: const TextStyle(
                          color: Color(0xFF00E676),
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

            if (droneCatchesCompleted > 0)
              Container(
                key: const Key('game_over_drone_catch_badge'),
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
                    const Icon(Icons.flight_takeoff, color: Color(0xFF00E5FF), size: 16),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        '$droneCatchesCompleted DRONE CARGO CATCH${droneCatchesCompleted > 1 ? 'ES' : ''}',
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

            if (fireEscapesCompleted > 0)
              Container(
                key: const Key('game_over_fire_escape_badge'),
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
                    const Icon(Icons.stairs, color: Color(0xFFFF9800), size: 16),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        '$fireEscapesCompleted FIRE ESCAPE DROP${fireEscapesCompleted > 1 ? 'S' : ''}',
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

            if (foodTruckDriftsCompleted > 0)
              Container(
                key: const Key('game_over_grease_drift_badge'),
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFB300).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFFB300), width: 1.5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.local_shipping, color: Color(0xFFFFB300), size: 16),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        '$foodTruckDriftsCompleted GREASE DRIFT SLIDE${foodTruckDriftsCompleted > 1 ? 'S' : ''}',
                        style: const TextStyle(
                          color: Color(0xFFFFB300),
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

            if (barricadesCompleted > 0)
              Container(
                key: const Key('game_over_barricade_badge'),
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6D00).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFF6D00), width: 1.5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.construction, color: Color(0xFFFF6D00), size: 16),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        '$barricadesCompleted BARRICADE VAULT${barricadesCompleted > 1 ? 'S' : ''}',
                        style: const TextStyle(
                          color: Color(0xFFFF6D00),
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

            if (satelliteLaunchesCompleted > 0)
              Container(
                key: const Key('game_over_satellite_badge'),
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
                    const Icon(Icons.satellite_alt, color: Color(0xFF00E5FF), size: 16),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        '$satelliteLaunchesCompleted SATELLITE LAUNCH${satelliteLaunchesCompleted > 1 ? 'ES' : ''}',
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

            if (mailboxesCompleted > 0)
              Container(
                key: const Key('game_over_mailbox_badge'),
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF1976D2).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF1976D2), width: 1.5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.markunread_mailbox, color: Color(0xFF1976D2), size: 16),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        '$mailboxesCompleted MAILBOX VAULT${mailboxesCompleted > 1 ? 'S' : ''}',
                        style: const TextStyle(
                          color: Color(0xFF1976D2),
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

            if (acCondensersCompleted > 0)
              Container(
                key: const Key('game_over_condenser_badge'),
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
                    const Icon(Icons.ac_unit, color: Color(0xFF00E5FF), size: 16),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        '$acCondensersCompleted CONDENSER LIFT${acCondensersCompleted > 1 ? 'S' : ''}',
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

            if (skylightsCompleted > 0)
              Container(
                key: const Key('game_over_skylight_badge'),
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
                    const Icon(Icons.window, color: Color(0xFF00E5FF), size: 16),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        '$skylightsCompleted SKYLIGHT SMASH${skylightsCompleted > 1 ? 'ES' : ''}',
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

            if (flowerKiosksCompleted > 0)
              Container(
                key: const Key('game_over_flower_kiosk_badge'),
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFE91E63).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE91E63), width: 1.5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.local_florist, color: Color(0xFFE91E63), size: 16),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        '$flowerKiosksCompleted FLOWER KIOSK VAULT${flowerKiosksCompleted > 1 ? 'S' : ''}',
                        style: const TextStyle(
                          color: Color(0xFFE91E63),
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

            if (waterTowersCompleted > 0)
              Container(
                key: const Key('game_over_water_tower_badge'),
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
                    const Icon(Icons.water, color: Color(0xFF00E5FF), size: 16),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        '$waterTowersCompleted WATER TOWER TRAVERSE${waterTowersCompleted > 1 ? 'S' : ''}',
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

            if (newsstandsCompleted > 0)
              Container(
                key: const Key('game_over_newsstand_badge'),
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFB300).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFFB300), width: 1.5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.newspaper, color: Color(0xFFFFB300), size: 16),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        '$newsstandsCompleted NEWSSTAND VAULT${newsstandsCompleted > 1 ? 'S' : ''}',
                        style: const TextStyle(
                          color: Color(0xFFFFB300),
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

            if (cafeBistrosCompleted > 0)
              Container(
                key: const Key('game_over_cafe_bistro_badge'),
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF8D6E63).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF8D6E63), width: 1.5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.coffee, color: Color(0xFFD7CCC8), size: 16),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        '$cafeBistrosCompleted CAFE BISTRO VAULT${cafeBistrosCompleted > 1 ? 'S' : ''}',
                        style: const TextStyle(
                          color: Color(0xFFD7CCC8),
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

            if (buskersCompleted > 0)
              Container(
                key: const Key('game_over_busker_badge'),
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF9C27B0).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFBA68C8), width: 1.5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.music_note, color: Color(0xFFE1BEE7), size: 16),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        '$buskersCompleted STREET BUSKER JAZZ${buskersCompleted > 1 ? ' ENCOUNTERS' : ' ENCOUNTER'}',
                        style: const TextStyle(
                          color: Color(0xFFE1BEE7),
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

            if (hydrantsCompleted > 0)
              Container(
                key: const Key('game_over_hydrant_badge'),
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF00ACC1).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF00E5FF), width: 1.5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.water_drop, color: Color(0xFFB2EBF2), size: 16),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        '$hydrantsCompleted FIRE HYDRANT SPRAY${hydrantsCompleted > 1 ? ' BLASTS' : ' BLAST'}',
                        style: const TextStyle(
                          color: Color(0xFFB2EBF2),
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

            if (clotheslinesCompleted > 0)
              Container(
                key: const Key('game_over_clothesline_badge'),
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF7043).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFF8A80), width: 1.5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.dry_cleaning, color: Color(0xFFFFCCBC), size: 16),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        '$clotheslinesCompleted ROOFTOP CLOTHESLINE${clotheslinesCompleted > 1 ? ' REBOUNDS' : ' REBOUND'}',
                        style: const TextStyle(
                          color: Color(0xFFFFCCBC),
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

            if (subwayGratesCompleted > 0)
              Container(
                key: const Key('game_over_subway_grate_badge'),
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF455A64).withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFFB74D), width: 1.5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.air, color: Color(0xFFFFCC80), size: 16),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        '$subwayGratesCompleted SUBWAY EXHAUST UPDRAFT${subwayGratesCompleted > 1 ? 'S' : ''}',
                        style: const TextStyle(
                          color: Color(0xFFFFCC80),
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

            if (ziplinesCompleted > 0)
              Container(
                key: const Key('game_over_zipline_badge'),
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
                    const Icon(Icons.electric_bolt, color: Color(0xFF00E5FF), size: 16),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        '$ziplinesCompleted AERIAL CATENARY ZIPLINE SLIDE${ziplinesCompleted > 1 ? 'S' : ''}',
                        style: const TextStyle(
                          color: Color(0xFFE0F7FA),
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

            if (busSheltersCompleted > 0)
              Container(
                key: const Key('game_over_bus_shelter_badge'),
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFB300).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFFB300), width: 1.5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.directions_bus, color: Color(0xFFFFB300), size: 16),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        '$busSheltersCompleted TRANSIT SHELTER VAULT${busSheltersCompleted > 1 ? 'S' : ''}',
                        style: const TextStyle(
                          color: Color(0xFFFFF8E1),
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

            if (securityShuttersCompleted > 0)
              Container(
                key: const Key('game_over_security_shutter_badge'),
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF007F).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFF007F), width: 1.5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.door_sliding, color: Color(0xFFFF007F), size: 16),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        '$securityShuttersCompleted SECURITY SHUTTER REBOUND${securityShuttersCompleted > 1 ? 'S' : ''}',
                        style: const TextStyle(
                          color: Color(0xFFFFE0EB),
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
                  ],
                ),
              ),
              ),
            ),

            // Stats grid
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStatItem(distanceLabel, meters(distance), Icons.straighten,
                    labelKey: const Key('game_over_distance_label')),
                _buildStatItem('Run Tips', dollars(tips), Icons.monetization_on),
                _buildStatItem('Career Tips', dollars(careerTips), Icons.savings),
              ],
            ),

            if (nextOutfit != null) ...[
              SizedBox(height: compact ? 8 : 12),
              _buildOutfitGoal(nextOutfit!),
            ],

            SizedBox(height: compact ? 12 : 20),

            // Depot (title screen, where tips are spent) and Restart buttons
            SizedBox(
              height: 48,
              child: Row(
                children: [
                  if (onReturnToDepot != null) ...[
                    OutlinedButton.icon(
                      key: const Key('game_over_depot_button'),
                      onPressed: onReturnToDepot,
                      icon: const Icon(Icons.storefront, size: 20),
                      label: const Text(
                        'DEPOT',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        minimumSize: const Size(0, 48),
                        side: const BorderSide(color: Colors.white24, width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: onRestart,
                        icon: const Icon(Icons.replay, size: 20),
                        label: const KeyHintLabel(
                          label: 'START NEXT SHIFT',
                          keyLabel: 'SPACE',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF27AE60),
                          foregroundColor: Colors.white,
                          // The label gets the room, not the margins.
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// One of the three figures. Each takes a third of the row; a long figure
  /// or label shrinks to its third instead of pushing the others off the card.
  Widget _buildStatItem(String label, String value, IconData icon, {Key? labelKey}) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          children: [
            Icon(icon, color: Colors.white54, size: 20),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                maxLines: 1,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                key: labelKey,
                maxLines: 1,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

extension _OutfitGoal on GameOverModal {
  /// A slim bar: how far the career tips have got toward the next outfit.
  Widget _buildOutfitGoal(CourierSkin outfit) {
    final ready = careerTips >= outfit.price;
    final progress = outfit.price > 0 ? (careerTips / outfit.price).clamp(0.0, 1.0) : 1.0;
    final accent = ready ? const Color(0xFF2ECC71) : const Color(0xFFF1C40F);
    return Column(
      key: const Key('game_over_outfit_goal'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  'NEXT: ${outfit.name.toUpperCase()}',
                  maxLines: 1,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              outfitGoalText(outfit, careerTips),
              key: const Key('game_over_outfit_goal_text'),
              style: TextStyle(
                color: ready ? accent : Colors.white70,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 5,
            backgroundColor: Colors.white12,
            valueColor: AlwaysStoppedAnimation<Color>(accent),
          ),
        ),
      ],
    );
  }
}

/// The scrolling badge list, with a scrollbar that stays visible whenever
/// there are more badges than fit. The fade alone could not say so when the
/// list happened to end exactly between two rows.
class _BadgeScroller extends StatefulWidget {
  const _BadgeScroller({required this.child});

  final Widget child;

  @override
  State<_BadgeScroller> createState() => _BadgeScrollerState();
}

class _BadgeScrollerState extends State<_BadgeScroller> {
  final ScrollController _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      key: const Key('game_over_badges_scrollbar'),
      controller: _controller,
      thumbVisibility: true,
      child: SingleChildScrollView(
        key: const Key('game_over_badges_scroll'),
        controller: _controller,
        child: widget.child,
      ),
    );
  }
}
