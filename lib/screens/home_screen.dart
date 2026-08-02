import 'package:chess/chess.dart' as chesslib;
import 'package:flutter/material.dart';

import '../game/chess_ai.dart';
import 'game_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Difficulty _difficulty = Difficulty.medium;
  chesslib.Color _humanColor = chesslib.Color.WHITE;

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
                const Text('♛', style: TextStyle(fontSize: 72)),
                const SizedBox(height: 8),
                Text(
                  'Cờ Vua AI',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Đấu cờ vua với máy tính',
                  style: TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 32),
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
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => GameScreen(
                          difficulty: _difficulty,
                          humanColor: _humanColor,
                        ),
                      ),
                    );
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
