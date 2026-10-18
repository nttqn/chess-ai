import 'package:flutter/services.dart';

import 'settings_service.dart';

/// Light touch/sound feedback for moves. Uses the OS's own click sound and
/// haptics instead of bundled audio assets, since the app ships none.
class FeedbackService {
  FeedbackService._();
  static final FeedbackService instance = FeedbackService._();

  bool get _enabled => SettingsService.instance.soundEnabled;

  Future<void> move() async {
    if (!_enabled) return;
    await SystemSound.play(SystemSoundType.click);
    HapticFeedback.selectionClick();
  }

  Future<void> capture() async {
    if (!_enabled) return;
    await SystemSound.play(SystemSoundType.click);
    HapticFeedback.lightImpact();
  }

  Future<void> check() async {
    if (!_enabled) return;
    HapticFeedback.mediumImpact();
  }

  Future<void> gameOver() async {
    if (!_enabled) return;
    HapticFeedback.heavyImpact();
  }
}
