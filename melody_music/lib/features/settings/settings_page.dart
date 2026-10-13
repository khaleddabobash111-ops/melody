import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/l10n/strings.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/providers.dart';
import '../../shared/flows.dart';
import '../../shared/widgets.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final st = ref.watch(settingsProvider);
    final n = ref.read(settingsProvider.notifier);

    return SafeArea(
      bottom: false,
      child: ListView(padding: const EdgeInsets.only(bottom: 24), children: [
        Padding(padding: const EdgeInsets.fromLTRB(20, 16, 20, 0), child: Text(s.settings, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900))),
        SectionHeader(s.appearance),
        _Choice<ThemeMode>(title: s.theme, value: st.themeMode, options: {ThemeMode.dark: s.dark, ThemeMode.light: s.light, ThemeMode.system: s.system}, onChanged: (v) => n.update(st.copyWith(themeMode: v))),
        SwitchListTile(title: Text(s.reduceMotion), value: st.reduceMotion, onChanged: (v) => n.update(st.copyWith(reduceMotion: v))),
        SectionHeader(s.language),
        _Choice<String>(title: s.language, value: st.language, options: const {'ar': 'العربية', 'en': 'English'}, onChanged: (v) => n.update(st.copyWith(language: v))),
        SectionHeader(s.library),
        _Choice<bool>(title: s.libraryView, value: st.grid, options: {true: s.grid, false: s.list}, onChanged: (v) => n.update(st.copyWith(grid: v))),
        _Choice<String>(title: s.sortBy, value: st.sort, options: {'date': s.byDate, 'title': s.byTitle, 'artist': s.byArtist}, onChanged: (v) => n.update(st.copyWith(sort: v))),
        ListTile(leading: const Icon(Icons.library_add_rounded), title: Text(s.importMusic), onTap: () => importMusicFlow(context, ref)),
        ListTile(leading: const Icon(Icons.link_rounded), title: Text(s.importLink), onTap: () => importLinkFlow(context, ref)),
        SectionHeader(s.playback),
        SwitchListTile(title: Text(s.resumePlayback), value: st.resume, onChanged: (v) => n.update(st.copyWith(resume: v))),
        SectionHeader(s.data),
        ListTile(
          leading: const Icon(Icons.history_toggle_off_rounded),
          title: Text(s.clearHistory),
          onTap: () async {
            await ref.read(libraryProvider.notifier).clearHistory();
            if (context.mounted) toast(context, s.historyCleared);
          },
        ),
        SectionHeader(s.about),
        ListTile(title: const Text('Melody Music'), subtitle: const Text('1.0.0')),
        ListTile(leading: const Icon(Icons.lock_outline_rounded), title: Text(s.privacy, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary))),
        ListTile(leading: const Icon(Icons.folder_copy_outlined), title: Text(s.storagePolicy, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary))),
        ListTile(
          leading: const Icon(Icons.description_outlined),
          title: Text(s.licenses),
          onTap: () => showLicensePage(context: context, applicationName: 'Melody Music', applicationVersion: '1.0.0'),
        ),
      ]),
    );
  }
}

class _Choice<T> extends StatelessWidget {
  const _Choice({required this.title, required this.value, required this.options, required this.onChanged});
  final String title;
  final T value;
  final Map<T, String> options;
  final ValueChanged<T> onChanged;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<T>(
              showSelectedIcon: false,
              segments: [for (final e in options.entries) ButtonSegment(value: e.key, label: Text(e.value))],
              selected: {value},
              onSelectionChanged: (v) => onChanged(v.first),
            ),
          ),
        ]),
      );
}
