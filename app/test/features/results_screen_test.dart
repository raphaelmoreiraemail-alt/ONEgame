import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:onegame/core/l10n/l10n.dart';
import 'package:onegame/core/theme/app_theme.dart';
import 'package:onegame/features/play/play_request.dart';
import 'package:onegame/features/results/results_screen.dart';
import 'package:onegame/games/common/game_types.dart';

GameResult _result({List<String> highlights = const []}) => GameResult(
  gameId: 'survival',
  seed: 1,
  modifierId: null,
  official: false,
  score: 1450,
  playedTime: const Duration(seconds: 95),
  stats: const {'seconds': 95, 'orbs': 10, 'survived': 0},
  inputLog: const [],
  highlights: highlights,
  shareLine: '☄️ 95 s · 10 orbes',
  timedOut: false,
);

Widget _wrap(Widget child, {Locale locale = const Locale('fr')}) =>
    ProviderScope(
      child: MaterialApp(
        locale: locale,
        theme: AppTheme.light(),
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: child,
      ),
    );

void main() {
  testWidgets('shows score, stats, share text and training note', (t) async {
    await t.pumpWidget(
      _wrap(
        ResultsScreen(
          request: const PlayRequest(gameId: 'survival', seed: 1),
          result: _result(),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('1450'), findsOneWidget);
    expect(find.text('Secondes survécues'), findsOneWidget);
    expect(find.text('95'), findsOneWidget);
    expect(find.textContaining('☄️ 95 s · 10 orbes'), findsOneWidget);
    expect(find.textContaining('Score d\'entraînement'), findsOneWidget);
    expect(find.text('Rejouer'), findsOneWidget);
  });

  testWidgets('official results hide replay and show highlights', (t) async {
    await t.pumpWidget(
      _wrap(
        ResultsScreen(
          request: const PlayRequest(
            gameId: 'survival',
            seed: 1,
            official: true,
            dayKey: '2026-11-24',
          ),
          result: _result(highlights: ['survivor']),
        ),
        locale: const Locale('en'),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('Play again'), findsNothing);
    expect(find.text('SURVIVOR!'), findsOneWidget);
    expect(find.textContaining('OneGame · 2026-11-24'), findsOneWidget);
  });
}
