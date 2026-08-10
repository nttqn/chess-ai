import 'package:chess/chess.dart' as chesslib;
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../game/chess_ai.dart';
import '../game/game_controller.dart';
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
  }

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
      builder: (context) => AlertDialog(
        title: const Text('Kết thúc ván cờ'),
        content: Text(_resultMessage()),
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
        title: Text('Chess with AI · ${widget.difficulty.label}'),
        actions: [
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
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
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
