import 'package:audio_service/audio_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/l10n/strings.dart';
import '../core/theme/app_theme.dart';
import '../data/models/track.dart';
import '../features/player/ui/models.dart';
import '../providers/providers.dart';
import '../services/import_service.dart';
import 'widgets.dart';

void toast(BuildContext c, String msg) {
  ScaffoldMessenger.of(c)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg)));
}

// ---------- استيراد ملفات ----------
Future<void> importMusicFlow(BuildContext context, WidgetRef ref) async {
  final s = S.of(context);
  FilePickerResult? res;
  try {
    res = await FilePicker.platform.pickFiles(type: FileType.audio, allowMultiple: true);
  } catch (_) {
    if (context.mounted) toast(context, s.playbackError);
    return;
  }
  if (res == null || !context.mounted) return;
  final paths = res.paths.whereType<String>().toList();
  if (paths.isEmpty) return;
  var cancel = false;
  final nav = Navigator.of(context, rootNavigator: true);
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => AlertDialog(
      content: Row(children: [const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 3)), const SizedBox(width: 16), Expanded(child: Text(s.importing))]),
      actions: [TextButton(onPressed: () => cancel = true, child: Text(s.cancel))],
    ),
  );
  ImportResult? r;
  try {
    r = await ref.read(libraryProvider.notifier).importFiles(paths, cancelled: () => cancel);
  } finally {
    nav.pop();
  }
  if (context.mounted) toast(context, s.importResult(r.added, r.skipped, r.failed));
}

// ---------- استيراد رابط ----------
Future<void> importLinkFlow(BuildContext context, WidgetRef ref) =>
    showDialog<void>(context: context, builder: (_) => _LinkDialog(ref: ref));

class _LinkDialog extends StatefulWidget {
  const _LinkDialog({required this.ref});
  final WidgetRef ref;
  @override
  State<_LinkDialog> createState() => _LinkDialogState();
}

class _LinkDialogState extends State<_LinkDialog> {
  final _c = TextEditingController();
  bool _busy = false, _cancel = false;
  String? _error;

  @override
  void dispose() {
    _cancel = true;
    _c.dispose();
    super.dispose();
  }

  Future<void> _go(S s) async {
    final bad = ImportService.validateLink(_c.text);
    if (bad != null) {
      setState(() => _error = bad == LinkError.streaming ? s.unsupportedStreaming : s.invalidLink);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final t = await widget.ref.read(importServiceProvider).importLink(_c.text, cancelled: () => _cancel);
      await widget.ref.read(libraryProvider.notifier).reload();
      if (!mounted) return;
      Navigator.pop(context);
      toast(context, '${s.linkAdded}: ${t.title}');
    } on LinkImportException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = switch (e.error) {
          LinkError.streaming => s.unsupportedStreaming,
          LinkError.invalid => s.invalidLink,
          LinkError.notAudio => s.notAudio,
          LinkError.duplicate => s.importResult(0, 1, 0),
          LinkError.network => s.networkError,
        };
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return AlertDialog(
      title: Text(s.importLink),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        TextField(controller: _c, enabled: !_busy, keyboardType: TextInputType.url, textDirection: TextDirection.ltr, decoration: InputDecoration(hintText: 'https://…'), onSubmitted: (_) => _go(s)),
        const SizedBox(height: 8),
        Text(s.linkHint, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        if (_busy) const Padding(padding: EdgeInsets.only(top: 16), child: LinearProgressIndicator()),
        if (_error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_error!, style: const TextStyle(color: AppColors.error))),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(s.cancel)),
        FilledButton(onPressed: _busy ? null : () => _go(s), child: Text(s.import)),
      ],
    );
  }
}

// ---------- حوارات عامة ----------
Future<String?> promptText(BuildContext context, String title, {String? initial, String? hint, String? action}) async {
  final s = S.of(context);
  final c = TextEditingController(text: initial);
  final r = await showDialog<String>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(title),
      content: TextField(controller: c, autofocus: true, decoration: InputDecoration(hintText: hint), onSubmitted: (v) => Navigator.pop(context, v)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(s.cancel)),
        FilledButton(onPressed: () => Navigator.pop(context, c.text), child: Text(action ?? s.create)),
      ],
    ),
  );
  final t = r?.trim();
  return (t == null || t.isEmpty) ? null : t;
}

Future<bool> confirm(BuildContext context, String title, String body, String action) async {
  final s = S.of(context);
  return await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: Text(s.cancel)),
            FilledButton(style: FilledButton.styleFrom(backgroundColor: AppColors.error), onPressed: () => Navigator.pop(context, true), child: Text(action)),
          ],
        ),
      ) ??
      false;
}

// ---------- قائمة الأغنية السياقية ----------
Future<void> showTrackSheet(BuildContext context, WidgetRef ref, Track t, {String? playlistId}) {
  final s = S.of(context);
  final svc = ref.read(playbackServiceProvider);
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    showDragHandle: true,
    builder: (sheetCtx) {
      void close() => Navigator.pop(sheetCtx);
      final fav = ref.read(libraryProvider).valueOrNull?.firstWhere((x) => x.id == t.id, orElse: () => t).isFavorite ?? t.isFavorite;
      return SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: Cover(path: t.artworkPath, size: 48, radius: 10),
            title: Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Text(artistLabel(context, t), maxLines: 1),
          ),
          const Divider(height: 1),
          _Item(Icons.play_arrow_rounded, s.playNow, () {
            close();
            svc.playTracks([t], 0);
          }),
          _Item(Icons.playlist_play_rounded, s.playNext, () {
            close();
            svc.playNext(t);
          }),
          _Item(Icons.queue_music_rounded, s.addToQueue, () {
            close();
            svc.addToQueue(t);
          }),
          _Item(Icons.playlist_add_rounded, s.addToPlaylist, () {
            close();
            showAddToPlaylist(context, ref, t);
          }),
          _Item(fav ? Icons.favorite_rounded : Icons.favorite_border_rounded, fav ? s.removeFromFavorites : s.addToFavorites, () {
            close();
            ref.read(libraryProvider.notifier).toggleFavorite(t.id);
          }),
          _Item(Icons.edit_rounded, s.rename, () async {
            close();
            final title = await promptText(context, s.rename, initial: t.title, action: 'OK');
            if (title != null) await ref.read(libraryProvider.notifier).edit(t.id, title: title, artist: t.artist, album: t.album);
          }),
          if (playlistId != null)
            _Item(Icons.remove_circle_outline_rounded, s.removeFromPlaylist, () {
              close();
              ref.read(playlistsProvider.notifier).removeTrack(playlistId, t.id);
            }),
          _Item(Icons.delete_outline_rounded, s.removeFromLibrary, () async {
            close();
            if (await confirm(context, s.removeFromLibrary, s.confirmRemove, s.delete)) {
              await ref.read(libraryProvider.notifier).remove(t.id);
            }
          }, color: AppColors.error),
        ]),
      );
    },
  );
}

class _Item extends StatelessWidget {
  const _Item(this.icon, this.label, this.onTap, {this.color});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;
  @override
  Widget build(BuildContext context) => ListTile(leading: Icon(icon, color: color), title: Text(label, style: TextStyle(color: color)), onTap: onTap);
}

Future<void> showAddToPlaylist(BuildContext context, WidgetRef ref, Track t) async {
  final s = S.of(context);
  final lists = ref.read(playlistsProvider).valueOrNull ?? [];
  await showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * .6),
        child: ListView(shrinkWrap: true, children: [
          ListTile(
            leading: const Icon(Icons.add_rounded),
            title: Text(s.newPlaylist),
            onTap: () async {
              Navigator.pop(ctx);
              final name = await promptText(context, s.newPlaylist, hint: s.playlistName);
              if (name == null) return;
              final id = await ref.read(playlistsProvider.notifier).create(name);
              await ref.read(playlistsProvider.notifier).add(id, t.id);
              if (context.mounted) toast(context, name);
            },
          ),
          for (final p in lists)
            ListTile(
              leading: Cover(path: p.artworkPath, size: 44, radius: 8, icon: Icons.queue_music_rounded),
              title: Text(p.name),
              subtitle: Text(s.tracksCount(p.trackCount)),
              onTap: () async {
                Navigator.pop(ctx);
                await ref.read(playlistsProvider.notifier).add(p.id, t.id);
                if (context.mounted) toast(context, p.name);
              },
            ),
        ]),
      ),
    ),
  );
}

// ---------- قائمة الانتظار ----------
Future<void> showQueueSheet(BuildContext context, WidgetRef ref) {
  final s = S.of(context);
  final h = ref.read(audioHandlerProvider);
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: .7,
      minChildSize: .4,
      maxChildSize: .95,
      builder: (ctx, scroll) => StreamBuilder<List<MediaItem>>(
        initialData: h.queue.value,
        stream: h.queue,
        builder: (ctx, qs) {
          final items = qs.data ?? const <MediaItem>[];
          return StreamBuilder<int?>(
            initialData: h.player.currentIndex,
            stream: h.player.currentIndexStream,
            builder: (ctx, cs) {
              final cur = cs.data ?? -1;
              return Column(children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 8, 8),
                  child: Row(children: [
                    Expanded(child: Text(s.queue, style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800))),
                    TextButton(onPressed: items.length > cur + 1 ? h.clearUpcoming : null, child: Text(s.clearUpcoming)),
                  ]),
                ),
                Expanded(
                  child: items.isEmpty
                      ? EmptyState(icon: Icons.queue_music_rounded, title: s.queueEmpty)
                      : ReorderableListView.builder(
                          scrollController: scroll,
                          itemCount: items.length,
                          onReorder: (a, b) => h.moveInQueue(a, b > a ? b - 1 : b),
                          itemBuilder: (ctx, i) {
                            final it = items[i];
                            final isCur = i == cur;
                            return Dismissible(
                              key: ValueKey('${it.id}_$i'),
                              direction: isCur ? DismissDirection.none : DismissDirection.endToStart,
                              background: Container(color: AppColors.error, alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20), child: const Icon(Icons.delete_rounded)),
                              onDismissed: (_) => h.removeFromQueue(i),
                              child: ListTile(
                                key: ValueKey('t_${it.id}_$i'),
                                onTap: () => h.skipToQueueItem(i),
                                leading: Cover(path: it.artUri?.toFilePath(), size: 46, radius: 8),
                                title: Text(it.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w700, color: isCur ? AppColors.brand : null)),
                                subtitle: Text(it.artist ?? '', maxLines: 1),
                                trailing: ReorderableDragStartListener(index: i, child: const Icon(Icons.drag_handle_rounded)),
                              ),
                            );
                          },
                        ),
                ),
              ]);
            },
          );
        },
      ),
    ),
  );
}

/// أزرار مشغّل الصوت الكامل المرتبطة بمنطق التطبيق.
PlayerActions buildPlayerActions(BuildContext context, WidgetRef ref) => PlayerActions(
      isFavorite: (t) => ref.read(libraryProvider).valueOrNull?.any((x) => x.id == t.id && x.isFavorite) ?? false,
      onToggleFavorite: (t) => ref.read(libraryProvider.notifier).toggleFavorite(t.id),
      onShowQueue: () => showQueueSheet(context, ref),
      onTrackOptions: (t) {
        final full = ref.read(libraryProvider).valueOrNull?.where((x) => x.id == t.id).firstOrNull;
        if (full != null) showTrackSheet(context, ref, full);
      },
    );
