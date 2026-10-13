import 'package:just_audio/just_audio.dart';
import 'models.dart';
import 'player_backend.dart';

/// محوّل جاهز لـ just_audio. إن كنت تستخدم مكتبة أخرى، اكتب محوّلًا مماثلًا.
/// [trackFromTag] يحوّل `AudioSource.tag` (الذي تضعه عند بناء القائمة) إلى TrackInfo.
class JustAudioBackend implements PlayerBackend {
  JustAudioBackend(this.player, {required this.trackFromTag});
  final AudioPlayer player;
  final TrackInfo? Function(Object? tag) trackFromTag;

  @override
  TrackInfo? get currentTrack => trackFromTag(player.sequenceState?.currentSource?.tag);
  @override
  Stream<TrackInfo?> get trackStream => player.sequenceStateStream
      .map((s) => trackFromTag(s?.currentSource?.tag))
      .distinct((a, b) => a?.id == b?.id);

  @override
  bool get playing => player.playing;
  @override
  Stream<bool> get playingStream => player.playingStream;

  @override
  Stream<Duration> get positionStream => player.positionStream;
  @override
  Duration? get duration => player.duration;
  @override
  Stream<Duration?> get durationStream => player.durationStream;

  @override
  bool get shuffle => player.shuffleModeEnabled;
  @override
  Stream<bool> get shuffleStream => player.shuffleModeEnabledStream;
  @override
  RepeatMode get repeat => _fromLoop(player.loopMode);
  @override
  Stream<RepeatMode> get repeatStream => player.loopModeStream.map(_fromLoop);

  @override
  double get volume => player.volume;

  static RepeatMode _fromLoop(LoopMode m) => switch (m) {
        LoopMode.off => RepeatMode.off,
        LoopMode.all => RepeatMode.all,
        LoopMode.one => RepeatMode.one,
      };

  @override
  Future<void> play() async {
    // play() يكتمل عند انتهاء التشغيل، لذلك لا ننتظره.
    player.play();
  }

  @override
  Future<void> pause() => player.pause();
  @override
  Future<void> seek(Duration position) => player.seek(position);
  @override
  Future<void> next() => player.seekToNext();
  @override
  Future<void> previous() => player.seekToPrevious();
  @override
  Future<void> setShuffle(bool value) async {
    if (value) await player.shuffle();
    await player.setShuffleModeEnabled(value);
  }

  @override
  Future<void> setRepeat(RepeatMode mode) => player.setLoopMode(switch (mode) {
        RepeatMode.off => LoopMode.off,
        RepeatMode.all => LoopMode.all,
        RepeatMode.one => LoopMode.one,
      });
  @override
  Future<void> setVolume(double value) => player.setVolume(value);
}
