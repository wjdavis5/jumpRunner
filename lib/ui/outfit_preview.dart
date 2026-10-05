import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../game/logic/outfit_tailor.dart';
import '../game/models/courier_skin.dart';

/// A small picture of the courier wearing [skin], for the Locker.
///
/// The picture is the game's own running sprite, dressed by the same
/// [OutfitTailor] the game uses, so what the shop shows is what the street
/// shows. Until it is ready (it takes a moment to decode and recolour), and
/// wherever the art cannot be loaded, [placeholder] is shown instead.
class OutfitPreview extends StatefulWidget {
  const OutfitPreview({
    super.key,
    required this.skin,
    required this.placeholder,
    this.width = 48.0,
    this.height = 58.0,
  });

  final CourierSkin skin;
  final Widget placeholder;
  final double width;
  final double height;

  /// The courier frame used for every preview.
  static const String artAsset = 'assets/images/courier/run_1.png';

  @override
  State<OutfitPreview> createState() => _OutfitPreviewState();
}

class _OutfitPreviewState extends State<OutfitPreview> {
  // Four small images at most, kept for the life of the app so reopening the
  // Locker is instant.
  static final Map<String, ui.Image> _dressed = {};

  // The decoded art itself rather than the future that produces it: a cached
  // future belongs to the zone it was made in, and awaiting it from another
  // (every widget test has its own) never completes.
  static ui.Image? _art;

  ui.Image? _image;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(OutfitPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.skin.id != widget.skin.id) {
      _image = null;
      _load();
    }
  }

  Future<void> _load() async {
    final skin = widget.skin;
    final ready = _dressed[skin.id];
    if (ready != null) {
      _image = ready;
      return;
    }
    try {
      final art = _art ??= await _decodeArt();
      final data = await art.toByteData();
      if (data == null) return;
      final pixels = OutfitTailor.dress(
        data.buffer.asUint8List(),
        art.width,
        art.height,
        skin.outfit,
      );
      final decoded = Completer<ui.Image>();
      ui.decodeImageFromPixels(
        pixels,
        art.width,
        art.height,
        ui.PixelFormat.rgba8888,
        decoded.complete,
      );
      final image = _dressed[skin.id] ??= await decoded.future;
      if (mounted && widget.skin.id == skin.id) {
        setState(() => _image = image);
      }
    } catch (_) {
      // No art (a test without assets, a failed fetch): keep the placeholder.
    }
  }

  static Future<ui.Image> _decodeArt() async {
    final bytes = await rootBundle.load(OutfitPreview.artAsset);
    final codec = await ui.instantiateImageCodec(bytes.buffer.asUint8List());
    return (await codec.getNextFrame()).image;
  }

  @override
  Widget build(BuildContext context) {
    final image = _image;
    if (image == null) return widget.placeholder;

    final skin = widget.skin;
    final hasGlow = skin.glowColor != Colors.transparent;
    return Container(
      key: Key('outfit_preview_${skin.id}'),
      width: widget.width,
      height: widget.height,
      padding: const EdgeInsets.fromLTRB(3, 4, 3, 2),
      decoration: BoxDecoration(
        color: const Color(0xFF10151C),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: hasGlow ? skin.glowColor : Colors.white24,
          width: 1.5,
        ),
        boxShadow: hasGlow
            ? [
                BoxShadow(
                  color: skin.glowColor.withValues(alpha: 0.45),
                  blurRadius: 8,
                ),
              ]
            : null,
      ),
      child: RawImage(
        image: image,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
      ),
    );
  }
}
