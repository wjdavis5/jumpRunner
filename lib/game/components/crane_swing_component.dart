import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// Industrial construction crane towering overhead with a physics-simulated
/// pendulum swing cable and high-visibility grab harness for aerial chasm traversal.
class CraneSwingComponent extends PositionComponent {
  CraneSwingComponent({
    required Vector2 position,
    Vector2? size,
    Vector2? anchorOffset,
    this.cableLength = 175.0,
    this.gravity = 980.0,
  })  : anchorOffset = anchorOffset ?? Vector2(140.0, 42.0),
        super(
          position: position,
          size: size ?? Vector2(260.0, 320.0),
        );

  /// Anchor point offset on the crane boom arm from which the cable dangles.
  final Vector2 anchorOffset;

  /// Length of the braided steel cable in pixels.
  final double cableLength;

  /// Gravitational acceleration applied to pendulum simulation (px/s²).
  final double gravity;

  /// Current pendulum deflection angle in radians (0 = straight down, positive = forward).
  double swingAngle = 0.0;

  /// Current angular velocity in radians per second.
  double angularVelocity = 0.0;

  /// Pendulum damping coefficient to dissipate swing energy.
  double damping = 0.15;

  /// True when the courier is currently hooked into the swing harness.
  bool isCourierAttached = false;

  /// True once the swing launch has been executed.
  bool hasLaunched = false;

  /// Whether this crane has scrolled completely past the screen horizon.
  bool get shouldRecycle => position.x + size.x < -180.0;

  double _swayTimer = 0.0;
  double _beaconTimer = 0.0;
  bool _beaconOn = true;

  /// Returns whether the aviation warning beacon is illuminated.
  bool get beaconOn => _beaconOn;

  /// Global world position of the cable grab hook ring.
  Vector2 get hookPosition => Vector2(
        position.x + anchorOffset.x + math.sin(swingAngle) * cableLength,
        position.y + anchorOffset.y + math.cos(swingAngle) * cableLength,
      );

  /// Local coordinates of the cable grab hook ring relative to this component.
  Vector2 get localHookPosition => Vector2(
        anchorOffset.x + math.sin(swingAngle) * cableLength,
        anchorOffset.y + math.cos(swingAngle) * cableLength,
      );

  /// Checks if the courier's hands/torso are within grab range of the hook ring.
  bool canGrabHook(Vector2 playerPosition, Vector2 playerSize) {
    if (hasLaunched || isCourierAttached) return false;

    final playerGrabPoint = Vector2(
      playerPosition.x + (playerSize.x / 2),
      playerPosition.y + 14.0,
    );
    final distance = (playerGrabPoint - hookPosition).length;
    return distance <= 42.0;
  }

  /// Latches the courier onto the cable grab hook and imparts forward angular momentum.
  void attachCourier() {
    isCourierAttached = true;
    // Impart strong forward angular velocity when courier leaps into the hook
    angularVelocity = 2.6;
    swingAngle = -0.45;
  }

  /// Releases the courier from the cable and returns (horizontalLaunchImpulse, verticalLaunchImpulse).
  Vector2 releaseCourier() {
    isCourierAttached = false;
    hasLaunched = true;

    // Calculate launch impulses based on pendulum angle and angular speed
    final speed = (cableLength * angularVelocity).abs();
    final horizontalBoost = (speed * math.cos(swingAngle)).clamp(120.0, 380.0);
    final verticalBoost = (370.0 + (swingAngle > 0 ? 90.0 * math.sin(swingAngle) : 0.0)).clamp(330.0, 480.0);

    return Vector2(horizontalBoost, verticalBoost);
  }

  @override
  void update(double dt) {
    super.update(dt);

    // Aviation safety beacon blinker (1.2 Hz)
    _beaconTimer += dt;
    if (_beaconTimer >= 0.42) {
      _beaconTimer = 0.0;
      _beaconOn = !_beaconOn;
    }

    if (isCourierAttached) {
      // Semi-implicit Euler pendulum integration
      final angularAccel =
          -(gravity / cableLength) * math.sin(swingAngle) - (damping * angularVelocity);
      angularVelocity += angularAccel * dt;
      swingAngle += angularVelocity * dt;

      // Auto-launch at forward apex crest or if forward swing starts reversing
      if (swingAngle >= 0.72 || (swingAngle > 0.35 && angularVelocity < -0.15)) {
        // Trigger auto-release in game loop
      }
    } else if (!hasLaunched) {
      // Idle ambient wind sway before grab
      _swayTimer += dt;
      swingAngle = math.sin(_swayTimer * 1.6) * 0.12;
    } else {
      // Post-launch dampening swing back toward resting vertical
      final angularAccel =
          -(gravity / cableLength) * math.sin(swingAngle) - (1.4 * angularVelocity);
      angularVelocity += angularAccel * dt;
      swingAngle += angularVelocity * dt;
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    _renderCraneStructure(canvas);
    _renderCableAndHook(canvas);
  }

  void _renderCraneStructure(Canvas canvas) {
    final mastX = anchorOffset.x - 70.0;
    const mastTopY = 32.0;
    final mastHeight = size.y - mastTopY;

    // 1. Vertical Mast Truss (Industrial Construction Yellow)
    final mastPaint = Paint()
      ..color = const Color(0xFFF39C12)
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke;

    final mastFill = Paint()..color = const Color(0xFF2C3E50).withValues(alpha: 0.85);

    // Mast upright chords (26px wide column)
    final mastRect = Rect.fromLTWH(mastX, mastTopY, 28.0, mastHeight);
    canvas.drawRect(mastRect, mastFill);
    canvas.drawLine(Offset(mastX, mastTopY), Offset(mastX, mastTopY + mastHeight), mastPaint);
    canvas.drawLine(Offset(mastX + 28.0, mastTopY), Offset(mastX + 28.0, mastTopY + mastHeight), mastPaint);

    // Diagonal lattice cross braces
    final latticePaint = Paint()
      ..color = const Color(0xFFD35400)
      ..strokeWidth = 1.8;
    for (double y = mastTopY; y < mastTopY + mastHeight - 20.0; y += 22.0) {
      canvas.drawLine(Offset(mastX, y), Offset(mastX + 28.0, y + 22.0), latticePaint);
      canvas.drawLine(Offset(mastX + 28.0, y), Offset(mastX, y + 22.0), latticePaint);
      canvas.drawLine(Offset(mastX, y + 22.0), Offset(mastX + 28.0, y + 22.0), latticePaint);
    }

    // 2. Crane Apex Tower & Guy Wires
    final apexX = mastX + 14.0;
    const apexY = 10.0;
    final apexPaint = Paint()
      ..color = const Color(0xFFE67E22)
      ..strokeWidth = 3.0;
    canvas.drawLine(Offset(mastX, mastTopY), Offset(apexX, apexY), apexPaint);
    canvas.drawLine(Offset(mastX + 28.0, mastTopY), Offset(apexX, apexY), apexPaint);

    // Flashing Aviation Warning Beacon
    if (_beaconOn) {
      final beaconGlow = Paint()
        ..color = const Color(0xFFE74C3C).withValues(alpha: 0.45)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawCircle(Offset(apexX, apexY), 7.0, beaconGlow);

      final beaconCore = Paint()..color = const Color(0xFFFF5252);
      canvas.drawCircle(Offset(apexX, apexY), 3.0, beaconCore);
    }

    // 3. Horizontal Jib / Boom Arm
    final boomPaint = Paint()
      ..color = const Color(0xFFF1C40F)
      ..strokeWidth = 3.0;
    const boomY = mastTopY + 10.0;
    // Front jib extending forward to anchor
    canvas.drawLine(Offset(mastX + 28.0, boomY), Offset(anchorOffset.x + 40.0, boomY), boomPaint);
    canvas.drawLine(Offset(mastX + 28.0, boomY + 12.0), Offset(anchorOffset.x + 40.0, boomY + 12.0), boomPaint);

    // Boom diagonal webbing
    for (double x = mastX + 28.0; x < anchorOffset.x + 30.0; x += 20.0) {
      canvas.drawLine(Offset(x, boomY), Offset(x + 20.0, boomY + 12.0), latticePaint);
      canvas.drawLine(Offset(x + 20.0, boomY), Offset(x, boomY + 12.0), latticePaint);
    }

    // Guy wire from apex to boom tip
    final wirePaint = Paint()
      ..color = const Color(0xFFBDC3C7)
      ..strokeWidth = 1.4;
    canvas.drawLine(Offset(apexX, apexY), Offset(anchorOffset.x + 35.0, boomY), wirePaint);

    // 4. Rear Counter-Jib & Concrete Counterweight Block
    canvas.drawLine(Offset(mastX, boomY), Offset(mastX - 45.0, boomY), boomPaint);
    canvas.drawLine(Offset(mastX, boomY + 12.0), Offset(mastX - 45.0, boomY + 12.0), boomPaint);
    canvas.drawLine(Offset(apexX, apexY), Offset(mastX - 40.0, boomY), wirePaint);

    final counterweightPaint = Paint()..color = const Color(0xFF7F8C8D);
    final counterweightBorder = Paint()
      ..color = const Color(0xFF34495E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final counterweightRect = Rect.fromLTWH(mastX - 42.0, boomY + 2.0, 22.0, 24.0);
    canvas.drawRect(counterweightRect, counterweightPaint);
    canvas.drawRect(counterweightRect, counterweightBorder);

    // 5. Operator Cab
    final cabPaint = Paint()..color = const Color(0xFFF39C12);
    final cabRect = Rect.fromLTWH(mastX + 29.0, boomY + 4.0, 16.0, 18.0);
    canvas.drawRect(cabRect, cabPaint);
    // Tinted Cab Window
    final windowPaint = Paint()..color = const Color(0xFF1ABC9C).withValues(alpha: 0.8);
    canvas.drawRect(Rect.fromLTWH(mastX + 37.0, boomY + 7.0, 7.0, 10.0), windowPaint);
  }

  void _renderCableAndHook(Canvas canvas) {
    final anchor = Offset(anchorOffset.x, anchorOffset.y);
    final hook = Offset(localHookPosition.x, localHookPosition.y);

    // 1. Braided Steel Cable
    final cablePaint = Paint()
      ..color = const Color(0xFFBDC3C7)
      ..strokeWidth = 2.2;
    canvas.drawLine(anchor, hook, cablePaint);

    // Tension Cable Highlight
    final highlightPaint = Paint()
      ..color = isCourierAttached ? const Color(0xFF00E5FF) : const Color(0xFFECF0F1)
      ..strokeWidth = isCourierAttached ? 2.5 : 1.0;
    canvas.drawLine(anchor, hook, highlightPaint);

    // Pulley Trolley on Boom Arm
    final trolleyPaint = Paint()..color = const Color(0xFF2C3E50);
    canvas.drawCircle(anchor, 5.0, trolleyPaint);

    // 2. High-Visibility Traversal Grab Ring / Harness
    final ringCenter = hook;

    // Glowing aura when ready to grab
    if (!hasLaunched && !isCourierAttached) {
      final glowPaint = Paint()
        ..color = const Color(0xFF00E5FF).withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawCircle(ringCenter, 14.0, glowPaint);
    } else if (isCourierAttached) {
      final tensionGlow = Paint()
        ..color = const Color(0xFFF1C40F).withValues(alpha: 0.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
      canvas.drawCircle(ringCenter, 16.0, tensionGlow);
    }

    // Steel Carabiner / Ring Frame
    final ringPaint = Paint()
      ..color = isCourierAttached ? const Color(0xFFF1C40F) : const Color(0xFF00E5FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5;
    canvas.drawCircle(ringCenter, 9.0, ringPaint);

    // Rubber Grip Wrap
    final gripPaint = Paint()
      ..color = const Color(0xFF1C2833)
      ..strokeWidth = 2.0;
    canvas.drawLine(
      Offset(ringCenter.dx - 6.0, ringCenter.dy + 6.0),
      Offset(ringCenter.dx + 6.0, ringCenter.dy + 6.0),
      gripPaint,
    );
  }
}
