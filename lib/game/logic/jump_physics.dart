import 'dart:math' as math;

/// Pure Dart jump physics simulator using semi-implicit Euler integration.
///
/// Implements variable height jump mechanics for Courier Dash:
/// - A quick 80ms tap produces a short ~70px hop to clear small obstacles (scooters, dogs).
/// - A full 250ms hold produces a high ~180px leap to clear vans or elevated hazards.
/// - Any shorter tap is stretched to the 80ms hop, so a quick flick always clears
///   a scooter or dog instead of producing a hop too low to matter.
/// - Running off a ledge leaves a brief coyote window in which a jump still registers.
/// - Gravity acceleration: 980 px/s²
/// - Headless testable without Flame canvas dependencies.
class JumpPhysicsSimulator {
  JumpPhysicsSimulator({
    this.gravity = 980.0,
    this.initialImpulse = 240.0,
    this.holdAcceleration = 1760.0,
    this.maxHoldTime = 0.250,
    this.minHoldTime = 0.080,
    this.coyoteDuration = 0.100,
    this.groundY = 460.0,
  }) {
    targetSurfaceY = groundY;
    currentY = groundY;
  }

  /// Downward gravitational acceleration in px/s².
  final double gravity;

  /// Instantaneous vertical velocity impulse upon initiating a jump (px/s).
  final double initialImpulse;

  /// Sustained upward acceleration while jump input is held (px/s²).
  final double holdAcceleration;

  /// Maximum duration in seconds that holding input sustains upward force.
  final double maxHoldTime;

  /// Minimum duration in seconds a jump is sustained even if input is released
  /// sooner, so every tap produces at least the short hop.
  final double minHoldTime;

  /// Grace window in seconds after running off a ledge during which a jump
  /// is still accepted as if grounded.
  final double coyoteDuration;

  /// Baseline ground surface Y coordinate in screen coordinates.
  final double groundY;

  /// Current surface Y coordinate where the courier can land (defaults to groundY).
  late double targetSurfaceY;

  /// Returns the current active surface baseline coordinate.
  double get currentSurfaceY => targetSurfaceY;

  /// Current Y coordinate of the avatar in screen coordinates.
  double currentY = 0.0;

  /// Current vertical velocity (positive = upward, negative = downward).
  double verticalVelocity = 0.0;

  /// Whether the avatar is currently resting on the ground.
  bool isGrounded = true;

  /// Whether jump input is currently being held down.
  bool isHolding = false;

  /// Whether aerodynamic gliding chute is active, reducing descent speed.
  bool isGliding = false;

  /// Whether courier is actively hydroplaning through hydrant water spray,
  /// enhancing aerodynamic glide buoyancy (+25% float duration).
  bool isHydroplaning = false;

  /// Whether courier is actively buoyed by a sidewalk subway exhaust thermal updraft,
  /// enhancing aerodynamic glide buoyancy (+35% float hang time).
  bool isThermalUpdraft = false;

  /// Elapsed duration in seconds for the current jump hold.
  double holdTimer = 0.0;

  /// True when input was released before [minHoldTime]; the hold ends as soon
  /// as the minimum is reached.
  bool _releasePending = false;

  /// Remaining coyote grace in seconds (only armed by running off a ledge).
  double _coyoteTimer = 0.0;

  /// Whether a jump would currently be accepted: grounded, or just ran off a ledge.
  bool get canJump => isGrounded || _coyoteTimer > 0;

  /// Estimated seconds until touchdown on the current surface under free fall,
  /// or 0 when grounded. Ignores glide drag and jump hold thrust.
  double get timeToLanding {
    if (isGrounded) return 0.0;
    final height = (targetSurfaceY - currentY).clamp(0.0, double.infinity);
    final v = verticalVelocity;
    return (v + math.sqrt((v * v) + (2.0 * gravity * height))) / gravity;
  }

  /// Height in pixels above the ground plane (0.0 when grounded).
  double get heightAboveGround =>
      (groundY - currentY).clamp(0.0, double.infinity);

  /// Sets an elevated surface Y coordinate (e.g. scaffolding platform).
  void setSurfaceY(double y) {
    targetSurfaceY = y;
    if (currentY < targetSurfaceY && isGrounded) {
      // Surface beneath avatar dropped (e.g. walked off scaffolding edge)
      isGrounded = false;
      verticalVelocity = 0.0;
      _coyoteTimer = coyoteDuration;
    }
  }

  /// Resets target surface baseline to the default ground floor.
  void resetSurfaceY() {
    setSurfaceY(groundY);
  }

  /// How much higher the courier will climb from here with no further help:
  /// what is left of a held jump's boost, then whatever speed carries.
  double get riseRemaining {
    if (isGrounded || verticalVelocity <= 0) return 0.0;
    var speed = verticalVelocity;
    var rise = 0.0;
    if (isHolding) {
      final until = _releasePending ? minHoldTime : maxHoldTime;
      final boost = math.max(0.0, until - holdTimer);
      final acceleration = holdAcceleration - gravity;
      rise += speed * boost + 0.5 * acceleration * boost * boost;
      speed += acceleration * boost;
    }
    return rise + speed * speed / (2 * gravity);
  }

  /// Whether a jump already under way will climb higher on its own than
  /// being sent upward at [speed] would take it.
  ///
  /// Help from the street never costs height. Fourteen street pieces launch
  /// the courier (an awning, a storm drain, a satellite dish, a thermal),
  /// most at 200 to 240 px/s, and a held leap climbs at up to 435. Setting
  /// the speed to the launch's and ending the hold, as a launch used to,
  /// cut a leap that brushed one of them down to a hop: the courier leapt
  /// a van, touched a newsstand on the way up and came down on the van.
  bool _outclimbs(double speed) =>
      speed > 0 && riseRemaining > speed * speed / (2 * gravity);

  /// Launches the avatar upward with an external velocity impulse (e.g. construction ramp).
  ///
  /// Does nothing to a courier whose own jump is already taking them higher.
  void launch(double impulse) {
    if (_outclimbs(impulse)) return;
    isGrounded = false;
    isHolding = false;
    _releasePending = false;
    _coyoteTimer = 0.0;
    holdTimer = 0.0;
    verticalVelocity = impulse;
  }

  /// Applies a continuous or impulse vertical updraft lift (e.g. steam vent).
  ///
  /// Like [launch], it leaves a jump that is already climbing higher alone:
  /// it used to end the hold of a leap passing through it.
  void applyUpdraft(double upwardVelocity, {double maxUpwardSpeed = 420.0}) {
    if (_outclimbs(upwardVelocity.clamp(-maxUpwardSpeed, maxUpwardSpeed).toDouble())) return;
    isGrounded = false;
    isHolding = false;
    _releasePending = false;
    _coyoteTimer = 0.0;
    holdTimer = 0.0;
    if (verticalVelocity < upwardVelocity) {
      verticalVelocity = upwardVelocity.clamp(-maxUpwardSpeed, maxUpwardSpeed);
    }
  }

  /// Initiates a jump from the ground, or within the coyote window after
  /// running off a ledge.
  ///
  /// Returns `true` if jump successfully initiated; `false` if rejected (e.g. mid-air).
  bool startJump({double impulseMultiplier = 1.0}) {
    if (!canJump) return false;

    isGrounded = false;
    isHolding = true;
    _releasePending = false;
    _coyoteTimer = 0.0;
    holdTimer = 0.0;
    verticalVelocity = initialImpulse * impulseMultiplier;
    return true;
  }

  /// Cancels holding the jump button, allowing gravity to take full effect.
  ///
  /// A release before [minHoldTime] is deferred until the minimum is reached.
  void stopJump() {
    if (isHolding && holdTimer < minHoldTime) {
      _releasePending = true;
      return;
    }
    isHolding = false;
  }

  /// Updates physics state by [dt] seconds using semi-implicit Euler integration.
  void update(double dt) {
    if (isGrounded) {
      _coyoteTimer = 0.0;
      return;
    }

    if (_coyoteTimer > 0) {
      _coyoteTimer = math.max(0.0, _coyoteTimer - dt);
    }

    if (isHolding) {
      if (_releasePending && holdTimer >= minHoldTime) {
        // Deferred release: the minimum hold has been fully served.
        isHolding = false;
        _releasePending = false;
      } else {
        holdTimer += dt;
        if (holdTimer >= maxHoldTime) {
          isHolding = false;
          _releasePending = false;
        }
      }
    }

    final double effectiveAcceleration;
    if (isHolding && verticalVelocity > 0) {
      effectiveAcceleration = -gravity + holdAcceleration;
    } else if (isGliding && verticalVelocity < 0) {
      // Gentle aerodynamic glide descent (buoyant when hydroplaning or catching thermal updraft)
      effectiveAcceleration = -gravity * (isThermalUpdraft ? 0.10 : (isHydroplaning ? 0.13 : 0.18));
    } else {
      effectiveAcceleration = -gravity;
    }

    verticalVelocity += effectiveAcceleration * dt;
    final terminalGlideVelocity = isThermalUpdraft
        ? -35.0
        : (isHydroplaning ? -42.0 : -55.0);
    if (isGliding && verticalVelocity < terminalGlideVelocity) {
      verticalVelocity = terminalGlideVelocity; // Terminal gentle glide descent rate
    }

    // In screen coordinates, positive vertical velocity moves avatar upward (decreasing Y)
    currentY -= verticalVelocity * dt;

    if (verticalVelocity <= 0 && currentY >= targetSurfaceY) {
      currentY = targetSurfaceY;
      verticalVelocity = 0.0;
      isGrounded = true;
      isHolding = false;
      _releasePending = false;
      _coyoteTimer = 0.0;
      isGliding = false;
      holdTimer = 0.0;
    } else if (currentY >= groundY) {
      // Safety net: absolute ground floor
      currentY = groundY;
      verticalVelocity = 0.0;
      isGrounded = true;
      isHolding = false;
      _releasePending = false;
      _coyoteTimer = 0.0;
      isGliding = false;
      holdTimer = 0.0;
      targetSurfaceY = groundY;
    }
  }

  /// Simulates a jump with a given hold duration and time step, returning the peak height reached.
  static double simulateJumpPeak({
    required double holdDuration,
    double dt = 1.0 / 60.0,
    double gravity = 980.0,
    double initialImpulse = 240.0,
    double holdAcceleration = 1760.0,
    double maxHoldTime = 0.250,
  }) {
    final sim = JumpPhysicsSimulator(
      gravity: gravity,
      initialImpulse: initialImpulse,
      holdAcceleration: holdAcceleration,
      maxHoldTime: maxHoldTime,
    );

    sim.startJump();
    double maxPeak = 0.0;
    double elapsed = 0.0;

    while (elapsed < 3.0) {
      if (elapsed >= holdDuration && sim.isHolding) {
        sim.stopJump();
      }
      sim.update(dt);
      elapsed += dt;

      if (sim.heightAboveGround > maxPeak) {
        maxPeak = sim.heightAboveGround;
      }
      if (sim.isGrounded && elapsed > 0.05) {
        break;
      }
    }

    return maxPeak;
  }
}
