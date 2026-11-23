import '../../core/l10n/l10n.dart';
import 'game_sim.dart';
import 'game_types.dart';

/// Contract of a mini-game (section 5.1).
///
/// Text is resolved through [AppLocalizations] (Dart gen-l10n has no lookup
/// by key string), see DECISIONS.md.
abstract class MiniGameDefinition {
  const MiniGameDefinition();

  String get id;
  String get emoji;
  GameCategory get category;
  int get rulesVersion;

  /// Always <= 120 s.
  Duration get maxDuration => const Duration(seconds: 120);

  Set<String> get supportedModifiers;
  ScoreBounds get scoreBounds;

  /// Balancing defaults, overridable from Remote Config (`games.<id>.*`).
  Map<String, num> get defaultTuning => const {};

  String name(AppLocalizations l10n);
  String rule(AppLocalizations l10n);

  /// Wordle-like line, e.g. "⛳ 3 trous · 8 coups (-1) · 1 trou en un".
  String shareLine(AppLocalizations l10n, Map<String, num> stats);

  /// Rows `(label, value)` displayed on the results screen.
  List<(String, String)> statRows(
    AppLocalizations l10n,
    Map<String, num> stats,
  );

  GameSim createSim(GameContext ctx);

  /// Fingerprint of the level generated from a seed (determinism tests).
  String levelFingerprint(int seed, String? modifierId);
}
