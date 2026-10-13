import 'dart:io';
import 'dart:typed_data';
import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:flutter/foundation.dart';

class ParsedMeta {
  const ParsedMeta({this.title, this.artist, this.album, this.albumArtist, this.trackNumber, this.durationMs = 0, this.artwork, this.artworkExt = 'jpg'});
  final String? title, artist, album, albumArtist;
  final int? trackNumber;
  final int durationMs;
  final Uint8List? artwork;
  final String artworkExt;
}

/// الاعتماد الوحيد على مكتبة قراءة الوسوم. إن تغيّرت واجهة المكتبة أو استبدلتها، عدّل هذا الملف فقط.
ParsedMeta readTrackMeta(File file) {
  try {
    final m = readMetadata(file, getImage: true);
    Uint8List? art;
    var ext = 'jpg';
    if (m.pictures.isNotEmpty) {
      art = m.pictures.first.bytes;
      if (m.pictures.first.mimetype.toLowerCase().contains('png')) ext = 'png';
    }
    return ParsedMeta(
      title: m.title,
      artist: m.artist,
      album: m.album,
      trackNumber: m.trackNumber,
      durationMs: m.duration?.inMilliseconds ?? 0,
      artwork: art,
      artworkExt: ext,
    );
  } catch (e) {
    debugPrint('metadata read failed for ${file.path}: $e'); // ملف تالف أو صيغة بلا وسوم
    return const ParsedMeta();
  }
}
