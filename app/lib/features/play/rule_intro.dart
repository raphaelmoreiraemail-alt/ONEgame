import 'package:material_ui/material_ui.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../games/common/game_strings.dart';
import '../../games/common/mini_game_definition.dart';

/// "Rule in one sentence" + 3, 2, 1 countdown (section 5.2 step 1).
class RuleIntro extends StatelessWidget {
  const RuleIntro({
    super.key,
    required this.def,
    required this.count,
    required this.official,
    this.modifierId,
  });

  final MiniGameDefinition def;

  /// 3, 2, 1, then 0 = GO.
  final int count;
  final bool official;
  final String? modifierId;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return ColoredBox(
      color: AppColors.night,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Text(
                official ? l10n.playOfficial : l10n.playTraining,
                style: const TextStyle(color: AppColors.yellow),
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              Text(def.emoji, style: const TextStyle(fontSize: 88)),
              const SizedBox(height: 12),
              Text(
                def.name(l10n),
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: AppColors.bone,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                def.rule(l10n),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.bone,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (modifierId != null) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.yellow,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '${GameStrings.modifierEmoji(modifierId!)} '
                    '${GameStrings.modifierName(l10n, modifierId!)} · '
                    '${GameStrings.modifierDescription(l10n, modifierId!)}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.night,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              Text(
                count > 0 ? '$count' : l10n.playGo,
                key: ValueKey(count),
                style: const TextStyle(
                  fontFamily: AppFonts.display,
                  fontSize: 96,
                  color: AppColors.alarmRed,
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
