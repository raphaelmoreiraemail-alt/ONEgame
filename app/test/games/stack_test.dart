import 'package:flutter_test/flutter_test.dart';
import 'package:onegame/games/common/game_types.dart';
import 'package:onegame/games/stack/stack.dart';

const def = StackGame();

void run(StackSim sim, int steps) {
  for (var i = 0; i < steps && !sim.over; i++) {
    sim.tick();
    sim.step++;
    sim.cues.clear();
  }
}

void main() {
  test('block speeds come from the seed and turbo is faster', () {
    final a = StackPlan(const GameContext(seed: 1), def.defaultTuning);
    final b = StackPlan(
      const GameContext(seed: 1, modifierId: 'turbo'),
      def.defaultTuning,
    );
    expect(b.speedOf(5), closeTo(a.speedOf(5) * 1.25, 1e-9));
    expect(a.speedOf(30), greaterThan(a.speedOf(0)));
  });

  test('tapping at once misses (block still off-screen) → game over', () {
    final sim = def.createSim(const GameContext(seed: 1)) as StackSim;
    sim.onPointer(PointerPhase.down, 1, Offset.zero);
    run(sim, 1);
    expect(sim.over, isTrue);
    expect(sim.score, 0);
  });

  test('score = height × 50 + perfects × 100', () {
    final sim = def.createSim(const GameContext(seed: 3)) as StackSim;
    var drops = 0;
    while (!sim.over && drops < 25) {
      // Wait ~1.4 s then tap (imprecise player).
      run(sim, 170);
      sim.onPointer(PointerPhase.down, 1, Offset.zero);
      run(sim, 1);
      drops++;
    }
    expect(sim.score, sim.height * 50 + sim.perfects * 100);
    expect(sim.height, greaterThan(0));
  });
}
