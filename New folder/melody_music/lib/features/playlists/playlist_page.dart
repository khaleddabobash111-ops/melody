import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/l10n/strings.dart';
import '../../data/models/track.dart';
import '../../providers/providers.dart';
import '../../shared/flows.dart';
import '../../shared/widgets.dart';

class PlaylistPage extends ConsumerStatefulWidget {
  const PlaylistPage({super.key, required this.playlistId});
  final String playlistId;
  @override
  ConsumerState<PlaylistPage> createState() => _PlaylistPageState();
}

class _PlaylistPageState extends ConsumerState<PlaylistPage> {
  List<Track> _items = [];

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final pl = ref.watch(playlistsProvider).valueOrNull?.where((p) => p.id == widget.playlistId).firstOrNull;
    ref.listen(playlistTracksProvider(widget.playlistId), (_, next) {
      next.whenData((v) => setState(() => _items = v));
    });
    final initial = ref.watch(playlistTracksProvider(widget.playlistId));
    if (_items.isEmpty) _items = initial.valueOrNull ?? [];
    final svc = ref.read(playbackServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(pl?.name ?? ''),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'rename' && pl != null) {
                final n = await promptText(context, s.rename, initial: pl.name, action: 'OK');
                if (n != null) await ref.read(playlistsProvider.notifier).rename(pl.id, n);
              } else if (v == 'delete' && pl != null) {
                if (await confirm(context, s.delete, s.confirmDeletePlaylist, s.delete)) {
                  await ref.read(playlistsProvider.notifier).delete(pl.id);
                  if (context.mounted) Navigator.pop(context);
                }
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'rename', child: Text(s.rename)),
              PopupMenuItem(value: 'delete', child: Text(s.delete)),
            ],
          ),
        ],
      ),
      body: _items.isEmpty
          ? EmptyState(icon: Icons.queue_music_rounded, title: s.emptyTitle)
          : Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Row(children: [
                  Expanded(child: Text(s.tracksCount(_items.length), style: const TextStyle(fontWeight: FontWeight.w700))),
                  IconButton.filledTonal(tooltip: s.shuffle, onPressed: () => svc.shuffleAll(_items), icon: const Icon(Icons.shuffle_rounded)),
                  const SizedBox(width: 8),
                  IconButton.filled(tooltip: s.playAll, onPressed: () => svc.playTracks(_items, 0), icon: const Icon(Icons.play_arrow_rounded)),
                ]),
              ),
              Expanded(
                child: ReorderableListView.builder(
                  itemCount: _items.length,
                  onReorder: (a, b) {
                    final to = b > a ? b - 1 : b;
                    setState(() => _items.insert(to, _items.removeAt(a)));
                    ref.read(playlistsProvider.notifier).reorder(widget.playlistId, _items.map((t) => t.id).toList());
                  },
                  itemBuilder: (c, i) {
                    final t = _items[i];
                    return KeyedSubtree(
                      key: ValueKey(t.id),
                      child: TrackTile(
                        track: t,
                        onTap: () => svc.playTracks(_items, i),
                        onLongPress: () => showTrackSheet(context, ref, t, playlistId: widget.playlistId),
                        trailing: ReorderableDragStartListener(index: i, child: const Padding(padding: EdgeInsets.all(12), child: Icon(Icons.drag_handle_rounded))),
                      ),
                    );
                  },
                ),
              ),
            ]),
    );
  }
}
