import 'package:flutter_test/flutter_test.dart';
import 'package:onegame/games/common/game_sim.dart';
import 'package:onegame/games/common/game_types.dart';
import 'package:onegame/games/petanque/petanque.dart';

const def = PetanqueGame();

void run(PetanqueSim sim, int steps) {
  for (var i = 0; i < steps && !sim.over; i++) {
    sim.tick();
    sim.step++;
    sim.cues.clear();
  }
}

/// Holds for [holdSteps] steps (power gauge) then releases.
void throwBoule(PetanqueSim sim, int holdSteps) {
  sim.onPointer(PointerPhase.down, 1, const Offset(180, 600));
  run(sim, holdSteps);
  sim.onPointer(PointerPhase.up, 1, const Offset(180, 600));
}

void main() {
  test('terrain: 3 jacks, AI errors and bumps from the seed', () {
    final t = PetanqueTerrain.generate(const GameContext(seed: 2));
    expect(t.jacks, hasLength(3));
    expect(t.aiTargets, hasLength(9));
    expect(
      PetanqueTerrain.generate(const GameContext(seed: 2, modifierId: 'wind'))
          .wind,
      isNot(Offset.zero),
    );
  });

  test('a full match: 3 ends of 3 + 3 boules, score = points×100 + bonus', () {
    final sim = def.createSim(const GameContext(seed: 2)) as PetanqueSim;
    var guard = 0;
    while (!sim.over && guard++ < 200) {
      // ~0.55 power (gauge period 1.4 s, starts after 0.15 s).
      throwBoule(sim, 18 + 46);
      run(sim, 120);
    }
    expect(sim.over, isTrue);
    expect(sim.endResults, hasLength(3));
    expect(
      sim.score,
      sim.myPoints * 100 + sim.proximityBonus + sim.carreaux * 500,
    );
    expect(sim.step, lessThan(120 * stepsPerSecond));
  });
}
