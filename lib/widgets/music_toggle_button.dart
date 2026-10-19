import 'package:flutter/material.dart';

import '../services/music_service.dart';

/// Note icon that toggles [MusicService]'s on/off state, reflecting the
/// current value via its `enabledNotifier` so every instance of this
/// button (home screen, in-game AppBar) stays in sync with the same
/// shared state.
class MusicToggleButton extends StatelessWidget {
  const MusicToggleButton({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: MusicService.instance.enabledNotifier,
      builder: (context, enabled, _) {
        return IconButton(
          tooltip: enabled ? 'Tắt nhạc nền' : 'Bật nhạc nền',
          icon: Icon(enabled ? Icons.music_note : Icons.music_off),
          onPressed: () => MusicService.instance.toggle(),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        );
      },
    );
  }
}
