import 'package:flutter_test/flutter_test.dart';
import 'package:melody_music/data/database/app_database.dart';
import 'package:melody_music/data/models/track.dart';
import 'package:melody_music/data/repositories/library_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Track t(String id) => Track(id: id, title: 'T$id', artist: '', album: '', path: '/x/$id.mp3', dateAdded: int.parse(id), fingerprint: 'fp$id');

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  late LibraryRepository repo;

  setUp(() async => repo = LibraryRepository(await AppDatabase.open(path: inMemoryDatabasePath)));

  test('منع التكرار عبر البصمة', () async {
    expect(await repo.insertTrack(t('1')), isTrue);
    final dup = Track.fromMap({...t('2').toMap(), 'fingerprint': 'fp1'});
    expect(await repo.insertTrack(dup), isFalse);
    expect((await repo.allTracks()).length, 1);
  });

  test('المفضلة وسجل التشغيل', () async {
    await repo.insertTrack(t('1'));
    await repo.setFavorite('1', true);
    await repo.markPlayed('1', 123);
    var l = await repo.allTracks();
    expect(l.first.isFavorite, isTrue);
    expect(l.first.lastPlayed, 123);
    await repo.clearHistory();
    l = await repo.allTracks();
    expect(l.first.lastPlayed, isNull);
    expect(l.first.isFavorite, isTrue); // المسح لا يلمس المفضلة
  });

  test('قوائم التشغيل: إضافة وترتيب وحذف دون حذف الأغاني', () async {
    for (final i in ['1', '2', '3']) {
      await repo.insertTrack(t(i));
    }
    final pl = await repo.createPlaylist('Mix');
    for (final i in ['1', '2', '3']) {
      await repo.addToPlaylist(pl, i);
    }
    await repo.addToPlaylist(pl, '2'); // تكرار يُتجاهل
    expect((await repo.playlistTracks(pl)).map((e) => e.id), ['1', '2', '3']);

    await repo.reorderPlaylist(pl, ['3', '1', '2']);
    expect((await repo.playlistTracks(pl)).map((e) => e.id), ['3', '1', '2']);

    final lists = await repo.playlists();
    expect(lists.first.trackCount, 3);

    await repo.removeFromPlaylist(pl, '1');
    expect((await repo.playlistTracks(pl)).length, 2);

    await repo.deletePlaylist(pl);
    expect((await repo.allTracks()).length, 3);
  });

  test('حذف أغنية يزيلها من القوائم تلقائيًا', () async {
    await repo.insertTrack(t('1'));
    final pl = await repo.createPlaylist('A');
    await repo.addToPlaylist(pl, '1');
    await repo.removeTrack('1');
    expect(await repo.playlistTracks(pl), isEmpty);
  });

  test('tracksByIds يحافظ على الترتيب المطلوب', () async {
    for (final i in ['1', '2', '3']) {
      await repo.insertTrack(t(i));
    }
    expect((await repo.tracksByIds(['3', '1'])).map((e) => e.id), ['3', '1']);
  });
}
