import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:melody_music/features/player/ui/artwork_palette.dart';

void main() {
  test('الغلاف الرمادي يبقى محايدًا', () {
    final p = ArtworkPalette.fromColors(const Color(0xFF808080));
    expect(HSLColor.fromColor(p.dominant).saturation, lessThan(0.1));
  });
  test('اللون الأساسي ضمن حدود الإضاءة المريحة', () {
    for (final c in [Colors.red, Colors.blue, Colors.white, Colors.black, Colors.amber]) {
      final l = HSLColor.fromColor(ArtworkPalette.fromColors(c).dominant).lightness;
      expect(l, inInclusiveRange(0.30, 0.57));
    }
  });
  test('لون الخلفية داكن ولون النص فاتح', () {
    final p = ArtworkPalette.fromColors(Colors.red);
    expect(HSLColor.fromColor(p.dark).lightness, lessThan(0.12));
    expect(HSLColor.fromColor(p.light).lightness, greaterThan(0.8));
  });
  test('lerp عند الطرفين', () {
    const a = ArtworkPalette.fallback;
    final b = ArtworkPalette.fromColors(Colors.red);
    expect(ArtworkPalette.lerp(a, b, 0), a);
    expect(ArtworkPalette.lerp(a, b, 1), b);
  });
}
