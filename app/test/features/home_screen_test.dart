import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:onegame/app/app.dart';
import 'package:onegame/app/locale_controller.dart';

Future<void> _pumpApp(WidgetTester tester, Locale locale) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [localeProvider.overrideWithBuild((ref, _) => locale)],
      child: const OneGameApp(),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('home shows the waiting state in French', (tester) async {
    await _pumpApp(tester, const Locale('fr'));
    expect(find.text("L'alarme n'a pas encore sonné."), findsOneWidget);
    expect(find.text('Entraînement'), findsOneWidget);
    expect(find.bySemanticsLabel('Réveil OneGame'), findsOneWidget);
  });

  testWidgets('home shows the waiting state in English', (tester) async {
    await _pumpApp(tester, const Locale('en'));
    expect(find.text("The alarm hasn't rung yet."), findsOneWidget);
    expect(find.text('Training'), findsOneWidget);
  });

  testWidgets('language can be switched from settings', (tester) async {
    await _pumpApp(tester, const Locale('fr'));
    await tester.tap(find.text('Réglages'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    expect(find.text('Settings'), findsWidgets);
  });

  testWidgets('training opens from home', (tester) async {
    await _pumpApp(tester, const Locale('fr'));
    await tester.tap(find.text('Entraînement'));
    await tester.pumpAndSettle();
    expect(find.text('Bientôt disponible'), findsOneWidget);
  });
}
