import 'package:flutter_test/flutter_test.dart';
import 'package:onegame/games/common/game_types.dart';
import 'package:onegame/games/darts/darts.dart';

const def = DartsGame();

void main() {
  test('dartboard scoring', () {
    const c = Board.center;
    expect(Board.score(c), (50, 2, 25));
    expect(Board.score(c.translate(0, -12)), (25, 1, 25));
    // Triple 20 straight up.
    final t20 = (Board.tripleIn + Board.tripleOut) / 2;
    expect(Board.score(c.translate(0, -t20)), (60, 3, 20));
    // Double 3 straight down.
    final d = (Board.doubleIn + Board.doubleOut) / 2;
    expect(Board.score(c.translate(0, d)), (6, 2, 3));
    // Single 6 to the right.
    expect(Board.score(c.translate(60, 0)), (6, 1, 6));
    expect(Board.score(c.translate(0, -Board.radius - 5)), (0, 0, 0));
  });

  test('drift is smooth and deterministic', () {
    final a = Drift(const GameContext(seed: 4), 9, 1.3);
    final b = Drift(const GameContext(seed: 4), 9, 1.3);
    expect(a.at(2, 0.8), b.at(2, 0.8));
    expect((a.at(0, 1.0) - a.at(0, 1.01)).distance, lessThan(1));
    expect(a.at(0, 0.3).dx.abs(), lessThanOrEqualTo(9));
  });

  test('9 darts aimed at T20 score high; 180 gives +500', () {
    final sim = def.createSim(
      const GameContext(seed: 4, tuning: {'drift': 0}),
    ) as DartsSim;
    final t20 = (Board.tripleIn + Board.tripleOut) / 2;
    final aim = Board.center.translate(0, -t20 + 90);
    while (!sim.over) {
      sim
        ..onPointer(PointerPhase.down, 1, aim)
        ..onPointer(PointerPhase.up, 1, aim);
      for (var i = 0; i < 200 && !sim.over; i++) {
        sim.tick();
        sim.step++;
      }
    }
    expect(sim.points, 540);
    expect(sim.score, 5400 + 3 * 500);
    expect(sim.highlights, ['oneEighty', 'oneEighty', 'oneEighty']);
    expect(def.scoreBounds.contains(sim.score), isTrue);
  });
}
