import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'artwork_palette.dart';

/// خلفية سينمائية: تدرج + غلاف مموّه + توهج عائم + Vignette.
/// الطبقات الثقيلة (Blur) داخل RepaintBoundary منفصل فلا تُعاد رسمها مع الحركة.
class DynamicBackground extends StatefulWidget {
  const DynamicBackground({
    super.key,
    required this.palette,
    this.artwork,
    this.artKey,
  });
  final ArtworkPalette palette;
  final ImageProvider? artwork;
  final String? artKey;

  @override
  State<DynamicBackground> createState() => _DynamicBackgroundState();
}

class _DynamicBackgroundState extends State<DynamicBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 24));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduce) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat(); // يتوقف تلقائيًا عند إخفاء الصفحة (TickerMode)
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.palette;
    final size = MediaQuery.sizeOf(context);
    return RepaintBoundary(
      child: Stack(fit: StackFit.expand, children: [
        ColoredBox(color: p.dark),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color.lerp(p.dark, p.dominant, 0.55)!,
                Color.lerp(p.dark, p.secondary, 0.18)!,
                p.dark,
              ],
              stops: const [0, 0.55, 1],
            ),
          ),
        ),
        if (widget.artwork != null)
          RepaintBoundary(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 700),
              child: KeyedSubtree(
                key: ValueKey(widget.artKey),
                child: Opacity(
                  opacity: 0.22,
                  child: ImageFiltered(
                    imageFilter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
                    child: Image(
                      image: ResizeImage(widget.artwork!, width: 64),
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        RepaintBoundary(
          child: AnimatedBuilder(
            animation: _c,
            builder: (_, __) {
              final t = _c.value * 2 * math.pi;
              return Align(
                alignment: Alignment(0.5 * math.sin(t), -0.35 + 0.15 * math.cos(t)),
                child: Container(
                  width: size.width * 1.3,
                  height: size.width * 1.3,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [
                      p.secondary.withOpacity(0.30),
                      p.secondary.withOpacity(0),
                    ]),
                  ),
                ),
              );
            },
          ),
        ),
        // Vignette لزيادة وضوح النصوص
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              radius: 1.15,
              colors: [Colors.transparent, Colors.black.withOpacity(0.62)],
              stops: const [0.5, 1],
            ),
          ),
        ),
      ]),
    );
  }
}
