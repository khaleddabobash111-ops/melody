import 'package:flutter_test/flutter_test.dart';
import 'package:melody_music/data/models/track.dart';
import 'package:melody_music/providers/providers.dart';

Track t(String id, {String title = 't', String artist = '', String album = '', int? no, int added = 0, bool fav = false}) => Track(
      id: id, title: title, artist: artist, album: album, path: '/x/$id.mp3', dateAdded: added, fingerprint: id, trackNumber: no, isFavorite: fav);

void main() {
  test('Track toMap/fromMap تحفظ كل الحقول', () {
    final a = t('1', title: 'Song', artist: 'A', album: 'B', no: 3, fav: true);
    final b = Track.fromMap(a.toMap());
    expect(b.title, 'Song');
    expect(b.artist, 'A');
    expect(b.album, 'B');
    expect(b.trackNumber, 3);
    expect(b.isFavorite, isTrue);
  });

  test('التجميع يتجاهل الأسماء الفارغة ولا يختلق ألبومات', () {
    final groups = groupTracks([t('1', album: 'X', no: 2), t('2', album: 'X', no: 1), t('3', album: '')], (e) => e.album);
    expect(groups.length, 1);
    expect(groups.first.name, 'X');
    expect(groups.first.tracks.map((e) => e.id), ['2', '1']); // حسب رقم المقطع
  });

  test('الترتيب حسب الاسم/الفنان/التاريخ', () {
    final list = [t('1', title: 'b', artist: 'z', added: 1), t('2', title: 'a', artist: 'y', added: 3), t('3', title: 'c', artist: 'x', added: 2)];
    expect(sortTracks(list, 'title').map((e) => e.id), ['2', '1', '3']);
    expect(sortTracks(list, 'artist').map((e) => e.id), ['3', '2', '1']);
    expect(sortTracks(list, 'date').map((e) => e.id), ['2', '3', '1']);
  });
}
