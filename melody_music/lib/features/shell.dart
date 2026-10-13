import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/l10n/strings.dart';
import '../providers/nav.dart';
import '../providers/providers.dart';
import '../shared/flows.dart';
import 'home/home_page.dart';
import 'library/library_page.dart';
import 'player/ui/mini_player.dart';
import 'search/search_page.dart';
import 'settings/settings_page.dart';

/// الهيكل الرئيسي: IndexedStack يحفظ حالة كل تبويب، والمشغل المصغّر ثابت فوق شريط التنقل.
class Shell extends ConsumerStatefulWidget {
  const Shell({super.key});
  @override
  ConsumerState<Shell> createState() => _ShellState();
}

class _ShellState extends ConsumerState<Shell> {
  @override
  void initState() {
    super.initState();
    final handler = ref.read(audioHandlerProvider);
    handler.error.addListener(_onError);
    // تشغيل مراقب السجل والحفظ، ثم استعادة آخر جلسة
    final svc = ref.read(playbackServiceProvider)..start();
    ref.read(libraryProvider.future).then((_) => svc.restore());
  }

  @override
  void dispose() {
    ref.read(audioHandlerProvider).error.removeListener(_onError);
    super.dispose();
  }

  void _onError() {
    final e = ref.read(audioHandlerProvider).error.value;
    if (e == null || !mounted) return;
    final s = S.of(context);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(s.playbackError),
        action: SnackBarAction(label: s.skip, onPressed: () => ref.read(audioHandlerProvider).skipToNext()),
      ));
    ref.read(audioHandlerProvider).error.value = null;
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final index = ref.watch(tabProvider);
    return PopScope(
      canPop: index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) ref.read(tabProvider.notifier).set(0);
      },
      child: Scaffold(
        body: IndexedStack(index: index, children: const [HomePage(), SearchPage(), LibraryPage(), SettingsPage()]),
        bottomNavigationBar: Column(mainAxisSize: MainAxisSize.min, children: [
          MiniPlayer(actions: buildPlayerActions(context, ref)),
          NavigationBar(
            selectedIndex: index,
            onDestinationSelected: ref.read(tabProvider.notifier).set,
            destinations: [
              NavigationDestination(icon: const Icon(Icons.home_outlined), selectedIcon: const Icon(Icons.home_rounded), label: s.home),
              NavigationDestination(icon: const Icon(Icons.search_rounded), selectedIcon: const Icon(Icons.search_rounded), label: s.search),
              NavigationDestination(icon: const Icon(Icons.library_music_outlined), selectedIcon: const Icon(Icons.library_music_rounded), label: s.library),
              NavigationDestination(icon: const Icon(Icons.settings_outlined), selectedIcon: const Icon(Icons.settings_rounded), label: s.settings),
            ],
          ),
        ]),
      ),
    );
  }
}
