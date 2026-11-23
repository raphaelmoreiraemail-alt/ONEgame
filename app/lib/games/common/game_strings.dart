import '../../core/l10n/l10n.dart';
import '../game_registry.dart';
import 'game_types.dart';

/// Localized labels for ids that travel as strings (modifiers, highlights...).
abstract final class GameStrings {
  static String modifierName(AppLocalizations l, String id) => switch (id) {
    Modifiers.wind => l.modifierWind,
    Modifiers.night => l.modifierNight,
    Modifiers.turbo => l.modifierTurbo,
    Modifiers.mirror => l.modifierMirror,
    Modifiers.ice => l.modifierIce,
    Modifiers.giant => l.modifierGiant,
    _ => id,
  };

  static String modifierDescription(AppLocalizations l, String id) =>
      switch (id) {
        Modifiers.wind => l.modifierWindDesc,
        Modifiers.night => l.modifierNightDesc,
        Modifiers.turbo => l.modifierTurboDesc,
        Modifiers.mirror => l.modifierMirrorDesc,
        Modifiers.ice => l.modifierIceDesc,
        Modifiers.giant => l.modifierGiantDesc,
        _ => '',
      };

  static String modifierEmoji(String id) => switch (id) {
    Modifiers.wind => '🌬️',
    Modifiers.night => '🌙',
    Modifiers.turbo => '⚡',
    Modifiers.mirror => '🪞',
    Modifiers.ice => '🧊',
    Modifiers.giant => '🦣',
    _ => '',
  };

  static String category(AppLocalizations l, GameCategory c) => switch (c) {
    GameCategory.sport => l.categorySport,
    GameCategory.adresse => l.categoryAdresse,
    GameCategory.arcade => l.categoryArcade,
    GameCategory.reflexion => l.categoryReflexion,
  };

  static String highlight(AppLocalizations l, String id) {
    for (final g in GameRegistry.all) {
      final label = g.highlightLabels(l)[id];
      if (label != null) return label;
    }
    return id.toUpperCase();
  }
}
