import 'dart:math';

import 'package:chess/chess.dart' as chesslib;
import 'package:flutter/foundation.dart';

/// Difficulty levels exposed to the player. Higher levels search deeper
/// and never play a deliberately random move.
enum Difficulty { easy, medium, hard, expert }

extension DifficultyLabel on Difficulty {
  String get label {
    switch (this) {
      case Difficulty.easy:
        return 'Dễ';
      case Difficulty.medium:
        return 'Trung bình';
      case Difficulty.hard:
        return 'Khó';
      case Difficulty.expert:
        return 'Rất khó';
    }
  }

  int get searchDepth {
    switch (this) {
      case Difficulty.easy:
        return 1;
      case Difficulty.medium:
        return 2;
      case Difficulty.hard:
        return 3;
      case Difficulty.expert:
        return 4;
    }
  }

  /// Chance [0-1] the AI ignores its own search and plays a random legal
  /// move instead, to keep easy modes beatable for beginners.
  double get randomMoveChance {
    switch (this) {
      case Difficulty.easy:
        return 0.35;
      case Difficulty.medium:
        return 0.15;
      case Difficulty.hard:
        return 0.0;
      case Difficulty.expert:
        return 0.0;
    }
  }
}

const int _mateScore = 1000000;

const Map<String, int> _pieceValues = {
  'p': 100,
  'n': 320,
  'b': 330,
  'r': 500,
  'q': 900,
  'k': 20000,
};

// Simple piece-square tables (from White's perspective, rank 8 -> rank 1)
// encourage central control and reasonable king safety without a large
// engine. Values are added on top of material for a lightweight positional
// nudge.
const List<int> _pawnTable = [
  0, 0, 0, 0, 0, 0, 0, 0,
  50, 50, 50, 50, 50, 50, 50, 50,
  10, 10, 20, 30, 30, 20, 10, 10,
  5, 5, 10, 25, 25, 10, 5, 5,
  0, 0, 0, 20, 20, 0, 0, 0,
  5, -5, -10, 0, 0, -10, -5, 5,
  5, 10, 10, -20, -20, 10, 10, 5,
  0, 0, 0, 0, 0, 0, 0, 0,
];

const List<int> _knightTable = [
  -50, -40, -30, -30, -30, -30, -40, -50,
  -40, -20, 0, 0, 0, 0, -20, -40,
  -30, 0, 10, 15, 15, 10, 0, -30,
  -30, 5, 15, 20, 20, 15, 5, -30,
  -30, 0, 15, 20, 20, 15, 0, -30,
  -30, 5, 10, 15, 15, 10, 5, -30,
  -40, -20, 0, 5, 5, 0, -20, -40,
  -50, -40, -30, -30, -30, -30, -40, -50,
];

int _squareTableValue(List<int> table, int file, int rank, bool isWhite) {
  // table is defined rank8 -> rank1 (row 0 = rank 8). file 0=a..7=h.
  final row = isWhite ? 7 - rank : rank;
  return table[row * 8 + file];
}

int _evaluate(chesslib.Chess game) {
  if (game.in_checkmate) {
    // The side to move is checkmated, so the other side wins.
    return game.turn == chesslib.Color.WHITE ? -_mateScore : _mateScore;
  }
  if (game.in_draw) return 0;

  var score = 0;
  for (var i = 0; i < 128; i++) {
    if ((i & 0x88) != 0) continue;
    final piece = game.board[i];
    if (piece == null) continue;
    final value = _pieceValues[piece.type.name] ?? 0;
    final file = i & 0x7;
    final rank = i >> 4;
    final isWhite = piece.color == chesslib.Color.WHITE;
    var bonus = 0;
    if (piece.type.name == 'p') {
      bonus = _squareTableValue(_pawnTable, file, rank, isWhite);
    } else if (piece.type.name == 'n') {
      bonus = _squareTableValue(_knightTable, file, rank, isWhite);
    }
    final total = value + bonus;
    score += isWhite ? total : -total;
  }
  return score;
}

int _minimax(
  chesslib.Chess game,
  int depth,
  int alpha,
  int beta,
  bool maximizing,
) {
  if (game.game_over || depth == 0) {
    return _evaluate(game);
  }

  final moves = game.generate_moves({'legal': true});
  if (maximizing) {
    var best = -_mateScore - 1;
    for (final move in moves) {
      game.make_move(move);
      final score = _minimax(game, depth - 1, alpha, beta, false);
      game.undo_move();
      if (score > best) best = score;
      if (best > alpha) alpha = best;
      if (beta <= alpha) break;
    }
    return best;
  } else {
    var best = _mateScore + 1;
    for (final move in moves) {
      game.make_move(move);
      final score = _minimax(game, depth - 1, alpha, beta, true);
      game.undo_move();
      if (score < best) best = score;
      if (best < beta) beta = best;
      if (beta <= alpha) break;
    }
    return best;
  }
}

class AiMoveResult {
  final String from;
  final String to;
  final String? promotion;

  const AiMoveResult({required this.from, required this.to, this.promotion});
}

/// Entry point safe to run inside a background isolate via [compute].
/// Takes/returns only plain Map/String/int/double/bool values, which are
/// guaranteed sendable across the isolate boundary.
Map<String, dynamic>? findBestMoveIsolate(Map<String, dynamic> request) {
  final fen = request['fen'] as String;
  final depth = request['depth'] as int;
  final randomMoveChance = request['randomMoveChance'] as double;
  final seed = request['seed'] as int;

  final game = chesslib.Chess.fromFEN(fen);
  final rng = Random(seed);
  final legalMoves = game.generate_moves({'legal': true});
  if (legalMoves.isEmpty) return null;

  if (randomMoveChance > 0 && rng.nextDouble() < randomMoveChance) {
    final move = legalMoves[rng.nextInt(legalMoves.length)];
    return {
      'from': move.fromAlgebraic,
      'to': move.toAlgebraic,
      'promotion': move.promotion?.name,
    };
  }

  final maximizing = game.turn == chesslib.Color.WHITE;
  chesslib.Move? best;
  var bestScore = maximizing ? -_mateScore - 1 : _mateScore + 1;
  var alpha = -_mateScore - 1;
  var beta = _mateScore + 1;

  legalMoves.shuffle(rng);
  for (final move in legalMoves) {
    game.make_move(move);
    final score = _minimax(game, depth - 1, alpha, beta, !maximizing);
    game.undo_move();

    final better = maximizing ? score > bestScore : score < bestScore;
    if (better) {
      bestScore = score;
      best = move;
    }
    if (maximizing) {
      if (bestScore > alpha) alpha = bestScore;
    } else {
      if (bestScore < beta) beta = bestScore;
    }
  }

  best ??= legalMoves.first;
  return {
    'from': best.fromAlgebraic,
    'to': best.toAlgebraic,
    'promotion': best.promotion?.name,
  };
}

class ChessAi {
  final Difficulty difficulty;
  final Random _rng = Random();

  ChessAi(this.difficulty);

  /// Runs the search on a background isolate so the UI thread never jams,
  /// even at the deepest difficulty level.
  Future<AiMoveResult?> chooseMove(chesslib.Chess game) async {
    final request = <String, dynamic>{
      'fen': game.fen,
      'depth': difficulty.searchDepth,
      'randomMoveChance': difficulty.randomMoveChance,
      'seed': _rng.nextInt(1 << 31),
    };
    final result = await compute(findBestMoveIsolate, request);
    if (result == null) return null;
    return AiMoveResult(
      from: result['from'] as String,
      to: result['to'] as String,
      promotion: result['promotion'] as String?,
    );
  }
}
