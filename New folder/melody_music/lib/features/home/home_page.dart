import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/l10n/strings.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/track.dart';
import '../../providers/nav.dart';
import '../../providers/providers.dart';
import '../../shared/flows.dart';
import '../../shared/widgets.dart';
import '../library/track_list_page.dart';
import '../playlists/playlist_page.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final lib = ref.watch(libraryProvider);
    final hour = DateTime.now().hour;
    final greet = hour < 12 ? s.greetMorning : hour < 18 ? s.greetDay : s.greetEvening;

    final header = Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 8, 0),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ShaderMask(
              shaderCallback: (r) => const LinearGradient(colors: [Colors.white, AppColors.brand]).createShader(r),
              child: const Text('Melody', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: .5)),
            ),
            Text(greet, style: const TextStyle(color: AppColors.textSecondary)),
          ]),
        ),
        IconButton(tooltip: s.search, icon: const Icon(Icons.search_rounded), onPressed: () => ref.read(tabProvider.notifier).set(1)),
        IconButton(tooltip: s.settings, icon: const Icon(Icons.settings_outlined), onPressed: () => ref.read(tabProvider.notifier).set(3)),
      ]),
    );

    return SafeArea(
      bottom: false,
      child: lib.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyState(icon: Icons.error_outline_rounded, title: s.loadError, actionLabel: s.retry, onAction: () => ref.invalidate(libraryProvider)),
        data: (all) {
          if (all.isEmpty) {
            return Column(children: [header, Expanded(child: EmptyState(icon: Icons.library_music_rounded, title: s.emptyTitle, body: s.emptyBody, actionLabel: s.importMusic, onAction: () => importMusicFlow(context, ref)))]);
          }
          final played = ref.watch(recentlyPlayedProvider);
          final added = ref.watch(recentlyAddedProvider);
          final favs = ref.watch(favoritesProvider);
          final pls = (ref.watch(playlistsProvider).valueOrNull ?? const <Playlist>[]);
          final albums = ref.watch(albumsProvider);
          final artists = ref.watch(artistsProvider);

          return CustomScrollView(slivers: [
            SliverToBoxAdapter(child: header),
            if (played.isNotEmpty) SliverToBoxAdapter(child: _Continue(track: played.first, all: played)),
            if (played.length > 1) _tracksRow(context, ref, s.recentlyPlayed, played),
            _tracksRow(context, ref, s.recentlyAdded, added),
            if (favs.isNotEmpty) _tracksRow(context, ref, s.favorites, favs),
            if (pls.isNotEmpty)
              _row(s.playlists, [
                for (final p in pls.take(12))
                  GroupCard(width: 140, title: p.name, subtitle: s.tracksCount(p.trackCount), artworkPath: p.artworkPath, icon: Icons.queue_music_rounded,
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PlaylistPage(playlistId: p.id)))),
              ]),
            if (albums.isNotEmpty)
              _row(s.albums, [
                for (final g in albums.take(12))
                  GroupCard(width: 140, title: g.name, subtitle: s.tracksCount(g.tracks.length), artworkPath: g.artworkPath,
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TrackListPage(title: g.name, tracks: g.tracks, artworkPath: g.artworkPath)))),
              ]),
            if (artists.isNotEmpty)
              _row(s.artists, [
                for (final g in artists.take(12))
                  GroupCard(width: 120, circle: true, icon: Icons.person_rounded, title: g.name, subtitle: s.tracksCount(g.tracks.length), artworkPath: g.artworkPath,
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TrackListPage(title: g.name, tracks: g.tracks, artworkPath: g.artworkPath)))),
              ], height: 175),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ]);
        },
      ),
    );
  }

  Widget _tracksRow(BuildContext context, WidgetRef ref, String title, List<Track> tracks) {
    final svc = ref.read(playbackServiceProvider);
    return _row(title, [
      for (var i = 0; i < tracks.length; i++)
        TrackCard(width: 140, track: tracks[i], onTap: () => svc.playTracks(tracks, i), onLongPress: () => showTrackSheet(context, ref, tracks[i])),
    ]);
  }

  Widget _row(String title, List<Widget> children, {double height = 205}) => SliverToBoxAdapter(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SectionHeader(title),
          SizedBox(
            height: height,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: children.length,
              separatorBuilder: (_, __) => const SizedBox(width: 14),
              itemBuilder: (_, i) => children[i],
            ),
          ),
        ]),
      );
}

class _Continue extends ConsumerWidget {
  const _Continue({required this.track, required this.all});
  final Track track;
  final List<Track> all;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () => ref.read(playbackServiceProvider).playTracks(all, 0),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(colors: [AppColors.brand.withOpacity(.35), AppColors.surface]),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(children: [
            Cover(path: track.artworkPath, size: 88, radius: 16),
            const SizedBox(width: 16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s.continueListening, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(height: 4),
                Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                Text(artistLabel(context, track), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textSecondary)),
              ]),
            ),
            const Icon(Icons.play_circle_fill_rounded, size: 44),
          ]),
        ),
      ),
    );
  }
}
