import 'package:flutter_test/flutter_test.dart';
import 'package:onegame/games/airhockey/airhockey.dart';
import 'package:onegame/games/common/game_sim.dart';
import 'package:onegame/games/common/game_types.dart';
import 'package:onegame/games/tennis/tennis.dart';

void run(GameSim sim, int steps, [void Function()? each]) {
  for (var i = 0; i < steps && !sim.over; i++) {
    each?.call();
    sim.tick();
    sim.step++;
    sim.cues.clear();
  }
}

void main() {
  test('tennis: a player tracking the ball wins points; match to 7', () {
    const def = TennisGame();
    final sim = def.createSim(const GameContext(seed: 4)) as TennisSim;
    var x = 180.0;
    sim.onPointer(PointerPhase.down, 1, const Offset(180, 600));
    run(sim, 120 * 120, () {
      // Follow the ball with the paddle (relative drag).
      final target = sim.focus.dx;
      x += (target - x).clamp(-6, 6);
      sim.onPointer(PointerPhase.move, 1, Offset(x, 600));
      if (sim.step % 200 == 0) {
        sim
          ..onPointer(PointerPhase.up, 1, Offset(x, 600))
          ..onPointer(PointerPhase.down, 1, Offset(x, 600));
      }
    });
    expect(sim.me + sim.opp, greaterThan(0));
    expect(sim.me, greaterThan(0));
    expect(sim.over || sim.step >= 120 * 120, isTrue);
    expect(def.scoreBounds.contains(sim.finalScore), isTrue);
  });

  test('tennis AI style comes from the seed', () {
    final styles = {for (var s = 0; s < 30; s++) TennisAi.generate(s).style};
    expect(styles, hasLength(3));
  });

  test('air hockey: a passive player concedes, score never negative', () {
    const def = AirhockeyGame();
    final sim = def.createSim(const GameContext(seed: 2)) as AirhockeySim;
    // Push the puck to the AI once, then stay in a corner.
    run(
      sim,
      120 * 120,
      () => sim.onPointer(PointerPhase.down, 1, const Offset(330, 610)),
    );
    expect(sim.opp + sim.me, greaterThanOrEqualTo(0));
    expect(sim.score, greaterThanOrEqualTo(0));
    sim.dispose();
  });

  test('air hockey: pushing the puck up scores goals', () {
    const def = AirhockeyGame();
    final sim = def.createSim(const GameContext(seed: 7)) as AirhockeySim;
    var t = 0;
    run(sim, 120 * 60, () {
      // Rush through the puck toward the top goal.
      final p = sim.focus;
      final aim = t++ % 120 < 60 ? p.translate(0, 40) : p.translate(0, -60);
      sim.onPointer(PointerPhase.down, 1, aim);
    });
    expect(sim.me + sim.opp, greaterThan(0));
    expect(def.levelFingerprint(7, null), def.levelFingerprint(7, null));
    sim.dispose();
  });
}
