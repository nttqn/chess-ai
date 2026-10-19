import 'dart:async';

import 'package:flutter/material.dart';

import 'services/ads_service.dart';
import 'services/music_service.dart';
import 'services/sound_service.dart';
import 'screens/home_screen.dart';

// None of SoundService/MusicService/SettingsService.load() are awaited
// here before runApp(). Calling a shared_preferences-backed plugin this
// early (before runApp()/the first frame) races its Pigeon-generated
// platform-channel registration and previously crashed this exact app on
// launch with "NoSuchMethodError: SharedPreferencesApiRegistrar.getAll"
// on some devices — see the comment on HomeScreen.initState(), which is
// where all of these are actually loaded from instead, matching every
// other shared_preferences call in this app (ScoreService,
// GameSaveService), which only ever run from widget lifecycle methods
// after the first frame.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AdsService.instance.initialize();
  unawaited(SoundService.instance.init());
  unawaited(MusicService.instance.init());
  runApp(const ChessApp());
}

class ChessApp extends StatelessWidget {
  const ChessApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chess with AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF6D4C41),
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      home: const HomeScreen(),
    );
  }
}
