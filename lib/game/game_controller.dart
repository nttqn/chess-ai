import 'package:chess/chess.dart' as chesslib;
import 'package:flutter/foundation.dart';

import 'chess_ai.dart';

enum GameStatus { playing, checkmate, stalemate, draw }

/// Owns the chess rules engine plus everything the UI needs to render a
/// game against the AI: whose turn it is, the selected square, legal
/// destinations for that square, and the current game status.
class GameController extends ChangeNotifier {
  chesslib.Chess _game = chesslib.Chess();
  late chesslib.Color humanColor;
  late Difficulty difficulty;
  late ChessAi _ai;

  String? selectedSquare;
  List<String> legalTargets = [];
  bool isAiThinking = false;
  String? lastMoveFrom;
  String? lastMoveTo;
  final List<String> moveHistorySan = [];

  GameController({
    chesslib.Color humanColor = chesslib.Color.WHITE,
    Difficulty difficulty = Difficulty.medium,
  }) {
    this.humanColor = humanColor;
    this.difficulty = difficulty;
    _ai = ChessAi(difficulty);
    if (humanColor == chesslib.Color.BLACK) {
      _scheduleAiMove();
    }
  }

  chesslib.Chess get game => _game;
  chesslib.Color get turn => _game.turn;
  bool get isHumanTurn => turn == humanColor && !isAiThinking;

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
  }) {
    _game = chesslib.Chess();
    this.humanColor = humanColor;
    this.difficulty = difficulty;
    _ai = ChessAi(difficulty);
    selectedSquare = null;
    legalTargets = [];
    lastMoveFrom = null;
    lastMoveTo = null;
    isAiThinking = false;
    moveHistorySan.clear();
    notifyListeners();
    if (humanColor == chesslib.Color.BLACK) {
      _scheduleAiMove();
    }
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

    if (selectedSquare == null) {
      if (piece != null && piece.color == humanColor) {
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
      if (piece != null && piece.color == humanColor) {
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
    notifyListeners();

    if (!isGameOver) {
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
      final history = _game.getHistory({'verbose': true}) as List;
      if (history.isNotEmpty) {
        moveHistorySan.add(history.last['san'] as String);
      }
    }
  }

  void _scheduleAiMove() {
    isAiThinking = true;
    notifyListeners();
    Future.microtask(() async {
      final result = await _ai.chooseMove(_game);
      if (result != null) {
        _applyMove(result.from, result.to, promotion: result.promotion);
      }
      isAiThinking = false;
      notifyListeners();
    });
  }

  /// Undo the player's last move together with the AI reply that followed
  /// it, so the player always lands back on their own turn.
  void undoLastPlayerMove() {
    if (isAiThinking) return;
    if (_game.turn == humanColor) {
      // AI already replied; undo both half-moves.
      if (_game.history.isNotEmpty) _game.undo();
    }
    if (_game.history.isNotEmpty) _game.undo();
    if (moveHistorySan.isNotEmpty) moveHistorySan.removeLast();
    if (moveHistorySan.isNotEmpty) moveHistorySan.removeLast();
    selectedSquare = null;
    legalTargets = [];
    lastMoveFrom = null;
    lastMoveTo = null;
    notifyListeners();
  }
}
