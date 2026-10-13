import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app.dart';
import 'data/database/app_database.dart';
import 'providers/providers.dart';
import 'services/audio_handler.dart';

Future<void> main() async {
  await runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    FlutterError.onError = (d) => debugPrint('FlutterError: ${d.exceptionAsString()}'); // لا Stack Trace للمستخدم
    final prefs = await SharedPreferences.getInstance();
    final db = await AppDatabase.open();
    final handler = await AudioService.init(
      builder: MelodyAudioHandler.new,
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.melodymusic.app.playback',
        androidNotificationChannelName: 'Melody Music',
        androidNotificationOngoing: true,
      ),
    );
    runApp(ProviderScope(
      overrides: [
        prefsProvider.overrideWithValue(prefs),
        dbProvider.overrideWithValue(db),
        audioHandlerProvider.overrideWithValue(handler),
      ],
      child: const MelodyApp(),
    ));
  }, (e, s) => debugPrint('Uncaught: $e'));
}
