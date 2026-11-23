import 'package:flutter_test/flutter_test.dart';
import 'package:onegame/games/calcul/calcul.dart';
import 'package:onegame/games/common/game_sim.dart';
import 'package:onegame/games/common/game_types.dart';
import 'package:onegame/games/memory/memory.dart';

void run(GameSim sim, int steps) {
  for (var i = 0; i < steps && !sim.over; i++) {
    sim
      ..tick()
      ..step += 1;
    sim.cues.clear();
  }
}

void main() {
  test(
    'memory: repeating the sequence grows it; a wrong pad ends the game',
    () {
      const def = MemoryGame();
      final sim = def.createSim(const GameContext(seed: 2)) as MemorySim;
      final seq = MemorySim.sequence(2);
      var length = 3;
      for (var round = 0; round < 8; round++) {
        run(sim, (0.25 + length * 0.6) * 120 ~/ 1 + 40);
        for (var k = 0; k < length; k++) {
          sim.onPointer(PointerPhase.down, 1, MemorySim.pads[seq[k]].center);
          run(sim, 10);
        }
        expect(sim.stats['length'], length);
        run(sim, 70);
        length++;
      }
      expect(sim.score, greaterThanOrEqualTo(10 * 100));
      expect(sim.highlights, ['memoryTen']);
      // Wrong pad.
      run(sim, (0.25 + length * 0.6) * 120 ~/ 1 + 40);
      sim.onPointer(
        PointerPhase.down,
        1,
        MemorySim.pads[(seq[0] + 1) % 4].center,
      );
      expect(sim.over, isTrue);
    },
  );

  test('calcul: questions are well formed and get harder', () {
    for (var i = 0; i < 60; i++) {
      final q = Question.generate(7, i, 4);
      expect(q.choices, hasLength(4));
      expect(q.choices.toSet(), hasLength(4));
      expect(q.choices, contains(q.answer));
    }
    expect(Question.generate(7, 0, 4).text, contains('+'));
    expect(Question.generate(7, 8, 4).text, contains('×'));
  });

  test(
    'calcul: right answers score with speed and streak bonus, wrong −50',
    () {
      const def = CalculGame();
      final sim = def.createSim(const GameContext(seed: 7)) as CalculSim;
      for (var i = 0; i < 12; i++) {
        sim.answer(sim.question.choices.indexOf(sim.question.answer));
        run(sim, 60);
      }
      expect(sim.correct, 12);
      expect(sim.highlights, ['streak10']);
      final before = sim.score;
      sim.answer(
        sim.question.choices.indexWhere((c) => c != sim.question.answer),
      );
      expect(sim.score, before - 50);
      expect(sim.streak, 0);
    },
  );
}
