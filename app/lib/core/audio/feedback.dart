import 'dart:async';
import 'dart:io' show Platform;

import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../games/common/game_sim.dart';
import '../settings/settings.dart';

/// Plays sounds and vibrations, honoring the user's settings.
class FeedbackService {
  FeedbackService(this._settings);

  final AppSettings Function() _settings;

  /// Audio plugins are unavailable in unit / widget tests.
  static final bool _audioAvailable = !Platform.environment.containsKey(
    'FLUTTER_TEST',
  );
  static bool _preloaded = false;

  static Future<void> preload() async {
    if (!_audioAvailable || _preloaded) return;
    _preloaded = true;
    try {
      await FlameAudio.audioCache.loadAll([
        for (final s in Sfx.values) '${s.name}.wav',
      ]);
    } on Object {
      // Missing audio must never break a game.
    }
  }

  void play(Sfx sfx, {double volume = 1}) {
    if (!_audioAvailable || !_settings().sound) return;
    unawaited(
      FlameAudio.play(
        '${sfx.name}.wav',
        volume: volume,
      ).then<void>((_) {}, onError: (Object _) {}),
    );
  }

  void vibrate(Haptic h) {
    if (!_settings().haptics) return;
    unawaited(switch (h) {
      Haptic.light => HapticFeedback.lightImpact(),
      Haptic.medium => HapticFeedback.mediumImpact(),
      Haptic.heavy => HapticFeedback.heavyImpact(),
      Haptic.selection => HapticFeedback.selectionClick(),
    });
  }

  void cue(GameCue c) {
    if (c.sfx != null) play(c.sfx!);
    if (c.haptic != null) vibrate(c.haptic!);
  }
}

final feedbackProvider = Provider<FeedbackService>(
  (ref) => FeedbackService(() => ref.read(settingsProvider)),
);
