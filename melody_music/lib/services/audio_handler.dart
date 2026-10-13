import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import '../data/models/track.dart';

/// خدمة التشغيل المركزية: مشغل واحد + قائمة انتظار + إشعار/شاشة قفل عبر audio_service.
/// الواجهات لا تتحدث مع المشغل إلا من خلالها (أو عبر PlayerBackend للقراءة).
class MelodyAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  MelodyAudioHandler() {
    _init();
  }

  final AudioPlayer player = AudioPlayer();
  final List<Track> _tracks = [];
  ConcatenatingAudioSource? _source;

  /// آخر خطأ تشغيل (تُظهره الواجهة برسالة مفهومة).
  final ValueNotifier<String?> error = ValueNotifier(null);

  List<Track> get tracks => List.unmodifiable(_tracks);

  void _init() {
    player.playbackEventStream.map(_toState).listen(playbackState.add, onError: (Object e, StackTrace s) {
      debugPrint('Playback error: $e');
      error.value = 'playback';
    });
    player.currentIndexStream.listen((i) {
      if (i != null && i >= 0 && i < queue.value.length) mediaItem.add(queue.value[i]);
    });
    player.durationStream.listen((d) {
      final i = player.currentIndex;
      if (d != null && i != null && i < queue.value.length && queue.value[i].duration == null) {
        final updated = queue.value[i].copyWith(duration: d);
        final q = [...queue.value]..[i] = updated;
        queue.add(q);
        mediaItem.add(updated);
      }
    });
  }

  AudioSource _src(Track t) => AudioSource.file(t.path, tag: t);

  MediaItem _item(Track t) => MediaItem(
        id: t.id,
        title: t.title,
        artist: t.artist.isEmpty ? null : t.artist,
        album: t.album.isEmpty ? null : t.album,
        duration: t.durationMs > 0 ? t.duration : null,
        artUri: t.artworkPath == null ? null : Uri.file(t.artworkPath!),
      );

  void _publishQueue() => queue.add(_tracks.map(_item).toList());

  /// يضبط قائمة الانتظار ويشغّل [index] (autoplay=false لاستعادة الحالة).
  Future<void> setQueue(List<Track> list, {int index = 0, bool autoplay = true, Duration? position}) async {
    if (list.isEmpty) return;
    error.value = null;
    _tracks
      ..clear()
      ..addAll(list);
    _publishQueue();
    _source = ConcatenatingAudioSource(children: list.map(_src).toList());
    try {
      await player.setAudioSource(_source!, initialIndex: index.clamp(0, list.length - 1), initialPosition: position);
      mediaItem.add(queue.value[player.currentIndex ?? index]);
      if (autoplay) unawaited(player.play());
    } catch (e) {
      debugPrint('setQueue failed: $e');
      error.value = 'playback';
    }
  }

  Future<void> enqueue(Track t, {bool next = false}) async {
    if (_source == null || _tracks.isEmpty) return setQueue([t]);
    final src = _src(t);
    if (next) {
      final at = (player.currentIndex ?? -1) + 1;
      await _source!.insert(at, src);
      _tracks.insert(at, t);
    } else {
      await _source!.add(src);
      _tracks.add(t);
    }
    _publishQueue();
  }

  Future<void> removeFromQueue(int index) async {
    if (_source == null || index < 0 || index >= _tracks.length) return;
    await _source!.removeAt(index);
    _tracks.removeAt(index);
    _publishQueue();
  }

  Future<void> moveInQueue(int from, int to) async {
    if (_source == null || from == to) return;
    await _source!.move(from, to);
    final t = _tracks.removeAt(from);
    _tracks.insert(to, t);
    _publishQueue();
  }

  Future<void> clearUpcoming() async {
    if (_source == null) return;
    final start = (player.currentIndex ?? -1) + 1;
    if (start >= _tracks.length) return;
    await _source!.removeRange(start, _tracks.length);
    _tracks.removeRange(start, _tracks.length);
    _publishQueue();
  }

  // ---- أوامر AudioHandler (تُستخدم أيضًا من الإشعار وشاشة القفل) ----
  @override
  Future<void> play() async {
    unawaited(player.play());
  }

  @override
  Future<void> pause() => player.pause();
  @override
  Future<void> seek(Duration position) => player.seek(position);
  @override
  Future<void> skipToNext() => player.seekToNext();
  @override
  Future<void> skipToPrevious() async {
    // أكثر من 3 ثوانٍ: ارجع لبداية الأغنية، وإلا السابقة
    if (player.position > const Duration(seconds: 3)) {
      await player.seek(Duration.zero);
    } else {
      await player.seekToPrevious();
    }
  }

  @override
  Future<void> skipToQueueItem(int index) => player.seek(Duration.zero, index: index);
  @override
  Future<void> stop() async {
    await player.stop();
    return super.stop();
  }

  PlaybackState _toState(PlaybackEvent e) => PlaybackState(
        controls: [
          MediaControl.skipToPrevious,
          if (player.playing) MediaControl.pause else MediaControl.play,
          MediaControl.skipToNext,
        ],
        systemActions: const {MediaAction.seek, MediaAction.seekForward, MediaAction.seekBackward},
        androidCompactActionIndices: const [0, 1, 2],
        processingState: const {
          ProcessingState.idle: AudioProcessingState.idle,
          ProcessingState.loading: AudioProcessingState.loading,
          ProcessingState.buffering: AudioProcessingState.buffering,
          ProcessingState.ready: AudioProcessingState.ready,
          ProcessingState.completed: AudioProcessingState.completed,
        }[player.processingState]!,
        playing: player.playing,
        updatePosition: player.position,
        bufferedPosition: player.bufferedPosition,
        speed: player.speed,
        queueIndex: e.currentIndex,
      );
}
