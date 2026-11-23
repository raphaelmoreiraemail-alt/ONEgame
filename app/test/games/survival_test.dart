import 'package:flutter_test/flutter_test.dart';
import 'package:onegame/games/common/game_types.dart';
import 'package:onegame/games/survival/survival.dart';

void main() {
  const def = SurvivalGame();

  test('level covers the full two minutes with walls and orbs', () {
    final spawns = SurvivalLevel.generate(
      const GameContext(seed: 1),
      def.defaultTuning,
    );
    expect(spawns.last.step, greaterThan(115 * 120));
    expect(spawns.where((s) => s.kind == SpawnKind.wall), isNotEmpty);
    expect(spawns.where((s) => s.kind == SpawnKind.orb).length, lessThan(40));
  });

  test('turbo makes the level denser', () {
    int count(String? m) => SurvivalLevel.generate(
      GameContext(seed: 1, modifierId: m),
      def.defaultTuning,
    ).length;
    expect(count(Modifiers.turbo), greaterThan(count(null)));
  });

  test('standing still eventually gets hit; score = seconds*10 + orbs*50', () {
    final sim = def.createSim(const GameContext(seed: 5)) as SurvivalSim;
    while (!sim.over && sim.step < 120 * 120) {
      sim.tick();
      sim.step++;
    }
    expect(sim.over, isTrue);
    expect(sim.score, sim.elapsed.floor() * 10 + sim.orbs * 50);
  });

  test('surviving 2:00 grants +500 and the highlight', () {
    final sim = def.createSim(const GameContext(seed: 5)) as SurvivalSim;
    sim
      ..step = 120 * 120
      ..onTimeUp();
    expect(sim.score, 1200 + 500);
    expect(sim.highlights, ['survivor']);
    expect(def.scoreBounds.contains(sim.finalScore), isTrue);
  });
}
