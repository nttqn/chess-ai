import 'package:flutter/material.dart';

import '../game/score_service.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late Future<List<GameHistoryEntry>> _future;

  @override
  void initState() {
    super.initState();
    _future = ScoreService.instance.loadHistory();
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  String _formatDate(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(dt.day)}/${two(dt.month)} ${two(dt.hour)}:${two(dt.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lịch sử ván thắng')),
      body: FutureBuilder<List<GameHistoryEntry>>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final entries = snapshot.data!;
          if (entries.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Chưa có ván nào thắng. Thắng một ván để bắt đầu ghi lịch sử!',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black54),
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: entries.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final entry = entries[index];
              return ListTile(
                leading: CircleAvatar(
                  child: Text(
                    '${entry.score}',
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
                title: Text('Cấp độ: ${entry.difficulty.label}'),
                subtitle: Text(
                  'Thắng sau ${_formatDuration(entry.elapsed)} · ${_formatDate(entry.playedAt)}',
                ),
                trailing: const Icon(Icons.emoji_events, color: Colors.amber),
              );
            },
          );
        },
      ),
    );
  }
}
