import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Wall-clock abstraction, injectable for tests.
///
/// Used for day states (waiting / ringing / late...). Never used for in-game
/// timing: games count fixed 1/120 s steps instead (see section 6).
abstract class Clock {
  const Clock();

  /// Current instant, always in UTC.
  DateTime now();
}

class SystemClock extends Clock {
  const SystemClock();

  @override
  DateTime now() => DateTime.now().toUtc();
}

/// Manually driven clock for tests and the Game Lab.
class FakeClock extends Clock {
  FakeClock(DateTime initial) : _now = initial.toUtc();

  DateTime _now;

  @override
  DateTime now() => _now;

  void set(DateTime value) => _now = value.toUtc();

  void advance(Duration delta) => _now = _now.add(delta);
}

/// Override in tests with `clockProvider.overrideWithValue(FakeClock(...))`.
final clockProvider = Provider<Clock>((ref) => const SystemClock());
