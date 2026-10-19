import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Looping background music, kept separate from [SoundService] (one-shot
/// effects via `AudioPool`) since `FlameAudio.bgm` is a different
/// mechanism — a single lifecycle-aware looping player. Has its own
/// independent on/off toggle so a player can mute music without losing
/// move/capture sound effects, or vice versa.
class MusicService {
  MusicService._();
  static final MusicService instance = MusicService._();

  static const _menuTrack = 'music/menu.ogg';
  static const _gameTrack = 'music/bamboo.ogg';
  static const _volume = 0.45;
  static const _enabledKey = 'music_enabled';

  final ValueNotifier<bool> enabledNotifier = ValueNotifier<bool>(true);

  String? _wanted;
  String? _playing;
  bool _initialized = false;

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      enabledNotifier.value = prefs.getBool(_enabledKey) ?? true;
    } catch (_) {}
    try {
      // Same audio-context fix as SoundService.init() (audioFocus: none,
      // so SFX don't steal focus and cut this loop out) — passed
      // explicitly here too since main.dart fires both services' init()
      // unawaited with no guaranteed order, and FlameAudio.bgm otherwise
      // falls back to its own default the instant it's first referenced.
      await FlameAudio.bgm.initialize(
        audioContext: AudioContext(
          android: const AudioContextAndroid(audioFocus: AndroidAudioFocus.none),
          iOS: AudioContextIOS(category: AVAudioSessionCategory.ambient),
        ),
      );
      _initialized = true;
    } catch (_) {
      // No bgm this session (e.g. a broken/missing asset) — the app must
      // stay fully usable in silence, same contract as SoundService.
    }
  }

  void playMenu() => _play(_menuTrack);

  void playGame() => _play(_gameTrack);

  void _play(String track) {
    _wanted = track;
    if (!_initialized || !enabledNotifier.value) return;
    // Already playing this exact track — don't restart it from 0.
    if (FlameAudio.bgm.isPlaying && _playing == track) return;
    // Bgm.play() releases the old source first, so switching menu <->
    // game music is just calling this again with the other file.
    _playing = track;
    FlameAudio.bgm.play(track, volume: _volume).catchError((_) {});
  }

  Future<void> toggle() async {
    enabledNotifier.value = !enabledNotifier.value;
    if (_initialized && _wanted != null) {
      if (enabledNotifier.value) {
        _playing = _wanted;
        FlameAudio.bgm.play(_wanted!, volume: _volume).catchError((_) {});
      } else {
        _playing = null;
        FlameAudio.bgm.stop().catchError((_) {});
      }
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_enabledKey, enabledNotifier.value);
    } catch (_) {}
  }
}
