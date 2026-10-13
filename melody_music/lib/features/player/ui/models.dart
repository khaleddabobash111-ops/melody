import 'package:flutter/widgets.dart';

enum RepeatMode { off, all, one }

/// بيانات الأغنية التي تحتاجها الواجهة فقط.
/// حوّل نموذج أغنيتك الحالي إليها (artwork = FileImage / MemoryImage / NetworkImage ...).
@immutable
class TrackInfo {
  const TrackInfo({
    required this.id,
    required this.title,
    required this.artist,
    this.album,
    this.artwork,
    this.duration,
  });
  final String id;
  final String title;
  final String artist;
  final String? album;
  final ImageProvider? artwork;
  final Duration? duration;

  @override
  bool operator ==(Object other) => other is TrackInfo && other.id == id;
  @override
  int get hashCode => id.hashCode;
}

/// أزرار اختيارية تربطها بمنطق تطبيقك (المفضلة، القائمة، ...).
class PlayerActions {
  const PlayerActions({
    this.isFavorite,
    this.onToggleFavorite,
    this.onShowQueue,
    this.onTrackOptions,
    this.onPickDevice,
    this.contextTitle,
  });
  final bool Function(TrackInfo track)? isFavorite;
  final void Function(TrackInfo track)? onToggleFavorite;
  final VoidCallback? onShowQueue;
  final void Function(TrackInfo track)? onTrackOptions;
  final VoidCallback? onPickDevice;
  final String? contextTitle;
}
