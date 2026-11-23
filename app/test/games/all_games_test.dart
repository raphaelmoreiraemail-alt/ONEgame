import 'package:flutter_test/flutter_test.dart';
import 'package:onegame/games/common/game_types.dart';
import 'package:onegame/games/game_registry.dart';

import 'sim_runner.dart';

/// Contract tests applied to every registered mini-game (sections 6 and 15).
void main() {
  test('game ids are unique', () {
    final ids = GameRegistry.all.map((g) => g.id).toList();
    expect(ids.toSet().length, ids.length);
  });

  for (final def in GameRegistry.all) {
    group(def.id, () {
      test('max duration <= 120 s', () {
        expect(def.maxDuration.inSeconds, lessThanOrEqualTo(120));
      });

      test('modifiers are known', () {
        expect(Modifiers.all, containsAll(def.supportedModifiers));
      });

      test('same seed ⇒ same level, different seeds ⇒ different levels', () {
        for (final m in [null, ...def.supportedModifiers]) {
          expect(
            def.levelFingerprint(12345, m),
            def.levelFingerprint(12345, m),
          );
        }
        final prints = {
          for (final s in [1, 2, 3, 42, 2938471923])
            def.levelFingerprint(s, null),
        };
        expect(prints.length, 5);
      });

      test('a full game is deterministic, ends in time, score in bounds', () {
        for (final seed in [7, 2938471923]) {
          final a = runMonkey(def, seed: seed, inputSeed: seed);
          final b = runMonkey(def, seed: seed, inputSeed: seed);
          expect(a.score, b.score);
          expect(a.sim.stats, b.sim.stats);
          expect(a.steps, b.steps);
          expect(a.steps, lessThanOrEqualTo(def.maxDuration.inSeconds * 120));
          expect(
            def.scoreBounds.contains(a.score),
            isTrue,
            reason: '${a.score}',
          );
          expect(a.score, greaterThanOrEqualTo(0));
        }
      });

      test('every supported modifier runs', () {
        for (final m in def.supportedModifiers) {
          final r = runMonkey(def, seed: 99, modifier: m);
          expect(def.scoreBounds.contains(r.score), isTrue, reason: m);
        }
      });
    });
  }
}
