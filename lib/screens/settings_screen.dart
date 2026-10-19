import 'package:flutter/material.dart';

import '../game/settings_service.dart';
import '../services/music_service.dart';
import '../services/sound_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late BoardTheme _boardTheme = SettingsService.instance.boardTheme;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cài đặt')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ValueListenableBuilder<bool>(
            valueListenable: SoundService.instance.enabledNotifier,
            builder: (context, enabled, _) => SwitchListTile(
              title: const Text('Hiệu ứng âm thanh'),
              subtitle: const Text(
                'Âm báo khi đi quân, ăn quân, chiếu tướng và kết thúc ván',
              ),
              value: enabled,
              onChanged: (_) => SoundService.instance.toggle(),
            ),
          ),
          ValueListenableBuilder<bool>(
            valueListenable: MusicService.instance.enabledNotifier,
            builder: (context, enabled, _) => SwitchListTile(
              title: const Text('Nhạc nền'),
              subtitle: const Text('Nhạc nền phát trong lúc chơi'),
              value: enabled,
              onChanged: (_) => MusicService.instance.toggle(),
            ),
          ),
          const SizedBox(height: 24),
          Text('Màu bàn cờ', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: BoardTheme.values.map((theme) {
              final selected = theme == _boardTheme;
              return InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  setState(() => _boardTheme = theme);
                  SettingsService.instance.setBoardTheme(theme);
                },
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: selected
                          ? Theme.of(context).colorScheme.primary
                          : Colors.transparent,
                      width: 3,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      _ThemeSwatch(theme: theme),
                      const SizedBox(height: 4),
                      Text(theme.label),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _ThemeSwatch extends StatelessWidget {
  final BoardTheme theme;

  const _ThemeSwatch({required this.theme});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        width: 64,
        height: 64,
        child: Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  Expanded(child: Container(color: theme.light)),
                  Expanded(child: Container(color: theme.dark)),
                ],
              ),
            ),
            Expanded(
              child: Row(
                children: [
                  Expanded(child: Container(color: theme.dark)),
                  Expanded(child: Container(color: theme.light)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
