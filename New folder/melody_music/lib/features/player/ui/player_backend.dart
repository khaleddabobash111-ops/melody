import 'models.dart';

/// الواجهة الوحيدة بين الـ UI والمشغّل الحقيقي. لا يوجد منطق صوت داخل الواجهات.
abstract class PlayerBackend {
  TrackInfo? get currentTrack;
  Stream<TrackInfo?> get trackStream;

  bool get playing;
  Stream<bool> get playingStream;

  Stream<Duration> get positionStream;
  Duration? get duration;
  Stream<Duration?> get durationStream;

  bool get shuffle;
  Stream<bool> get shuffleStream;
  RepeatMode get repeat;
  Stream<RepeatMode> get repeatStream;

  double get volume;

  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration position);
  Future<void> next();
  Future<void> previous();
  Future<void> setShuffle(bool value);
  Future<void> setRepeat(RepeatMode mode);
  Future<void> setVolume(double value);
}
