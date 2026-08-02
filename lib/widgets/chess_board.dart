import 'package:chess/chess.dart' as chesslib;
import 'package:flutter/material.dart';

import '../game/game_controller.dart';

const Color _lightSquare = Color(0xFFF0D9B5);
const Color _darkSquare = Color(0xFFB58863);
const Color _selectedHighlight = Color(0xAAF6F669);
const Color _lastMoveHighlight = Color(0x66F6F669);
const Color _checkHighlight = Color(0xAAEF5350);

const Map<String, String> _whiteGlyphs = {
  'k': '♔',
  'q': '♕',
  'r': '♖',
  'b': '♗',
  'n': '♘',
  'p': '♙',
};

const Map<String, String> _blackGlyphs = {
  'k': '♚',
  'q': '♛',
  'r': '♜',
  'b': '♝',
  'n': '♞',
  'p': '♟',
};

String pieceGlyph(chesslib.Piece piece) {
  final map = piece.color == chesslib.Color.WHITE ? _whiteGlyphs : _blackGlyphs;
  return map[piece.type.name] ?? '?';
}

/// Renders the 8x8 board and forwards taps to [GameController]. Handles the
/// pawn-promotion dialog itself since it needs a [BuildContext].
class ChessBoard extends StatelessWidget {
  final GameController controller;

  const ChessBoard({super.key, required this.controller});

  bool get _flipped => controller.humanColor == chesslib.Color.BLACK;

  String _squareAt(int row, int col) {
    final file = _flipped ? 7 - col : col;
    final rank = _flipped ? row + 1 : 8 - row;
    return String.fromCharCode('a'.codeUnitAt(0) + file) + rank.toString();
  }

  String? _checkedKingSquare() {
    final game = controller.game;
    if (!game.in_check) return null;
    for (var i = 0; i < 128; i++) {
      if ((i & 0x88) != 0) continue;
      final piece = game.board[i];
      if (piece != null && piece.type.name == 'k' && piece.color == game.turn) {
        return chesslib.Chess.algebraic(i);
      }
    }
    return null;
  }

  Future<String?> _askPromotionPiece(BuildContext context) {
    final isWhite = controller.humanColor == chesslib.Color.WHITE;
    final glyphs = isWhite ? _whiteGlyphs : _blackGlyphs;
    const choices = ['q', 'r', 'b', 'n'];
    const labels = {'q': 'Hậu', 'r': 'Xe', 'b': 'Tượng', 'n': 'Mã'};
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Phong cấp cho Tốt'),
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: choices
              .map(
                (c) => Expanded(
                  child: InkWell(
                    onTap: () => Navigator.of(context).pop(c),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(glyphs[c]!, style: const TextStyle(fontSize: 36)),
                        Text(labels[c]!),
                      ],
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final checkedKingSquare = _checkedKingSquare();

    return AspectRatio(
      aspectRatio: 1,
      child: Column(
        children: List.generate(8, (row) {
          return Expanded(
            child: Row(
              children: List.generate(8, (col) {
                final square = _squareAt(row, col);
                final piece = controller.game.get(square);
                final isDark = (row + col) % 2 == 1;
                final isSelected = controller.selectedSquare == square;
                final isLegalTarget = controller.legalTargets.contains(square);
                final isLastMove = square == controller.lastMoveFrom ||
                    square == controller.lastMoveTo;
                final isCheckedKing = square == checkedKingSquare;

                Color background = isDark ? _darkSquare : _lightSquare;

                return Expanded(
                  child: GestureDetector(
                    onTap: () => controller.onSquareTap(
                      square,
                      choosePromotion: () => _askPromotionPiece(context),
                    ),
                    child: Container(
                      color: background,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          if (isLastMove)
                            Container(color: _lastMoveHighlight),
                          if (isCheckedKing)
                            Container(color: _checkHighlight),
                          if (isSelected)
                            Container(color: _selectedHighlight),
                          if (piece != null)
                            Text(
                              pieceGlyph(piece),
                              style: const TextStyle(fontSize: 30),
                            ),
                          if (isLegalTarget && piece == null)
                            Container(
                              width: 14,
                              height: 14,
                              decoration: BoxDecoration(
                                color: Colors.black26,
                                shape: BoxShape.circle,
                              ),
                            ),
                          if (isLegalTarget && piece != null)
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.black45,
                                  width: 3,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          );
        }),
      ),
    );
  }
}
