import 'package:flutter/material.dart';

/// A brisk "3, 2, 1" over the frozen street before a paused shift carries on.
///
/// Resuming used to drop the courier straight back in at full speed, with a
/// hazard often a second away and the player's eyes still on the menu. The
/// street stays visible (and still) under the count so there is time to find
/// the courier and the next hazard again.
class ResumeCountdown extends StatefulWidget {
  const ResumeCountdown({super.key, required this.onDone});

  /// Called once, when the count reaches zero.
  final VoidCallback onDone;

  /// How many numbers are counted.
  static const int steps = 3;

  /// How long each number is on screen.
  static const Duration stepDuration = Duration(milliseconds: 350);

  /// The whole count.
  static Duration get total => stepDuration * steps;

  @override
  State<ResumeCountdown> createState() => _ResumeCountdownState();
}

class _ResumeCountdownState extends State<ResumeCountdown>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: ResumeCountdown.total)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) widget.onDone();
      })
      ..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Taps during the count belong to nobody: the shift is still on hold.
    return AbsorbPointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final progress = _controller.value * ResumeCountdown.steps;
          final step = progress.floor().clamp(0, ResumeCountdown.steps - 1);
          final number = ResumeCountdown.steps - step;
          // Each number pops in a little large and settles.
          final within = (progress - step).clamp(0.0, 1.0);
          final scale = 1.0 + 0.35 * (1.0 - Curves.easeOut.transform(within));

          return ColoredBox(
            color: Colors.black.withValues(alpha: 0.25),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'GET READY',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2.0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Transform.scale(
                    scale: scale,
                    child: Text(
                      '$number',
                      key: const Key('resume_countdown_number'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 84,
                        height: 1.0,
                        fontWeight: FontWeight.w900,
                        shadows: [
                          Shadow(color: Colors.black87, blurRadius: 12, offset: Offset(0, 4)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
