import 'package:chess/chess.dart' as chesslib;
import 'package:flutter/material.dart';

import '../game/chess_ai.dart';
import '../game/score_service.dart';
import 'game_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Difficulty _difficulty = Difficulty.medium;
  chesslib.Color _humanColor = chesslib.Color.WHITE;

  bool _signedIn = false;
  String? _playerName;
  int _bestScore = 0;

  @override
  void initState() {
    super.initState();
    _refreshStatus();
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

  Future<void> _handleSignIn() => _refreshStatus();

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
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
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
                const SizedBox(height: 40),
                FilledButton.icon(
                  onPressed: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => GameScreen(
                          difficulty: _difficulty,
                          humanColor: _humanColor,
                        ),
                      ),
                    );
                    _refreshStatus();
                  },
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
