import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/backend/backend.dart';
import '../../core/l10n/l10n.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/time/regions.dart';
import '../../data/daily/models.dart';
import '../../games/game_registry.dart';
import '../home/today_controller.dart';
import 'badges.dart';

/// Official history for the calendar and per-game records.
final historyProvider = FutureProvider<List<DayRecord>>((ref) async {
  ref.watch(todayProvider); // refresh after each game
  return ref.watch(dailyRepositoryProvider).history();
});

/// Profile (section 9.8): streak, GitHub-like calendar, records, badges.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final profile =
        ref.watch(todayProvider).value?.profile ?? const ProfileSummary();
    final history = ref.watch(historyProvider).value ?? const [];
    final records = <String, int>{};
    for (final d in history) {
      if (d.gameId != null && d.score != null) {
        records[d.gameId!] = (records[d.gameId!] ?? 0) > d.score!
            ? records[d.gameId!]!
            : d.score!;
      }
    }
    return Scaffold(
      appBar: AppBar(title: Text(l10n.profileTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  label: l10n.profileStreak,
                  value: '🔥 ${profile.streak}',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatTile(
                  label: l10n.profileBest,
                  value: '🏆 ${profile.bestStreak}',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatTile(
                  label: l10n.homeJokers,
                  value: '🃏 ${profile.jokers}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(l10n.profileCalendar, style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          CalendarGrid(
            history: history,
            today:
                ref.read(todayProvider).value?.dayKey ??
                dayKeyFor(
                  DateTime.now(),
                  ref.read(dailyRepositoryProvider).region,
                ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              _Legend(color: AppColors.onTime, label: l10n.profileLegendOnTime),
              _Legend(color: AppColors.late, label: l10n.profileLegendLate),
              _Legend(color: AppColors.missed, label: l10n.profileLegendMissed),
              _Legend(
                color: const Color(0xFF3FA7FF),
                label: l10n.profileLegendSaved,
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(l10n.profileRecords, style: theme.textTheme.titleMedium),
          if (records.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(l10n.profileNoRecords),
            ),
          for (final e in records.entries)
            ListTile(
              dense: true,
              leading: Text(
                GameRegistry.byId(e.key)?.emoji ?? '🎮',
                style: const TextStyle(fontSize: 22),
              ),
              title: Text(GameRegistry.byId(e.key)?.name(l10n) ?? e.key),
              trailing: Text(
                '${e.value}',
                style: const TextStyle(
                  fontFamily: AppFonts.display,
                  fontFeatures: AppFonts.tabular,
                ),
              ),
            ),
          const SizedBox(height: 24),
          Text(l10n.profileBadges, style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final b in allBadges)
                Opacity(
                  opacity: profile.badges.contains(b) ? 1 : 0.3,
                  child: Chip(
                    avatar: Text(badgeEmoji(b)),
                    label: Text(badgeName(l10n, b)),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(fontFamily: AppFonts.display, fontSize: 22),
          ),
          Text(label, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(3),
        ),
      ),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(fontSize: 12)),
    ],
  );
}

/// GitHub-like grid: one column per week, Monday at the top.
class CalendarGrid extends StatelessWidget {
  const CalendarGrid({
    super.key,
    required this.history,
    required this.today,
    this.weeks = 16,
  });

  final List<DayRecord> history;
  final String today;
  final int weeks;

  @override
  Widget build(BuildContext context) {
    final byDay = {for (final d in history) d.dayKey: d};
    final todayDow = (dayOfWeek(today) + 6) % 7; // Monday = 0
    final start = addDays(today, -(weeks - 1) * 7 - todayDow);
    final empty = Theme.of(context).colorScheme.surfaceContainerHighest;
    return LayoutBuilder(
      builder: (context, c) {
        final cell = ((c.maxWidth - (weeks - 1) * 3) / weeks).clamp(8.0, 20.0);
        return Row(
          children: [
            for (var w = 0; w < weeks; w++)
              Padding(
                padding: EdgeInsets.only(right: w == weeks - 1 ? 0 : 3),
                child: Column(
                  children: [
                    for (var d = 0; d < 7; d++)
                      Builder(
                        builder: (context) {
                          final key = addDays(start, w * 7 + d);
                          final rec = byDay[key];
                          final future = key.compareTo(today) > 0;
                          final color = future
                              ? Colors.transparent
                              : switch (rec?.status) {
                                  DayStatus.onTime => AppColors.onTime,
                                  DayStatus.late => AppColors.late,
                                  DayStatus.saved => const Color(0xFF3FA7FF),
                                  DayStatus.missed => AppColors.missed,
                                  null => empty,
                                };
                          return Tooltip(
                            message: rec?.score == null
                                ? key
                                : '$key · ${rec!.score}',
                            child: Container(
                              width: cell,
                              height: cell,
                              margin: const EdgeInsets.only(bottom: 3),
                              decoration: BoxDecoration(
                                color: color,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}
