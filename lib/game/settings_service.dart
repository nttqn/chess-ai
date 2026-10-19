import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum BoardTheme { classic, forest, ocean }

extension BoardThemeStyle on BoardTheme {
  String get label {
    switch (this) {
      case BoardTheme.classic:
        return 'Cổ điển';
      case BoardTheme.forest:
        return 'Rừng xanh';
      case BoardTheme.ocean:
        return 'Đại dương';
    }
  }

  Color get light {
    switch (this) {
      case BoardTheme.classic:
        return const Color(0xFFF0D9B5);
      case BoardTheme.forest:
        return const Color(0xFFEEEED2);
      case BoardTheme.ocean:
        return const Color(0xFFDCEEF5);
    }
  }

  Color get dark {
    switch (this) {
      case BoardTheme.classic:
        return const Color(0xFFB58863);
      case BoardTheme.forest:
        return const Color(0xFF769656);
      case BoardTheme.ocean:
        return const Color(0xFF5E92A8);
    }
  }
}

/// Simple in-memory setting backed by SharedPreferences, for the board
/// color theme only — sound/music toggles live in SoundService/
/// MusicService instead, each with its own independent on/off state.
/// [load] is called from HomeScreen.initState() (never from main() before
/// runApp() — see the comment there) so [boardTheme] is synchronously
/// readable everywhere else (the board paints every frame and can't await
/// a prefs lookup per square).
class SettingsService {
  SettingsService._();
  static final SettingsService instance = SettingsService._();

  BoardTheme boardTheme = BoardTheme.classic;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final themeName = prefs.getString('settings_board_theme');
    boardTheme = BoardTheme.values.firstWhere(
      (t) => t.name == themeName,
      orElse: () => BoardTheme.classic,
    );
  }

  Future<void> setBoardTheme(BoardTheme theme) async {
    boardTheme = theme;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('settings_board_theme', theme.name);
  }
}
