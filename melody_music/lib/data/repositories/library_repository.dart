import 'package:sqflite/sqflite.dart';
import '../models/track.dart';

class LibraryRepository {
  LibraryRepository(this.db);
  final Database db;

  // ---------- Tracks ----------
  Future<List<Track>> allTracks() async {
    final rows = await db.query('tracks', orderBy: 'date_added DESC');
    return rows.map(Track.fromMap).toList();
  }

  Future<List<Track>> tracksByIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    final rows = await db.query('tracks', where: 'id IN (${List.filled(ids.length, '?').join(',')})', whereArgs: ids);
    final byId = {for (final r in rows) r['id'] as String: Track.fromMap(r)};
    return [for (final id in ids) if (byId[id] != null) byId[id]!]; // يحافظ على الترتيب
  }

  Future<bool> hasFingerprint(String fp) async =>
      (await db.query('tracks', columns: ['id'], where: 'fingerprint = ?', whereArgs: [fp], limit: 1)).isNotEmpty;

  /// يرجع false إن كانت الأغنية مكررة.
  Future<bool> insertTrack(Track t) async {
    final id = await db.insert('tracks', t.toMap(), conflictAlgorithm: ConflictAlgorithm.ignore);
    return id != 0;
  }

  Future<void> setFavorite(String id, bool fav) =>
      db.update('tracks', {'is_favorite': fav ? 1 : 0}, where: 'id = ?', whereArgs: [id]);

  Future<void> updateMeta(String id, {required String title, required String artist, required String album}) =>
      db.update('tracks', {'title': title, 'artist': artist, 'album': album}, where: 'id = ?', whereArgs: [id]);

  Future<void> markPlayed(String id, int at) =>
      db.update('tracks', {'last_played': at}, where: 'id = ?', whereArgs: [id]);

  Future<void> clearHistory() => db.update('tracks', {'last_played': null});

  /// يحذف السجل من المكتبة (ويُحذف تلقائيًا من القوائم بسبب CASCADE).
  Future<Track?> removeTrack(String id) async {
    final rows = await db.query('tracks', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    await db.delete('tracks', where: 'id = ?', whereArgs: [id]);
    return Track.fromMap(rows.first);
  }

  // ---------- Playlists ----------
  Future<List<Playlist>> playlists() async {
    final rows = await db.rawQuery('''
SELECT p.*, COUNT(pt.track_id) AS track_count, COALESCE(SUM(t.duration_ms),0) AS total_ms
FROM playlists p
LEFT JOIN playlist_tracks pt ON pt.playlist_id = p.id
LEFT JOIN tracks t ON t.id = pt.track_id
GROUP BY p.id ORDER BY p.updated_at DESC''');
    return rows.map(Playlist.fromMap).toList();
  }

  Future<String> createPlaylist(String name, {String? description}) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = 'pl_$now';
    await db.insert('playlists', {'id': id, 'name': name, 'description': description, 'created_at': now, 'updated_at': now});
    return id;
  }

  Future<void> renamePlaylist(String id, String name) => db.update(
      'playlists', {'name': name, 'updated_at': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?', whereArgs: [id]);

  Future<void> setPlaylistArtwork(String id, String? path) =>
      db.update('playlists', {'artwork_path': path}, where: 'id = ?', whereArgs: [id]);

  Future<void> deletePlaylist(String id) => db.delete('playlists', where: 'id = ?', whereArgs: [id]);

  Future<List<Track>> playlistTracks(String playlistId) async {
    final rows = await db.rawQuery('''
SELECT t.* FROM playlist_tracks pt JOIN tracks t ON t.id = pt.track_id
WHERE pt.playlist_id = ? ORDER BY pt.position ASC''', [playlistId]);
    return rows.map(Track.fromMap).toList();
  }

  Future<void> addToPlaylist(String playlistId, String trackId) async {
    final r = await db.rawQuery('SELECT COALESCE(MAX(position), -1) + 1 AS p FROM playlist_tracks WHERE playlist_id = ?', [playlistId]);
    final pos = (r.first['p'] as int?) ?? 0;
    await db.insert('playlist_tracks', {'playlist_id': playlistId, 'track_id': trackId, 'position': pos},
        conflictAlgorithm: ConflictAlgorithm.ignore);
    await _touch(playlistId);
  }

  Future<void> removeFromPlaylist(String playlistId, String trackId) async {
    await db.delete('playlist_tracks', where: 'playlist_id = ? AND track_id = ?', whereArgs: [playlistId, trackId]);
    await _touch(playlistId);
  }

  /// يحفظ ترتيب القائمة كما هو في [orderedIds].
  Future<void> reorderPlaylist(String playlistId, List<String> orderedIds) async {
    await db.transaction((txn) async {
      for (var i = 0; i < orderedIds.length; i++) {
        await txn.update('playlist_tracks', {'position': i},
            where: 'playlist_id = ? AND track_id = ?', whereArgs: [playlistId, orderedIds[i]]);
      }
    });
    await _touch(playlistId);
  }

  Future<void> _touch(String id) => db.update('playlists', {'updated_at': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?', whereArgs: [id]);
}
