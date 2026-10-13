import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import '../data/models/track.dart';
import '../data/repositories/library_repository.dart';
import '../features/player/ui/just_audio_backend.dart';
import '../features/player/ui/player_backend.dart';
import '../services/audio_handler.dart';
import '../services/import_service.dart';
import '../services/playback_service.dart';

// ---------- البنية التحتية (تُمرَّر قيمها من main) ----------
final prefsProvider = Provider<SharedPreferences>((_) => throw UnimplementedError());
final dbProvider = Provider<Database>((_) => throw UnimplementedError());
final audioHandlerProvider = Provider<MelodyAudioHandler>((_) => throw UnimplementedError());

final repoProvider = Provider((ref) => LibraryRepository(ref.watch(dbProvider)));
final importServiceProvider = Provider((ref) => ImportService(ref.watch(repoProvider)));

final backendProvider = Provider<PlayerBackend>((ref) =>
    JustAudioBackend(ref.watch(audioHandlerProvider).player, trackFromTag: trackInfoFromTag));

final playbackServiceProvider = Provider<PlaybackService>((ref) {
  final s = PlaybackService(
    handler: ref.watch(audioHandlerProvider),
    backend: ref.watch(backendProvider),
    repo: ref.watch(repoProvider),
    prefs: ref.watch(prefsProvider),
    onPlayed: (id, at) => ref.read(libraryProvider.notifier).markPlayed(id, at),
    resumeEnabled: () => ref.read(settingsProvider).resume,
  );
  ref.onDispose(s.dispose);
  return s;
});

// ---------- الإعدادات ----------
@immutable
class AppSettings {
  const AppSettings({this.themeMode = ThemeMode.dark, this.language = 'ar', this.grid = true, this.reduceMotion = false, this.resume = true, this.sort = 'date'});
  final ThemeMode themeMode;
  final String language; // ar | en
  final bool grid;
  final bool reduceMotion;
  final bool resume;
  final String sort; // title | artist | date

  AppSettings copyWith({ThemeMode? themeMode, String? language, bool? grid, bool? reduceMotion, bool? resume, String? sort}) => AppSettings(
        themeMode: themeMode ?? this.themeMode,
        language: language ?? this.language,
        grid: grid ?? this.grid,
        reduceMotion: reduceMotion ?? this.reduceMotion,
        resume: resume ?? this.resume,
        sort: sort ?? this.sort,
      );
}

class SettingsNotifier extends Notifier<AppSettings> {
  SharedPreferences get _p => ref.read(prefsProvider);
  @override
  AppSettings build() => AppSettings(
        themeMode: ThemeMode.values[(_p.getInt('theme') ?? ThemeMode.dark.index).clamp(0, 2)],
        language: _p.getString('lang') ?? 'ar',
        grid: _p.getBool('grid') ?? true,
        reduceMotion: _p.getBool('reduce') ?? false,
        resume: _p.getBool('resume') ?? true,
        sort: _p.getString('sort') ?? 'date',
      );

  void update(AppSettings s) {
    state = s;
    _p
      ..setInt('theme', s.themeMode.index)
      ..setString('lang', s.language)
      ..setBool('grid', s.grid)
      ..setBool('reduce', s.reduceMotion)
      ..setBool('resume', s.resume)
      ..setString('sort', s.sort);
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);

// ---------- المكتبة ----------
class LibraryNotifier extends AsyncNotifier<List<Track>> {
  LibraryRepository get _repo => ref.read(repoProvider);

  @override
  Future<List<Track>> build() => _repo.allTracks();

  Future<void> reload() async => state = await AsyncValue.guard(_repo.allTracks);

  Future<ImportResult> importFiles(List<String> paths, {bool Function()? cancelled}) async {
    final r = await ref.read(importServiceProvider).importFiles(paths, cancelled: cancelled);
    await reload();
    return r;
  }

  Future<void> toggleFavorite(String id) async {
    final cur = state.valueOrNull ?? [];
    final i = cur.indexWhere((t) => t.id == id);
    if (i < 0) return;
    final next = !cur[i].isFavorite;
    state = AsyncData([...cur]..[i] = cur[i].copyWith(isFavorite: next)); // تحديث فوري في كل الشاشات
    await _repo.setFavorite(id, next);
  }

  Future<void> remove(String id) async {
    final removed = await _repo.removeTrack(id);
    state = AsyncData([...(state.valueOrNull ?? [])]..removeWhere((t) => t.id == id));
    if (removed != null) await ref.read(importServiceProvider).deleteFiles(removed);
    ref.invalidate(playlistsProvider);
  }

  Future<void> edit(String id, {required String title, required String artist, required String album}) async {
    await _repo.updateMeta(id, title: title, artist: artist, album: album);
    final cur = state.valueOrNull ?? [];
    state = AsyncData([for (final t in cur) t.id == id ? t.copyWith(title: title, artist: artist, album: album) : t]);
  }

  void markPlayed(String id, int at) {
    final cur = state.valueOrNull;
    if (cur == null) return;
    state = AsyncData([for (final t in cur) t.id == id ? t.copyWith(lastPlayed: at) : t]);
  }

  Future<void> clearHistory() async {
    await _repo.clearHistory();
    state = AsyncData([for (final t in state.valueOrNull ?? <Track>[]) t.copyWith(clearLastPlayed: true)]);
  }
}

final libraryProvider = AsyncNotifierProvider<LibraryNotifier, List<Track>>(LibraryNotifier.new);

List<Track> _tracks(Ref ref) => ref.watch(libraryProvider).valueOrNull ?? const [];

final favoritesProvider = Provider<List<Track>>((ref) => _tracks(ref).where((t) => t.isFavorite).toList());
final recentlyAddedProvider = Provider<List<Track>>((ref) {
  final l = [..._tracks(ref)]..sort((a, b) => b.dateAdded.compareTo(a.dateAdded));
  return l.take(30).toList();
});
final recentlyPlayedProvider = Provider<List<Track>>((ref) {
  final l = _tracks(ref).where((t) => t.lastPlayed != null).toList()..sort((a, b) => b.lastPlayed!.compareTo(a.lastPlayed!));
  return l.take(30).toList();
});
final albumsProvider = Provider<List<TrackGroup>>((ref) => groupTracks(_tracks(ref), (t) => t.album));
final artistsProvider = Provider<List<TrackGroup>>((ref) => groupTracks(_tracks(ref), (t) => t.artist));

List<Track> sortTracks(List<Track> list, String sort) {
  final l = [...list];
  switch (sort) {
    case 'title':
      l.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    case 'artist':
      l.sort((a, b) => a.artist.toLowerCase().compareTo(b.artist.toLowerCase()));
    default:
      l.sort((a, b) => b.dateAdded.compareTo(a.dateAdded));
  }
  return l;
}

// ---------- قوائم التشغيل ----------
class PlaylistsNotifier extends AsyncNotifier<List<Playlist>> {
  LibraryRepository get _repo => ref.read(repoProvider);
  @override
  Future<List<Playlist>> build() => _repo.playlists();
  Future<void> reload() async => state = await AsyncValue.guard(_repo.playlists);

  Future<String> create(String name) async {
    final id = await _repo.createPlaylist(name);
    await reload();
    return id;
  }

  Future<void> rename(String id, String name) async {
    await _repo.renamePlaylist(id, name);
    await reload();
  }

  Future<void> delete(String id) async {
    await _repo.deletePlaylist(id);
    await reload();
  }

  Future<void> add(String playlistId, String trackId) async {
    await _repo.addToPlaylist(playlistId, trackId);
    await reload();
    ref.invalidate(playlistTracksProvider(playlistId));
  }

  Future<void> removeTrack(String playlistId, String trackId) async {
    await _repo.removeFromPlaylist(playlistId, trackId);
    await reload();
    ref.invalidate(playlistTracksProvider(playlistId));
  }

  Future<void> reorder(String playlistId, List<String> ids) async {
    await _repo.reorderPlaylist(playlistId, ids);
    ref.invalidate(playlistTracksProvider(playlistId));
  }
}

final playlistsProvider = AsyncNotifierProvider<PlaylistsNotifier, List<Playlist>>(PlaylistsNotifier.new);
final playlistTracksProvider = FutureProvider.family<List<Track>, String>((ref, id) {
  ref.watch(libraryProvider); // يتحدث مع المفضلة والحذف
  return ref.read(repoProvider).playlistTracks(id);
});

// ---------- البحث المحلي ----------
class SearchResults {
  const SearchResults(this.tracks, this.albums, this.artists, this.playlists);
  final List<Track> tracks;
  final List<TrackGroup> albums, artists;
  final List<Playlist> playlists;
  bool get isEmpty => tracks.isEmpty && albums.isEmpty && artists.isEmpty && playlists.isEmpty;
}

final searchProvider = Provider.family<SearchResults, String>((ref, q) {
  final query = q.trim().toLowerCase();
  if (query.isEmpty) return const SearchResults([], [], [], []);
  bool m(String s) => s.toLowerCase().contains(query);
  final tracks = _tracks(ref).where((t) => m(t.title) || m(t.artist) || m(t.album)).toList();
  final albums = ref.watch(albumsProvider).where((g) => m(g.name)).toList();
  final artists = ref.watch(artistsProvider).where((g) => m(g.name)).toList();
  final pls = (ref.watch(playlistsProvider).valueOrNull ?? const <Playlist>[]).where((p) => m(p.name)).toList();
  return SearchResults(tracks, albums, artists, pls);
});

class SearchHistoryNotifier extends Notifier<List<String>> {
  @override
  List<String> build() {
    final raw = ref.read(prefsProvider).getString('search_history');
    return raw == null ? [] : (jsonDecode(raw) as List).cast<String>();
  }

  void add(String q) {
    final t = q.trim();
    if (t.isEmpty) return;
    state = [t, ...state.where((e) => e != t)].take(10).toList();
    ref.read(prefsProvider).setString('search_history', jsonEncode(state));
  }

  void clear() {
    state = [];
    ref.read(prefsProvider).remove('search_history');
  }
}

final searchHistoryProvider = NotifierProvider<SearchHistoryNotifier, List<String>>(SearchHistoryNotifier.new);
