import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:onegame/games/common/game_sim.dart';
import 'package:onegame/games/common/game_types.dart';
import 'package:onegame/games/minigolf/minigolf.dart';
import 'package:onegame/games/minigolf/minigolf_level.dart';

/// Shoots straight at the cup whenever it can.
MinigolfSim aimbot(int seed, {String? modifier}) {
  const def = MinigolfGame();
  final sim = def.createSim(
    GameContext(seed: seed, modifierId: modifier),
  ) as MinigolfSim;
  var cooldown = 0;
  while (!sim.over && sim.step < 120 * 120) {
    if (cooldown-- <= 0 && sim.holeIndex < sim.holes.length) {
      final ball = sim.focus;
      final toCup = sim.hole.cup - ball;
      final pull =
          toCup / toCup.distance * math.min(140, toCup.distance * 0.45);
      sim
        ..onPointer(PointerPhase.down, 1, ball)
        ..onPointer(PointerPhase.up, 1, ball - pull);
      cooldown = 20;
    }
    sim.tick();
    sim.step++;
    sim.cues.clear();
  }
  if (!sim.over) sim.onTimeUp();
  return sim;
}

void main() {
  test('3 holes, par between 2 and 4, enough course modules', () {
    expect(GolfLevel.moduleIds.length, greaterThanOrEqualTo(24));
    for (final seed in List.generate(50, (i) => i * 7919)) {
      final holes = GolfLevel.generate(seed);
      expect(holes, hasLength(3));
      for (final h in holes) {
        expect(h.par, inInclusiveRange(2, 4));
        expect(Course.bounds.contains(h.cup), isTrue);
        expect(Course.bounds.contains(h.tee), isTrue);
      }
    }
  });

  test('score formula: 1000 + Σ(par − strokes)×150 + aces×300 + time×3', () {
    for (final seed in [1, 2, 3, 4]) {
      final sim = aimbot(seed);
      final s = sim.stats;
      expect(s['holes'], 3);
      final bonus = sim.timeBonusSeconds * 3;
      final expected = math.max(
        0,
        1000 - (s['toPar']!.toInt()) * 150 + (s['aces']!.toInt()) * 300 + bonus,
      );
      expect(sim.finalScore, expected, reason: 'seed $seed');
      expect(const MinigolfGame().scoreBounds.contains(sim.finalScore), isTrue);
    }
  });

  test('never shooting scores 0, decent play scores > 1000', () {
    const def = MinigolfGame();
    final idle = def.createSim(const GameContext(seed: 3));
    while (idle.step < 120 * 120) {
      idle.tick();
      idle.step++;
    }
    idle.onTimeUp();
    expect(idle.finalScore, 0);
    expect(aimbot(1).finalScore, greaterThan(1000));
    idle.dispose();
  });

  test('ice and wind change the outcome deterministically', () {
    expect(
      aimbot(5, modifier: Modifiers.ice).finalScore,
      aimbot(5, modifier: Modifiers.ice).finalScore,
    );
    expect(
      MinigolfSim.windFor(const GameContext(seed: 5, modifierId: 'wind')),
      isNot(Offset.zero),
    );
    expect(MinigolfSim.windFor(const GameContext(seed: 5)), Offset.zero);
  });

  test('a hole-in-one is celebrated', () {
    // Search a seed where the aimbot aces a hole.
    for (var seed = 1; seed < 400; seed++) {
      final sim = aimbot(seed);
      if (sim.aces > 0) {
        expect(sim.highlights, contains('ace'));
        expect(stepsPerSecond, 120);
        return;
      }
    }
    fail('no ace found');
  });
}
