import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:onegame/core/backend/backend.dart';
import 'package:onegame/core/l10n/l10n.dart';
import 'package:onegame/core/time/regions.dart';
import 'package:onegame/data/social/models.dart';
import 'package:onegame/data/social/pseudo.dart';
import 'package:onegame/data/social/social_repository.dart';
import 'package:onegame/features/friends/friends_screen.dart';
import 'package:onegame/features/friends/phone.dart';
import 'package:onegame/features/profile/avatar.dart';
import 'package:onegame/features/share/share_card.dart';
import 'package:onegame/games/common/game_types.dart';

import '../helpers/harness.dart';

void main() {
  final banned = bannedWords();

  test('app asset banned list = shared list', () {
    final asset = jsonDecode(
      File('assets/data/banned_words.json').readAsStringSync(),
    );
    final shared = jsonDecode(
      File('../shared/banned_words.json').readAsStringSync(),
    );
    expect(asset, shared);
  });

  test('pseudo filter (same cases as the server)', () {
    expect(checkPseudo('ab', banned), PseudoProblem.length);
    expect(checkPseudo('jean dupont', banned), PseudoProblem.charset);
    expect(checkPseudo('Zoé', banned), PseudoProblem.charset);
    expect(checkPseudo('Raph_42', banned), isNull);
    expect(normalizeForFilter('C0nn4rd!'), 'connard');
    expect(checkPseudo('C0nn4rd', banned), PseudoProblem.offensive);
    expect(checkPseudo('xxF_u_c_kxx', banned), PseudoProblem.offensive);
    expect(checkPseudo('PD.', banned), PseudoProblem.offensive);
    expect(checkPseudo('Speedy', banned), isNull);
    expect(checkPseudo('Essex_fan', banned), isNull);
  });

  test('phone normalisation and hashing', () {
    expect(normalizePhone('06 12 34 56 78', 'FR'), '+33612345678');
    expect(normalizePhone('+33 6 12 34 56 78', 'BE'), '+33612345678');
    expect(normalizePhone('0032 470 12 34 56', 'FR'), '+32470123456');
    expect(normalizePhone('(415) 555-0100', 'US'), '+14155550100');
    expect(normalizePhone('123', 'FR'), isNull);
    expect(normalizePhone('0612345678', null), isNull);
    expect(hashPhone('+33612345678'), hasLength(64));
  });

  testWidgets('onboarding: concept → notifications → pseudo → home', (t) async {
    final h = await pumpApp(
      t,
      onboarded: false,
      now: DateTime.utc(2026, 11, 24, 5),
    );
    expect(find.text('Une alarme. Deux minutes. Un jeu.'), findsWidgets);
    await t.tap(find.text('Suivant'));
    await settle(t, 6);
    expect(find.text("Autorise l'alarme"), findsOneWidget);
    await t.tap(find.text('Plus tard'));
    await settle(t, 6);
    expect(find.text('Choisis ton pseudo'), findsOneWidget);
    await t.enterText(find.byType(TextField), 'c0nnard');
    await t.tap(find.text("C'est parti !"));
    await settle(t);
    expect(find.text("Ce pseudo n'est pas autorisé."), findsOneWidget);
    await t.enterText(find.byType(TextField), 'Raph_42');
    await t.tap(find.text("C'est parti !"));
    await settle(t);
    expect(find.text("L'alarme n'a pas encore sonné."), findsOneWidget);
    expect(h.container.read(socialRepositoryProvider).pseudo, 'Raph_42');
    await unmount(t);
  });

  testWidgets('demo leaderboards, locked feed until played, add friend', (
    t,
  ) async {
    final daily = localDaily('2026-11-24');
    final h = await pumpApp(
      t,
      now: daily.alertAt[Region.europe]!.add(const Duration(hours: 3)),
    );
    final social = h.container.read(socialRepositoryProvider);
    await social.claimPseudo('Raph_42');
    final world = await social.leaderboard(Scope.world, '2026-11-24');
    expect(world.top, isNotEmpty);
    expect(world.me, isNull); // not played yet
    expect((await social.feed('2026-11-24')).locked, isTrue);

    // Play late, then the feed unlocks and friends see the late score.
    await h.repo.startAttempt();
    await h.repo.submit(_result(daily.gameId, 123));
    expect((await social.feed('2026-11-24')).locked, isFalse);
    final friends = await social.leaderboard(Scope.friends, '2026-11-24');
    expect(friends.me!.onTime, isFalse);
    final worldAfter = await social.leaderboard(Scope.world, '2026-11-24');
    expect(worldAfter.me, isNull); // late: not in the world ranking

    await expectLater(
      social.sendRequest('nobody_here'),
      throwsA(isA<PseudoRejected>()),
    );
    final name = (await social.leaderboard(
      Scope.world,
      '2026-11-24',
    )).top.last.pseudo!;
    expect(await social.sendRequest(name), isTrue);

    await t.tap(find.text('Classements'));
    await settle(t);
    expect(find.text('Mode démo : joueurs simulés'), findsWidgets);
    await t.tap(find.byIcon(Icons.group_outlined));
    await settle(t);
    expect(find.text('Fil'), findsOneWidget);
    await unmount(t);
  });

  testWidgets('profile shows a generated avatar that can be re-rolled', (
    t,
  ) async {
    final h = await pumpApp(t, now: DateTime.utc(2026, 11, 24, 5));
    await t.tap(find.byIcon(Icons.person_outline));
    await settle(t);
    expect(find.byType(Avatar), findsOneWidget);
    final before = h.container.read(socialRepositoryProvider).avatar;
    await t.tap(find.text('🎲'));
    await settle(t);
    expect(h.container.read(socialRepositoryProvider).avatar, isNot(before));
    await unmount(t);
  });

  testWidgets('share card renders a 1080 × 1350 image', (t) async {
    await t.pumpWidget(
      MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => const Center(
            child: FittedBox(
              child: ShareCard(
                data: ShareCardData(
                  dayKey: '2026-11-24',
                  gameId: 'minigolf',
                  score: 1840,
                  shareLine: '⛳ 3 trous · 8 coups (-1)',
                  streak: 12,
                  highlights: ['ace'],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await t.pump();
    expect(find.text('1840'), findsOneWidget);
    final png = await t.runAsync(
      () => renderShareCard(
        t.element(find.byType(ShareCard)),
        const ShareCardData(
          dayKey: 'd',
          gameId: 'stack',
          score: 1,
          shareLine: 'x',
        ),
      ),
    );
    final codec = await t.runAsync(() => ui.instantiateImageCodec(png!));
    final frame = await t.runAsync(() => codec!.getNextFrame());
    expect(frame!.image.width, 1080);
    expect(frame.image.height, 1350);
  });
}

GameResult _result(String gameId, int score) => GameResult(
  gameId: gameId,
  seed: 1,
  modifierId: null,
  official: true,
  score: score,
  playedTime: const Duration(seconds: 30),
  stats: const {},
  inputLog: const [],
  highlights: const [],
  shareLine: '',
  timedOut: false,
);
