import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/backend/backend.dart';
import '../../core/l10n/l10n.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/time/regions.dart';
import '../../data/social/models.dart';
import '../home/today_controller.dart';

String currentDayKey(WidgetRef ref) =>
    ref.read(todayProvider).value?.dayKey ??
    dayKeyFor(DateTime.now(), ref.read(dailyRepositoryProvider).region);

final boardProvider = FutureProvider.family<Board, (Scope, String)>((ref, key) {
  ref.watch(todayProvider); // refresh after playing
  return ref.watch(socialRepositoryProvider).leaderboard(key.$1, key.$2);
});

String scopeLabel(AppLocalizations l, Scope s) => switch (s) {
  Scope.friends => l.lbFriends,
  Scope.country => l.lbCountry,
  Scope.region => l.lbRegion,
  Scope.world => l.lbWorld,
  Scope.weekly => l.lbWeekly,
  Scope.language => l.lbLanguage,
};

/// Leaderboards (section 9.5): friends / country / region / world for
/// today, plus weekly. Top 100 + your position.
class LeaderboardScreen extends ConsumerWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final dayKey = currentDayKey(ref);
    // The per-language board only makes sense for Mot éclair (section 7.22).
    final scopes = [
      ...Scope.values.where((s) => s != Scope.language),
      if (ref.watch(todayProvider).value?.gameId == 'motflash') Scope.language,
    ];
    return DefaultTabController(
      length: scopes.length,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.lbTitle),
          bottom: TabBar(
            isScrollable: true,
            tabs: [for (final s in scopes) Tab(text: scopeLabel(l10n, s))],
          ),
        ),
        body: TabBarView(
          children: [
            for (final s in scopes) _BoardView(scope: s, dayKey: dayKey),
          ],
        ),
      ),
    );
  }
}

class _BoardView extends ConsumerWidget {
  const _BoardView({required this.scope, required this.dayKey});

  final Scope scope;
  final String dayKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final async = ref.watch(boardProvider((scope, dayKey)));
    final demo = ref.watch(socialRepositoryProvider).isDemo;
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => Center(child: Text(l10n.homeError)),
      data: (board) => RefreshIndicator(
        onRefresh: () => ref.refresh(boardProvider((scope, dayKey)).future),
        child: ListView(
          children: [
            if (demo)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  l10n.lbDemo,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontStyle: FontStyle.italic),
                ),
              ),
            if (scope == Scope.weekly)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(l10n.lbWeeklyHelp, textAlign: TextAlign.center),
              ),
            if (board.me != null)
              Card(
                color: AppColors.yellow,
                margin: const EdgeInsets.all(12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      Text(
                        l10n.lbYourRank(board.me!.rank, board.total),
                        style: const TextStyle(
                          color: AppColors.night,
                          fontFamily: AppFonts.display,
                          fontSize: 18,
                        ),
                      ),
                      if (board.percentile != null)
                        Text(
                          l10n.lbPercentile(board.percentile!),
                          style: const TextStyle(color: AppColors.night),
                        ),
                    ],
                  ),
                ),
              ),
            if (board.top.isEmpty)
              Padding(
                padding: const EdgeInsets.all(32),
                child: Text(l10n.lbEmpty, textAlign: TextAlign.center),
              ),
            for (final r in board.top)
              _Row(row: r, scope: scope, dayKey: dayKey),
          ],
        ),
      ),
    );
  }
}

class _Row extends ConsumerWidget {
  const _Row({required this.row, required this.scope, required this.dayKey});

  final BoardRow row;
  final Scope scope;
  final String dayKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final medal = switch (row.rank) {
      1 => '🥇',
      2 => '🥈',
      3 => '🥉',
      _ => '${row.rank}',
    };
    return ListTile(
      tileColor: row.isMe ? AppColors.yellow.withValues(alpha: 0.25) : null,
      leading: SizedBox(
        width: 40,
        child: Center(
          child: Text(
            medal,
            style: const TextStyle(
              fontFamily: AppFonts.display,
              fontFeatures: AppFonts.tabular,
            ),
          ),
        ),
      ),
      title: Text(
        row.isMe ? '${row.pseudo ?? '?'} (${l10n.lbYou})' : row.pseudo ?? '?',
      ),
      subtitle: !row.onTime
          ? Text(l10n.lbLate, style: const TextStyle(color: AppColors.late))
          : (row.country != null ? Text(row.country!) : null),
      trailing: Text(
        '${row.score}',
        style: const TextStyle(
          fontFamily: AppFonts.display,
          fontSize: 18,
          fontFeatures: AppFonts.tabular,
        ),
      ),
      onLongPress: row.isMe
          ? null
          : () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (c) => AlertDialog(
                  title: Text(l10n.lbReport),
                  content: Text('${row.pseudo} · ${row.score}'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(c, false),
                      child: Text(l10n.commonCancel),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(c, true),
                      child: Text(l10n.lbReport),
                    ),
                  ],
                ),
              );
              if (ok ?? false) {
                unawaited(
                  ref.read(socialRepositoryProvider).report(dayKey, row.uid),
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text(l10n.lbReported)));
                }
              }
            },
    );
  }
}
