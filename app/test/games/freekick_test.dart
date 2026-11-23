import 'package:flutter_test/flutter_test.dart';
import 'package:onegame/games/common/game_types.dart';
import 'package:onegame/games/freekick/freekick.dart';

const def = FreekickGame();

void run(FreekickSim sim, int steps) {
  for (var i = 0; i < steps && !sim.over; i++) {
    sim.tick();
    sim.step++;
    sim.cues.clear();
  }
}

void swipe(
  FreekickSim sim,
  Offset from,
  Offset to, {
  Offset bend = Offset.zero,
}) {
  sim.onPointer(PointerPhase.down, 1, from);
  for (var i = 1; i < 8; i++) {
    final t = i / 8;
    sim.onPointer(
      PointerPhase.move,
      1,
      Offset.lerp(from, to, t)! + bend * (4 * t * (1 - t)),
    );
    run(sim, 1);
  }
  sim.onPointer(PointerPhase.up, 1, to);
  run(sim, 300);
}

void main() {
  test('8 kicks from the seed, 2 to 5 players in the wall', () {
    final p = FreekickPlan.generate(const GameContext(seed: 3));
    expect(p, hasLength(8));
    for (final k in p) {
      expect(k.wallSize, inInclusiveRange(2, 5));
    }
  });

  test('a low straight shot hits the wall or the keeper; wide misses', () {
    final sim = def.createSim(const GameContext(seed: 3)) as FreekickSim;
    swipe(sim, const Offset(180, 560), const Offset(380, 500));
    expect(sim.outcomes, isNotEmpty);
    expect(sim.outcomes.first, anyOf(KickOutcome.wide, KickOutcome.wall));
  });

  test('some curled shot scores; a full game ends after 8 kicks', () {
    var scored = false;
    for (var seed = 1; seed < 30 && !scored; seed++) {
      final sim = def.createSim(GameContext(seed: seed)) as FreekickSim;
      for (final dx in [-120.0, -60.0, 60.0, 120.0]) {
        for (final bend in [-60.0, 60.0]) {
          if (sim.over) break;
          swipe(
            sim,
            const Offset(180, 560),
            Offset(180 + dx, 330),
            bend: Offset(bend, 0),
          );
        }
      }
      scored = sim.goals > 0;
      expect(sim.score, greaterThanOrEqualTo(sim.goals * 150));
    }
    expect(scored, isTrue);
  });
}
