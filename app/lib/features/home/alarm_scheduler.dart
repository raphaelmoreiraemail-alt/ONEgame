import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/backend/backend.dart';
import '../../core/l10n/l10n.dart';
import '../../core/notifications/alarm_notifications.dart';
import '../../games/common/game_strings.dart';
import '../../games/game_registry.dart';
import 'today_controller.dart';

/// Keeps the alarm notifications up to date: local schedule in local mode,
/// FCM topic subscription with Firebase.
class AlarmScheduler extends ConsumerStatefulWidget {
  const AlarmScheduler({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AlarmScheduler> createState() => _AlarmSchedulerState();
}

class _AlarmSchedulerState extends ConsumerState<AlarmScheduler> {
  String? _lastKey;

  Future<void> _sync() async {
    final l10n = context.l10n;
    final lang = Localizations.localeOf(context).languageCode;
    final backend = ref.read(backendProvider);
    final repo = backend.daily;
    final n = ref.read(alarmNotificationsProvider);
    final key =
        '${repo.region.name}/$lang/${ref.read(todayProvider).value?.dayKey}';
    if (key == _lastKey) return;
    _lastKey = key;
    await n.init(channelName: l10n.notifChannel);
    if (backend.usesFirebase) {
      await n.subscribe(
        repo.region,
        lang == 'en' ? 'en' : 'fr',
        () => ref.read(todayProvider.notifier).refresh(),
      );
      return;
    }
    final alerts = await repo.upcomingAlerts();
    await n.scheduleLocal([
      for (final (at, gameId, modifier) in alerts)
        (
          at,
          l10n.notifTitle,
          l10n.notifBody(
            '${GameRegistry.byId(gameId)?.name(l10n) ?? gameId}'
            '${modifier == null ? '' : ' · ${GameStrings.modifierName(l10n, modifier)}'}',
          ),
        ),
    ], channelName: l10n.notifChannel);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(todayProvider, (_, next) {
      if (next.hasValue) unawaited(_sync());
    });
    return widget.child;
  }
}
