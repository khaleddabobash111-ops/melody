import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/l10n/strings.dart';
import '../core/theme/app_theme.dart';
import '../data/models/track.dart';
import '../providers/providers.dart';

/// معرّف الأغنية الحالية (للمؤشر في القوائم).
final currentTrackIdProvider = StreamProvider<String?>((ref) async* {
  final b = ref.watch(backendProvider);
  yield b.currentTrack?.id;
  yield* b.trackStream.map((t) => t?.id);
});

/// صورة غلاف مصغّرة (تُفك بدقة محدودة لتوفير الذاكرة) مع placeholder.
class Cover extends StatelessWidget {
  const Cover({super.key, this.path, this.size, this.radius = 12, this.circle = false, this.icon = Icons.music_note_rounded});
  final String? path;
  final double? size;
  final double radius;
  final bool circle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final placeholder = DecoratedBox(
      decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF2A2A36), Color(0xFF15151C)], begin: Alignment.topLeft, end: Alignment.bottomRight)),
      child: Center(child: Icon(icon, color: Colors.white38, size: (size ?? 80) * .4)),
    );
    final px = ((size ?? 300) * MediaQuery.devicePixelRatioOf(context)).round();
    final child = path == null
        ? placeholder
        : Image(
            image: ResizeImage(FileImage(File(path!)), width: px),
            fit: BoxFit.cover,
            gaplessPlayback: true,
            errorBuilder: (_, __, ___) => placeholder,
          );
    final clipped = circle ? ClipOval(child: child) : ClipRRect(borderRadius: BorderRadius.circular(radius), child: child);
    return size == null ? clipped : SizedBox(width: size, height: size, child: clipped);
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, this.body, this.actionLabel, this.onAction});
  final IconData icon;
  final String title;
  final String? body;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [AppColors.brand.withOpacity(.35), AppColors.brand.withOpacity(.05)]),
              ),
              child: Icon(icon, size: 44, color: Colors.white70),
            ),
            const SizedBox(height: 20),
            Text(title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            if (body != null) ...[
              const SizedBox(height: 8),
              Text(body!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary, height: 1.5)),
            ],
            if (actionLabel != null) ...[
              const SizedBox(height: 24),
              FilledButton.icon(onPressed: onAction, icon: const Icon(Icons.add_rounded), label: Text(actionLabel!)),
            ],
          ]),
        ),
      );
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.trailing});
  final String title;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 12, 10),
        child: Row(children: [
          Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800))),
          if (trailing != null) trailing!,
        ]),
      );
}

String artistLabel(BuildContext c, Track t) => t.artist.isEmpty ? S.of(c).unknownArtist : t.artist;

String fmtDuration(int ms) {
  if (ms <= 0) return '';
  final d = Duration(milliseconds: ms);
  return '${d.inMinutes}:${d.inSeconds.remainder(60).toString().padLeft(2, '0')}';
}

class TrackTile extends ConsumerWidget {
  const TrackTile({super.key, required this.track, required this.onTap, this.onLongPress, this.trailing});
  final Track track;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final Widget? trailing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(currentTrackIdProvider).valueOrNull == track.id;
    final color = current ? AppColors.brand : null;
    return ListTile(
      onTap: onTap,
      onLongPress: onLongPress,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: Stack(alignment: Alignment.center, children: [
        Cover(path: track.artworkPath, size: 52, radius: 10),
        if (current) Container(width: 52, height: 52, decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.graphic_eq_rounded, color: AppColors.brand)),
      ]),
      title: Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w700, color: color)),
      subtitle: Text(artistLabel(context, track), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
      trailing: trailing ??
          Row(mainAxisSize: MainAxisSize.min, children: [
            if (track.isFavorite) const Icon(Icons.favorite_rounded, size: 16, color: Color(0xFFFF4D6D)),
            if (track.durationMs > 0) Padding(padding: const EdgeInsets.only(left: 8, right: 8), child: Text(fmtDuration(track.durationMs), style: const TextStyle(color: AppColors.textSecondary, fontSize: 12))),
            IconButton(icon: const Icon(Icons.more_vert_rounded, size: 20), onPressed: onLongPress),
          ]),
    );
  }
}

/// بطاقة أغنية بصورة كبيرة (شبكة أو قائمة أفقية).
class TrackCard extends ConsumerWidget {
  const TrackCard({super.key, required this.track, required this.onTap, this.onLongPress, this.width});
  final Track track;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final double? width;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(currentTrackIdProvider).valueOrNull == track.id;
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: SizedBox(
        width: width,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          AspectRatio(
            aspectRatio: 1,
            child: LayoutBuilder(builder: (c, box) => Stack(fit: StackFit.expand, children: [
              Cover(path: track.artworkPath, size: box.maxWidth, radius: 16),
              if (current) Positioned(right: 8, bottom: 8, child: Container(padding: const EdgeInsets.all(6), decoration: const BoxDecoration(color: AppColors.brand, shape: BoxShape.circle), child: const Icon(Icons.graphic_eq_rounded, size: 16, color: Colors.white))),
            ])),
          ),
          const SizedBox(height: 8),
          Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w700, color: current ? AppColors.brand : null)),
          Text(artistLabel(context, track), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        ]),
      ),
    );
  }
}

/// بطاقة ألبوم/فنان/قائمة تشغيل.
class GroupCard extends StatelessWidget {
  const GroupCard({super.key, required this.title, required this.subtitle, this.artworkPath, required this.onTap, this.circle = false, this.width, this.icon = Icons.album_rounded});
  final String title, subtitle;
  final String? artworkPath;
  final VoidCallback onTap;
  final bool circle;
  final double? width;
  final IconData icon;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: width,
          child: Column(crossAxisAlignment: circle ? CrossAxisAlignment.center : CrossAxisAlignment.start, children: [
            AspectRatio(aspectRatio: 1, child: LayoutBuilder(builder: (c, b) => Cover(path: artworkPath, size: b.maxWidth, radius: 16, circle: circle, icon: icon))),
            const SizedBox(height: 8),
            Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: circle ? TextAlign.center : null, style: const TextStyle(fontWeight: FontWeight.w700)),
            Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          ]),
        ),
      );
}
