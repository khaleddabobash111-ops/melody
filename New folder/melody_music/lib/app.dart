import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'features/player/ui/player_scope.dart';
import 'features/shell.dart';
import 'providers/providers.dart';

class MelodyApp extends ConsumerWidget {
  const MelodyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final st = ref.watch(settingsProvider);
    final backend = ref.watch(backendProvider);
    return MaterialApp(
      title: 'Melody Music',
      debugShowCheckedModeBanner: false,
      locale: Locale(st.language),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: st.themeMode,
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(
            disableAnimations: mq.disableAnimations || st.reduceMotion,
            textScaler: mq.textScaler.clamp(minScaleFactor: .85, maxScaleFactor: 1.3), // دعم تكبير النص بحدود
          ),
          // PlayerScope فوق الـ Navigator ليراه المشغل الكامل والمصغّر
          child: PlayerScope(backend: backend, child: child!),
        );
      },
      home: const Shell(),
    );
  }
}
