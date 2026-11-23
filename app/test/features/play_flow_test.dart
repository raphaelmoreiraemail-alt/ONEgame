import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:onegame/app/router.dart';
import 'package:onegame/core/time/regions.dart';
import 'package:onegame/data/daily/models.dart';
import 'package:onegame/features/home/today_controller.dart';
import 'package:onegame/features/play/play_request.dart';

import '../helpers/harness.dart';

void main() {
  testWidgets('training: rule → 3-2-1-GO → game → FIN → results', (
    tester,
  ) async {
    final h = await pumpApp(tester, now: DateTime.utc(2026, 11, 24, 5));
    unawaited(
      h.container
          .read(routerProvider)
          .push(
            Routes.play,
            extra: const PlayRequest(gameId: 'survival', seed: 5),
          ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Survie 2:00'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('2'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('2:00'), findsOneWidget);
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.text('1:59'), findsOneWidget);
    // Standing still, the player gets hit well before 2:00.
    for (
      var i = 0;
      i < 1300 && find.text('Résultats').evaluate().isEmpty;
      i++
    ) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Résultats'), findsOneWidget);
    expect(find.textContaining("Score d'entraînement"), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('official: JOUER while ringing → game → submitted → played', (
    tester,
  ) async {
    final daily = localDaily('2026-11-24');
    final alert = daily.alertAt[Region.europe]!;
    final h = await pumpApp(tester, now: alert.add(const Duration(seconds: 5)));
    await tester.tap(find.text('JOUER'));
    await settle(tester, 2);
    expect(
      find.text('Partie officielle · une seule tentative'),
      findsOneWidget,
    );
    // Let the game run to its end (fake clock does not matter for the game:
    // it counts fixed steps).
    for (
      var i = 0;
      i < 1400 && find.text('Résultats').evaluate().isEmpty;
      i++
    ) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Résultats'), findsOneWidget);
    await settle(tester);
    expect(find.text('🔥 Série : 1'), findsOneWidget);
    expect(find.text('Premier pas'), findsOneWidget);
    final today = h.container.read(todayProvider).value!;
    expect(today.attempt!.status, AttemptStatus.finished);
    expect(today.attempt!.onTime, isTrue);
    // A second official start is refused.
    await expectLater(h.repo.startAttempt(), throwsA(anything));
    await unmount(tester);
  });
}
