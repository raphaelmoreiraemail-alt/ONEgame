/// Deterministic PRNG (mulberry32) shared with Cloud Functions.
///
/// MUST stay bit-for-bit identical to `functions/src/core/seededRandom.ts`.
/// Both implementations are checked against `shared/rng_vectors.json`.
///
/// Mini-games must never use `dart:math` `Random` for anything that can
/// influence the score: use [SeededRandom.derive] with a stable label instead.
library;

import 'dart:convert';

const int _mask32 = 0xFFFFFFFF;

/// 32-bit multiplication modulo 2^32 (equivalent to JavaScript `Math.imul`,
/// unsigned). Split in 16-bit halves so it never overflows a 64-bit int.
int _imul(int a, int b) {
  final ah = (a >>> 16) & 0xFFFF;
  final al = a & 0xFFFF;
  final bh = (b >>> 16) & 0xFFFF;
  final bl = b & 0xFFFF;
  return (al * bl + ((((ah * bl) + (al * bh)) & 0xFFFF) << 16)) & _mask32;
}

/// FNV-1a 32-bit hash of the UTF-8 bytes of [input].
int fnv1a32(String input) {
  var hash = 0x811C9DC5;
  for (final byte in utf8.encode(input)) {
    hash ^= byte;
    hash = _imul(hash, 0x01000193);
  }
  return hash;
}

class SeededRandom {
  SeededRandom(int seed) : _state = seed & _mask32;

  /// Sub-generator independent from other draws: `seed ^ fnv1a32(label)`.
  ///
  /// Example: `SeededRandom.derive(seed, 'minigolf:hole2')`. Adding a draw in
  /// one part of a game never shifts the values drawn in another part.
  factory SeededRandom.derive(int seed, String label) =>
      SeededRandom((seed & _mask32) ^ fnv1a32(label));

  int _state;

  /// mulberry32 step. Returns an unsigned 32-bit integer.
  int nextUint32() {
    _state = (_state + 0x6D2B79F5) & _mask32;
    var t = _state;
    t = _imul(t ^ (t >>> 15), t | 1);
    t = ((t + _imul(t ^ (t >>> 7), t | 61)) & _mask32) ^ t;
    return (t ^ (t >>> 14)) & _mask32;
  }

  /// Uniform double in [0, 1).
  double nextDouble() => nextUint32() / 4294967296.0;

  /// Uniform integer in [0, max).
  int nextInt(int max) {
    if (max <= 0 || max > _mask32) {
      throw RangeError.range(max, 1, _mask32, 'max');
    }
    return (nextDouble() * max).floor();
  }

  /// Uniform integer in [min, max] (inclusive).
  int intInRange(int min, int max) => min + nextInt(max - min + 1);

  /// Uniform double in [min, max).
  double doubleInRange(double min, double max) =>
      min + nextDouble() * (max - min);

  /// True with probability [p].
  bool chance(double p) => nextDouble() < p;

  T pick<T>(List<T> items) {
    if (items.isEmpty) throw StateError('cannot pick from an empty list');
    return items[nextInt(items.length)];
  }

  /// Fisher-Yates shuffle, returns a new list.
  List<T> shuffled<T>(List<T> items) {
    final out = List<T>.of(items);
    for (var i = out.length - 1; i > 0; i--) {
      final j = nextInt(i + 1);
      final tmp = out[i];
      out[i] = out[j];
      out[j] = tmp;
    }
    return out;
  }
}
