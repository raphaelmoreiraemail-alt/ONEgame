import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Device-level preferences (section 9.10).
class AppSettings {
  const AppSettings({
    this.sound = true,
    this.haptics = true,
    this.reduceMotion = false,
  });

  final bool sound;
  final bool haptics;

  /// Disables shaking and flashes (section 12).
  final bool reduceMotion;

  AppSettings copyWith({bool? sound, bool? haptics, bool? reduceMotion}) =>
      AppSettings(
        sound: sound ?? this.sound,
        haptics: haptics ?? this.haptics,
        reduceMotion: reduceMotion ?? this.reduceMotion,
      );
}

/// Overridden in `main()` with the loaded instance.
final sharedPrefsProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sharedPrefsProvider must be overridden'),
);

class SettingsController extends Notifier<AppSettings> {
  static const _sound = 'settings.sound';
  static const _haptics = 'settings.haptics';
  static const _reduceMotion = 'settings.reduceMotion';

  SharedPreferences get _prefs => ref.read(sharedPrefsProvider);

  @override
  AppSettings build() => AppSettings(
    sound: _prefs.getBool(_sound) ?? true,
    haptics: _prefs.getBool(_haptics) ?? true,
    reduceMotion: _prefs.getBool(_reduceMotion) ?? false,
  );

  Future<void> setSound(bool v) async {
    state = state.copyWith(sound: v);
    await _prefs.setBool(_sound, v);
  }

  Future<void> setHaptics(bool v) async {
    state = state.copyWith(haptics: v);
    await _prefs.setBool(_haptics, v);
  }

  Future<void> setReduceMotion(bool v) async {
    state = state.copyWith(reduceMotion: v);
    await _prefs.setBool(_reduceMotion, v);
  }
}

final settingsProvider = NotifierProvider<SettingsController, AppSettings>(
  SettingsController.new,
);
