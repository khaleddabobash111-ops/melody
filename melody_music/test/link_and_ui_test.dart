import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:melody_music/core/l10n/strings.dart';
import 'package:melody_music/services/import_service.dart';
import 'package:melody_music/shared/widgets.dart';

void main() {
  group('التحقق من الروابط', () {
    test('يرفض الفارغ وغير https', () {
      expect(ImportService.validateLink(''), LinkError.invalid);
      expect(ImportService.validateLink('http://a.com/x.mp3'), LinkError.invalid);
      expect(ImportService.validateLink('not a url'), LinkError.invalid);
    });
    test('يميّز منصات البث', () {
      expect(ImportService.validateLink('https://www.youtube.com/watch?v=1'), LinkError.streaming);
      expect(ImportService.validateLink('https://open.spotify.com/track/1'), LinkError.streaming);
    });
    test('يقبل الرابط المباشر مبدئيًا', () {
      expect(ImportService.validateLink('https://example.com/a.mp3'), isNull);
    });
  });

  test('النصوص العربية والإنجليزية', () {
    expect(const S(true).library, 'المكتبة');
    expect(const S(false).library, 'Library');
    expect(const S(false).importResult(2, 1, 0), 'Added 2, skipped 1 duplicate');
  });

  testWidgets('EmptyState يعرض العنوان والزر ويستجيب', (tester) async {
    var tapped = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: EmptyState(icon: Icons.music_note, title: 'فارغ', actionLabel: 'استيراد', onAction: () => tapped = true)),
    ));
    expect(find.text('فارغ'), findsOneWidget);
    await tester.tap(find.text('استيراد'));
    expect(tapped, isTrue);
  });
}
