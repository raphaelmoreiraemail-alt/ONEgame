import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme/app_colors.dart';
import '../../data/social/models.dart';
import '../../games/common/game_types.dart';
import '../home/today_controller.dart';
import '../leaderboard/leaderboard_screen.dart';
import '../profile/badges.dart';

/// Streak and new badges after an official game.
class OfficialOutcomePanel extends ConsumerWidget {
  const OfficialOutcomePanel({super.key, required this.result});

  final GameResult result;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final out = ref.watch(lastOutcomeProvider);
    final today = ref.watch(todayProvider).value;
    final late = today?.attempt != null && !today!.attempt!.onTime;
    return Column(
      children: [
        if (late)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Chip(
              backgroundColor: AppColors.late,
              label: Text(
                l10n.resultsOfficialLate,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
        _Ranks(dayKey: today?.dayKey),
        if (out != null) ...[
          Text(
            l10n.resultsStreak(out.streak),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          if (out.newBadges.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(l10n.resultsNewBadges),
            Wrap(
              spacing: 8,
              children: [
                for (final b in out.newBadges)
                  Chip(
                    avatar: Text(badgeEmoji(b)),
                    label: Text(badgeName(l10n, b)),
                  ),
              ],
            ),
          ],
        ],
      ],
    );
  }
}

/// Position among friends and world percentile (section 9.4).
class _Ranks extends ConsumerWidget {
  const _Ranks({required this.dayKey});

  final String? dayKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    if (dayKey == null) return const SizedBox.shrink();
    final friends = ref.watch(boardProvider((Scope.friends, dayKey!))).value;
    final world = ref.watch(boardProvider((Scope.world, dayKey!))).value;
    return Column(
      children: [
        if (friends?.me != null)
          Text(l10n.resultsFriendsRank(friends!.me!.rank, friends.total)),
        if (world?.percentile != null)
          Text(l10n.lbPercentile(world!.percentile!)),
      ],
    );
  }
}
