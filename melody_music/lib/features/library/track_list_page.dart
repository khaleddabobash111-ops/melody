import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/l10n/strings.dart';
import '../../data/models/track.dart';
import '../../providers/providers.dart';
import '../../shared/flows.dart';
import '../../shared/widgets.dart';

/// صفحة عامة لعرض أغاني ألبوم/فنان/قائمة مع أزرار تشغيل.
class TrackListPage extends ConsumerWidget {
  const TrackListPage({super.key, required this.title, required this.tracks, this.artworkPath});
  final String title;
  final List<Track> tracks;
  final String? artworkPath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final svc = ref.read(playbackServiceProvider);
    // نقرأ النسخة الحيّة من المكتبة كي تتحدث المفضلة/التعديلات هنا أيضًا
    final live = ref.watch(libraryProvider).valueOrNull ?? const <Track>[];
    final byId = {for (final t in live) t.id: t};
    final list = [for (final t in tracks) if (byId[t.id] != null) byId[t.id]!];
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: list.isEmpty
          ? EmptyState(icon: Icons.music_off_rounded, title: s.noResults)
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: 24),
              itemCount: list.length + 1,
              itemBuilder: (c, i) {
                if (i == 0) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                    child: Row(children: [
                      Cover(path: artworkPath ?? list.first.artworkPath, size: 96, radius: 16),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(s.tracksCount(list.length), style: const TextStyle(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 8),
                          Wrap(spacing: 8, children: [
                            FilledButton.icon(onPressed: () => svc.playTracks(list, 0), icon: const Icon(Icons.play_arrow_rounded), label: Text(s.playAll)),
                            OutlinedButton.icon(onPressed: () => svc.shuffleAll(list), icon: const Icon(Icons.shuffle_rounded), label: Text(s.shuffle)),
                          ]),
                        ]),
                      ),
                    ]),
                  );
                }
                final t = list[i - 1];
                return TrackTile(track: t, onTap: () => svc.playTracks(list, i - 1), onLongPress: () => showTrackSheet(context, ref, t));
              },
            ),
    );
  }
}
