import 'package:games_services/games_services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'chess_ai.dart';

/// Play Games Services App ID and leaderboard ID come from Play Console →
/// Play Games Services → Setup and management, injected at build time via
/// --dart-define (see .github/workflows/build-apk.yml). The defaults below
/// are placeholders so local builds still compile — every call below is
/// wrapped so a missing/placeholder ID just fails silently instead of
/// crashing, same pattern as the AdMob test-ID fallback.
class PlayGamesConfig {
  static const String leaderboardId = String.fromEnvironment(
    'PLAY_GAMES_LEADERBOARD_ID',
    defaultValue: 'REPLACE_ME_LEADERBOARD_ID',
  );
}

const Map<Difficulty, int> _baseScoreByDifficulty = {
  Difficulty.easy: 100,
  Difficulty.medium: 250,
  Difficulty.hard: 500,
  Difficulty.expert: 1000,
};

/// Higher difficulty is worth more; winning faster earns a bonus (up to
/// 1.5x at 0 minutes, down to a 0.5x floor past ~20 minutes) so grinding
/// out a slow win still counts for something.
int calculateScore({required Difficulty difficulty, required Duration elapsed}) {
  final base = _baseScoreByDifficulty[difficulty]!;
  final minutes = elapsed.inSeconds / 60.0;
  final speedMultiplier = (1.5 - minutes / 20).clamp(0.5, 1.5);
  return (base * speedMultiplier).round();
}

class ScoreService {
  ScoreService._();
  static final ScoreService instance = ScoreService._();

  /// Attempts a non-interactive sign-in (succeeds quietly if the player has
  /// already linked this app before). Safe to call on every app start.
  Future<void> trySilentSignIn() async {
    try {
      await GamesServices.signIn();
    } catch (_) {
      // No linked account yet, or Play Games unavailable (emulator without
      // Play Services, etc.) — the player can still sign in manually.
    }
  }

  Future<bool> isSignedIn() async {
    try {
      return await GamesServices.isSignedIn;
    } catch (_) {
      return false;
    }
  }

  Future<String?> playerName() async {
    try {
      return await GamesServices.getPlayerName();
    } catch (_) {
      return null;
    }
  }

  Future<void> showLeaderboard() async {
    try {
      await GamesServices.showLeaderboards(
        androidLeaderboardID: PlayGamesConfig.leaderboardId,
      );
    } catch (_) {
      // Not signed in, or the leaderboard ID hasn't been configured yet.
    }
  }

  Future<void> submitScore(int score) async {
    try {
      await GamesServices.submitScore(
        score: Score(
          androidLeaderboardID: PlayGamesConfig.leaderboardId,
          value: score,
        ),
      );
    } catch (_) {
      // Not signed in / offline / leaderboard not configured — the local
      // best score is the source of truth either way.
    }
  }

  Future<int> recordLocalBest(Difficulty difficulty, int score) async {
    final prefs = await SharedPreferences.getInstance();

    final key = 'best_score_${difficulty.name}';
    final current = prefs.getInt(key) ?? 0;
    if (score > current) await prefs.setInt(key, score);

    const overallKey = 'best_score_overall';
    final overallCurrent = prefs.getInt(overallKey) ?? 0;
    if (score > overallCurrent) await prefs.setInt(overallKey, score);

    return score > current ? score : current;
  }

  Future<int> bestScoreOverall() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('best_score_overall') ?? 0;
  }

  Future<int> bestScoreFor(Difficulty difficulty) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('best_score_${difficulty.name}') ?? 0;
  }
}
