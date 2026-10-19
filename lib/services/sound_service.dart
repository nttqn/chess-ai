import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum SoundEffect { move, capture, check, win, lose }

/// Short one-shot sound effects, played via `flame_audio`'s `AudioPool`.
/// `init()` must be fired unawaited from `main()`, not awaited before
/// `runApp()` — besides the risk of a stuck asset load hanging the first
/// frame, this app already hit a real black-screen crash from awaiting a
/// shared_preferences-backed service that early (see main.dart). Every
/// play call is a safe no-op if the pool never finished loading, or if
/// sound is toggled off.
class SoundService {
  SoundService._();
  static final SoundService instance = SoundService._();

  static const _enabledKey = 'sfx_enabled';

  static const Map<SoundEffect, String> _files = {
    SoundEffect.move: 'click.wav',
    SoundEffect.capture: 'hit.wav',
    SoundEffect.check: 'gong.wav',
    SoundEffect.win: 'levelup.wav',
    SoundEffect.lose: 'herodie.wav',
  };

  final ValueNotifier<bool> enabledNotifier = ValueNotifier<bool>(true);
  final Map<SoundEffect, AudioPool> _pools = {};

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      enabledNotifier.value = prefs.getBool(_enabledKey) ?? true;
    } catch (_) {}

    try {
      // Every audioplayers AudioPlayer (each AudioPool player below, and
      // MusicService's looping track) requests Android audio focus on
      // start by default, which *pauses* whichever player already had
      // it — so once MusicService starts the background loop, every
      // single move/capture sound here would cut it out for an instant.
      // Nothing in this app needs exclusive focus. Must run before any
      // AudioPool/bgm player is created, so they inherit this as their
      // default context.
      await AudioPlayer.global.setAudioContext(
        AudioContext(
          android: const AudioContextAndroid(audioFocus: AndroidAudioFocus.none),
          iOS: AudioContextIOS(category: AVAudioSessionCategory.ambient),
        ),
      );
    } catch (_) {
      // Worst case every sound still plays, just with the default
      // (focus-stealing) behavior — never let this block the app.
    }

    for (final entry in _files.entries) {
      try {
        final pool = await FlameAudio.createPool(entry.value, minPlayers: 1, maxPlayers: 2)
            .timeout(const Duration(seconds: 5));
        _pools[entry.key] = pool;
      } catch (_) {
        // Missing/broken asset for this one effect shouldn't block the
        // rest — that effect just stays silent.
      }
    }
  }

  void play(SoundEffect effect) {
    if (!enabledNotifier.value) return;
    _pools[effect]?.start();
  }

  Future<void> toggle() async {
    enabledNotifier.value = !enabledNotifier.value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_enabledKey, enabledNotifier.value);
    } catch (_) {}
  }
}
