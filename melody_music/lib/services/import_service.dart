import 'dart:async';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../data/models/track.dart';
import '../data/repositories/library_repository.dart';
import 'metadata_reader.dart';

class ImportResult {
  const ImportResult({this.added = 0, this.skipped = 0, this.failed = 0, this.tracks = const []});
  final int added, skipped, failed;
  final List<Track> tracks;
}

enum LinkError { invalid, streaming, notAudio, network, duplicate }

class LinkImportException implements Exception {
  LinkImportException(this.error);
  final LinkError error;
}

class ImportService {
  ImportService(this.repo);
  final LibraryRepository repo;

  static const supportedExt = {'.mp3', '.m4a', '.aac', '.flac', '.wav', '.ogg', '.opus', '.wma'};
  static const _streamingHosts = [
    'youtube.com', 'youtu.be', 'spotify.com', 'music.apple.com', 'soundcloud.com',
    'deezer.com', 'tidal.com', 'anghami.com', 'music.amazon.com',
  ];
  static const _maxDownload = 300 * 1024 * 1024;

  Future<Directory> _dir(String name) async {
    final base = await getApplicationDocumentsDirectory();
    return Directory(p.join(base.path, name)).create(recursive: true);
  }

  /// بصمة: حجم الملف + SHA1 لأول 256KB. سريعة وكافية لمنع التكرار.
  Future<String> fingerprint(File f) async {
    final raf = await f.open();
    try {
      final len = await raf.length();
      final head = await raf.read(len < 262144 ? len : 262144);
      return sha1.convert([...head, ...len.toString().codeUnits]).toString();
    } finally {
      await raf.close();
    }
  }

  // ---------- ملفات محلية ----------
  Future<ImportResult> importFiles(List<String> paths, {bool Function()? cancelled, void Function(int done, int total)? onProgress}) async {
    var added = 0, skipped = 0, failed = 0;
    final tracks = <Track>[];
    for (var i = 0; i < paths.length; i++) {
      if (cancelled?.call() ?? false) break;
      try {
        final t = await _importOne(File(paths[i]), 'local');
        if (t == null) {
          skipped++;
        } else {
          added++;
          tracks.add(t);
        }
      } catch (e) {
        debugPrint('import failed ${paths[i]}: $e');
        failed++;
      }
      onProgress?.call(i + 1, paths.length);
    }
    return ImportResult(added: added, skipped: skipped, failed: failed, tracks: tracks);
  }

  /// null = مكرر. يرمي استثناء عند الفشل (ملف غير مدعوم/تالف).
  Future<Track?> _importOne(File src, String sourceType) async {
    final ext = p.extension(src.path).toLowerCase();
    if (!supportedExt.contains(ext)) throw const FormatException('unsupported');
    if (!await src.exists() || await src.length() == 0) throw const FormatException('empty');

    final fp = await fingerprint(src);
    if (await repo.hasFingerprint(fp)) {
      await _cleanTemp(src);
      return null;
    }
    final musicDir = await _dir('music');
    final safe = p.basename(src.path).replaceAll(RegExp(r'[^\w\.\-\u0600-\u06FF ]'), '_');
    final dest = File(p.join(musicDir.path, '${fp.substring(0, 10)}_$safe'));
    if (src.path != dest.path) await src.copy(dest.path);
    await _cleanTemp(src);

    final meta = readTrackMeta(dest);
    String? artPath;
    if (meta.artwork != null && meta.artwork!.isNotEmpty) {
      final artDir = await _dir('artwork');
      final f = File(p.join(artDir.path, '$fp.${meta.artworkExt}'));
      await f.writeAsBytes(meta.artwork!, flush: true);
      artPath = f.path;
    }
    final fallbackTitle = p.basenameWithoutExtension(src.path);
    final track = Track(
      id: fp,
      title: (meta.title?.trim().isNotEmpty ?? false) ? meta.title!.trim() : fallbackTitle,
      artist: meta.artist?.trim() ?? '',
      album: meta.album?.trim() ?? '',
      albumArtist: meta.albumArtist,
      trackNumber: meta.trackNumber,
      durationMs: meta.durationMs,
      path: dest.path,
      artworkPath: artPath,
      dateAdded: DateTime.now().millisecondsSinceEpoch,
      fingerprint: fp,
      sourceType: sourceType,
    );
    final ok = await repo.insertTrack(track);
    if (!ok) {
      if (await dest.exists()) await dest.delete();
      return null;
    }
    return track;
  }

  Future<void> _cleanTemp(File f) async {
    try {
      final tmp = (await getTemporaryDirectory()).path;
      if (f.path.startsWith(tmp) && await f.exists()) await f.delete();
    } catch (_) {}
  }

  // ---------- رابط مباشر ----------
  static LinkError? validateLink(String raw) {
    final uri = Uri.tryParse(raw.trim());
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) return LinkError.invalid;
    final host = uri.host.toLowerCase();
    if (_streamingHosts.any((h) => host == h || host.endsWith('.$h'))) return LinkError.streaming;
    return null;
  }

  /// ينزّل ملفًا صوتيًا مباشرًا فقط. لا يتجاوز أي حماية أو اشتراك.
  Future<Track> importLink(String raw, {bool Function()? cancelled}) async {
    final bad = validateLink(raw);
    if (bad != null) throw LinkImportException(bad);
    final uri = Uri.parse(raw.trim());
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
    File? tmp;
    try {
      final req = await client.getUrl(uri);
      final res = await req.close().timeout(const Duration(seconds: 20));
      if (res.statusCode != 200) throw LinkImportException(LinkError.notAudio);
      final type = res.headers.contentType?.mimeType ?? '';
      var ext = p.extension(uri.path).toLowerCase();
      final looksAudio = type.startsWith('audio/') || (type == 'application/octet-stream' && supportedExt.contains(ext));
      if (!looksAudio) throw LinkImportException(LinkError.notAudio);
      if (!supportedExt.contains(ext)) ext = type.contains('mpeg') ? '.mp3' : type.contains('flac') ? '.flac' : type.contains('ogg') ? '.ogg' : '.m4a';
      if (res.contentLength > _maxDownload) throw LinkImportException(LinkError.notAudio);

      final tmpDir = await getTemporaryDirectory();
      final name = p.basenameWithoutExtension(uri.path).isEmpty ? 'track' : p.basenameWithoutExtension(uri.path);
      tmp = File(p.join(tmpDir.path, '${DateTime.now().microsecondsSinceEpoch}_$name$ext'));
      final sink = tmp.openWrite();
      var received = 0;
      try {
        await for (final chunk in res.timeout(const Duration(seconds: 30))) {
          if (cancelled?.call() ?? false) throw LinkImportException(LinkError.network);
          received += chunk.length;
          if (received > _maxDownload) throw LinkImportException(LinkError.notAudio);
          sink.add(chunk);
        }
      } finally {
        await sink.close();
      }
      final t = await _importOne(tmp, 'link');
      if (t == null) throw LinkImportException(LinkError.duplicate);
      return t;
    } on LinkImportException {
      if (tmp != null && await tmp.exists()) await tmp.delete();
      rethrow;
    } on FormatException {
      throw LinkImportException(LinkError.notAudio);
    } catch (e) {
      debugPrint('link import failed: $e');
      if (tmp != null && await tmp.exists()) await tmp.delete();
      throw LinkImportException(LinkError.network);
    } finally {
      client.close();
    }
  }

  /// يحذف نسخة التطبيق من الملف والغلاف (الملف الأصلي على الهاتف لا يُمس).
  Future<void> deleteFiles(Track t) async {
    for (final path in [t.path, t.artworkPath]) {
      if (path == null) continue;
      try {
        final f = File(path);
        if (await f.exists()) await f.delete();
      } catch (_) {}
    }
  }
}
