import 'dart:ui' show Offset;

/// Mini-game categories (section 7). Used by `pickGame` rotation rules.
enum GameCategory { sport, adresse, arcade, reflexion }

/// Daily modifiers (section 8).
abstract final class Modifiers {
  static const wind = 'wind';
  static const night = 'night';
  static const turbo = 'turbo';
  static const mirror = 'mirror';
  static const ice = 'ice';
  static const giant = 'giant';

  static const all = [wind, night, turbo, mirror, ice, giant];
}

/// Theoretical min / max score of a game, used by anti-cheat.
class ScoreBounds {
  const ScoreBounds(this.min, this.max);

  final int min;
  final int max;

  int clamp(int score) => score.clamp(min, max);
  bool contains(int score) => score >= min && score <= max;
}

enum PointerPhase { down, move, up }

/// One raw input, stamped with the fixed step at which it was applied.
/// Positions are in world units (360 x 640), rounded to 0.1.
class InputEvent {
  const InputEvent({
    required this.step,
    required this.phase,
    required this.pointer,
    required this.x,
    required this.y,
  });

  factory InputEvent.fromCompact(List<int> c) => InputEvent(
    step: c[0],
    phase: PointerPhase.values[c[1]],
    pointer: c[2],
    x: c[3] / 10,
    y: c[4] / 10,
  );

  final int step;
  final PointerPhase phase;
  final int pointer;
  final double x;
  final double y;

  Offset get position => Offset(x, y);

  /// Compact form stored server-side: `[step, phase, pointer, x*10, y*10]`.
  List<int> toCompact() => [
    step,
    phase.index,
    pointer,
    (x * 10).round(),
    (y * 10).round(),
  ];
}

class GameResult {
  const GameResult({
    required this.gameId,
    required this.seed,
    required this.modifierId,
    required this.official,
    required this.score,
    required this.playedTime,
    required this.stats,
    required this.inputLog,
    required this.highlights,
    required this.shareLine,
    required this.timedOut,
  });

  final String gameId;
  final int seed;
  final String? modifierId;
  final bool official;

  /// Integer, higher is better, ALWAYS.
  final int score;
  final Duration playedTime;

  /// Details shown on the results screen (keys resolved by `GameStrings`).
  final Map<String, num> stats;
  final List<InputEvent> inputLog;

  /// Highlight ids ("coups d'éclat") reached during the game, e.g. `ace`.
  final List<String> highlights;
  final String shareLine;
  final bool timedOut;
}

/// Everything a mini-game needs to build a level and run.
class GameContext {
  const GameContext({
    required this.seed,
    this.modifierId,
    this.official = false,
    this.tuning = const {},
    this.lang = 'fr',
  });

  final int seed;
  final String? modifierId;

  /// False in training and in the Game Lab.
  final bool official;

  /// Balancing values from Remote Config (`games.<id>.*`). Games fall back to
  /// their own defaults for missing keys.
  final Map<String, num> tuning;

  /// Language code, for games whose content depends on it (motflash).
  final String lang;

  bool has(String modifier) => modifierId == modifier;

  double tune(String key, num fallback) => (tuning[key] ?? fallback).toDouble();
}
