import 'package:flutter_test/flutter_test.dart';
import 'package:onegame/games/archery/archery.dart';
import 'package:onegame/games/billard/billard.dart';
import 'package:onegame/games/common/game_sim.dart';
import 'package:onegame/games/common/game_types.dart';

void run(GameSim sim, int steps) {
  for (var i = 0; i < steps && !sim.over; i++) {
    sim.tick();
    sim.step++;
    sim.cues.clear();
  }
}

void main() {
  test('archery: a nominal draw with no drift nor wind hits the gold', () {
    const def = ArcheryGame();
    final sim = def.createSim(
      const GameContext(seed: 1, tuning: {'drift': 0}),
    ) as ArcherySim;
    // First 7 targets are still; wind deflects a little.
    sim
      ..onPointer(PointerPhase.down, 1, const Offset(180, 450))
      ..onPointer(
        PointerPhase.move,
        1,
        const Offset(180, 450 + ArcherySim.nominalDraw),
      )
      ..onPointer(
        PointerPhase.up,
        1,
        const Offset(180, 450 + ArcherySim.nominalDraw),
      );
    run(sim, 200);
    expect(sim.points, greaterThanOrEqualTo(7));
  });

  test('archery: a weak draw falls short; 10 arrows end the game', () {
    const def = ArcheryGame();
    final sim = def.createSim(const GameContext(seed: 1)) as ArcherySim;
    for (var i = 0; i < 10; i++) {
      sim
        ..onPointer(PointerPhase.down, 1, const Offset(180, 450))
        ..onPointer(PointerPhase.up, 1, const Offset(180, 470));
      run(sim, 200);
    }
    expect(sim.over, isTrue);
    expect(sim.points, 0);
  });

  test(
    'billard: rack of 15 balls; a shot at a ball near a pocket can pot it',
    () {
      expect(BillardSim.rack(3), hasLength(15));
      var potted = false;
      for (var seed = 1; seed < 15 && !potted; seed++) {
        const def = BillardGame();
        final sim = def.createSim(GameContext(seed: seed)) as BillardSim;
        // Fire hard straight up a few times.
        for (var k = 0; k < 6 && !sim.over; k++) {
          final c = sim.focus;
          sim
            ..onPointer(PointerPhase.down, 1, c)
            ..onPointer(PointerPhase.up, 1, c.translate((k - 3) * 15.0, 110));
          run(sim, 9 * 120);
        }
        potted = sim.potted > 0;
        expect(sim.score, greaterThanOrEqualTo(0));
        sim.dispose();
      }
      expect(potted, isTrue);
    },
  );
}
