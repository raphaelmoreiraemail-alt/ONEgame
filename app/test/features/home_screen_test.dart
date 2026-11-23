import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:onegame/core/time/regions.dart';
import 'package:onegame/features/home/today_controller.dart';

import '../helpers/harness.dart';

void main() {
  final daily = localDaily('2026-11-24');
  final alert = daily.alertAt[Region.europe]!;

  testWidgets('waiting (FR): no game revealed, training available', (t) async {
    await pumpApp(t, now: alert.subtract(const Duration(hours: 1)));
    expect(find.text("L'alarme n'a pas encore sonné."), findsOneWidget);
    expect(find.text('Elle tombera entre 10h et 21h.'), findsOneWidget);
    expect(find.text('Entraînement'), findsOneWidget);
    expect(find.bySemanticsLabel('Réveil OneGame'), findsOneWidget);
    expect(find.text('JOUER'), findsNothing);
    await unmount(t);
  });

  testWidgets('waiting (EN)', (t) async {
    await pumpApp(
      t,
      locale: const Locale('en'),
      now: alert.subtract(const Duration(hours: 1)),
    );
    expect(find.text("The alarm hasn't rung yet."), findsOneWidget);
    expect(find.text('Training'), findsOneWidget);
    await unmount(t);
  });

  testWidgets('ringing: big PLAY button and a 2:00 → 0:00 countdown', (
    t,
  ) async {
    await pumpApp(t, now: alert.add(const Duration(seconds: 30)));
    expect(find.text('JOUER'), findsOneWidget);
    expect(find.text("C'EST L'HEURE !"), findsOneWidget);
    expect(find.text('1:30'), findsOneWidget);
    await unmount(t);
  });

  testWidgets('late: play anyway', (t) async {
    await pumpApp(t, now: alert.add(const Duration(minutes: 5)));
    expect(find.text('Tu es en retard'), findsOneWidget);
    expect(find.text('Jouer quand même'), findsOneWidget);
    await unmount(t);
  });

  testWidgets('played and interrupted states', (t) async {
    final h = await pumpApp(t, now: alert.add(const Duration(seconds: 10)));
    await h.repo.startAttempt();
    // Attempt started but the app "died": after the time limit it is lost.
    h.clock.advance(const Duration(minutes: 3));
    await h.container.read(todayProvider.notifier).refresh();
    await settle(t);
    expect(find.text('Partie interrompue'), findsOneWidget);
    await unmount(t);
  });

  testWidgets('language can be switched from settings', (t) async {
    await pumpApp(t, now: alert.subtract(const Duration(hours: 1)));
    await t.tap(find.text('Réglages'));
    await settle(t);
    await t.tap(find.text('English'));
    await settle(t);
    expect(find.text('Settings'), findsWidgets);
    await unmount(t);
  });

  testWidgets('training lists released games only', (t) async {
    await pumpApp(t, now: alert.subtract(const Duration(hours: 1)));
    await t.ensureVisible(find.text('Entraînement'));
    await settle(t, 3);
    await t.tap(find.text('Entraînement'));
    await settle(t);
    expect(find.textContaining('Rejoue les jeux'), findsOneWidget);
    expect(find.byType(ListTile), findsWidgets);
    await unmount(t);
  });
}
