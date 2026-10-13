import 'dart:io';
import 'package:flutter/widgets.dart';
import '../../features/player/ui/models.dart';

/// أغنية في المكتبة. [path] مسار الملف داخل مساحة التطبيق.
@immutable
class Track {
  const Track({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.path,
    required this.dateAdded,
    required this.fingerprint,
    this.albumArtist,
    this.trackNumber,
    this.durationMs = 0,
    this.artworkPath,
    this.lastPlayed,
    this.isFavorite = false,
    this.sourceType = 'local',
  });

  final String id;
  final String title;
  final String artist; // قد تكون فارغة إن لم تتوفر في الملف
  final String album; // قد تكون فارغة
  final String? albumArtist;
  final int? trackNumber;
  final int durationMs;
  final String path;
  final String? artworkPath;
  final int dateAdded;
  final int? lastPlayed;
  final bool isFavorite;
  final String sourceType; // local | link
  final String fingerprint;

  Duration get duration => Duration(milliseconds: durationMs);

  Track copyWith({bool? isFavorite, int? lastPlayed, String? title, String? artist, String? album, bool clearLastPlayed = false}) => Track(
        id: id,
        title: title ?? this.title,
        artist: artist ?? this.artist,
        album: album ?? this.album,
        albumArtist: albumArtist,
        trackNumber: trackNumber,
        durationMs: durationMs,
        path: path,
        artworkPath: artworkPath,
        dateAdded: dateAdded,
        lastPlayed: clearLastPlayed ? null : (lastPlayed ?? this.lastPlayed),
        isFavorite: isFavorite ?? this.isFavorite,
        sourceType: sourceType,
        fingerprint: fingerprint,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'title': title,
        'artist': artist,
        'album': album,
        'album_artist': albumArtist,
        'track_no': trackNumber,
        'duration_ms': durationMs,
        'path': path,
        'artwork_path': artworkPath,
        'date_added': dateAdded,
        'last_played': lastPlayed,
        'is_favorite': isFavorite ? 1 : 0,
        'source_type': sourceType,
        'fingerprint': fingerprint,
      };

  factory Track.fromMap(Map<String, Object?> m) => Track(
        id: m['id'] as String,
        title: m['title'] as String,
        artist: (m['artist'] as String?) ?? '',
        album: (m['album'] as String?) ?? '',
        albumArtist: m['album_artist'] as String?,
        trackNumber: m['track_no'] as int?,
        durationMs: (m['duration_ms'] as int?) ?? 0,
        path: m['path'] as String,
        artworkPath: m['artwork_path'] as String?,
        dateAdded: m['date_added'] as int,
        lastPlayed: m['last_played'] as int?,
        isFavorite: (m['is_favorite'] as int? ?? 0) == 1,
        sourceType: (m['source_type'] as String?) ?? 'local',
        fingerprint: m['fingerprint'] as String,
      );

  TrackInfo toInfo() => TrackInfo(
        id: id,
        title: title,
        artist: artist,
        album: album.isEmpty ? null : album,
        artwork: artworkPath == null ? null : FileImage(File(artworkPath!)),
        duration: durationMs > 0 ? duration : null,
      );

  @override
  bool operator ==(Object o) => o is Track && o.id == id && o.isFavorite == isFavorite && o.title == title && o.artist == artist && o.album == album;
  @override
  int get hashCode => Object.hash(id, isFavorite, title, artist, album);
}

@immutable
class Playlist {
  const Playlist({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    this.description,
    this.artworkPath,
    this.trackCount = 0,
    this.totalMs = 0,
  });
  final String id;
  final String name;
  final String? description;
  final String? artworkPath;
  final int createdAt;
  final int updatedAt;
  final int trackCount;
  final int totalMs;

  factory Playlist.fromMap(Map<String, Object?> m) => Playlist(
        id: m['id'] as String,
        name: m['name'] as String,
        description: m['description'] as String?,
        artworkPath: m['artwork_path'] as String?,
        createdAt: m['created_at'] as int,
        updatedAt: m['updated_at'] as int,
        trackCount: (m['track_count'] as int?) ?? 0,
        totalMs: (m['total_ms'] as int?) ?? 0,
      );
}

/// ألبوم أو فنان مجمّع من الأغاني.
class TrackGroup {
  TrackGroup(this.name, this.tracks);
  final String name;
  final List<Track> tracks;
  String? get artworkPath {
    for (final t in tracks) {
      if (t.artworkPath != null) return t.artworkPath;
    }
    return null;
  }
}

List<TrackGroup> groupTracks(List<Track> tracks, String Function(Track) key) {
  final map = <String, List<Track>>{};
  for (final t in tracks) {
    final k = key(t).trim();
    if (k.isEmpty) continue; // لا نختلق أسماء ألبومات/فنانين غير موجودة
    map.putIfAbsent(k, () => []).add(t);
  }
  final groups = map.entries.map((e) {
    final list = e.value..sort((a, b) => (a.trackNumber ?? 9999).compareTo(b.trackNumber ?? 9999));
    return TrackGroup(e.key, list);
  }).toList()
    ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  return groups;
}
