import 'dart:async';

import 'package:chess/chess.dart' as chesslib;
import 'package:flutter/foundation.dart';

import 'chess_ai.dart';
import 'feedback_service.dart';
import 'game_save_service.dart';
import 'score_service.dart';

enum GameStatus { playing, checkmate, stalemate, draw }

/// Owns the chess rules engine plus everything the UI needs to render a
/// game against the AI: whose turn it is, the selected square, legal
/// destinations for that square, and the current game status.
class GameController extends ChangeNotifier {
  chesslib.Chess _game = chesslib.Chess();
  late chesslib.Color humanColor;
  late Difficulty difficulty;
  late ChessAi _ai;
  bool vsHuman = false;

  String? selectedSquare;
  List<String> legalTargets = [];
  bool isAiThinking = false;
  String? lastMoveFrom;
  String? lastMoveTo;
  String? hintFrom;
  String? hintTo;
  bool isHintLoading = false;
  final List<String> moveHistorySan = [];

  DateTime _startTime = DateTime.now();
  bool _scoreHandled = false;

  /// Points earned for the game that just ended, or null if the player
  /// hasn't won a game yet this session. Set synchronously (from a pure
  /// function of difficulty + elapsed time) so the UI can show it
  /// immediately; [bestScoreAfterThisGame] follows shortly after once the
  /// local best-score lookup resolves.
  int? lastScore;
  int? bestScoreAfterThisGame;

  GameController({
    chesslib.Color humanColor = chesslib.Color.WHITE,
    Difficulty difficulty = Difficulty.medium,
    bool vsHuman = false,
  }) {
    this.humanColor = humanColor;
    this.difficulty = difficulty;
    this.vsHuman = vsHuman;
    _ai = ChessAi(difficulty);
    _maybeStartAiTurn();
  }

  /// Rebuilds a controller from a [SavedGame] snapshot so a match
  /// interrupted mid-play (app closed, phone call, etc.) can continue
  /// exactly where it left off, including the AI's turn if it was next.
  GameController.resume(SavedGame saved) {
    _game = chesslib.Chess.fromFEN(saved.fen);
    humanColor = saved.humanColor;
    difficulty = saved.difficulty;
    vsHuman = saved.vsHuman;
    _ai = ChessAi(difficulty);
    moveHistorySan.addAll(saved.moveHistorySan);
    _startTime =
        DateTime.now().subtract(Duration(seconds: saved.elapsedSeconds));
    _maybeStartAiTurn();
  }

  void _maybeStartAiTurn() {
    if (!vsHuman && _game.turn != humanColor) {
      _scheduleAiMove();
    }
  }

  chesslib.Chess get game => _game;
  chesslib.Color get turn => _game.turn;
  bool get isHumanTurn =>
      !isAiThinking && (vsHuman || turn == humanColor);

  GameStatus get status {
    if (_game.in_checkmate) return GameStatus.checkmate;
    if (_game.in_stalemate) return GameStatus.stalemate;
    if (_game.in_draw) return GameStatus.draw;
    return GameStatus.playing;
  }

  /// The color that just won by checkmate, or null if the game isn't over
  /// by checkmate.
  chesslib.Color? get winner {
    if (!_game.in_checkmate) return null;
    return _game.turn == chesslib.Color.WHITE
        ? chesslib.Color.BLACK
        : chesslib.Color.WHITE;
  }

  bool get isGameOver => status != GameStatus.playing;

  void newGame({
    required chesslib.Color humanColor,
    required Difficulty difficulty,
    bool vsHuman = false,
  }) {
    _game = chesslib.Chess();
    this.humanColor = humanColor;
    this.difficulty = difficulty;
    this.vsHuman = vsHuman;
    _ai = ChessAi(difficulty);
    selectedSquare = null;
    legalTargets = [];
    lastMoveFrom = null;
    lastMoveTo = null;
    hintFrom = null;
    hintTo = null;
    isAiThinking = false;
    moveHistorySan.clear();
    _startTime = DateTime.now();
    _scoreHandled = false;
    lastScore = null;
    bestScoreAfterThisGame = null;
    unawaited(GameSaveService.instance.clear());
    notifyListeners();
    _maybeStartAiTurn();
  }

  /// Call when the player taps a square. [choosePromotion] is invoked only
  /// when the tapped move is a pawn reaching the last rank; it should
  /// return one of 'q'/'r'/'b'/'n', or null to cancel the move.
  Future<void> onSquareTap(
    String square, {
    required Future<String?> Function() choosePromotion,
  }) async {
    if (!isHumanTurn || isGameOver) return;

    final piece = _game.get(square);
    // Whichever color's turn it is may move it — in 2-player mode that
    // alternates between both colors, not just [humanColor].
    final mover = turn;

    if (selectedSquare == null) {
      if (piece != null && piece.color == mover) {
        selectedSquare = square;
        legalTargets = _legalTargetsFrom(square);
        notifyListeners();
      }
      return;
    }

    if (square == selectedSquare) {
      selectedSquare = null;
      legalTargets = [];
      notifyListeners();
      return;
    }

    if (!legalTargets.contains(square)) {
      if (piece != null && piece.color == mover) {
        selectedSquare = square;
        legalTargets = _legalTargetsFrom(square);
        notifyListeners();
      } else {
        selectedSquare = null;
        legalTargets = [];
        notifyListeners();
      }
      return;
    }

    final from = selectedSquare!;
    final needsPromotion = _isPromotionMove(from, square);
    String? promotion;
    if (needsPromotion) {
      promotion = await choosePromotion();
      if (promotion == null) return; // cancelled
    }

    selectedSquare = null;
    legalTargets = [];
    _applyMove(from, square, promotion: promotion);
    _maybeAwardScore();
    notifyListeners();

    if (!vsHuman && !isGameOver) {
      _scheduleAiMove();
    }
  }

  List<String> _legalTargetsFrom(String square) {
    final verbose =
        _game.moves({'square': square, 'verbose': true}) as List;
    return verbose.map<String>((m) => m['to'] as String).toList();
  }

  bool _isPromotionMove(String from, String to) {
    final verbose = _game.moves({'square': from, 'verbose': true}) as List;
    for (final m in verbose) {
      if (m['to'] == to && (m['flags'] as String).contains('p')) {
        return true;
      }
    }
    return false;
  }

  void _applyMove(String from, String to, {String? promotion}) {
    final moveMap = <String, String>{'from': from, 'to': to};
    if (promotion != null) moveMap['promotion'] = promotion;
    final result = _game.move(moveMap);
    if (result) {
      lastMoveFrom = from;
      lastMoveTo = to;
      hintFrom = null;
      hintTo = null;
      bool wasCapture = false;
      final history = _game.getHistory({'verbose': true}) as List;
      if (history.isNotEmpty) {
        final last = history.last as Map;
        moveHistorySan.add(last['san'] as String);
        wasCapture = last['captured'] != null;
      }
      _playMoveFeedback(wasCapture: wasCapture);
      unawaited(_saveProgress());
    }
  }

  void _playMoveFeedback({required bool wasCapture}) {
    if (isGameOver) {
      unawaited(FeedbackService.instance.gameOver());
    } else if (_game.in_check) {
      unawaited(FeedbackService.instance.check());
    } else if (wasCapture) {
      unawaited(FeedbackService.instance.capture());
    } else {
      unawaited(FeedbackService.instance.move());
    }
  }

  Future<void> _saveProgress() async {
    if (isGameOver) {
      await GameSaveService.instance.clear();
      return;
    }
    await GameSaveService.instance.save(
      SavedGame(
        fen: _game.fen,
        humanColor: humanColor,
        difficulty: difficulty,
        vsHuman: vsHuman,
        moveHistorySan: List.of(moveHistorySan),
        elapsedSeconds: DateTime.now().difference(_startTime).inSeconds,
      ),
    );
  }

  /// Runs a short background search for the human side's best move and
  /// surfaces it as a board highlight. Disabled in 2-player mode, where
  /// hinting one side against the other would be unfair.
  Future<void> requestHint() async {
    if (vsHuman || !isHumanTurn || isGameOver || isHintLoading) return;
    isHintLoading = true;
    notifyListeners();
    final request = <String, dynamic>{
      'fen': _game.fen,
      'depth': difficulty.searchDepth < 3 ? 3 : difficulty.searchDepth,
      'randomMoveChance': 0.0,
      'seed': DateTime.now().millisecondsSinceEpoch,
    };
    final result = await compute(findBestMoveIsolate, request);
    if (result != null) {
      hintFrom = result['from'] as String;
      hintTo = result['to'] as String;
    }
    isHintLoading = false;
    notifyListeners();
  }

  void _scheduleAiMove() {
    isAiThinking = true;
    notifyListeners();
    Future.microtask(() async {
      final result = await _ai.chooseMove(_game);
      if (result != null) {
        _applyMove(result.from, result.to, promotion: result.promotion);
        _maybeAwardScore();
      }
      isAiThinking = false;
      notifyListeners();
    });
  }

  /// Only the player winning by checkmate earns points — losses and draws
  /// don't. Runs once per game (guarded by [_scoreHandled]): the score
  /// itself is a pure function of difficulty + elapsed time so it's set
  /// immediately, while persisting the local best and submitting to the
  /// Play Games leaderboard happen in the background and notify again once
  /// they resolve.
  void _maybeAwardScore() {
    if (_scoreHandled || !isGameOver || vsHuman) return;
    _scoreHandled = true;

    if (winner == humanColor) {
      final elapsed = DateTime.now().difference(_startTime);
      lastScore = calculateScore(difficulty: difficulty, elapsed: elapsed);
      unawaited(_persistAndSubmitScore(lastScore!, elapsed));
    } else if (winner != null) {
      // The AI won — breaks the player's current win streak.
      unawaited(ScoreService.instance.resetWinStreak());
    }
  }

  Future<void> _persistAndSubmitScore(int score, Duration elapsed) async {
    bestScoreAfterThisGame =
        await ScoreService.instance.recordLocalBest(difficulty, score);
    await ScoreService.instance.addHistoryEntry(
      GameHistoryEntry(
        difficulty: difficulty,
        elapsed: elapsed,
        score: score,
        playedAt: DateTime.now(),
      ),
    );
    notifyListeners();
    await ScoreService.instance.submitScore(score);
    await ScoreService.instance.recordWinAndUnlockAchievements(difficulty);
  }

  /// Undo the player's last move together with the AI reply that followed
  /// it, so the player always lands back on their own turn.
  void undoLastPlayerMove() {
    if (isAiThinking) return;
    if (vsHuman) {
      // Single local board — just take back the last half-move.
      if (_game.history.isNotEmpty) _game.undo();
      if (moveHistorySan.isNotEmpty) moveHistorySan.removeLast();
    } else {
      if (_game.turn == humanColor) {
        // AI already replied; undo both half-moves.
        if (_game.history.isNotEmpty) _game.undo();
      }
      if (_game.history.isNotEmpty) _game.undo();
      if (moveHistorySan.isNotEmpty) moveHistorySan.removeLast();
      if (moveHistorySan.isNotEmpty) moveHistorySan.removeLast();
    }
    selectedSquare = null;
    legalTargets = [];
    lastMoveFrom = null;
    lastMoveTo = null;
    hintFrom = null;
    hintTo = null;
    unawaited(_saveProgress());
    notifyListeners();
  }
}
