import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/l10n/strings.dart';
import '../../data/models/track.dart';
import '../../providers/providers.dart';
import '../../shared/flows.dart';
import '../../shared/widgets.dart';
import '../playlists/playlist_page.dart';
import 'track_list_page.dart';

class LibraryPage extends ConsumerWidget {
  const LibraryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final settings = ref.watch(settingsProvider);
    final lib = ref.watch(libraryProvider);
    final tabs = [s.songs, s.albums, s.artists, s.playlists, s.favorites, s.recentlyAdded, s.recentlyPlayed];

    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: Text(s.library),
          actions: [
            IconButton(
              tooltip: settings.grid ? s.list : s.grid,
              icon: Icon(settings.grid ? Icons.view_list_rounded : Icons.grid_view_rounded),
              onPressed: () => ref.read(settingsProvider.notifier).update(settings.copyWith(grid: !settings.grid)),
            ),
            PopupMenuButton<String>(
              tooltip: s.sortBy,
              icon: const Icon(Icons.sort_rounded),
              initialValue: settings.sort,
              onSelected: (v) => ref.read(settingsProvider.notifier).update(settings.copyWith(sort: v)),
              itemBuilder: (_) => [
                PopupMenuItem(value: 'date', child: Text(s.byDate)),
                PopupMenuItem(value: 'title', child: Text(s.byTitle)),
                PopupMenuItem(value: 'artist', child: Text(s.byArtist)),
              ],
            ),
            IconButton(tooltip: s.importMusic, icon: const Icon(Icons.add_rounded), onPressed: () => importMusicFlow(context, ref)),
          ],
          bottom: TabBar(isScrollable: true, tabAlignment: TabAlignment.start, tabs: [for (final t in tabs) Tab(text: t)]),
        ),
        body: lib.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => EmptyState(icon: Icons.error_outline_rounded, title: s.loadError, actionLabel: s.retry, onAction: () => ref.invalidate(libraryProvider)),
          data: (all) => TabBarView(children: [
            _SongsView(tracks: sortTracks(all, settings.sort), grid: settings.grid),
            _GroupsView(groups: ref.watch(albumsProvider), icon: Icons.album_rounded),
            _GroupsView(groups: ref.watch(artistsProvider), icon: Icons.person_rounded, circle: true),
            const _PlaylistsView(),
            _SongsView(tracks: sortTracks(ref.watch(favoritesProvider), settings.sort), grid: settings.grid, emptyIcon: Icons.favorite_border_rounded),
            _SongsView(tracks: ref.watch(recentlyAddedProvider), grid: settings.grid),
            _SongsView(tracks: ref.watch(recentlyPlayedProvider), grid: settings.grid, emptyIcon: Icons.history_rounded),
          ]),
        ),
      ),
    );
  }
}

class _SongsView extends ConsumerWidget {
  const _SongsView({required this.tracks, required this.grid, this.emptyIcon = Icons.library_music_rounded});
  final List<Track> tracks;
  final bool grid;
  final IconData emptyIcon;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final svc = ref.read(playbackServiceProvider);
    if (tracks.isEmpty) {
      return EmptyState(icon: emptyIcon, title: s.emptyTitle, body: s.emptyBody, actionLabel: s.importMusic, onAction: () => importMusicFlow(context, ref));
    }
    if (grid) {
      return GridView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 200, mainAxisSpacing: 16, crossAxisSpacing: 16, childAspectRatio: .78),
        itemCount: tracks.length,
        itemBuilder: (c, i) => TrackCard(track: tracks[i], onTap: () => svc.playTracks(tracks, i), onLongPress: () => showTrackSheet(context, ref, tracks[i])),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 24),
      itemExtent: 64,
      itemCount: tracks.length,
      itemBuilder: (c, i) => TrackTile(track: tracks[i], onTap: () => svc.playTracks(tracks, i), onLongPress: () => showTrackSheet(context, ref, tracks[i])),
    );
  }
}

class _GroupsView extends StatelessWidget {
  const _GroupsView({required this.groups, required this.icon, this.circle = false});
  final List<TrackGroup> groups;
  final IconData icon;
  final bool circle;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    if (groups.isEmpty) return EmptyState(icon: icon, title: s.noResults);
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 180, mainAxisSpacing: 16, crossAxisSpacing: 16, childAspectRatio: .82),
      itemCount: groups.length,
      itemBuilder: (c, i) {
        final g = groups[i];
        return GroupCard(
          title: g.name,
          subtitle: s.tracksCount(g.tracks.length),
          artworkPath: g.artworkPath,
          circle: circle,
          icon: icon,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TrackListPage(title: g.name, tracks: g.tracks, artworkPath: g.artworkPath))),
        );
      },
    );
  }
}

class _PlaylistsView extends ConsumerWidget {
  const _PlaylistsView();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final lists = ref.watch(playlistsProvider).valueOrNull ?? const <Playlist>[];
    return ListView(padding: const EdgeInsets.only(bottom: 24), children: [
      ListTile(
        leading: Container(width: 52, height: 52, decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: Colors.white10), child: const Icon(Icons.add_rounded)),
        title: Text(s.newPlaylist, style: const TextStyle(fontWeight: FontWeight.w700)),
        onTap: () async {
          final name = await promptText(context, s.newPlaylist, hint: s.playlistName);
          if (name != null) await ref.read(playlistsProvider.notifier).create(name);
        },
      ),
      if (lists.isEmpty)
        Padding(padding: const EdgeInsets.only(top: 48), child: EmptyState(icon: Icons.queue_music_rounded, title: s.playlists))
      else
        for (final p in lists)
          ListTile(
            leading: Cover(path: p.artworkPath, size: 52, radius: 10, icon: Icons.queue_music_rounded),
            title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(s.tracksCount(p.trackCount)),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PlaylistPage(playlistId: p.id))),
          ),
    ]);
  }
}
