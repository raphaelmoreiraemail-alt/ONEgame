import 'package:flutter_test/flutter_test.dart';
import 'package:onegame/games/common/game_types.dart';
import 'package:onegame/games/motflash/motflash.dart';

void main() {
  test('7 letters per language, always forming a 7-letter word', () {
    for (final seed in [1, 2, 3, 2938471923]) {
      for (final lang in ['fr', 'en']) {
        final letters = MotflashSim.lettersFor(seed, lang);
        expect(letters, hasLength(7));
        final sorted = (List.of(letters)..sort()).join();
        final exists = Dictionary.words(
          lang,
        ).any((w) => w.length == 7 && (w.split('')..sort()).join() == sorted);
        expect(exists, isTrue, reason: '$seed $lang $letters');
      }
    }
    expect(
      MotflashSim.lettersFor(5, 'fr'),
      isNot(MotflashSim.lettersFor(5, 'en')),
    );
  });

  test('valid words score by length; duplicates and unknown words do not', () {
    const def = MotflashGame();
    final sim =
        def.createSim(const GameContext(seed: 2, lang: 'en')) as MotflashSim;
    final letters = sim.letters;
    // Find all dictionary words buildable from the letters.
    bool buildable(String w) {
      final pool = List.of(letters);
      for (final c in w.split('')) {
        if (!pool.remove(c)) return false;
      }
      return true;
    }

    final words = Dictionary.words('en').where(buildable).toList();
    expect(words.where((w) => w.length == 7), isNotEmpty);
    final w3 = words.firstWhere(
      (w) => w.length == 3,
      orElse: () => words.first,
    );
    sim
      ..type(w3)
      ..submit();
    expect(sim.score, MotflashGame.points[w3.length]);
    sim
      ..type(w3)
      ..submit();
    expect(sim.found, hasLength(1));
    final seven = words.firstWhere((w) => w.length == 7);
    sim
      ..type(seven)
      ..submit();
    expect(sim.highlights, ['fullWord']);
    expect(sim.score, MotflashGame.points[w3.length]! + 500);
    sim
      ..type('ZZZ')
      ..submit();
    expect(sim.found, hasLength(2));
  });
}
