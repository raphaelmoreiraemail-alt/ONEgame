import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:onegame/games/basket/basket.dart';
import 'package:onegame/games/common/game_sim.dart';
import 'package:onegame/games/common/game_types.dart';

const def = BasketGame();

void run(BasketSim sim, int steps) {
  for (var i = 0; i < steps && !sim.over; i++) {
    sim.tick();
    sim.step++;
    sim.cues.clear();
  }
}

/// Swipe from [from] with a constant velocity [v] (px/s) during 0.1 s.
void flick(BasketSim sim, Offset from, Offset v) {
  sim.onPointer(PointerPhase.down, 1, from);
  for (var i = 1; i <= 12; i++) {
    sim.onPointer(PointerPhase.move, 1, from + v * (i / stepsPerSecond));
    run(sim, 1);
  }
  sim.onPointer(PointerPhase.up, 1, from + v * (12 / stepsPerSecond));
}

/// Brute-force a swipe that sinks the first shot at the static hoop.
Offset? findMake(int seed) {
  final spot = BasketLevel.generate(GameContext(seed: seed)).spots.first;
  for (var a = 46; a <= 84; a += 2) {
    for (var s = 1400; s <= 3600; s += 50) {
      final sim = def.createSim(GameContext(seed: seed)) as BasketSim;
      final ang = a * math.pi / 180;
      final v = Offset(math.cos(ang), -math.sin(ang)) * s.toDouble();
      flick(sim, spot, v);
      run(sim, 300);
      final made = sim.baskets > 0;
      sim.dispose();
      if (made) return v;
    }
  }
  return null;
}

void main() {
  test('5 spots inside the court, deterministic level', () {
    final l = BasketLevel.generate(const GameContext(seed: 3));
    expect(l.spots, hasLength(5));
    expect(l.wind, Offset.zero);
    expect(
      BasketLevel.generate(const GameContext(seed: 3, modifierId: 'wind')).wind,
      isNot(Offset.zero),
    );
  });

  test('a good swipe scores, a downward swipe does nothing', () {
    final v = findMake(11);
    expect(v, isNotNull, reason: 'some swipe should make the first shot');
    final sim = def.createSim(const GameContext(seed: 11)) as BasketSim;
    flick(sim, sim.level.spots.first, const Offset(0, 900));
    run(sim, 10);
    expect(sim.shots, 0);
    flick(sim, sim.level.spots.first, v!);
    run(sim, 300);
    expect(sim.baskets, 1);
    expect(sim.score, anyOf(2, 3));
    sim.dispose();
  });

  test('streak of 3 doubles the next baskets', () {
    final sim = def.createSim(const GameContext(seed: 11)) as BasketSim
      ..streak = 3;
    final before = sim.score;
    final v = findMake(11)!;
    flick(sim, sim.level.spots.first, v);
    run(sim, 300);
    expect(sim.score - before, anyOf(4, 6));
    sim.dispose();
  });
}
