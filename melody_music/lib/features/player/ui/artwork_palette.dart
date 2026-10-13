import 'package:flutter/material.dart';
import 'package:palette_generator/palette_generator.dart';
import 'models.dart';

/// لوحة ألوان كاملة مستخرجة من الغلاف.
@immutable
class ArtworkPalette {
  const ArtworkPalette({
    required this.dominant,
    required this.secondary,
    required this.dark,
    required this.light,
  });

  final Color dominant; // اللون الأساسي (مضبوط ليكون مريحًا)
  final Color secondary; // اللون الثانوي
  final Color dark; // لون خلفية داكن
  final Color light; // لون للنصوص واللمسات

  static const fallback = ArtworkPalette(
    dominant: Color(0xFF6C4DFF),
    secondary: Color(0xFF2E7DFF),
    dark: Color(0xFF0B0A12),
    light: Color(0xFFE9E4FF),
  );

  /// دالة نقية (قابلة للاختبار): تشتق اللوحة من لونين خام.
  static ArtworkPalette fromColors(Color base, [Color? second]) {
    final b = HSLColor.fromColor(base);
    final neutral = b.saturation < 0.08; // غلاف رمادي/أبيض/أسود: لا نُلوّنه
    final dom = _tune(base, minS: 0.35, minL: 0.32, maxL: 0.55);
    final sec = _tune(
      second ??
          HSLColor.fromAHSL(
            1,
            (b.hue + 35) % 360,
            neutral ? b.saturation : b.saturation.clamp(0.3, 1.0).toDouble(),
            0.4,
          ).toColor(),
      minS: 0.3,
      minL: 0.25,
      maxL: 0.6,
    );
    final dark = HSLColor.fromAHSL(
        1, b.hue, (b.saturation * 0.6).clamp(0.0, 0.5).toDouble(), 0.07).toColor();
    final light = HSLColor.fromAHSL(
        1, b.hue, (b.saturation * 0.8).clamp(0.0, 0.8).toDouble(), 0.88).toColor();
    return ArtworkPalette(dominant: dom, secondary: sec, dark: dark, light: light);
  }

  static Color _tune(Color c, {double minS = 0, double minL = 0, double maxL = 1}) {
    final h = HSLColor.fromColor(c);
    final s = h.saturation < 0.08 ? h.saturation : h.saturation.clamp(minS, 1.0).toDouble();
    final l = h.lightness.clamp(minL, maxL).toDouble();
    return h.withSaturation(s).withLightness(l).toColor();
  }

  /// استخراج من الصورة (على نسخة مصغّرة 96px لتوفير الأداء).
  static Future<ArtworkPalette> extract(ImageProvider image) async {
    try {
      final g = await PaletteGenerator.fromImageProvider(
        ResizeImage(image, width: 96, height: 96),
        maximumColorCount: 16,
      ).timeout(const Duration(seconds: 6));
      final base = g.vibrantColor?.color ??
          g.dominantColor?.color ??
          g.mutedColor?.color;
      if (base == null) return fallback;
      final second = g.darkVibrantColor?.color ??
          g.lightVibrantColor?.color ??
          g.mutedColor?.color;
      return fromColors(base, second == base ? null : second);
    } catch (_) {
      return fallback;
    }
  }

  static ArtworkPalette lerp(ArtworkPalette a, ArtworkPalette b, double t) =>
      ArtworkPalette(
        dominant: Color.lerp(a.dominant, b.dominant, t)!,
        secondary: Color.lerp(a.secondary, b.secondary, t)!,
        dark: Color.lerp(a.dark, b.dark, t)!,
        light: Color.lerp(a.light, b.light, t)!,
      );

  @override
  bool operator ==(Object o) =>
      o is ArtworkPalette &&
      o.dominant == dominant &&
      o.secondary == secondary &&
      o.dark == dark &&
      o.light == light;
  @override
  int get hashCode => Object.hash(dominant, secondary, dark, light);
}

class PaletteTween extends Tween<ArtworkPalette> {
  PaletteTween({super.begin, super.end});
  @override
  ArtworkPalette lerp(double t) => ArtworkPalette.lerp(begin!, end!, t);
}

/// يستخرج ألوان الأغنية الحالية، مع كاش LRU، ويتجاهل النتائج القديمة عند تغيير الأغاني بسرعة.
class PaletteController extends ValueNotifier<ArtworkPalette> {
  PaletteController() : super(ArtworkPalette.fallback);

  static final Map<String, ArtworkPalette> _cache = {};
  int _token = 0;

  Future<void> update(TrackInfo? track) async {
    final token = ++_token;
    final art = track?.artwork;
    if (track == null || art == null) {
      value = ArtworkPalette.fallback;
      return;
    }
    final hit = _cache.remove(track.id);
    if (hit != null) {
      _cache[track.id] = hit; // تحديث ترتيب LRU
      value = hit;
      return;
    }
    final p = await ArtworkPalette.extract(art);
    if (token != _token) return; // وصلت أغنية أحدث
    _cache[track.id] = p;
    if (_cache.length > 80) _cache.remove(_cache.keys.first);
    value = p;
  }
}
