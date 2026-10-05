import 'package:flutter/material.dart';

/// Hosts a scrolling list with a scrollbar that stays on screen whenever
/// there is more than fits.
///
/// A list that happens to end exactly on a row boundary gives no sign that
/// it continues. On a small phone the Locker did just that: three outfits
/// filled the card and the fourth was out of sight below.
class VisibleScrollbar extends StatefulWidget {
  const VisibleScrollbar({super.key, required this.builder});

  /// Builds the list. It must use the given controller.
  final Widget Function(BuildContext context, ScrollController controller) builder;

  @override
  State<VisibleScrollbar> createState() => _VisibleScrollbarState();
}

class _VisibleScrollbarState extends State<VisibleScrollbar> {
  final ScrollController _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      controller: _controller,
      thumbVisibility: true,
      thickness: 4,
      radius: const Radius.circular(2),
      child: widget.builder(context, _controller),
    );
  }
}
