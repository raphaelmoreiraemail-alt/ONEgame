import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/locale_controller.dart';
import '../../core/backend/backend.dart';
import '../../core/l10n/l10n.dart';
import '../../core/notifications/alarm_notifications.dart';
import '../../core/settings/settings.dart';
import '../../core/time/regions.dart';
import '../../data/daily/daily_repository.dart';
import '../home/today_controller.dart';

String regionName(AppLocalizations l, Region r) => switch (r) {
  Region.europe => l.regionEurope,
  Region.americas => l.regionAmericas,
  Region.asia => l.regionAsia,
  Region.west => l.regionWest,
};

/// Settings (section 9.10). Account linking / deletion arrive in Phase 4.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final settings = ref.watch(settingsProvider);
    final ctrl = ref.read(settingsProvider.notifier);
    final current = ref.watch(localeProvider)?.languageCode;
    final repo = ref.watch(dailyRepositoryProvider);
    ref.watch(todayProvider);
    final changed = repo.regionChangedAt;
    final cooldownUntil = changed?.add(const Duration(days: 30));
    final locked =
        cooldownUntil != null && cooldownUntil.isAfter(DateTime.now().toUtc());
    final options = <(String?, String)>[
      (null, l10n.languageSystem),
      ('fr', l10n.languageFrench),
      ('en', l10n.languageEnglish),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ListView(
        children: [
          ListTile(title: Text(l10n.settingsLanguage)),
          RadioGroup<String?>(
            groupValue: current,
            onChanged: (code) => ref
                .read(localeProvider.notifier)
                .set(code == null ? null : Locale(code)),
            child: Column(
              children: [
                for (final (code, label) in options)
                  RadioListTile<String?>(value: code, title: Text(label)),
              ],
            ),
          ),
          const Divider(),
          ListTile(
            title: Text(l10n.settingsRegion),
            subtitle: Text(
              locked
                  ? l10n.settingsRegionCooldown(
                      MaterialLocalizations.of(context)
                          .formatMediumDate(cooldownUntil.toLocal()),
                    )
                  : l10n.settingsRegionHelp,
            ),
          ),
          RadioGroup<Region>(
            groupValue: repo.region,
            onChanged: (r) async {
              if (r == null || locked) return;
              try {
                await repo.setRegion(r);
              } on RegionCooldown {
                // Shown by the subtitle.
              }
              unawaited(ref.read(todayProvider.notifier).refresh());
            },
            child: Column(
              children: [
                for (final r in Region.values)
                  RadioListTile<Region>(
                    value: r,
                    enabled: !locked || r == repo.region,
                    title: Text(regionName(l10n, r)),
                  ),
              ],
            ),
          ),
          const Divider(),
          SwitchListTile(
            value: settings.sound,
            onChanged: ctrl.setSound,
            title: Text(l10n.settingsSound),
          ),
          SwitchListTile(
            value: settings.haptics,
            onChanged: ctrl.setHaptics,
            title: Text(l10n.settingsHaptics),
          ),
          SwitchListTile(
            value: settings.reduceMotion,
            onChanged: ctrl.setReduceMotion,
            title: Text(l10n.settingsReduceMotion),
          ),
          ListTile(
            leading: const Icon(Icons.notifications_active_outlined),
            title: Text(l10n.settingsNotifications),
            onTap: () =>
                ref.read(alarmNotificationsProvider).requestPermission(),
          ),
          ListTile(
            dense: true,
            title: Text(
              l10n.settingsBackend(ref.watch(backendProvider).kind.name),
            ),
          ),
        ],
      ),
    );
  }
}
