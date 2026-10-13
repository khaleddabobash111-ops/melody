import 'dart:ui' show FontFeature;
import 'dart:math' as math;
import 'package:flutter/material.dart' hide RepeatMode;
import 'artwork_palette.dart';
import 'dynamic_background.dart';
import 'models.dart';
import 'player_backend.dart';
import 'player_scope.dart';
import 'widgets.dart';

/// يفتح المشغل الكامل. يتطلب وجود PlayerScope فوق الـ Navigator.
Future<void> openFullPlayer(BuildContext context, {PlayerActions actions = const PlayerActions()}) {
  return Navigator.of(context, rootNavigator: true).push(PageRouteBuilder(
    transitionDuration: const Duration(milliseconds: 420),
    reverseTransitionDuration: const Duration(milliseconds: 320),
    pageBuilder: (_, __, ___) => FullPlayerPage(actions: actions),
    transitionsBuilder: (_, a, __, child) {
      final c = CurvedAnimation(parent: a, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
      return SlideTransition(
        position: Tween(begin: const Offset(0, 0.08), end: Offset.zero).animate(c),
        child: FadeTransition(opacity: c, child: child),
      );
    },
  ));
}

class FullPlayerPage extends StatelessWidget {
  const FullPlayerPage({super.key, this.actions = const PlayerActions()});
  final PlayerActions actions;

  @override
  Widget build(BuildContext context) {
    final scope = PlayerScope.of(context);
    final reduce = MediaQuery.of(context).disableAnimations;
    return ValueListenableBuilder<ArtworkPalette>(
      valueListenable: scope.palette,
      builder: (context, target, _) => TweenAnimationBuilder<ArtworkPalette>(
        tween: PaletteTween(end: target),
        duration: reduce ? Duration.zero : const Duration(milliseconds: 700),
        curve: Curves.easeInOut,
        builder: (context, p, _) => Scaffold(
          backgroundColor: p.dark,
          body: GestureDetector(
            onVerticalDragEnd: (d) {
              if ((d.primaryVelocity ?? 0) > 700) Navigator.of(context).maybePop();
            },
            child: StreamBuilder<TrackInfo?>(
              initialData: scope.backend.currentTrack,
              stream: scope.backend.trackStream,
              builder: (context, snap) {
                final track = snap.data;
                return Stack(fit: StackFit.expand, children: [
                  DynamicBackground(palette: p, artwork: track?.artwork, artKey: track?.id),
                  SafeArea(child: _Content(track: track, p: p, actions: actions, backend: scope.backend)),
                ]);
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({required this.track, required this.p, required this.actions, required this.backend});
  final TrackInfo? track;
  final ArtworkPalette p;
  final PlayerActions actions;
  final PlayerBackend backend;

  @override
  Widget build(BuildContext context) {
    final t = track;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(children: [
        _TopBar(track: t, actions: actions),
        Expanded(
          child: LayoutBuilder(builder: (context, box) {
            final side = math.max(120.0, math.min(box.maxWidth, box.maxHeight - 16));
            return Center(child: _Artwork(track: t, p: p, side: side, backend: backend));
          }),
        ),
        const SizedBox(height: 20),
        _Info(track: t, actions: actions),
        const SizedBox(height: 8),
        _ProgressBar(backend: backend, p: p),
        const SizedBox(height: 4),
        _Controls(backend: backend, p: p),
        const SizedBox(height: 8),
        _BottomRow(backend: backend, actions: actions),
        const SizedBox(height: 8),
      ]),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.track, required this.actions});
  final TrackInfo? track;
  final PlayerActions actions;
  @override
  Widget build(BuildContext context) {
    final sub = actions.contextTitle ?? track?.album ?? '';
    return SizedBox(
      height: 56,
      child: Row(children: [
        IconButton(
          tooltip: 'رجوع',
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 32),
          color: Colors.white,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        Expanded(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text('يُشغّل الآن',
                style: TextStyle(fontSize: 11, letterSpacing: 1.2, color: Colors.white.withOpacity(.65))),
            if (sub.isNotEmpty)
              Text(sub,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
          ]),
        ),
        IconButton(
          tooltip: 'خيارات',
          icon: const Icon(Icons.more_vert_rounded),
          color: Colors.white,
          onPressed: track == null || actions.onTrackOptions == null
              ? null
              : () => actions.onTrackOptions!(track!),
        ),
      ]),
    );
  }
}

class _Artwork extends StatelessWidget {
  const _Artwork({required this.track, required this.p, required this.side, required this.backend});
  final TrackInfo? track;
  final ArtworkPalette p;
  final double side;
  final PlayerBackend backend;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      initialData: backend.playing,
      stream: backend.playingStream,
      builder: (context, snap) => AnimatedScale(
        scale: (snap.data ?? false) ? 1.0 : 0.92, // تكبير/تصغير خفيف مع التشغيل والإيقاف
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
        child: SizedBox(
          width: side,
          height: side,
          child: Hero(
            tag: kArtworkHeroTag,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(color: p.dominant.withOpacity(.45), blurRadius: 60, spreadRadius: -8, offset: const Offset(0, 26)),
                  BoxShadow(color: p.secondary.withOpacity(.18), blurRadius: 24),
                ],
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 450),
                transitionBuilder: (c, a) => FadeTransition(
                  opacity: a,
                  child: ScaleTransition(scale: Tween(begin: .96, end: 1.0).animate(a), child: c),
                ),
                child: SizedBox.expand(
                  key: ValueKey(track?.id),
                  child: ArtworkImage(track: track, radius: 22, cacheWidth: 900),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Info extends StatelessWidget {
  const _Info({required this.track, required this.actions});
  final TrackInfo? track;
  final PlayerActions actions;
  @override
  Widget build(BuildContext context) {
    final t = track;
    return Row(children: [
      Expanded(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: Column(
            key: ValueKey(t?.id),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t?.title ?? 'لا توجد أغنية قيد التشغيل',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white, height: 1.25)),
              const SizedBox(height: 2),
              Text(t?.artist ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 16, color: Colors.white.withOpacity(.72))),
              if ((t?.album ?? '').isNotEmpty)
                Text(t!.album!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(.5))),
            ],
          ),
        ),
      ),
      if (t != null && actions.onToggleFavorite != null) _FavoriteButton(key: ValueKey(t.id), track: t, actions: actions),
    ]);
  }
}

class _FavoriteButton extends StatefulWidget {
  const _FavoriteButton({super.key, required this.track, required this.actions});
  final TrackInfo track;
  final PlayerActions actions;
  @override
  State<_FavoriteButton> createState() => _FavoriteButtonState();
}

class _FavoriteButtonState extends State<_FavoriteButton> {
  late bool _fav = widget.actions.isFavorite?.call(widget.track) ?? false;
  @override
  Widget build(BuildContext context) => PressScale(
        onTap: () {
          widget.actions.onToggleFavorite!(widget.track);
          setState(() => _fav = !_fav);
        },
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
            child: Icon(
              _fav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              key: ValueKey(_fav),
              size: 28,
              color: _fav ? const Color(0xFFFF4D6D) : Colors.white,
            ),
          ),
        ),
      );
}

/// شريط التقدم: يستمع لتدفق الموضع وحده، فلا يُعاد بناء بقية الشاشة.
class _ProgressBar extends StatefulWidget {
  const _ProgressBar({required this.backend, required this.p});
  final PlayerBackend backend;
  final ArtworkPalette p;
  @override
  State<_ProgressBar> createState() => _ProgressBarState();
}

class _ProgressBarState extends State<_ProgressBar> {
  double? _drag;
  @override
  Widget build(BuildContext context) {
    final b = widget.backend;
    return StreamBuilder<Duration?>(
      initialData: b.duration,
      stream: b.durationStream,
      builder: (context, dSnap) {
        final total = dSnap.data ?? Duration.zero;
        return StreamBuilder<Duration>(
          initialData: Duration.zero,
          stream: b.positionStream,
          builder: (context, pSnap) {
            final pos = pSnap.data ?? Duration.zero;
            final ms = total.inMilliseconds;
            final ratio = ms <= 0 ? 0.0 : (pos.inMilliseconds / ms).clamp(0.0, 1.0);
            final value = _drag ?? ratio;
            final shown = _drag != null ? Duration(milliseconds: (_drag! * ms).round()) : pos;
            final dragging = _drag != null;
            return Column(children: [
              TweenAnimationBuilder<double>(
                tween: Tween(end: dragging ? 6 : 3),
                duration: const Duration(milliseconds: 150),
                builder: (context, h, _) => SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: h,
                    activeTrackColor: widget.p.light,
                    inactiveTrackColor: Colors.white.withOpacity(.2),
                    thumbColor: widget.p.light,
                    thumbShape: RoundSliderThumbShape(enabledThumbRadius: dragging ? 8 : 5.5, elevation: 0),
                    overlayShape: SliderComponentShape.noOverlay,
                  ),
                  child: Slider(
                    value: value,
                    onChanged: ms > 0 ? (v) => setState(() => _drag = v) : null,
                    onChangeEnd: (v) async {
                      await b.seek(Duration(milliseconds: (v * ms).round()));
                      if (mounted) setState(() => _drag = null);
                    },
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text(fmt(shown), style: _timeStyle),
                  Text('-${fmt(total - shown < Duration.zero ? Duration.zero : total - shown)}', style: _timeStyle),
                ]),
              ),
            ]);
          },
        );
      },
    );
  }

  static final _timeStyle = TextStyle(fontSize: 12, color: Colors.white.withOpacity(.6), fontFeatures: const [FontFeature.tabularFigures()]);
}

class _Controls extends StatelessWidget {
  const _Controls({required this.backend, required this.p});
  final PlayerBackend backend;
  final ArtworkPalette p;

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      StreamBuilder<bool>(
        initialData: backend.shuffle,
        stream: backend.shuffleStream,
        builder: (_, s) => _Toggle(
          icon: Icons.shuffle_rounded,
          active: s.data ?? false,
          color: p.light,
          tooltip: 'عشوائي',
          onTap: () => backend.setShuffle(!(s.data ?? false)),
        ),
      ),
      PressScale(
        onTap: backend.previous,
        child: const Padding(padding: EdgeInsets.all(8), child: Icon(Icons.skip_previous_rounded, size: 44, color: Colors.white)),
      ),
      StreamBuilder<bool>(
        initialData: backend.playing,
        stream: backend.playingStream,
        builder: (_, s) {
          final playing = s.data ?? false;
          return PressScale(
            scale: 0.93,
            onTap: () => playing ? backend.pause() : backend.play(),
            child: Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: p.light,
                boxShadow: [BoxShadow(color: p.dominant.withOpacity(.5), blurRadius: 28, offset: const Offset(0, 8))],
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
                child: Icon(
                  playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  key: ValueKey(playing),
                  size: 42,
                  color: p.dark,
                ),
              ),
            ),
          );
        },
      ),
      PressScale(
        onTap: backend.next,
        child: const Padding(padding: EdgeInsets.all(8), child: Icon(Icons.skip_next_rounded, size: 44, color: Colors.white)),
      ),
      StreamBuilder<RepeatMode>(
        initialData: backend.repeat,
        stream: backend.repeatStream,
        builder: (_, s) {
          final m = s.data ?? RepeatMode.off;
          return _Toggle(
            icon: m == RepeatMode.one ? Icons.repeat_one_rounded : Icons.repeat_rounded,
            active: m != RepeatMode.off,
            color: p.light,
            tooltip: 'تكرار',
            onTap: () => backend.setRepeat(RepeatMode.values[(m.index + 1) % 3]),
          );
        },
      ),
    ]);
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({required this.icon, required this.active, required this.color, required this.onTap, required this.tooltip});
  final IconData icon;
  final bool active;
  final Color color;
  final VoidCallback onTap;
  final String tooltip;
  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: PressScale(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 26, color: active ? color : Colors.white.withOpacity(.6)),
              const SizedBox(height: 3),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 4,
                height: 4,
                decoration: BoxDecoration(shape: BoxShape.circle, color: active ? color : Colors.transparent),
              ),
            ]),
          ),
        ),
      );
}

class _BottomRow extends StatelessWidget {
  const _BottomRow({required this.backend, required this.actions});
  final PlayerBackend backend;
  final PlayerActions actions;
  @override
  Widget build(BuildContext context) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      IconButton(
        tooltip: 'قائمة الانتظار',
        icon: const Icon(Icons.queue_music_rounded),
        color: Colors.white.withOpacity(.8),
        onPressed: actions.onShowQueue,
      ),
      Row(children: [
        if (actions.onPickDevice != null)
          IconButton(
            tooltip: 'جهاز الإخراج',
            icon: const Icon(Icons.speaker_group_outlined),
            color: Colors.white.withOpacity(.8),
            onPressed: actions.onPickDevice,
          ),
        IconButton(
          tooltip: 'مستوى الصوت',
          icon: const Icon(Icons.volume_up_rounded),
          color: Colors.white.withOpacity(.8),
          onPressed: () => _showVolume(context),
        ),
      ]),
    ]);
  }

  void _showVolume(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF16161D),
      builder: (_) {
        double v = backend.volume;
        return StatefulBuilder(
          builder: (context, set) => Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
            child: Row(children: [
              const Icon(Icons.volume_down_rounded, color: Colors.white70),
              Expanded(
                child: Slider(
                  value: v,
                  onChanged: (x) {
                    set(() => v = x);
                    backend.setVolume(x);
                  },
                ),
              ),
              const Icon(Icons.volume_up_rounded, color: Colors.white70),
            ]),
          ),
        );
      },
    );
  }
}
