import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme/app_colors.dart';
import '../../games/common/game_types.dart';
import '../home/today_controller.dart';
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
