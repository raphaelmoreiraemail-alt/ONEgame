import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:onegame/app/app.dart';
import 'package:onegame/app/locale_controller.dart';
import 'package:onegame/core/backend/backend.dart';
import 'package:onegame/core/settings/settings.dart';
import 'package:onegame/core/time/clock.dart';
import 'package:onegame/core/time/regions.dart';
import 'package:onegame/data/daily/daily_logic.dart';
import 'package:onegame/data/daily/local_daily_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Today's challenge of the local backend for [dayKey].
DailyChallenge localDaily(String dayKey) =>
    localSchedule(LocalDailyRepository.epoch, dayKey).last;

class Harness {
  Harness(this.container, this.clock, this.repo);

  final ProviderContainer container;
  final FakeClock clock;
  final LocalDailyRepository repo;
}

/// Pumps the whole app on the local backend with a fake clock.
Future<Harness> pumpApp(
  WidgetTester tester, {
  Locale locale = const Locale('fr'),
  DateTime? now,
  List<Override> overrides = const [],
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final clock = FakeClock(now ?? DateTime.utc(2026, 11, 24, 5));
  final repo = LocalDailyRepository(prefs, clock, Region.europe);
  final container = ProviderContainer(
    overrides: [
      localeProvider.overrideWithBuild((ref, _) => locale),
      sharedPrefsProvider.overrideWithValue(prefs),
      clockProvider.overrideWithValue(clock),
      backendProvider.overrideWithValue(
        BackendServices(daily: repo, kind: BackendKind.local),
      ),
      ...overrides,
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const OneGameApp()),
  );
  await settle(tester);
  return Harness(container, clock, repo);
}

/// pumpAndSettle never settles with the home ticker: pump a few frames.
Future<void> settle(WidgetTester tester, [int frames = 10]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Unmounts the app so periodic timers are cancelled.
Future<void> unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
}
