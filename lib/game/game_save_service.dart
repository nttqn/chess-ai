import 'dart:convert';

import 'package:chess/chess.dart' as chesslib;
import 'package:shared_preferences/shared_preferences.dart';

import 'chess_ai.dart';

const String _saveKey = 'in_progress_game';

/// A snapshot of one in-progress game, enough to reconstruct a
/// [GameController] via `GameController.resume(...)`.
class SavedGame {
  final String fen;
  final chesslib.Color humanColor;
  final Difficulty difficulty;
  final bool vsHuman;
  final List<String> moveHistorySan;
  final int elapsedSeconds;

  const SavedGame({
    required this.fen,
    required this.humanColor,
    required this.difficulty,
    required this.vsHuman,
    required this.moveHistorySan,
    required this.elapsedSeconds,
  });

  Map<String, dynamic> toJson() => {
        'fen': fen,
        'humanColor': humanColor == chesslib.Color.WHITE ? 'w' : 'b',
        'difficulty': difficulty.name,
        'vsHuman': vsHuman,
        'moveHistorySan': moveHistorySan,
        'elapsedSeconds': elapsedSeconds,
      };

  factory SavedGame.fromJson(Map<String, dynamic> json) => SavedGame(
        fen: json['fen'] as String,
        humanColor: json['humanColor'] == 'w'
            ? chesslib.Color.WHITE
            : chesslib.Color.BLACK,
        difficulty: Difficulty.values.byName(json['difficulty'] as String),
        vsHuman: json['vsHuman'] as bool? ?? false,
        moveHistorySan: (json['moveHistorySan'] as List).cast<String>(),
        elapsedSeconds: json['elapsedSeconds'] as int,
      );
}

/// Persists the single in-progress game so closing the app mid-match
/// doesn't lose it. Overwritten after every move, cleared as soon as the
/// game ends or a new one starts.
class GameSaveService {
  GameSaveService._();
  static final GameSaveService instance = GameSaveService._();

  Future<void> save(SavedGame game) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_saveKey, jsonEncode(game.toJson()));
  }

  Future<SavedGame?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_saveKey);
    if (raw == null) return null;
    try {
      return SavedGame.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      // Corrupt/stale save from an older app version — drop it.
      return null;
    }
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_saveKey);
  }
}
