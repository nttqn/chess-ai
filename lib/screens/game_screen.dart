import 'package:chess/chess.dart' as chesslib;
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../game/chess_ai.dart';
import '../game/game_controller.dart';
import '../game/score_service.dart';
import '../services/ads_service.dart';
import '../widgets/chess_board.dart';

class GameScreen extends StatefulWidget {
  final Difficulty difficulty;
  final chesslib.Color humanColor;

  const GameScreen({
    super.key,
    required this.difficulty,
    required this.humanColor,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final GameController _controller;
  BannerAd? _bannerAd;
  bool _bannerLoaded = false;
  bool _gameOverHandled = false;
  int? _bestScoreForDifficulty;

  @override
  void initState() {
    super.initState();
    _controller = GameController(
      humanColor: widget.humanColor,
      difficulty: widget.difficulty,
    );
    _controller.addListener(_onControllerChanged);
    _bannerAd = AdsService.instance.createBannerAd(
      onLoaded: () => setState(() => _bannerLoaded = true),
    );
    ScoreService.instance.bestScoreFor(widget.difficulty).then((best) {
      if (mounted) setState(() => _bestScoreForDifficulty = best);
    });
  }

  /// The score chip shows the best score for this difficulty once known,
  /// upgrading to the controller's live best-after-this-game figure as
  /// soon as a win updates it.
  int get _displayScore =>
      _controller.bestScoreAfterThisGame ?? _bestScoreForDifficulty ?? 0;

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    _bannerAd?.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (_controller.isGameOver && !_gameOverHandled) {
      _gameOverHandled = true;
      AdsService.instance.maybeShowInterstitialAfterGame();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showGameOverDialog();
      });
    }
    setState(() {});
  }

  String _resultMessage() {
    switch (_controller.status) {
      case GameStatus.checkmate:
        final humanWon = _controller.winner == widget.humanColor;
        return humanWon
            ? 'Chiếu hết! Bạn đã thắng! 🎉'
            : 'Chiếu hết! Máy đã thắng ván này.';
      case GameStatus.stalemate:
        return 'Hòa cờ - hết nước đi hợp lệ (Stalemate).';
      case GameStatus.draw:
        return 'Ván cờ kết thúc hòa.';
      case GameStatus.playing:
        return '';
    }
  }

  void _showGameOverDialog() {
    showDialog(
      context: context,
      builder: (context) => AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final score = _controller.lastScore;
          final best = _controller.bestScoreAfterThisGame;
          return AlertDialog(
            title: const Text('Kết thúc ván cờ'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_resultMessage()),
                if (score != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Điểm ván này: $score',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  if (best != null)
                    Text(
                      best == score
                          ? 'Kỷ lục mới cho cấp độ ${widget.difficulty.label}! 🏆'
                          : 'Kỷ lục cấp độ ${widget.difficulty.label}: $best',
                      style: TextStyle(color: Colors.black54),
                    ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pop();
                },
                child: const Text('Về màn hình chính'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  setState(() {
                    _gameOverHandled = false;
                    _controller.newGame(
                      humanColor: widget.humanColor,
                      difficulty: widget.difficulty,
                    );
                  });
                },
                child: const Text('Chơi lại'),
              ),
            ],
          );
        },
      ),
    );
  }

  String get _turnLabel {
    if (_controller.isAiThinking) return 'Máy đang suy nghĩ...';
    if (_controller.isHumanTurn) return 'Lượt của bạn';
    return 'Lượt của đối thủ';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chess with AI'),
        actions: [
          IconButton(
            tooltip: 'Bảng xếp hạng',
            icon: const Icon(Icons.leaderboard),
            onPressed: () => ScoreService.instance.showLeaderboard(),
          ),
          IconButton(
            tooltip: 'Đi lại nước trước',
            icon: const Icon(Icons.undo),
            onPressed: () => _controller.undoLastPlayerMove(),
          ),
          IconButton(
            tooltip: 'Ván mới',
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _gameOverHandled = false;
                _controller.newGame(
                  humanColor: widget.humanColor,
                  difficulty: widget.difficulty,
                );
              });
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: _InfoChip(
                        icon: Icons.speed,
                        label: widget.difficulty.label,
                      ),
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_controller.isAiThinking)
                        const Padding(
                          padding: EdgeInsets.only(right: 8),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      Text(
                        _turnLabel,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: _InfoChip(
                        icon: Icons.stars,
                        iconColor: Colors.amber[700],
                        label: '$_displayScore',
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: ChessBoard(controller: _controller),
                ),
              ),
            ),
            const SizedBox(height: 8),
            if (_bannerLoaded && _bannerAd != null)
              SizedBox(
                width: _bannerAd!.size.width.toDouble(),
                height: _bannerAd!.size.height.toDouble(),
                child: AdWidget(ad: _bannerAd!),
              ),
          ],
        ),
      ),
    );
  }
}

/// Small pill used for the difficulty and score readouts flanking the turn
/// indicator — compact enough to sit in the corners without crowding it.
class _InfoChip extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String label;

  const _InfoChip({required this.icon, required this.label, this.iconColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: iconColor ?? Colors.black54),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
