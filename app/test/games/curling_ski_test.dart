import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:onegame/games/common/game_sim.dart';
import 'package:onegame/games/common/game_types.dart';
import 'package:onegame/games/curling/curling.dart';
import 'package:onegame/games/ski/ski.dart';

void run(GameSim sim, int steps, [void Function()? each]) {
  for (var i = 0; i < steps && !sim.over; i++) {
    each?.call();
    sim.tick();
    sim.step++;
    sim.cues.clear();
  }
}

void main() {
  test('curling: some straight throw reaches the house and scores', () {
    const def = CurlingGame();
    var best = 0;
    for (final speed in [300.0, 380.0, 460.0, 540.0]) {
      final sim = def.createSim(const GameContext(seed: 5)) as CurlingSim;
      // Swipe up over 0.25 s at the given finger speed.
      sim.onPointer(PointerPhase.down, 1, const Offset(180, 600));
      for (var i = 1; i <= 30; i++) {
        sim.onPointer(
          PointerPhase.move,
          1,
          Offset(180, 600 - speed * i / 120 / 0.5 * 0.5),
        );
        run(sim, 1);
      }
      sim.onPointer(PointerPhase.up, 1, Offset(180, 600 - speed * 30 / 120));
      run(sim, 12 * 120);
      best = math.max(best, sim.inHouse);
      expect(sim.score, greaterThanOrEqualTo(0));
      sim.dispose();
    }
    expect(best, greaterThan(0));
  });

  test('curling: opponents come from the seed', () {
    final a = CurlingSim.opponents(3);
    expect(a.length, inInclusiveRange(2, 4));
    expect(CurlingSim.opponents(3), a);
  });

  test('ski: following the gates finishes in 50–110 s; idle misses gates', () {
    const def = SkiGame();
    final sim = def.createSim(const GameContext(seed: 2)) as SkiSim;
    var x = 180.0;
    sim.onPointer(PointerPhase.down, 1, const Offset(180, 500));
    run(sim, 120 * 120, () {
      final s = sim.stats;
      final next = s['gates']!.toInt();
      if (next < sim.course.gates.length) {
        final target = sim.course.gates[next];
        x += ((target - sim.focus.dx) / 1.3).clamp(-4, 4);
        sim.onPointer(PointerPhase.move, 1, Offset(x, 500));
      }
    });
    expect(sim.finished, isTrue, reason: '${sim.stats}');
    expect(sim.missed, lessThan(10));
    final seconds = sim.centis / 100;
    expect(seconds, inInclusiveRange(50, 110));
    expect(sim.score, greaterThan(0));

    final idle = def.createSim(const GameContext(seed: 2)) as SkiSim;
    run(idle, 120 * 120);
    expect(idle.missed, greaterThan(20));
  });
}
