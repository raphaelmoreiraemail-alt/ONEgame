import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/locale_controller.dart';
import '../../core/backend/account.dart';
import '../../core/backend/backend.dart';
import '../../core/l10n/l10n.dart';
import '../../core/notifications/alarm_notifications.dart';
import '../../core/settings/settings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/time/regions.dart';
import '../../data/daily/daily_repository.dart';
import '../home/today_controller.dart';
import '../onboarding/onboarding_screen.dart';
import '../onboarding/pseudo_field.dart';

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
          const Divider(),
          const _AccountSection(),
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

class _AccountSection extends ConsumerWidget {
  const _AccountSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final account = ref.read(accountServiceProvider);
    final pseudo = ref.watch(socialRepositoryProvider).pseudo;
    void toast(String m) =>
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

    Future<void> run(Future<void> Function() f) async {
      try {
        await f();
        toast(l10n.accountLinked);
      } on Object {
        toast(l10n.commonError);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          title: Text(l10n.accountTitle),
          subtitle: Text(l10n.accountLinkHelp),
        ),
        ListTile(
          leading: const Icon(Icons.badge_outlined),
          title: Text(l10n.accountPseudo),
          subtitle: Text(pseudo ?? '—'),
          trailing: const Icon(Icons.edit),
          onTap: () => showDialog<void>(
            context: context,
            builder: (c) => AlertDialog(
              title: Text(l10n.accountChangePseudo),
              content: PseudoField(onSaved: (_) => Navigator.pop(c)),
            ),
          ),
        ),
        if (!account.canLink)
          ListTile(dense: true, title: Text(l10n.accountLocalOnly))
        else ...[
          ListTile(
            leading: const Icon(Icons.g_mobiledata),
            title: Text(l10n.accountLinkGoogle),
            onTap: () => run(account.linkGoogle),
          ),
          if (Theme.of(context).platform == TargetPlatform.iOS)
            ListTile(
              leading: const Icon(Icons.apple),
              title: Text(l10n.accountLinkApple),
              onTap: () => run(account.linkApple),
            ),
          ListTile(
            leading: const Icon(Icons.alternate_email),
            title: Text(l10n.accountLinkEmail),
            onTap: () async {
              final email = TextEditingController();
              final pwd = TextEditingController();
              final ok = await showDialog<bool>(
                context: context,
                builder: (c) => AlertDialog(
                  title: Text(l10n.accountLinkEmail),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: email,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: l10n.accountEmail,
                        ),
                      ),
                      TextField(
                        controller: pwd,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: l10n.accountPassword,
                        ),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(c, false),
                      child: Text(l10n.commonCancel),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(c, true),
                      child: Text(l10n.commonOk),
                    ),
                  ],
                ),
              );
              final e = email.text.trim();
              final p = pwd.text;
              email.dispose();
              pwd.dispose();
              if (ok ?? false) await run(() => account.linkEmail(e, p));
            },
          ),
        ],
        ListTile(
          leading: const Icon(Icons.delete_forever, color: AppColors.alarmRed),
          title: Text(
            l10n.accountDelete,
            style: const TextStyle(color: AppColors.alarmRed),
          ),
          onTap: () async {
            final ok = await showDialog<bool>(
              context: context,
              builder: (c) => AlertDialog(
                title: Text(l10n.accountDelete),
                content: Text(l10n.accountDeleteConfirm),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(c, false),
                    child: Text(l10n.commonCancel),
                  ),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.alarmRed,
                    ),
                    onPressed: () => Navigator.pop(c, true),
                    child: Text(l10n.accountDelete),
                  ),
                ],
              ),
            );
            if (ok != true) return;
            try {
              await account.deleteAccount();
              toast(l10n.accountDeleted);
              ref.invalidate(onboardingDoneProvider);
            } on Object {
              toast(l10n.commonError);
            }
          },
        ),
      ],
    );
  }
}
