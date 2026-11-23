import 'package:flutter_test/flutter_test.dart';
import 'package:onegame/games/common/game_sim.dart';
import 'package:onegame/games/common/game_types.dart';
import 'package:onegame/games/flappy/flappy.dart';
import 'package:onegame/games/runner/runner.dart';
import 'package:onegame/games/snake/snake.dart';

void run(GameSim sim, int steps, [void Function()? each]) {
  for (var i = 0; i < steps && !sim.over; i++) {
    each?.call();
    sim.tick();
    sim.step++;
    sim.cues.clear();
  }
}

void main() {
  test('flappy: a bird that never flaps scores 0; flapping under the gap passes pipes', () {
    const def = FlappyGame();
    final idle = def.createSim(const GameContext(seed: 1)) as FlappySim;
    idle.onPointer(PointerPhase.down, 1, Offset.zero);
    run(idle, 120 * 120);
    expect(idle.over, isTrue);
    expect(idle.score, 0);

    final sim = def.createSim(const GameContext(seed: 1)) as FlappySim;
    final pipes = FlappySim.pipes(
      const GameContext(seed: 1),
      def.defaultTuning,
    );
    run(sim, 120 * 60, () {
      final target = pipes[sim.passed].gapY + 20;
      if (sim.focus.dy > target && sim.step % 12 == 0) {
        sim.onPointer(PointerPhase.down, 1, Offset.zero);
      }
    });
    expect(sim.passed, greaterThan(5));
    expect(sim.score, greaterThanOrEqualTo(sim.passed * 100));
  });

  test('runner: score = meters + coins × 20; standing still crashes', () {
    const def = RunnerGame();
    final sim = def.createSim(const GameContext(seed: 3)) as RunnerSim;
    run(sim, 120 * 120);
    expect(sim.over, isTrue);
    expect(sim.score, sim.meters + sim.coins * 20);
    expect(RunnerSim.track(const GameContext(seed: 3)), isNotEmpty);
  });

  test('snake: a greedy player eats fruits; walls come from the seed', () {
    const def = SnakeGame();
    final sim = def.createSim(const GameContext(seed: 5)) as SnakeSim;
    expect(SnakeSim.walls(5), isNotEmpty);
    run(sim, 30 * 120);
    // Going straight up hits the border.
    expect(sim.over, isTrue);
    expect(sim.score, sim.fruits * 100 + sim.golden * 300);
  });
}
