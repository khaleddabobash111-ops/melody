import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// قاعدة البيانات المحلية. الترحيلات تراكمية ولا تمسح البيانات أبدًا.
class AppDatabase {
  static const _version = 1;

  static Future<Database> open({String? path}) async {
    final dbPath = path ?? p.join(await getDatabasesPath(), 'melody.db');
    return openDatabase(
      dbPath,
      version: _version,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, v) async {
        await db.execute('''
CREATE TABLE tracks(
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  artist TEXT NOT NULL DEFAULT '',
  album TEXT NOT NULL DEFAULT '',
  album_artist TEXT,
  track_no INTEGER,
  duration_ms INTEGER NOT NULL DEFAULT 0,
  path TEXT NOT NULL,
  artwork_path TEXT,
  date_added INTEGER NOT NULL,
  last_played INTEGER,
  is_favorite INTEGER NOT NULL DEFAULT 0,
  source_type TEXT NOT NULL DEFAULT 'local',
  fingerprint TEXT NOT NULL UNIQUE
)''');
        await db.execute('''
CREATE TABLE playlists(
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  description TEXT,
  artwork_path TEXT,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
)''');
        await db.execute('''
CREATE TABLE playlist_tracks(
  playlist_id TEXT NOT NULL REFERENCES playlists(id) ON DELETE CASCADE,
  track_id TEXT NOT NULL REFERENCES tracks(id) ON DELETE CASCADE,
  position INTEGER NOT NULL,
  PRIMARY KEY(playlist_id, track_id)
)''');
        await db.execute('CREATE INDEX idx_pt_pos ON playlist_tracks(playlist_id, position)');
        await db.execute('CREATE INDEX idx_tracks_added ON tracks(date_added)');
      },
      onUpgrade: (db, from, to) async {
        // مستقبلًا: if (from < 2) { await db.execute('ALTER TABLE ...'); }
      },
    );
  }
}
