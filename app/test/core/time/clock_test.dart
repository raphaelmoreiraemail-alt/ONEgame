import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onegame/core/time/clock.dart';

void main() {
  test('SystemClock returns UTC', () {
    expect(const SystemClock().now().isUtc, isTrue);
  });

  test('FakeClock can be set and advanced', () {
    final clock = FakeClock(DateTime.utc(2026, 11, 24, 9));
    expect(clock.now(), DateTime.utc(2026, 11, 24, 9));
    clock.advance(const Duration(seconds: 120));
    expect(clock.now(), DateTime.utc(2026, 11, 24, 9, 2));
    clock.set(DateTime.utc(2026, 11, 25));
    expect(clock.now(), DateTime.utc(2026, 11, 25));
  });

  test('clockProvider can be overridden', () {
    final fake = FakeClock(DateTime.utc(2026));
    final container = ProviderContainer(
      overrides: [clockProvider.overrideWithValue(fake)],
    );
    addTearDown(container.dispose);
    expect(container.read(clockProvider).now(), DateTime.utc(2026));
  });
}
