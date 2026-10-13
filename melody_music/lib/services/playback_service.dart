import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/models/track.dart';
import '../data/repositories/library_repository.dart';
import '../features/player/ui/models.dart';
import '../features/player/ui/player_backend.dart';
import 'audio_handler.dart';

/// منطق التشغيل عالي المستوى: تشغيل قوائم، سجل الاستماع، حفظ واستعادة الحالة.
class PlaybackService {
  PlaybackService({required this.handler, required this.backend, required this.repo, required this.prefs, required this.onPlayed, required this.resumeEnabled});
  final MelodyAudioHandler handler;
  final PlayerBackend backend;
  final LibraryRepository repo;
  final SharedPreferences prefs;
  final void Function(String id, int at) onPlayed;
  final bool Function() resumeEnabled;

  static const _key = 'playback_state_v1';
  StreamSubscription? _playSub, _trackSub;
  Timer? _timer;
  String? _lastLogged;

  Future<void> playTracks(List<Track> list, int index) => handler.setQueue(list, index: index);
  Future<void> playNext(Track t) => handler.enqueue(t, next: true);
  Future<void> addToQueue(Track t) => handler.enqueue(t);

  Future<void> shuffleAll(List<Track> list) async {
    if (list.isEmpty) return;
    await handler.player.setShuffleModeEnabled(true);
    await handler.setQueue(list, index: Random().nextInt(list.length));
  }

  void start() {
    _playSub = backend.playingStream.listen((playing) {
      _timer?.cancel();
      if (playing) {
        _logCurrent();
        _timer = Timer.periodic(const Duration(seconds: 10), (_) => _save());
      } else {
        _save();
      }
    });
    _trackSub = backend.trackStream.listen((t) {
      if (t != null && backend.playing) _logCurrent();
      _save();
    });
  }

  void _logCurrent() {
    final t = backend.currentTrack;
    if (t == null || t.id == _lastLogged) return;
    _lastLogged = t.id;
    final now = DateTime.now().millisecondsSinceEpoch;
    repo.markPlayed(t.id, now);
    onPlayed(t.id, now);
  }

  Future<void> _save() async {
    final tracks = handler.tracks;
    if (tracks.isEmpty) return;
    final data = {
      'ids': tracks.map((t) => t.id).toList(),
      'index': handler.player.currentIndex ?? 0,
      'pos': handler.player.position.inMilliseconds,
    };
    await prefs.setString(_key, jsonEncode(data));
  }

  /// استعادة آخر قائمة وموضع دون تشغيل تلقائي.
  Future<void> restore() async {
    if (!resumeEnabled()) return;
    try {
      final raw = prefs.getString(_key);
      if (raw == null) return;
      final m = jsonDecode(raw) as Map<String, dynamic>;
      final ids = (m['ids'] as List).cast<String>();
      final tracks = await repo.tracksByIds(ids);
      if (tracks.isEmpty) return;
      final savedId = (m['index'] as int) < ids.length ? ids[m['index'] as int] : null;
      var index = tracks.indexWhere((t) => t.id == savedId);
      if (index < 0) index = 0;
      await handler.setQueue(tracks, index: index, autoplay: false, position: Duration(milliseconds: (m['pos'] as int?) ?? 0));
    } catch (e) {
      debugPrint('restore failed: $e');
    }
  }

  void dispose() {
    _playSub?.cancel();
    _trackSub?.cancel();
    _timer?.cancel();
  }
}

TrackInfo? trackInfoFromTag(Object? tag) => tag is Track ? tag.toInfo() : null;
