import 'package:flutter_test/flutter_test.dart';
import 'package:onegame/games/common/game_types.dart';
import 'package:onegame/games/parking/parking.dart';

void run(ParkingSim sim, int steps) {
  for (var i = 0; i < steps && !sim.over; i++) {
    sim
      ..tick()
      ..step += 1;
    sim.cues.clear();
  }
}

void main() {
  test('oriented boxes overlap test', () {
    const a = Obb(Offset(0, 0), 10, 20, 0);
    expect(a.overlaps(const Obb(Offset(35, 0), 10, 20, 0)), isTrue);
    expect(a.overlaps(const Obb(Offset(45, 0), 10, 20, 0)), isFalse);
    expect(a.overlaps(const Obb(Offset(31, 0), 10, 20, 1.5708)), isFalse);
    expect(a.overlaps(const Obb(Offset(25, 0), 10, 20, 1.5708)), isTrue);
  });

  test('4 levels, tighter and tighter', () {
    final l = ParkingLevel.generate(3);
    expect(l, hasLength(4));
    expect(l.first.margin, greaterThan(l.last.margin));
  });

  test('a car stopped centered in the spot parks with top precision', () {
    const def = ParkingGame();
    final sim = def.createSim(const GameContext(seed: 3)) as ParkingSim;
    for (var i = 0; i < 4; i++) {
      final l = sim.debugLevel;
      sim.debugPlace(l.spot.center, l.spotAngle);
      run(sim, 2 * 120);
    }
    expect(sim.over, isTrue);
    expect(sim.parked, 4);
    expect(sim.score, 4 * 800);
    expect(sim.highlights, hasLength(4));
  });

  test('driving into a parked car is a bump (−100, never below 0)', () {
    const def = ParkingGame();
    final sim = def.createSim(const GameContext(seed: 3)) as ParkingSim;
    final l = sim.debugLevel;
    final target = l.parked.first.center;
    sim
      ..debugPlace(target.translate(-60, 0), 0)
      ..onPointer(PointerPhase.down, 1, ParkingSim.forward.center);
    run(sim, 3 * 120);
    expect(sim.bumps, greaterThan(0));
    expect(sim.score, 0);
  });
}
