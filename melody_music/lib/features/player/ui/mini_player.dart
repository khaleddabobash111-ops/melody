import 'package:flutter/material.dart';
import 'artwork_palette.dart';
import 'full_player_page.dart';
import 'models.dart';
import 'player_scope.dart';
import 'widgets.dart';

/// ضعه فوق شريط التنقل السفلي. يختفي تلقائيًا عند عدم وجود أغنية.
class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key, this.actions = const PlayerActions()});
  final PlayerActions actions;

  @override
  Widget build(BuildContext context) {
    final scope = PlayerScope.of(context);
    final b = scope.backend;
    return StreamBuilder<TrackInfo?>(
      initialData: b.currentTrack,
      stream: b.trackStream,
      builder: (context, snap) {
        final t = snap.data;
        if (t == null) return const SizedBox.shrink();
        return ValueListenableBuilder<ArtworkPalette>(
          valueListenable: scope.palette,
          builder: (context, p, _) => TweenAnimationBuilder<ArtworkPalette>(
            tween: PaletteTween(end: p),
            duration: const Duration(milliseconds: 600),
            builder: (context, p, _) => Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
              child: GestureDetector(
                onTap: () => openFullPlayer(context, actions: actions),
                child: Container(
                  height: 66,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(colors: [
                      Color.lerp(p.dark, p.dominant, .55)!.withOpacity(.96),
                      p.dark.withOpacity(.96),
                    ]),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(.35), blurRadius: 16, offset: const Offset(0, 4))],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Column(children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Row(children: [
                            SizedBox(
                              width: 48,
                              height: 48,
                              child: Hero(tag: kArtworkHeroTag, child: ArtworkImage(track: t, radius: 10, cacheWidth: 150)),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
                                Text(t.artist, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white.withOpacity(.65), fontSize: 12)),
                              ]),
                            ),
                            StreamBuilder<bool>(
                              initialData: b.playing,
                              stream: b.playingStream,
                              builder: (_, s) {
                                final playing = s.data ?? false;
                                return IconButton(
                                  tooltip: playing ? 'إيقاف مؤقت' : 'تشغيل',
                                  icon: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 32),
                                  color: Colors.white,
                                  onPressed: () => playing ? b.pause() : b.play(),
                                );
                              },
                            ),
                            IconButton(
                              tooltip: 'التالي',
                              icon: const Icon(Icons.skip_next_rounded, size: 30),
                              color: Colors.white,
                              onPressed: b.next,
                            ),
                          ]),
                        ),
                      ),
                      StreamBuilder<Duration?>(
                        initialData: b.duration,
                        stream: b.durationStream,
                        builder: (_, d) => StreamBuilder<Duration>(
                          stream: b.positionStream,
                          builder: (_, s) {
                            final total = d.data?.inMilliseconds ?? 0;
                            final v = total <= 0 ? 0.0 : ((s.data?.inMilliseconds ?? 0) / total).clamp(0.0, 1.0);
                            return LinearProgressIndicator(
                              value: v,
                              minHeight: 2,
                              color: p.light,
                              backgroundColor: Colors.white.withOpacity(.12),
                            );
                          },
                        ),
                      ),
                    ]),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
