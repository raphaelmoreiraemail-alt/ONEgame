import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:onegame/games/common/game_sim.dart';
import 'package:onegame/games/common/game_types.dart';
import 'package:onegame/games/racing/racing.dart';

void main() {
  test('track is a closed loop of reasonable length', () {
    final t = RaceTrack.generate(3);
    expect(t.length, inInclusiveRange(3500, 7500));
    expect((t.center.first - t.center.last).distance, lessThan(60));
  });

  test('a driver steering toward the centerline finishes 3 laps', () {
    const def = RacingGame();
    final sim = def.createSim(const GameContext(seed: 3)) as RacingSim;
    final t = sim.track;
    var idx = 0;
    var heading = 0.0;
    var x = 180.0;
    sim.onPointer(PointerPhase.down, 1, const Offset(180, 600));
    while (!sim.over && sim.step < 120 * stepsPerSecond) {
      // Crude autopilot: aim 12 points ahead.
      final pos = sim.debugPos;
      idx = t.nearest(pos, idx);
      final ahead = t.center[(idx + 12) % t.center.length] - pos;
      final h = math.atan2(ahead.dy, ahead.dx);
      heading = sim.debugHeading;
      var dh = h - heading;
      while (dh > math.pi) {
        dh -= 2 * math.pi;
      }
      while (dh < -math.pi) {
        dh += 2 * math.pi;
      }
      x = 180 + (dh * 70).clamp(-70, 70);
      sim.onPointer(PointerPhase.move, 1, Offset(x, 600));
      sim.tick();
      sim.step++;
      sim.cues.clear();
    }
    expect(sim.finished, isTrue, reason: '${sim.stats}');
    expect(sim.score, greaterThanOrEqualTo(600));
  });
}
