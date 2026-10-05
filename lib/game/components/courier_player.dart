import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../components/crane_swing_component.dart';
import '../components/catenary_zipline_component.dart';
import '../logic/jump_physics.dart';
import '../logic/outfit_tailor.dart';
import '../models/courier_skin.dart';

/// Courier avatar state machine enum.
enum CourierState {
  running,
  jumping,
  falling,
  grinding,
  vaulting,
  gliding,
  swinging,
  ziplining,
  hurt,
}

/// The player-controlled gig economy courier.
///
/// Features calibrated torso hitbox to avoid unfair foot/limb collisions,
/// variable jump physics simulation, 1.5s post-hit invulnerability with flicker,
/// and responsive state transitions.
class CourierPlayer extends PositionComponent with CollisionCallbacks {
  CourierPlayer({
    this.groundY = 460.0,
    double initialX = 120.0,
    Vector2? playerSize,
    CourierSkin? skin,
    this.onJump,
    this.onLand,
    this.onDamage,
    this.onRailOllie,
    this.checkCanVault,
    this.onVault,
    this.onGlideStarted,
    this.onGlideEnded,
    this.onCraneLaunch,
    this.onDraftSlingshot,
  })  : defaultPlayerX = initialX,
        skin = skin ?? CourierSkin.standard,
        simulator = JumpPhysicsSimulator(groundY: groundY) {
    size = playerSize ?? Vector2(64, 64);
    position = Vector2(initialX, groundY - size.y);
  }

  final double groundY;
  final double defaultPlayerX;
  final JumpPhysicsSimulator simulator;

  final VoidCallback? onJump;
  final VoidCallback? onLand;
  final VoidCallback? onDamage;
  final VoidCallback? onRailOllie;
  final bool Function()? checkCanVault;
  final VoidCallback? onVault;
  final VoidCallback? onGlideStarted;
  final VoidCallback? onGlideEnded;
  final ValueChanged<double>? onCraneLaunch;
  final VoidCallback? onDraftSlingshot;

  CourierSkin skin;

  /// Updates the cosmetic outfit worn by the courier.
  void setSkin(CourierSkin newSkin) {
    skin = newSkin;
    _outfitReady = _tailorOutfit();
  }

  /// Recoloured copies of the courier art for the equipped outfit, keyed by
  /// the sprite each one replaces. Empty for the standard uniform, and for
  /// the few milliseconds the recolouring takes after an outfit change.
  ///
  /// Outfit colours used to reach only the vector fallback drawing, so with
  /// the real sprites loaded a skin bought in the Locker changed nothing on
  /// screen.
  final Map<Sprite, Sprite> _dressed = {};
  int _tailoringJob = 0;
  Future<void> _outfitReady = Future<void>.value();

  /// Completes once the equipped outfit is on every sprite.
  Future<void> get outfitReady => _outfitReady;

  /// The sprite actually drawn in place of [base] for the equipped outfit.
  @visibleForTesting
  Sprite wornSprite(Sprite base) => _dressed[base] ?? base;

  Future<void> _tailorOutfit() async {
    final job = ++_tailoringJob;
    final colors = skin.outfit;
    final dressed = <Sprite, Sprite>{};

    if (!colors.isPlain) {
      final bases = <Sprite>[
        ...?runSprites,
        if (jumpSprite != null) jumpSprite!,
        if (hurtSprite != null) hurtSprite!,
      ];
      for (final base in bases) {
        final image = base.image;
        final data = await image.toByteData();
        if (data == null) continue;
        final pixels = OutfitTailor.dress(
          data.buffer.asUint8List(),
          image.width,
          image.height,
          colors,
        );
        final decoded = Completer<ui.Image>();
        ui.decodeImageFromPixels(
          pixels,
          image.width,
          image.height,
          ui.PixelFormat.rgba8888,
          decoded.complete,
        );
        dressed[base] = Sprite(
          await decoded.future,
          srcPosition: base.srcPosition,
          srcSize: base.srcSize,
        );
      }
    }

    // A newer outfit was chosen while this one was being cut.
    if (job != _tailoringJob) {
      _disposeSprites(dressed.values);
      return;
    }
    final previous = _dressed.values.toList();
    _dressed
      ..clear()
      ..addAll(dressed);
    _disposeSprites(previous);
  }

  void _disposeSprites(Iterable<Sprite> sprites) {
    for (final sprite in sprites) {
      sprite.image.dispose();
    }
  }

  /// Draws a courier sprite wearing the equipped outfit: a glow behind, the
  /// outfit's own clothes on the sprite, and shoe sparks for outfits that
  /// have them.
  void _renderSprite(Canvas canvas, Sprite sprite) {
    if (skin.glowColor != Colors.transparent) {
      final glowPaint = Paint()
        ..color = skin.glowColor.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
      canvas.drawCircle(Offset(size.x / 2, size.y / 2), 24, glowPaint);
    }

    wornSprite(sprite).render(canvas, size: size);

    if (skin.hasSpeedTrail && state == CourierState.running) {
      final sparkPaint = Paint()
        ..color = skin.accentColor.withValues(alpha: 0.75)
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round;
      final stride = (_currentRunFrame % 2 == 0) ? 3.0 : -2.0;
      canvas.drawLine(Offset(2.0 + stride, size.y - 6.0), Offset(16.0 + stride, size.y - 6.0), sparkPaint);
      canvas.drawLine(Offset(-4.0 - stride, size.y - 12.0), Offset(8.0 - stride, size.y - 12.0), sparkPaint);
    }
  }

  /// Whether the courier is actively tucked inside a companion cyclist's slipstream draft wake.
  bool isDrafting = false;

  CourierState state = CourierState.running;

  /// Whether the courier is currently sliding along a metallic grind rail.
  bool get isGrinding => state == CourierState.grinding;

  /// Whether the courier is currently executing an agile parkour obstacle vault.
  bool get isVaulting => state == CourierState.vaulting;

  /// Whether the courier is currently gliding with deployed delivery poncho canopy.
  bool get isGliding => state == CourierState.gliding;

  /// Whether the courier is currently suspended from a swinging construction crane hook.
  bool get isSwinging => state == CourierState.swinging;

  /// The active crane component the courier is currently attached to.
  CraneSwingComponent? attachedCrane;

  /// Whether the courier is currently sliding along an aerial catenary power line.
  bool get isZiplining => state == CourierState.ziplining;

  /// The active catenary zipline component the courier is currently riding.
  CatenaryZiplineComponent? attachedZipline;

  /// Cumulative distance in meters traveled during the active glide session.
  double glideDistance = 0.0;

  double _vaultTimer = 0.0;
  static const double defaultVaultDuration = 0.36;

  /// Cumulative distance in meters traveled during the current grind session.
  double grindDistance = 0.0;

  /// True when the courier is under the Cold Brew Energy Drink speed/magnet buff.
  bool isBoosted = false;

  /// How close to touchdown, in seconds, a jump press is queued to fire on
  /// landing instead of being spent on the glide chute.
  ///
  /// Without this, a tap a few frames early deploys the chute and the courier
  /// lands flat-footed in front of the next hazard.
  static const double jumpBufferDuration = 0.10;

  /// Slack added to the queued press so frame quantization on the landing
  /// frame cannot expire it one tick early.
  static const double _jumpBufferSlack = 0.05;

  double _jumpBufferTimer = 0.0;
  double _bufferedImpulseMultiplier = 1.0;
  bool _jumpInputHeld = false;

  /// Whether the press that made the current jump is still down.
  bool get isJumpHeld => _jumpInputHeld;

  /// Whether a jump press is queued to fire on the next touchdown.
  bool get hasBufferedJump => _jumpBufferTimer > 0;

  // Invulnerability
  static const double invulnerabilityDuration = 1.5;
  double _invulnerabilityTimer = 0.0;
  bool get isInvulnerable => _invulnerabilityTimer > 0;

  /// True once the last package is dropped: the courier is bowled over and
  /// stays down until the next run, instead of jogging in place behind the
  /// results screen.
  bool isKnockedOut = false;

  /// Backward tumble rotation in radians while knocked out.
  double knockoutAngle = 0.0;

  static const double _knockoutSpinRate = 5.5;
  static const double _knockoutMaxAngle = math.pi / 2;

  /// How far the pivot rises as the courier settles, so the body rests on the
  /// pavement instead of sinking through it once rotated flat.
  static const double _knockoutRestLift = 14.0;

  /// Bowls the courier over after the final package is dropped: a short pop
  /// that tumbles backward onto the pavement.
  void knockOut() {
    if (isKnockedOut) return;
    isKnockedOut = true;
    knockoutAngle = 0.0;
    _jumpBufferTimer = 0.0;
    _jumpInputHeld = false;
    if (isGliding) stopGlide();
    isDrafting = false;
    state = CourierState.hurt;
    simulator.launch(230.0);
  }

  // Animation cycle timer for running frames
  double _runCycleTimer = 0.0;
  int _currentRunFrame = 0;

  /// Curated Kenney character sprites for running, jumping, and hurt states.
  List<Sprite>? runSprites;
  Sprite? jumpSprite;
  Sprite? hurtSprite;

  late final RectangleHitbox torsoHitbox;

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    try {
      runSprites = await Future.wait([
        Sprite.load('courier/run_1.png'),
        Sprite.load('courier/run_2.png'),
        Sprite.load('courier/run_3.png'),
        Sprite.load('courier/run_4.png'),
      ]);
      jumpSprite = await Sprite.load('courier/jump.png');
      hurtSprite = await Sprite.load('courier/hurt.png');
      // Not awaited: the art is usable as it is, and the outfit swaps in a
      // moment later.
      _outfitReady = _tailorOutfit();
    } catch (_) {
      // In headless test environments where asset bundles are mocked or unavailable,
      // fallback smoothly to procedural vector drawings.
      runSprites = null;
      jumpSprite = null;
      hurtSprite = null;
    }

    // Hitbox calibrated to the courier's torso and backpack (32x48 centered horizontally)
    // to prevent punitive collisions on swinging arms/feet.
    torsoHitbox = RectangleHitbox(
      position: Vector2((size.x - 32) / 2, size.y - 52),
      size: Vector2(32, 48),
    );
    add(torsoHitbox);
  }

  /// Handles a jump input press (tap down / key down).
  ///
  /// Jumps when possible. Otherwise, a press made within [jumpBufferDuration]
  /// of touchdown is queued and fires on landing; any other airborne press
  /// toggles the delivery glide chute.
  void pressJump({double impulseMultiplier = 1.0}) {
    if (isKnockedOut) return;
    _jumpInputHeld = true;
    if (jump(impulseMultiplier: impulseMultiplier)) return;

    final isAboutToLand = !isGliding &&
        state != CourierState.hurt &&
        simulator.verticalVelocity <= 0 &&
        simulator.timeToLanding <= jumpBufferDuration;
    if (isAboutToLand) {
      _jumpBufferTimer = jumpBufferDuration + _jumpBufferSlack;
      _bufferedImpulseMultiplier = impulseMultiplier;
      return;
    }
    toggleGlide();
  }

  /// Handles a jump input release (tap up / key up), shortening the trajectory.
  void releaseJump() {
    _jumpInputHeld = false;
    stopJump();
  }

  /// Restores input and damage state to a clean slate at the start of a run,
  /// so a queued jump or leftover hit flicker never carries across shifts.
  void resetForRun() {
    _jumpBufferTimer = 0.0;
    _jumpInputHeld = false;
    _invulnerabilityTimer = 0.0;
    isKnockedOut = false;
    knockoutAngle = 0.0;
  }

  /// Triggers a jump. Returns `true` if initiated, `false` if rejected (e.g. airborne).
  /// If initiated while grinding, executes a high-pop Rail Ollie combo jump.
  /// If initiated while grounded near a low vaultable obstacle, executes an agile parkour vault.
  /// If initiated while airborne, toggles the delivery glide chute.
  bool jump({double impulseMultiplier = 1.0}) {
    if (state == CourierState.swinging) {
      return releaseCraneSwing();
    }

    if (state == CourierState.ziplining) {
      return releaseZipline();
    }

    if (state == CourierState.grinding) {
      state = CourierState.jumping;
      simulator.launch(340.0 * impulseMultiplier);
      onJump?.call();
      onRailOllie?.call();
      return true;
    }

    if (simulator.isGrounded && checkCanVault != null && checkCanVault!()) {
      startVault();
      onVault?.call();
      return true;
    }

    if (isDrafting && simulator.isGrounded) {
      isDrafting = false;
      state = CourierState.jumping;
      simulator.launch(360.0 * impulseMultiplier);
      onJump?.call();
      onDraftSlingshot?.call();
      return true;
    }

    if (simulator.startJump(impulseMultiplier: impulseMultiplier)) {
      state = CourierState.jumping;
      onJump?.call();
      return true;
    }

    return false;
  }

  /// Deploys emergency delivery glide chute while airborne.
  bool deployGlide() {
    if (simulator.isGrounded || state == CourierState.hurt || state == CourierState.gliding) {
      return false;
    }
    startGlide();
    return true;
  }

  /// Toggles delivery glide chute while airborne.
  bool toggleGlide() {
    if (simulator.isGrounded || state == CourierState.hurt) return false;
    if (isGliding) {
      stopGlide();
      return true;
    } else {
      startGlide();
      return true;
    }
  }

  /// Deploys emergency delivery glide chute while airborne.
  void startGlide() {
    if (simulator.isGrounded || state == CourierState.hurt) return;
    state = CourierState.gliding;
    simulator.isGliding = true;
    glideDistance = 0.0;
    onGlideStarted?.call();
  }

  /// Stows delivery glide chute, reverting to standard gravity fall.
  void stopGlide() {
    if (state == CourierState.gliding) {
      simulator.isGliding = false;
      state = CourierState.falling;
      onGlideEnded?.call();
    }
  }

  /// Initiates grinding along a rail surface at [railSurfaceY].
  void startGrinding(double railSurfaceY) {
    setTargetSurfaceY(railSurfaceY);
    simulator.currentY = railSurfaceY;
    simulator.verticalVelocity = 0.0;
    simulator.isGrounded = true;
    state = CourierState.grinding;
    grindDistance = 0.0;
  }

  /// Concludes grinding, reverting to standard running.
  void endGrinding() {
    if (state == CourierState.grinding) {
      state = CourierState.running;
    }
    grindDistance = 0.0;
  }

  /// Initiates an agile parkour speed vault over a low obstacle.
  void startVault({double impulse = 220.0}) {
    state = CourierState.vaulting;
    _vaultTimer = defaultVaultDuration;
    simulator.launch(impulse);
  }

  /// Launches the courier into an aerial trajectory from a ramp.
  void launchFromRamp({double impulse = 420.0}) {
    simulator.launch(impulse);
    state = CourierState.jumping;
    onJump?.call();
  }

  /// Sets an elevated landing surface (e.g. scaffolding walkway).
  void setTargetSurfaceY(double y) {
    simulator.setSurfaceY(y);
  }

  /// Resets landing surface back to the ground sidewalk.
  void resetTargetSurfaceY() {
    simulator.resetSurfaceY();
  }

  /// Whether the courier is currently elevated above street level.
  bool get isElevated => simulator.currentSurfaceY < groundY;

  bool _isReturningFromCrane = false;

  /// Attaches the courier to an overhead construction crane swing harness.
  void attachToCrane(CraneSwingComponent crane) {
    if (isSwinging) return;
    if (isGliding) stopGlide();
    attachedCrane = crane;
    state = CourierState.swinging;
    simulator.isGrounded = false;
    simulator.verticalVelocity = 0.0;
    _isReturningFromCrane = false;
    crane.attachCourier();
  }

  /// Releases the courier from the crane hook, catapulting into high-speed aerial flight.
  bool releaseCraneSwing() {
    if (state != CourierState.swinging || attachedCrane == null) return false;
    final swingAngle = attachedCrane!.swingAngle;
    final impulse = attachedCrane!.releaseCourier();
    attachedCrane = null;
    state = CourierState.jumping;
    simulator.launch(impulse.y);
    _isReturningFromCrane = true;
    onJump?.call();
    onCraneLaunch?.call(swingAngle);
    return true;
  }

  /// Attaches the courier to an overhead catenary power line zipline.
  void attachToZipline(CatenaryZiplineComponent zipline) {
    if (isZiplining || isSwinging) return;
    if (isGliding) stopGlide();
    attachedZipline = zipline;
    state = CourierState.ziplining;
    simulator.isGrounded = false;
    simulator.verticalVelocity = 0.0;
    zipline.attachCourier();
  }

  /// Releases the courier from the catenary wire, catapulting with forward and upward momentum.
  bool releaseZipline({Vector2? launchImpulse}) {
    if (state != CourierState.ziplining || attachedZipline == null) return false;
    final zipline = attachedZipline!;
    attachedZipline = null;
    state = CourierState.jumping;
    final impulse = launchImpulse ?? zipline.releaseCourier();
    simulator.launch(impulse.y);
    onJump?.call();
    return true;
  }

  /// Releases jump hold to shorten trajectory.
  void stopJump() {
    simulator.stopJump();
  }

  /// Applies damage from a hazard.
  ///
  /// Returns `true` if damage was registered; `false` if ignored due to invulnerability.
  bool takeDamage() {
    if (isInvulnerable || isSwinging || isZiplining) return false;

    if (isGliding) {
      stopGlide();
    }
    _invulnerabilityTimer = invulnerabilityDuration;
    state = CourierState.hurt;
    onDamage?.call();
    return true;
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (isKnockedOut) {
      simulator.update(dt);
      position.y = simulator.currentY - size.y;
      knockoutAngle = math.min(_knockoutMaxAngle, knockoutAngle + (_knockoutSpinRate * dt));
      state = CourierState.hurt;
      return;
    }

    final wasAirborne = !simulator.isGrounded;

    if (state == CourierState.swinging && attachedCrane != null) {
      final hookPos = attachedCrane!.hookPosition;
      position.x = hookPos.x - (size.x / 2);
      position.y = hookPos.y - 12.0;
      simulator.currentY = position.y + size.y;
    } else if (state == CourierState.ziplining && attachedZipline != null) {
      final footX = position.x + (size.x * 0.5);
      final wireY = attachedZipline!.cableYAt(footX);
      position.y = wireY - 14.0;
      simulator.currentY = position.y + size.y;
      simulator.verticalVelocity = 0.0;
    } else {
      simulator.update(dt);
      position.y = simulator.currentY - size.y;

      if (_isReturningFromCrane) {
        position.x += (defaultPlayerX - position.x) * (4.0 * dt).clamp(0.0, 1.0);
        if ((position.x - defaultPlayerX).abs() < 1.0) {
          position.x = defaultPlayerX;
          _isReturningFromCrane = false;
        }
      }
    }

    // Fire a queued jump the frame the courier touches down
    if (_jumpBufferTimer > 0) {
      if (simulator.isGrounded) {
        _jumpBufferTimer = 0.0;
        if (wasAirborne) onLand?.call();
        if (jump(impulseMultiplier: _bufferedImpulseMultiplier) && !_jumpInputHeld) {
          simulator.stopJump();
        }
      } else {
        _jumpBufferTimer = math.max(0.0, _jumpBufferTimer - dt);
      }
    }

    // Handle invulnerability countdown
    if (_invulnerabilityTimer > 0) {
      _invulnerabilityTimer -= dt;
      if (_invulnerabilityTimer < 0) {
        _invulnerabilityTimer = 0;
      }
    }

    // State machine updates
    if (state == CourierState.vaulting) {
      _vaultTimer -= dt;
      if (_vaultTimer <= 0 || simulator.isGrounded) {
        if (simulator.isGrounded) {
          state = CourierState.running;
          if (wasAirborne) onLand?.call();
        } else {
          state = CourierState.falling;
        }
      }
    } else if (state == CourierState.gliding) {
      if (simulator.isGrounded) {
        state = CourierState.running;
        simulator.isGliding = false;
        if (wasAirborne) onLand?.call();
        onGlideEnded?.call();
      }
    } else if (state == CourierState.swinging) {
      // Retain swinging state while attached to crane hook
    } else if (state == CourierState.ziplining) {
      // Retain ziplining state while sliding on catenary wire
    } else if (!simulator.isGrounded) {
      if (_invulnerabilityTimer > 0 && state == CourierState.hurt) {
        // Retain hurt visual during invulnerability
      } else if (simulator.verticalVelocity > 0) {
        state = CourierState.jumping;
      } else {
        state = CourierState.falling;
      }
    } else {
      if (wasAirborne) {
        onLand?.call();
      }
      if (_invulnerabilityTimer > 0) {
        state = CourierState.hurt;
      } else if (state == CourierState.grinding) {
        // Retain grinding state while grounded on rail
      } else {
        state = CourierState.running;
      }
    }

    // Run animation ticker
    if (state == CourierState.running) {
      _runCycleTimer += dt;
      if (_runCycleTimer >= 0.12) {
        _runCycleTimer = 0.0;
        _currentRunFrame = (_currentRunFrame + 1) % 4;
      }
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    // Knocked out: tumble backward about the feet and come to rest on the pavement
    if (isKnockedOut) {
      final settle = knockoutAngle / _knockoutMaxAngle;
      canvas.save();
      canvas.translate(size.x / 2, size.y - (_knockoutRestLift * settle));
      canvas.rotate(-knockoutAngle);
      canvas.translate(-size.x / 2, -size.y);
      if (hurtSprite != null) {
        _renderSprite(canvas, hurtSprite!);
      } else {
        _drawCourier(canvas);
      }
      canvas.restore();
      return;
    }

    // Render electric energy aura when boosted by cold brew
    if (isBoosted) {
      _drawEnergyAura(canvas);
    }

    // Invulnerability flicker: strobe alpha at 10Hz
    if (isInvulnerable) {
      final flicker = ((_invulnerabilityTimer * 10).floor() % 2) == 0;
      if (flicker) return;
    }

    if (state == CourierState.hurt && hurtSprite != null) {
      _renderSprite(canvas, hurtSprite!);
    } else if ((state == CourierState.jumping || state == CourierState.falling) && jumpSprite != null) {
      _renderSprite(canvas, jumpSprite!);
    } else if (state == CourierState.running && runSprites != null && runSprites!.isNotEmpty) {
      _renderSprite(canvas, runSprites![_currentRunFrame % runSprites!.length]);
    } else {
      _drawCourier(canvas);
    }
  }

  void _drawEnergyAura(Canvas canvas) {
    final center = Offset(size.x / 2, size.y / 2);
    final pulse = 0.5 + 0.5 * math.sin(_runCycleTimer * 25.0);

    // Glowing electric halo
    final glowPaint = Paint()
      ..color = const Color(0xFF2ECC71).withValues(alpha: 0.35 + 0.15 * pulse)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    canvas.drawCircle(center, 30 + 4 * pulse, glowPaint);

    final innerGlowPaint = Paint()
      ..color = const Color(0xFFF1C40F).withValues(alpha: 0.5 + 0.2 * pulse)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawCircle(center, 24, innerGlowPaint);

    // Speed trails behind the courier
    final trailPaint = Paint()
      ..color = const Color(0xFF00E676).withValues(alpha: 0.7)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final trailOffsets = [-6.0, 4.0, 14.0];
    for (var i = 0; i < trailOffsets.length; i++) {
      final y = center.dy + trailOffsets[i];
      final length = 18.0 + (i % 2 == 0 ? 8.0 * pulse : -4.0 * pulse);
      canvas.drawLine(
        Offset(-length, y),
        Offset(6.0, y),
        trailPaint,
      );
    }
  }

  void _drawCourier(Canvas canvas) {
    // Ambient vanity glow for neon / golden skins
    if (skin.glowColor != Colors.transparent) {
      final glowPaint = Paint()
        ..color = skin.glowColor.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
      canvas.drawCircle(const Offset(30, 30), 22, glowPaint);
    }

    // Stylized courier rendering: courier shirt, cap, delivery backpack
    final bodyPaint = Paint()..color = skin.primaryColor;
    final backpackPaint = Paint()..color = const Color(0xFFE67E22);
    final skinPaint = Paint()..color = const Color(0xFFF5CBA7);
    final capPaint = Paint()..color = skin.accentColor;
    final pantsPaint = Paint()..color = skin.accentColor;

    // Torso / Jacket
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(18, 20, 24, 26),
        const Radius.circular(4),
      ),
      bodyPaint,
    );

    // Delivery Backpack on courier's back
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(10, 22, 12, 22),
        const Radius.circular(3),
      ),
      backpackPaint,
    );

    // Head
    canvas.drawCircle(const Offset(30, 14), 10, skinPaint);

    // Courier Cap (visor pointing right)
    final capPath = Path()
      ..moveTo(20, 12)
      ..lineTo(40, 12)
      ..lineTo(44, 15)
      ..lineTo(20, 15)
      ..close();
    canvas.drawPath(capPath, capPaint);

    // Legs / Running pose offset
    if (state == CourierState.jumping) {
      // Tucked jump legs
      canvas.drawRect(const Rect.fromLTWH(20, 46, 8, 12), pantsPaint);
      canvas.drawRect(const Rect.fromLTWH(30, 44, 8, 10), pantsPaint);
    } else if (state == CourierState.falling) {
      // Extended landing legs
      canvas.drawRect(const Rect.fromLTWH(22, 46, 8, 16), pantsPaint);
      canvas.drawRect(const Rect.fromLTWH(32, 46, 8, 16), pantsPaint);
    } else if (state == CourierState.grinding) {
      // Crouched grinding stance with skateboard deck locked onto the rail
      canvas.drawRect(const Rect.fromLTWH(18, 50, 10, 10), pantsPaint);
      canvas.drawRect(const Rect.fromLTWH(34, 48, 10, 12), pantsPaint);

      // Grind skateboard / sole plate
      final boardPaint = Paint()..color = const Color(0xFF1ABC9C);
      canvas.drawRRect(
        RRect.fromRectAndRadius(const Rect.fromLTWH(12, 59, 40, 4), const Radius.circular(2)),
        boardPaint,
      );

      // Friction sparks showering backwards from under the board
      final sparkPaint = Paint()
        ..color = const Color(0xFFFF9F43)
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(const Offset(10, 61), const Offset(2, 63), sparkPaint);
      canvas.drawLine(const Offset(14, 60), const Offset(6, 65), sparkPaint);
      canvas.drawLine(const Offset(16, 62), const Offset(8, 66), sparkPaint);
    } else if (state == CourierState.vaulting) {
      // Parkour Speed Vault: low forward body pitch, planted lead hand, tucked legs
      canvas.drawRect(const Rect.fromLTWH(14, 40, 18, 8), pantsPaint);
      canvas.drawRect(const Rect.fromLTWH(26, 42, 16, 7), pantsPaint);

      // Planted right arm vaulting downwards
      final armPaint = Paint()
        ..color = skin.primaryColor
        ..strokeWidth = 4.5
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(const Offset(36, 30), const Offset(42, 46), armPaint);
      canvas.drawCircle(const Offset(42, 47), 2.5, skinPaint);

      // Trailing aerodynamic speed wind lines
      final streakPaint = Paint()
        ..color = const Color(0xFF00E5FF).withValues(alpha: 0.75)
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(const Offset(-4, 34), const Offset(10, 34), streakPaint);
      canvas.drawLine(const Offset(-8, 44), const Offset(6, 44), streakPaint);
    } else if (state == CourierState.gliding) {
      // Aerodynamic horizontal flight legs trailing back
      canvas.drawRect(const Rect.fromLTWH(10, 44, 18, 7), pantsPaint);
      canvas.drawRect(const Rect.fromLTWH(24, 46, 16, 6), pantsPaint);

      // Suspension rigging cords from backpack up to parachute canopy
      final cordPaint = Paint()
        ..color = const Color(0xFFBDC3C7)
        ..strokeWidth = 1.2;
      canvas.drawLine(const Offset(22, 22), const Offset(4, -6), cordPaint);
      canvas.drawLine(const Offset(24, 22), const Offset(20, -10), cordPaint);
      canvas.drawLine(const Offset(28, 22), const Offset(44, -10), cordPaint);
      canvas.drawLine(const Offset(30, 22), const Offset(60, -6), cordPaint);

      // Deployed high-visibility delivery parachute canopy arch overhead
      final canopyPath = Path()
        ..moveTo(2, -4)
        ..quadraticBezierTo(32, -18, 62, -4)
        ..quadraticBezierTo(32, -10, 2, -4)
        ..close();
      final canopyPaint = Paint()..color = const Color(0xFFFF5722);
      canvas.drawPath(canopyPath, canopyPaint);

      // Reflective safety chevron stripe along canopy
      final stripePath = Path()
        ..moveTo(14, -7)
        ..quadraticBezierTo(32, -14, 50, -7)
        ..quadraticBezierTo(32, -11, 14, -7)
        ..close();
      final stripePaint = Paint()..color = Colors.white.withValues(alpha: 0.9);
      canvas.drawPath(stripePath, stripePaint);

      // Trailing cyan aerodynamic wind glide lines
      final windPaint = Paint()
        ..color = const Color(0xFF00E5FF).withValues(alpha: 0.7)
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(const Offset(-10, 36), const Offset(6, 36), windPaint);
      canvas.drawLine(const Offset(-16, 44), const Offset(2, 44), windPaint);
      canvas.drawLine(const Offset(-6, 28), const Offset(12, 28), windPaint);
    } else if (state == CourierState.swinging) {
      // Arms reaching overhead gripping the crane harness hook ring
      final armPaint = Paint()
        ..color = skin.primaryColor
        ..strokeWidth = 4.0
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(const Offset(24, 22), const Offset(28, 4), armPaint);
      canvas.drawLine(const Offset(32, 22), const Offset(36, 4), armPaint);
      canvas.drawCircle(const Offset(28, 3), 2.5, skinPaint);
      canvas.drawCircle(const Offset(36, 3), 2.5, skinPaint);

      // Trailing wind-swept legs swinging with pendulum momentum
      canvas.drawRect(const Rect.fromLTWH(18, 46, 8, 14), pantsPaint);
      canvas.drawRect(const Rect.fromLTWH(28, 48, 8, 14), pantsPaint);
    } else if (state == CourierState.ziplining) {
      // Arms reaching overhead gripping insulated catenary trolley handle
      final armPaint = Paint()
        ..color = skin.primaryColor
        ..strokeWidth = 4.0
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(const Offset(24, 22), const Offset(28, 4), armPaint);
      canvas.drawLine(const Offset(32, 22), const Offset(36, 4), armPaint);

      // Insulated carbon-fiber grip gloves
      final glovePaint = Paint()
        ..color = const Color(0xFF263238)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(const Offset(28, 3), 3.0, glovePaint);
      canvas.drawCircle(const Offset(36, 3), 3.0, glovePaint);

      // Electric contact corona sparks
      final sparkPaint = Paint()
        ..color = const Color(0xFF00E5FF)
        ..strokeWidth = 1.5;
      canvas.drawLine(const Offset(24, 1), const Offset(40, 1), sparkPaint);

      // Trailing aerodynamic legs
      canvas.drawRect(const Rect.fromLTWH(14, 46, 8, 14), pantsPaint);
      canvas.drawRect(const Rect.fromLTWH(24, 48, 8, 14), pantsPaint);
    } else {
      // Alternating run stride
      final legOffset = (_currentRunFrame % 2 == 0) ? 4.0 : -4.0;
      canvas.drawRect(Rect.fromLTWH(20 + legOffset, 46, 8, 16), pantsPaint);
      canvas.drawRect(Rect.fromLTWH(32 - legOffset, 46, 8, 16), pantsPaint);

      // Trailing shoe spark VFX for high-top sneakers
      if (skin.hasSpeedTrail) {
        final sparkPaint = Paint()
          ..color = skin.accentColor.withValues(alpha: 0.6)
          ..strokeWidth = 2.0;
        canvas.drawLine(
          Offset(12.0 + legOffset, 60.0),
          Offset(20.0 + legOffset, 60.0),
          sparkPaint,
        );
      }
    }
  }
}
