import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/l10n/strings.dart';
import '../../providers/providers.dart';
import '../../shared/flows.dart';
import '../../shared/widgets.dart';
import '../library/track_list_page.dart';
import '../playlists/playlist_page.dart';

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});
  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final _c = TextEditingController();
  Timer? _debounce;
  String _q = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _c.dispose();
    super.dispose();
  }

  void _onChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 180), () => setState(() => _q = v));
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final history = ref.watch(searchHistoryProvider);
    final svc = ref.read(playbackServiceProvider);
    final r = ref.watch(searchProvider(_q));

    Widget body;
    if (_q.trim().isEmpty) {
      body = history.isEmpty
          ? EmptyState(icon: Icons.search_rounded, title: s.searchHint)
          : ListView(children: [
              SectionHeader(s.recentSearches, trailing: TextButton(onPressed: ref.read(searchHistoryProvider.notifier).clear, child: Text(s.clear))),
              for (final h in history)
                ListTile(
                  leading: const Icon(Icons.history_rounded),
                  title: Text(h),
                  onTap: () {
                    _c.text = h;
                    setState(() => _q = h);
                  },
                ),
            ]);
    } else if (r.isEmpty) {
      body = EmptyState(icon: Icons.search_off_rounded, title: s.noResults);
    } else {
      body = ListView(padding: const EdgeInsets.only(bottom: 24), children: [
        if (r.tracks.isNotEmpty) SectionHeader(s.songs),
        for (var i = 0; i < r.tracks.length && i < 25; i++)
          TrackTile(
            track: r.tracks[i],
            onTap: () {
              ref.read(searchHistoryProvider.notifier).add(_q);
              svc.playTracks(r.tracks, i);
            },
            onLongPress: () => showTrackSheet(context, ref, r.tracks[i]),
          ),
        if (r.albums.isNotEmpty) SectionHeader(s.albums),
        for (final g in r.albums)
          ListTile(
            leading: Cover(path: g.artworkPath, size: 52, radius: 10, icon: Icons.album_rounded),
            title: Text(g.name),
            subtitle: Text(s.tracksCount(g.tracks.length)),
            onTap: () {
              ref.read(searchHistoryProvider.notifier).add(_q);
              Navigator.push(context, MaterialPageRoute(builder: (_) => TrackListPage(title: g.name, tracks: g.tracks, artworkPath: g.artworkPath)));
            },
          ),
        if (r.artists.isNotEmpty) SectionHeader(s.artists),
        for (final g in r.artists)
          ListTile(
            leading: Cover(path: g.artworkPath, size: 52, circle: true, icon: Icons.person_rounded),
            title: Text(g.name),
            subtitle: Text(s.tracksCount(g.tracks.length)),
            onTap: () {
              ref.read(searchHistoryProvider.notifier).add(_q);
              Navigator.push(context, MaterialPageRoute(builder: (_) => TrackListPage(title: g.name, tracks: g.tracks, artworkPath: g.artworkPath)));
            },
          ),
        if (r.playlists.isNotEmpty) SectionHeader(s.playlists),
        for (final p in r.playlists)
          ListTile(
            leading: Cover(path: p.artworkPath, size: 52, radius: 10, icon: Icons.queue_music_rounded),
            title: Text(p.name),
            subtitle: Text(s.tracksCount(p.trackCount)),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PlaylistPage(playlistId: p.id))),
          ),
      ]);
    }

    return SafeArea(
      bottom: false,
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: _c,
            onChanged: _onChanged,
            textInputAction: TextInputAction.search,
            style: const TextStyle(fontSize: 16),
            decoration: InputDecoration(
              hintText: s.searchHint,
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _c.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: s.clear,
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () {
                        _c.clear();
                        setState(() => _q = '');
                      },
                    ),
              contentPadding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
        Expanded(child: body),
      ]),
    );
  }
}

