import 'dart:async';

import 'package:flutter/widgets.dart';

/// Rebuilds [builder] when [listenable] changes, but at most once every
/// [minInterval].
///
/// The first change after a quiet spell is shown at once. Changes that
/// arrive during the following [minInterval] are shown together when it
/// ends, so the last state is always drawn and nothing is ever stuck stale.
///
/// The game state notifies its listeners several times in every frame of a
/// shift. Rebuilding and laying out the whole HUD for each frame was a sixth
/// of the main thread's work on the web build, for numbers that change a few
/// times a second.
class ThrottledListenableBuilder extends StatefulWidget {
  const ThrottledListenableBuilder({
    super.key,
    required this.listenable,
    required this.builder,
    this.minInterval = const Duration(milliseconds: 80),
  });

  final Listenable listenable;
  final WidgetBuilder builder;

  /// The shortest time between two rebuilds caused by [listenable].
  final Duration minInterval;

  @override
  State<ThrottledListenableBuilder> createState() => ThrottledListenableBuilderState();
}

@visibleForTesting
class ThrottledListenableBuilderState extends State<ThrottledListenableBuilder> {
  Timer? _cooldown;
  bool _changedDuringCooldown = false;

  /// How many times [ThrottledListenableBuilder.builder] has run.
  @visibleForTesting
  int buildCount = 0;

  @override
  void initState() {
    super.initState();
    widget.listenable.addListener(_onChange);
  }

  @override
  void didUpdateWidget(ThrottledListenableBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.listenable != widget.listenable) {
      oldWidget.listenable.removeListener(_onChange);
      widget.listenable.addListener(_onChange);
    }
  }

  @override
  void dispose() {
    widget.listenable.removeListener(_onChange);
    _cooldown?.cancel();
    super.dispose();
  }

  void _onChange() {
    if (_cooldown != null) {
      _changedDuringCooldown = true;
      return;
    }
    _rebuildAndCoolDown();
  }

  void _rebuildAndCoolDown() {
    _changedDuringCooldown = false;
    setState(() {});
    _cooldown = Timer(widget.minInterval, () {
      _cooldown = null;
      if (_changedDuringCooldown && mounted) _rebuildAndCoolDown();
    });
  }

  @override
  Widget build(BuildContext context) {
    buildCount++;
    return widget.builder(context);
  }
}
