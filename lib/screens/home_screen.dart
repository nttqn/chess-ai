import 'package:chess/chess.dart' as chesslib;
import 'package:flutter/material.dart';

import '../game/chess_ai.dart';
import '../game/game_save_service.dart';
import '../game/score_service.dart';
import '../game/settings_service.dart';
import '../services/music_service.dart';
import '../widgets/music_toggle_button.dart';
import '../widgets/sound_toggle_button.dart';
import 'game_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Difficulty _difficulty = Difficulty.medium;
  chesslib.Color _humanColor = chesslib.Color.WHITE;
  bool _vsHuman = false;

  bool _signedIn = false;
  String? _playerName;
  int _bestScore = 0;

  SavedGame? _savedGame;

  @override
  void initState() {
    super.initState();
    // Safe to call shared_preferences here (post-first-frame widget
    // lifecycle) — see the comment in main.dart for why it must NOT be
    // awaited in main() before runApp().
    SettingsService.instance.load();
    MusicService.instance.playMenu();
    _refreshStatus();
    _loadSavedGame();
  }

  Future<void> _refreshStatus() async {
    await ScoreService.instance.trySilentSignIn();
    final signedIn = await ScoreService.instance.isSignedIn();
    final name = signedIn ? await ScoreService.instance.playerName() : null;
    final best = await ScoreService.instance.bestScoreOverall();
    if (!mounted) return;
    setState(() {
      _signedIn = signedIn;
      _playerName = name;
      _bestScore = best;
    });
  }

  Future<void> _loadSavedGame() async {
    final saved = await GameSaveService.instance.load();
    if (!mounted) return;
    setState(() => _savedGame = saved);
  }

  Future<void> _handleSignIn() => _refreshStatus();

  Future<void> _playGame(GameScreen screen) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => screen),
    );
    MusicService.instance.playMenu();
    _refreshStatus();
    _loadSavedGame();
  }

  Widget _buildPlayGamesStatus() {
    return Column(
      children: [
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            if (_signedIn)
              Chip(
                avatar: const Icon(Icons.check_circle, color: Colors.green, size: 18),
                label: Text(_playerName ?? 'Đã đăng nhập'),
              )
            else
              OutlinedButton.icon(
                onPressed: _handleSignIn,
                icon: const Icon(Icons.login),
                label: const Text('Đăng nhập Play Games'),
              ),
            OutlinedButton.icon(
              onPressed: () => ScoreService.instance.showLeaderboard(),
              icon: const Icon(Icons.leaderboard),
              label: const Text('Bảng xếp hạng'),
            ),
            OutlinedButton.icon(
              onPressed: () => ScoreService.instance.showAchievements(),
              icon: const Icon(Icons.emoji_events_outlined),
              label: const Text('Thành tích'),
            ),
          ],
        ),
        if (_bestScore > 0) ...[
          const SizedBox(height: 8),
          Text(
            'Điểm cao nhất của bạn: $_bestScore',
            style: const TextStyle(color: Colors.black54),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          const SoundToggleButton(),
          const SizedBox(width: 12),
          const MusicToggleButton(),
          const SizedBox(width: 12),
          IconButton(
            tooltip: 'Cài đặt',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Image.asset(
                    'assets/icon/icon.png',
                    width: 120,
                    height: 120,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Chess with AI',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Đấu cờ vua với máy tính',
                  style: TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 20),
                _buildPlayGamesStatus(),
                if (_savedGame != null) ...[
                  const SizedBox(height: 24),
                  Card(
                    color: Theme.of(context).colorScheme.secondaryContainer,
                    child: ListTile(
                      leading: const Icon(Icons.play_circle_fill),
                      title: const Text('Tiếp tục ván đang chơi'),
                      subtitle: Text(
                        _savedGame!.vsHuman
                            ? '2 người chơi'
                            : 'Cấp độ: ${_savedGame!.difficulty.label}',
                      ),
                      onTap: () => _playGame(
                        GameScreen(
                          difficulty: _savedGame!.difficulty,
                          humanColor: _savedGame!.humanColor,
                          vsHuman: _savedGame!.vsHuman,
                          resume: _savedGame,
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Chế độ',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                const SizedBox(height: 8),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(
                      value: false,
                      label: Text('Đấu với máy'),
                      icon: Icon(Icons.smart_toy_outlined),
                    ),
                    ButtonSegment(
                      value: true,
                      label: Text('2 người chơi'),
                      icon: Icon(Icons.people_outline),
                    ),
                  ],
                  selected: {_vsHuman},
                  onSelectionChanged: (s) =>
                      setState(() => _vsHuman = s.first),
                ),
                if (!_vsHuman) ...[
                  const SizedBox(height: 24),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Cấp độ',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: Difficulty.values.map((d) {
                      final selected = d == _difficulty;
                      return ChoiceChip(
                        label: Text(d.label),
                        selected: selected,
                        onSelected: (_) => setState(() => _difficulty = d),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Bạn cầm quân',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<chesslib.Color>(
                    segments: const [
                      ButtonSegment(
                        value: chesslib.Color.WHITE,
                        label: Text('Trắng'),
                        icon: Text('♙'),
                      ),
                      ButtonSegment(
                        value: chesslib.Color.BLACK,
                        label: Text('Đen'),
                        icon: Text('♟'),
                      ),
                    ],
                    selected: {_humanColor},
                    onSelectionChanged: (s) =>
                        setState(() => _humanColor = s.first),
                  ),
                ],
                const SizedBox(height: 40),
                FilledButton.icon(
                  onPressed: () => _playGame(
                    GameScreen(
                      difficulty: _difficulty,
                      humanColor: _humanColor,
                      vsHuman: _vsHuman,
                    ),
                  ),
                  icon: const Icon(Icons.play_arrow),
                  label: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                    child: Text('Bắt đầu ván mới', style: TextStyle(fontSize: 16)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
