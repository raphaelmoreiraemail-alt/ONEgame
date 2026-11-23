import 'package:flutter_test/flutter_test.dart';
import 'package:onegame/games/common/game_types.dart';
import 'package:onegame/games/fishing/fishing.dart';

void main() {
  test('cast, strike at the bite, reel with pauses → fish landed', () {
    const def = FishingGame();
    final sim = def.createSim(const GameContext(seed: 4)) as FishingSim;
    var guard = 0;
    while (sim.fish == 0 && guard++ < 6) {
      // Cast: quick swipe up.
      sim
        ..onPointer(PointerPhase.down, 1, const Offset(180, 600))
        ..onPointer(PointerPhase.up, 1, const Offset(180, 450));
      // Wait for the bite (the bobber dunks), then strike.
      for (var i = 0; i < 5 * 120; i++) {
        sim
          ..tick()
          ..step += 1;
        if (sim.stats['fish'] != null && sim.focus.dy > 0 && _biting(sim)) {
          break;
        }
      }
      sim.onPointer(PointerPhase.down, 1, const Offset(180, 600));
      // Reel, releasing whenever the tension is high.
      for (var i = 0; i < 20 * 120; i++) {
        if (sim.tension > 0.75) {
          sim.onPointer(PointerPhase.up, 1, const Offset(180, 600));
        } else if (sim.tension < 0.35) {
          sim.onPointer(PointerPhase.down, 1, const Offset(180, 600));
        }
        sim
          ..tick()
          ..step += 1;
        sim.cues.clear();
        if (sim.fish > 0 || sim.breaks > 0) break;
      }
      sim.onPointer(PointerPhase.up, 1, const Offset(180, 600));
      for (var i = 0; i < 200; i++) {
        sim
          ..tick()
          ..step += 1;
      }
    }
    expect(sim.fish, greaterThan(0));
    expect(
      sim.score,
      sim.grams ~/ 10 + (sim.highlights.contains('legendary') ? 1000 : 0),
    );
  });

  test('legendary fish are rare (1 %)', () {
    final lake = Lake.generate(1);
    var legendary = 0;
    for (var i = 0; i < 2000; i++) {
      if (identical(lake.fishFor(i, 2, 0.01).$1, Lake.legendary)) legendary++;
    }
    expect(legendary, inInclusiveRange(5, 40));
  });
}

bool _biting(FishingSim sim) => sim.debugBiting;
