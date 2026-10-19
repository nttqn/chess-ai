import 'dart:async';
import 'dart:convert';

import 'package:games_services/games_services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'chess_ai.dart';

const String _historyKey = 'game_history';
const int _maxHistoryEntries = 50;

/// One completed win: which difficulty, how long it took, and the score
/// earned. Only wins are recorded — see [GameController.\_maybeAwardScore].
class GameHistoryEntry {
  final Difficulty difficulty;
  final Duration elapsed;
  final int score;
  final DateTime playedAt;

  const GameHistoryEntry({
    required this.difficulty,
    required this.elapsed,
    required this.score,
    required this.playedAt,
  });

  Map<String, dynamic> toJson() => {
        'difficulty': difficulty.name,
        'elapsedSeconds': elapsed.inSeconds,
        'score': score,
        'playedAt': playedAt.toIso8601String(),
      };

  factory GameHistoryEntry.fromJson(Map<String, dynamic> json) {
    return GameHistoryEntry(
      difficulty: Difficulty.values.byName(json['difficulty'] as String),
      elapsed: Duration(seconds: json['elapsedSeconds'] as int),
      score: json['score'] as int,
      playedAt: DateTime.parse(json['playedAt'] as String),
    );
  }
}

/// Play Games Services App ID, leaderboard ID, and achievement IDs come
/// from Play Console → Play Games Services → Setup and management,
/// injected at build time via --dart-define (see
/// .github/workflows/build-apk.yml). The defaults below are placeholders
/// so local builds still compile — every call below is wrapped so a
/// missing/placeholder ID just fails silently instead of crashing, same
/// pattern as the AdMob test-ID fallback.
///
/// Achievement IDs are a single comma-separated secret
/// (PLAY_GAMES_ACHIEVEMENT_IDS) in a fixed order: first win, 10 wins,
/// 5-win streak, an Expert-difficulty win. Leave the secret unset (or an
/// entry blank, e.g. "id1,,id3,id4") to skip that achievement.
class PlayGamesConfig {
  static const String leaderboardId = String.fromEnvironment(
    'PLAY_GAMES_LEADERBOARD_ID',
    defaultValue: 'REPLACE_ME_LEADERBOARD_ID',
  );

  static const String _achievementIdsRaw = String.fromEnvironment(
    'PLAY_GAMES_ACHIEVEMENT_IDS',
    defaultValue: '',
  );
  static final List<String> _achievementIds = _achievementIdsRaw.split(',');

  static String _achievementId(int index) =>
      index < _achievementIds.length ? _achievementIds[index].trim() : '';

  static String get firstWinAchievementId => _achievementId(0);
  static String get tenWinsAchievementId => _achievementId(1);
  static String get winStreak5AchievementId => _achievementId(2);
  static String get expertWinAchievementId => _achievementId(3);
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

  /// Signs in (no-op if already signed in) before showing the leaderboard
  /// or achievements screen — there's no separate "sign in" button in the
  /// UI, so this is the fallback for whenever the silent sign-in attempt
  /// on app start didn't succeed (no network yet, first launch, etc.).
  Future<void> showLeaderboard() async {
    try {
      await GamesServices.signIn();
      await GamesServices.showLeaderboards(
        androidLeaderboardID: PlayGamesConfig.leaderboardId,
      );
    } catch (_) {
      // Sign-in failed/declined, or the leaderboard ID hasn't been
      // configured yet.
    }
  }

  Future<void> showAchievements() async {
    try {
      await GamesServices.signIn();
      await GamesServices.showAchievements();
    } catch (_) {
      // Sign-in failed/declined, or no achievements configured yet.
    }
  }

  Future<void> _unlockAchievement(String id) async {
    if (id.isEmpty) return;
    try {
      await GamesServices.unlock(achievement: Achievement(androidID: id));
    } catch (_) {
      // Not signed in / achievement ID not configured — safe to ignore.
    }
  }

  Future<void> resetWinStreak() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('stat_current_streak', 0);
  }

  /// Bumps the local win/streak counters after a win against the AI and
  /// unlocks whichever Play Games achievements that just crossed their
  /// threshold. Safe to call even with no achievement IDs configured.
  Future<void> recordWinAndUnlockAchievements(Difficulty difficulty) async {
    final prefs = await SharedPreferences.getInstance();
    final totalWins = (prefs.getInt('stat_total_wins') ?? 0) + 1;
    final streak = (prefs.getInt('stat_current_streak') ?? 0) + 1;
    await prefs.setInt('stat_total_wins', totalWins);
    await prefs.setInt('stat_current_streak', streak);

    if (totalWins == 1) {
      unawaited(_unlockAchievement(PlayGamesConfig.firstWinAchievementId));
    }
    if (totalWins == 10) {
      unawaited(_unlockAchievement(PlayGamesConfig.tenWinsAchievementId));
    }
    if (streak == 5) {
      unawaited(_unlockAchievement(PlayGamesConfig.winStreak5AchievementId));
    }
    if (difficulty == Difficulty.expert) {
      unawaited(_unlockAchievement(PlayGamesConfig.expertWinAchievementId));
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

  Future<void> addHistoryEntry(GameHistoryEntry entry) async {
    final prefs = await SharedPreferences.getInstance();
    final entries = await _loadHistoryRaw(prefs);
    entries.add(entry);
    if (entries.length > _maxHistoryEntries) {
      entries.removeRange(0, entries.length - _maxHistoryEntries);
    }
    await prefs.setString(
      _historyKey,
      jsonEncode(entries.map((e) => e.toJson()).toList()),
    );
  }

  /// Most recently played first.
  Future<List<GameHistoryEntry>> loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final entries = await _loadHistoryRaw(prefs);
    return entries.reversed.toList();
  }

  Future<List<GameHistoryEntry>> _loadHistoryRaw(
    SharedPreferences prefs,
  ) async {
    final raw = prefs.getString(_historyKey);
    if (raw == null) return [];
    final decoded = jsonDecode(raw) as List;
    return decoded
        .map((e) => GameHistoryEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
