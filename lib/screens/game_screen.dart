import 'package:chess/chess.dart' as chesslib;
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../game/chess_ai.dart';
import '../game/game_controller.dart';
import '../game/game_save_service.dart';
import '../game/score_service.dart';
import '../services/ads_service.dart';
import '../services/music_service.dart';
import '../widgets/chess_board.dart';
import '../widgets/music_toggle_button.dart';
import '../widgets/sound_toggle_button.dart';
import 'history_screen.dart';

class GameScreen extends StatefulWidget {
  final Difficulty difficulty;
  final chesslib.Color humanColor;
  final bool vsHuman;
  final SavedGame? resume;

  const GameScreen({
    super.key,
    required this.difficulty,
    required this.humanColor,
    this.vsHuman = false,
    this.resume,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final GameController _controller;
  BannerAd? _bannerAd;
  bool _bannerLoaded = false;
  bool _gameOverHandled = false;
  bool _paused = false;
  int? _bestScoreForDifficulty;

  @override
  void initState() {
    super.initState();
    _controller = widget.resume != null
        ? GameController.resume(widget.resume!)
        : GameController(
            humanColor: widget.humanColor,
            difficulty: widget.difficulty,
            vsHuman: widget.vsHuman,
          );
    _controller.addListener(_onControllerChanged);
    MusicService.instance.playGame();
    _bannerAd = AdsService.instance.createBannerAd(
      onLoaded: () => setState(() => _bannerLoaded = true),
    );
    if (!widget.vsHuman) {
      ScoreService.instance.bestScoreFor(widget.difficulty).then((best) {
        if (mounted) setState(() => _bestScoreForDifficulty = best);
      });
    }
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

  void _togglePause() => setState(() => _paused = !_paused);

  void _restart() {
    setState(() {
      _paused = false;
      _gameOverHandled = false;
      _controller.newGame(
        humanColor: widget.humanColor,
        difficulty: widget.difficulty,
        vsHuman: widget.vsHuman,
      );
    });
  }

  void _exitToHome() => Navigator.of(context).pop();

  String _resultMessage() {
    switch (_controller.status) {
      case GameStatus.checkmate:
        if (widget.vsHuman) {
          final winnerLabel = _controller.winner == chesslib.Color.WHITE
              ? 'Trắng'
              : 'Đen';
          return 'Chiếu hết! $winnerLabel thắng! 🎉';
        }
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
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
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
                  _restart();
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
    if (widget.vsHuman) {
      return _controller.turn == chesslib.Color.WHITE
          ? 'Lượt Trắng'
          : 'Lượt Đen';
    }
    if (_controller.isAiThinking) return 'Máy đang suy nghĩ...';
    if (_controller.isHumanTurn) return 'Lượt của bạn';
    return 'Lượt của đối thủ';
  }

  @override
  Widget build(BuildContext context) {
    // Back button pauses mid-game instead of exiting straight to the
    // home screen (and dropping an in-progress, unsaved-by-intent
    // decision) — only lets the system pop once the game is actually
    // over, matching the pattern already used across this app series.
    return PopScope(
      canPop: _controller.isGameOver,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _togglePause();
      },
      child: _buildScaffold(context),
    );
  }

  Widget _buildScaffold(BuildContext context) {
    return Scaffold(
      // titleSpacing: 0 plus zero-padding/tight-constraints on every action
      // icon below: with 6 actions, AppBar's default 48x48 IconButton tap
      // targets don't leave enough room on a narrow window — AppBar's
      // internal layout squeezes the actions area down arbitrarily rather
      // than wrapping, so this needs each action's own footprint shrunk
      // (see block-puzzle-app's game_screen.dart for the same fix after
      // hitting a real "RenderFlex overflowed" there).
      appBar: AppBar(
        titleSpacing: 0,
        title: const Text('Chess with AI', overflow: TextOverflow.ellipsis),
        actions: [
          const SoundToggleButton(),
          const SizedBox(width: 8),
          const MusicToggleButton(),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Lịch sử',
            icon: const Icon(Icons.history),
            onPressed: () {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const HistoryScreen()));
            },
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: widget.vsHuman
                ? 'Gợi ý không khả dụng ở chế độ 2 người chơi'
                : 'Gợi ý nước đi',
            icon: _controller.isHintLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.lightbulb_outline),
            onPressed: widget.vsHuman || _controller.isGameOver
                ? null
                : () => _controller.requestHint(),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Đi lại nước trước',
            icon: const Icon(Icons.undo),
            onPressed: () => _controller.undoLastPlayerMove(),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Ván mới',
            icon: const Icon(Icons.refresh),
            onPressed: _restart,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            _buildBoardColumn(context),
            if (_paused && !_controller.isGameOver)
              _PauseOverlay(
                onResume: _togglePause,
                onRestart: _restart,
                onExit: _exitToHome,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBoardColumn(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: widget.vsHuman
                      ? const _InfoChip(
                          icon: Icons.people,
                          label: '2 người chơi',
                        )
                      : _InfoChip(
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
                  child: widget.vsHuman
                      ? const SizedBox.shrink()
                      : _InfoChip(
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

/// Shown over the board when the Android back button is pressed mid-game
/// — pauses rather than exiting straight back to the home screen.
class _PauseOverlay extends StatelessWidget {
  final VoidCallback onResume;
  final VoidCallback onRestart;
  final VoidCallback onExit;

  const _PauseOverlay({
    required this.onResume,
    required this.onRestart,
    required this.onExit,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.75),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Tạm dừng',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onResume,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Tiếp tục'),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  OutlinedButton(
                    onPressed: onExit,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Về màn hình chính'),
                  ),
                  const SizedBox(width: 16),
                  OutlinedButton(
                    onPressed: onRestart,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Ván mới'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
