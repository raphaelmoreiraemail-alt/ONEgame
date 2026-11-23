import 'package:flutter_test/flutter_test.dart';
import 'package:onegame/core/time/regions.dart';
import 'package:onegame/data/daily/models.dart';
import 'package:onegame/features/home/day_state.dart';

void main() {
  final alert = DateTime.utc(2026, 11, 24, 14);
  TodayInfo open({AttemptInfo? attempt}) => TodayInfo(
    kind: TodayKind.open,
    serverNow: alert,
    region: Region.europe,
    dayKey: '2026-11-24',
    gameId: 'stack',
    seed: 1,
    alertAt: alert,
    attempt: attempt,
  );

  test('the five states of section 4.4', () {
    expect(
      dayStateOf(
        TodayInfo(
          kind: TodayKind.waiting,
          serverNow: alert,
          region: Region.europe,
        ),
        alert,
      ),
      DayState.waiting,
    );
    expect(
      dayStateOf(open(), alert.add(const Duration(seconds: 119))),
      DayState.ringing,
    );
    expect(
      dayStateOf(open(), alert.add(const Duration(seconds: 121))),
      DayState.late,
    );
    expect(
      dayStateOf(
        open(
          attempt: AttemptInfo(
            startedAt: alert,
            onTime: true,
            status: AttemptStatus.finished,
            score: 10,
          ),
        ),
        alert,
      ),
      DayState.played,
    );
    expect(
      dayStateOf(
        open(
          attempt: AttemptInfo(
            startedAt: alert,
            onTime: true,
            status: AttemptStatus.lost,
          ),
        ),
        alert,
      ),
      DayState.inProgressLost,
    );
    expect(
      ringingSecondsLeft(open(), alert.add(const Duration(seconds: 30))),
      90,
    );
    expect(
      ringingSecondsLeft(open(), alert.add(const Duration(minutes: 3))),
      0,
    );
  });
}
