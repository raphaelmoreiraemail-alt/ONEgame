import '../../data/daily/models.dart';

/// The five day states of the home screen (section 4.4), plus technical ones.
enum DayState { unavailable, waiting, ringing, late, played, inProgressLost }

const onTimeWindow = Duration(seconds: 120);

/// Pure state machine, driven by `getToday` and the (server-corrected) clock.
DayState dayStateOf(TodayInfo t, DateTime now) {
  switch (t.kind) {
    case TodayKind.unavailable:
      return DayState.unavailable;
    case TodayKind.waiting:
      return DayState.waiting;
    case TodayKind.open:
      final a = t.attempt;
      if (a == null) {
        return now.difference(t.alertAt!) < onTimeWindow
            ? DayState.ringing
            : DayState.late;
      }
      return switch (a.status) {
        AttemptStatus.finished => DayState.played,
        AttemptStatus.lost || AttemptStatus.started => DayState.inProgressLost,
      };
  }
}

/// Seconds left to start on time, while ringing.
int ringingSecondsLeft(TodayInfo t, DateTime now) {
  final left = onTimeWindow - now.difference(t.alertAt!);
  return left.isNegative ? 0 : (left.inMilliseconds / 1000).ceil();
}
