import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'models.dart';

const kArtworkHeroTag = 'now-playing-artwork';

String fmt(Duration d) {
  final m = d.inMinutes;
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$m:$s';
}

/// تأثير ضغط خفيف + Haptic.
class PressScale extends StatefulWidget {
  const PressScale({super.key, required this.child, required this.onTap, this.scale = 0.9});
  final Widget child;
  final VoidCallback? onTap;
  final double scale;
  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _down = false;
  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _down = true),
        onTapUp: (_) => setState(() => _down = false),
        onTapCancel: () => setState(() => _down = false),
        onTap: widget.onTap == null
            ? null
            : () {
                HapticFeedback.selectionClick();
                widget.onTap!();
              },
        child: AnimatedScale(
          scale: _down ? widget.scale : 1,
          duration: const Duration(milliseconds: 90),
          child: widget.child,
        ),
      );
}

/// صورة الغلاف مع placeholder أنيق عند غيابها.
class ArtworkImage extends StatelessWidget {
  const ArtworkImage({super.key, required this.track, required this.radius, this.cacheWidth});
  final TrackInfo? track;
  final double radius;
  final int? cacheWidth;

  @override
  Widget build(BuildContext context) {
    final art = track?.artwork;
    final placeholder = DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [Color(0xFF2A2A36), Color(0xFF15151C)]),
      ),
      child: const Center(child: Icon(Icons.music_note_rounded, color: Colors.white38, size: 40)),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: art == null
          ? placeholder
          : Image(
              image: cacheWidth == null ? art : ResizeImage(art, width: cacheWidth),
              fit: BoxFit.cover,
              gaplessPlayback: true,
              errorBuilder: (_, __, ___) => placeholder,
            ),
    );
  }
}
