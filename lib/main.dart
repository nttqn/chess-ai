import 'package:flutter/material.dart';

import 'services/ads_service.dart';
import 'screens/home_screen.dart';

// SettingsService.load() is deliberately NOT called here. Calling a
// shared_preferences-backed plugin this early (before runApp()/the first
// frame) races its Pigeon-generated platform-channel registration and
// crashes on launch with "NoSuchMethodError:
// SharedPreferencesApiRegistrar.getAll" on some devices. It's loaded from
// HomeScreen.initState() instead, matching every other shared_preferences
// call in this app (ScoreService, GameSaveService), which only ever run
// from widget lifecycle methods after the first frame.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AdsService.instance.initialize();
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
