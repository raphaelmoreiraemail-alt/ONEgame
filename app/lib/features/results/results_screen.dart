import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/router.dart';
import '../../core/l10n/l10n.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../games/common/game_strings.dart';
import '../../games/common/game_types.dart';
import '../../games/game_registry.dart';
import '../play/hud.dart';
import '../play/play_request.dart';
import '../share/share_card.dart';

/// Results (section 9.4): giant score, stats, highlights, share.
///
/// Rank among friends / world percentile and the image share card are added
/// with the daily and social features (Phases 3 and 4) through [extra].
class ResultsScreen extends StatelessWidget {
  const ResultsScreen({
    super.key,
    required this.request,
    required this.result,
    this.extra,
  });

  final PlayRequest request;
  final GameResult result;

  /// Slot for rank / share card widgets.
  final Widget? extra;

  String _shareText(AppLocalizations l10n) {
    final def = GameRegistry.byId(result.gameId)!;
    final lines = [
      'OneGame${request.dayKey != null ? ' · ${request.dayKey}' : ''}',
      '${def.emoji} ${def.name(l10n)} · ${result.score}',
      result.shareLine,
    ];
    return lines.join('\n');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final def = GameRegistry.byId(result.gameId)!;
    final rows = def.statRows(l10n, result.stats);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.resultsTitle),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Center(
              child: Text(
                '${def.emoji} ${def.name(l10n)}',
                style: theme.textTheme.titleLarge,
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: result.score.toDouble()),
                duration: Duration(
                  milliseconds: math.min(1200, 300 + result.score ~/ 4),
                ),
                builder: (context, v, _) => Text(
                  '${v.round()}',
                  semanticsLabel: '${l10n.playScore} ${result.score}',
                  style: const TextStyle(
                    fontFamily: AppFonts.display,
                    fontSize: 72,
                    color: AppColors.alarmRed,
                    fontFeatures: AppFonts.tabular,
                  ),
                ),
              ),
            ),
            if (!request.official)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  l10n.resultsTrainingNote,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ?extra,
            if (result.highlights.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(l10n.resultsHighlights, style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final h in result.highlights.toSet())
                    Chip(
                      backgroundColor: AppColors.yellow,
                      label: Text(
                        '${GameStrings.highlight(l10n, h)}'
                        '${result.highlights.where((x) => x == h).length > 1 ? ' ×${result.highlights.where((x) => x == h).length}' : ''}',
                        style: const TextStyle(color: AppColors.night),
                      ),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Card(
              child: Column(
                children: [
                  for (final (label, value) in rows)
                    ListTile(
                      dense: true,
                      title: Text(label),
                      trailing: Text(
                        value,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontFeatures: AppFonts.tabular,
                        ),
                      ),
                    ),
                  ListTile(
                    dense: true,
                    title: Text(l10n.resultsDuration),
                    trailing: Text(
                      result.timedOut
                          ? l10n.resultsTimeUp
                          : formatClock(result.playedTime.inSeconds),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: SelectableText(_shareText(l10n)),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: () => shareResult(
                context,
                ShareCardData(
                  dayKey: request.dayKey ?? '',
                  gameId: result.gameId,
                  score: result.score,
                  shareLine: result.shareLine,
                  modifierId: result.modifierId,
                  highlights: result.highlights,
                ),
                _shareText(l10n),
              ),
              icon: const Icon(Icons.image_outlined),
              label: Text(l10n.shareImage),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () {
                unawaited(
                  Clipboard.setData(ClipboardData(text: _shareText(l10n))),
                );
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text(l10n.resultsCopied)));
              },
              icon: const Icon(Icons.copy),
              label: Text(l10n.resultsCopy),
            ),
            const SizedBox(height: 16),
            if (!request.official)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: FilledButton.icon(
                  onPressed: () => context.pushReplacement(
                    Routes.play,
                    extra: PlayRequest(
                      gameId: request.gameId,
                      seed: request.debug
                          ? request.seed
                          : math.Random().nextInt(0x7FFFFFFF),
                      modifierId: request.modifierId,
                      debug: request.debug,
                    ),
                  ),
                  icon: const Icon(Icons.replay),
                  label: Text(l10n.resultsReplay),
                ),
              ),
            FilledButton.tonal(
              onPressed: () => context.go(Routes.home),
              child: Text(l10n.resultsHome),
            ),
          ],
        ),
      ),
    );
  }
}
