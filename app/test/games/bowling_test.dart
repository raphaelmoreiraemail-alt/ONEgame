import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:onegame/games/bowling/bowling.dart';
import 'package:onegame/games/common/game_types.dart';

const def = BowlingGame();

void run(BowlingSim sim, int steps) {
  for (var i = 0; i < steps && !sim.over; i++) {
    sim.tick();
    sim.step++;
    sim.cues.clear();
  }
}

/// Places the ball at [x] then throws straight up with a ~0.15 s swipe.
void bowl(BowlingSim sim, double x, {double dx = 0}) {
  // Position drag (horizontal, from the ball position).
  sim
    ..onPointer(PointerPhase.down, 1, const Offset(180, 600))
    ..onPointer(PointerPhase.move, 1, Offset(x, 600))
    ..onPointer(PointerPhase.up, 1, Offset(x, 600));
  run(sim, 2);
  sim.onPointer(PointerPhase.down, 2, Offset(x, BowlingSim.foulY));
  for (var i = 1; i <= 18; i++) {
    sim.onPointer(
      PointerPhase.move,
      2,
      Offset(x + dx * i / 18, BowlingSim.foulY - i * 14),
    );
    run(sim, 1);
  }
  sim.onPointer(PointerPhase.up, 2, Offset(x + dx, BowlingSim.foulY - 18 * 14));
  run(sim, 8 * 120);
}

void main() {
  test('a center throw knocks pins, a gutter throw scores 0', () {
    final sim = def.createSim(const GameContext(seed: 2)) as BowlingSim;
    bowl(sim, 180);
    expect(sim.rolls, isNotEmpty);
    expect(sim.rolls.first, greaterThanOrEqualTo(5));
    sim.dispose();

    final g = def.createSim(const GameContext(seed: 2)) as BowlingSim;
    bowl(g, BowlingSim.laneLeft + BowlingSim.ballR, dx: -60);
    expect(g.rolls.first, 0);
    g.dispose();
  });

  test('full games end after 5 frames, official scoring ×10, real spread', () {
    final totals = <int>[];
    for (final x in [170.0, 176.0, 180.0, 184.0, 190.0]) {
      final sim = def.createSim(const GameContext(seed: 8)) as BowlingSim;
      var guard = 0;
      while (!sim.over && guard++ < 20) {
        bowl(sim, x);
      }
      expect(sim.over, isTrue);
      expect(sim.frame, 5);
      expect(sim.finalScore, sim.stats['pins']! * 10);
      totals.add(sim.finalScore);
      sim.dispose();
    }
    totals.sort();
    expect(totals.last - totals.first, greaterThan(300), reason: '$totals');
  });
}
