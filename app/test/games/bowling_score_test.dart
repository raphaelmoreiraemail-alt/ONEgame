import 'package:flutter_test/flutter_test.dart';
import 'package:onegame/games/bowling/bowling_score.dart';

void main() {
  test('perfect game over 5 frames = 150', () {
    expect(bowlingTotals(List.filled(7, 10)), [30, 60, 90, 120, 150]);
  });

  test('all gutters = 0', () {
    expect(bowlingTotals(List.filled(10, 0)), [0, 0, 0, 0, 0]);
  });

  test('spares and open frames', () {
    // 9/ | 7 2 | X | 5 4 | 6 / 8
    expect(bowlingTotals([9, 1, 7, 2, 10, 5, 4, 6, 4, 8]), [
      17,
      26,
      45,
      54,
      72,
    ]);
  });

  test('pending bonus is unresolved', () {
    expect(bowlingTotals([10, 3]), [null, null, null, null, null]);
    expect(bowlingTotals([3, 4, 10]), [7, null, null, null, null]);
    expect(bowlingResolved([3, 4, 10, 2, 2]), 7 + 14 + 4);
  });
}
