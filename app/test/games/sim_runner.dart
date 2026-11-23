import 'dart:ui';

import 'package:onegame/core/rng/seeded_random.dart';
import 'package:onegame/games/common/game_sim.dart';
import 'package:onegame/games/common/game_types.dart';
import 'package:onegame/games/common/mini_game_definition.dart';

/// Outcome of a headless run.
class SimRun {
  SimRun(this.sim, this.steps, this.timedOut);

  final GameSim sim;
  final int steps;
  final bool timedOut;

  int get score => sim.finalScore;
}

/// Runs a game headless with a scripted "monkey" player: random taps, drags
/// and swipes drawn from [inputSeed]. Mirrors `MiniGame.stepOnce`.
SimRun runMonkey(
  MiniGameDefinition def, {
  required int seed,
  String? modifier,
  int inputSeed = 1,
  int? maxSteps,
  bool Function(GameSim sim)? stopWhen,
}) {
  final sim = def.createSim(GameContext(seed: seed, modifierId: modifier));
  final limit =
      maxSteps ?? def.maxDuration.inMilliseconds * stepsPerSecond ~/ 1000;
  final rng = SeededRandom(inputSeed);
  // Scripted gesture state.
  var nextGesture = 30;
  var gestureEnd = -1;
  Offset from = Offset.zero;
  Offset to = Offset.zero;
  var gestureStart = 0;
  var timedOut = false;

  while (!sim.over) {
    if (sim.step == nextGesture) {
      from = Offset(rng.doubleInRange(20, 340), rng.doubleInRange(200, 620));
      to =
          from +
          Offset(rng.doubleInRange(-160, 160), rng.doubleInRange(-420, 120));
      gestureStart = sim.step;
      gestureEnd = sim.step + rng.intInRange(1, 60);
      sim.onPointer(PointerPhase.down, 1, from);
    } else if (gestureEnd > 0 && sim.step < gestureEnd) {
      final t = (sim.step - gestureStart) / (gestureEnd - gestureStart);
      sim.onPointer(PointerPhase.move, 1, Offset.lerp(from, to, t)!);
    } else if (sim.step == gestureEnd) {
      sim.onPointer(PointerPhase.up, 1, to);
      gestureEnd = -1;
      nextGesture = sim.step + rng.intInRange(10, 150);
    }
    sim.tick();
    sim.step++;
    sim.cues.clear();
    if (stopWhen != null && stopWhen(sim)) break;
    if (!sim.over && sim.step >= limit) {
      timedOut = true;
      sim.onTimeUp();
      sim.over = true;
    }
  }
  return SimRun(sim, sim.step, timedOut);
}
