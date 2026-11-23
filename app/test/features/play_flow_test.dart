import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:onegame/app/app.dart';
import 'package:onegame/app/locale_controller.dart';
import 'package:onegame/app/router.dart';
import 'package:onegame/core/settings/settings.dart';
import 'package:onegame/features/play/play_request.dart';
import 'package:onegame/features/play/play_screen.dart';
import 'package:onegame/games/common/game_types.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('rule → 3-2-1-GO → game → FIN → results', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    GameResult? sunk;
    final container = ProviderContainer(
      overrides: [
        localeProvider.overrideWithBuild((ref, _) => const Locale('fr')),
        sharedPrefsProvider.overrideWithValue(prefs),
        resultSinkProvider.overrideWithValue((req, r) async => sunk = r),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const OneGameApp(),
      ),
    );
    await tester.pumpAndSettle();

    unawaited(
      container
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
    // Game running: HUD clock visible.
    expect(find.text('2:00'), findsOneWidget);
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.text('1:59'), findsOneWidget);

    // Standing still, the player gets hit well before 2:00.
    for (var i = 0; i < 1300 && sunk == null; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(sunk, isNotNull);
    await tester.pumpAndSettle();
    expect(find.text('Résultats'), findsOneWidget);
    expect(find.text('${sunk!.score}'), findsWidgets);
    expect(sunk!.official, isFalse);
  });
}
