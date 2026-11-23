import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/router.dart';
import '../../core/l10n/l10n.dart';
import '../../core/widgets/alarm_clock.dart';

/// Home screen. Phase 0 only shows the `waiting` state; the five day states
/// (section 4.4) arrive in Phase 3.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l10n.appTitle, style: theme.textTheme.displaySmall),
                const SizedBox(height: 4),
                Text(l10n.tagline, textAlign: TextAlign.center),
                const SizedBox(height: 32),
                AlarmClock(semanticLabel: l10n.alarmClockSemantics),
                const SizedBox(height: 32),
                Text(
                  l10n.homeWaitingTitle,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(l10n.homeWaitingBody, textAlign: TextAlign.center),
                const SizedBox(height: 32),
                FilledButton.icon(
                  onPressed: () => context.push(Routes.training),
                  icon: const Icon(Icons.sports_esports),
                  label: Text(l10n.homeTraining),
                ),
                if (kDebugMode) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => context.push(Routes.gameLab),
                    icon: const Icon(Icons.science_outlined),
                    label: Text(l10n.homeGameLab),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
