import 'package:flutter_test/flutter_test.dart';
import 'package:onegame/games/common/game_types.dart';
import 'package:onegame/games/penalty/penalty.dart';

const def = PenaltyGame();

void run(PenaltySim sim, int steps) {
  for (var i = 0; i < steps && !sim.over; i++) {
    sim.tick();
    sim.step++;
    sim.cues.clear();
  }
}

void swipe(
  PenaltySim sim,
  Offset from,
  Offset to, {
  int steps = 8,
  Offset bend = Offset.zero,
}) {
  sim.onPointer(PointerPhase.down, 1, from);
  for (var i = 1; i < steps; i++) {
    final t = i / steps;
    final p = Offset.lerp(from, to, t)! + bend * (4 * t * (1 - t));
    sim.onPointer(PointerPhase.move, 1, p);
    run(sim, 1);
  }
  sim.onPointer(PointerPhase.up, 1, to);
}

void main() {
  test('plan: 10 keeper plans, 5 AI shots, deterministic', () {
    final a = PenaltyPlan.generate(const GameContext(seed: 9));
    expect(a.keeper, hasLength(PenaltySim.maxShots));
    expect(a.aiShots, hasLength(PenaltySim.saveRounds));
    expect(def.levelFingerprint(9, null), def.levelFingerprint(9, null));
  });

  test('a tap is not a shot; a wide swipe misses', () {
    final sim = def.createSim(const GameContext(seed: 1)) as PenaltySim;
    sim
      ..onPointer(PointerPhase.down, 1, const Offset(180, 540))
      ..onPointer(PointerPhase.up, 1, const Offset(182, 540));
    run(sim, 200);
    expect(sim.outcomes, isEmpty);
    swipe(sim, const Offset(180, 560), const Offset(340, 420));
    run(sim, 200);
    expect(sim.outcomes.single, ShotOutcome.wide);
  });

  test('panenka beats a diving keeper (+400) and is celebrated', () {
    for (var seed = 1; seed < 50; seed++) {
      final sim = def.createSim(GameContext(seed: seed)) as PenaltySim;
      if (sim.plan.keeper.first.side == 0) continue;
      swipe(sim, const Offset(180, 560), const Offset(182, 520), steps: 4);
      run(sim, 200);
      expect(sim.outcomes.single, ShotOutcome.panenka);
      expect(sim.score, 400);
      expect(sim.highlights, ['panenka']);
      return;
    }
    fail('no diving keeper found');
  });

  test('saving: diving on the hinted side saves shots', () {
    final sim = def.createSim(const GameContext(seed: 4)) as PenaltySim;
    // Miss the first shot on purpose to end the shooting part quickly.
    for (var i = 0; i < 5 && sim.saveIndex == 0 && sim.saves == 0; i++) {
      swipe(sim, const Offset(180, 560), const Offset(360, 420));
      run(sim, 260);
      if (sim.outcomes.length >= 5) break;
    }
    final scoreAfterShots = sim.score;
    var dove = 0;
    while (!sim.over) {
      while (!sim.aiShotInFlight && !sim.over) {
        run(sim, 1);
      }
      if (sim.over) break;
      final shot = sim.plan.aiShots[sim.saveIndex];
      while (!sim.aiShotInFlight && !sim.over) {
        run(sim, 1);
      }
      final dx = shot.u * 110;
      final dy = -(shot.v * 0.8 - 0.3) * 160;
      swipe(sim, const Offset(180, 400), Offset(180 + dx, 400 + dy), steps: 3);
      dove++;
      while (sim.aiShotInFlight) {
        run(sim, 1);
      }
    }
    expect(dove, PenaltySim.saveRounds);
    expect(sim.saves, greaterThanOrEqualTo(3));
    expect(sim.score, greaterThan(scoreAfterShots));
    expect(def.scoreBounds.contains(sim.finalScore), isTrue);
  });
}
