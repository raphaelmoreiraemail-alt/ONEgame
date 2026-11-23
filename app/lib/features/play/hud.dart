import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../games/common/game_strings.dart';

String formatClock(int seconds) =>
    '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';

/// Common HUD (section 5.2): remaining time, current score, modifier icon.
class GameHud extends StatelessWidget {
  const GameHud({
    super.key,
    required this.remaining,
    required this.score,
    this.modifierId,
    this.onQuit,
  });

  final ValueListenable<int> remaining;
  final ValueListenable<int> score;
  final String? modifierId;
  final VoidCallback? onQuit;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        child: Row(
          children: [
            ValueListenableBuilder<int>(
              valueListenable: remaining,
              builder: (context, s, _) => Semantics(
                label: l10n.playTimeLeft,
                value: formatClock(s),
                child: _Pill(
                  color: s <= 10 ? AppColors.alarmRed : AppColors.night,
                  child: Text(
                    formatClock(s),
                    style: const TextStyle(
                      fontFamily: AppFonts.display,
                      fontSize: 22,
                      color: Colors.white,
                      fontFeatures: AppFonts.tabular,
                    ),
                  ),
                ),
              ),
            ),
            const Spacer(),
            ValueListenableBuilder<int>(
              valueListenable: score,
              builder: (context, v, _) => Semantics(
                label: l10n.playScore,
                value: '$v',
                child: Text(
                  '$v',
                  style: const TextStyle(
                    fontFamily: AppFonts.display,
                    fontSize: 30,
                    color: AppColors.yellow,
                    fontFeatures: AppFonts.tabular,
                    shadows: [Shadow(blurRadius: 6, color: Colors.black)],
                  ),
                ),
              ),
            ),
            const Spacer(),
            if (modifierId != null)
              Tooltip(
                message: GameStrings.modifierName(l10n, modifierId!),
                child: _Pill(
                  color: AppColors.night,
                  child: Text(
                    GameStrings.modifierEmoji(modifierId!),
                    style: const TextStyle(fontSize: 20),
                  ),
                ),
              ),
            if (onQuit != null)
              IconButton(
                tooltip: l10n.playQuit,
                onPressed: onQuit,
                icon: const Icon(Icons.close, color: Colors.white),
                iconSize: 28,
              ),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.color, required this.child});

  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.85),
      borderRadius: BorderRadius.circular(22),
    ),
    // Center with factors 1: never expand to the available height.
    child: Center(widthFactor: 1, heightFactor: 1, child: child),
  );
}
