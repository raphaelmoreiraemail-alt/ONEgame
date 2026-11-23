import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/router.dart';
import '../../core/backend/backend.dart';
import '../../core/l10n/l10n.dart';
import '../../core/notifications/alarm_notifications.dart';
import '../../core/settings/settings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/alarm_clock.dart';
import '../../data/social/social_repository.dart';
import 'pseudo_field.dart';

const onboardingDoneKey = 'onboarding.done';

class OnboardingDone extends Notifier<bool> {
  @override
  bool build() =>
      ref.read(sharedPrefsProvider).getBool(onboardingDoneKey) ?? false;

  Future<void> complete() async {
    state = true;
    await ref.read(sharedPrefsProvider).setBool(onboardingDoneKey, true);
  }
}

final onboardingDoneProvider = NotifierProvider<OnboardingDone, bool>(
  OnboardingDone.new,
);

/// Onboarding (section 9.1): concept, notification permission, pseudo.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pages = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _next() => _pages.nextPage(
    duration: const Duration(milliseconds: 300),
    curve: Curves.easeOut,
  );

  Future<void> _finish() async {
    await ref.read(onboardingDoneProvider.notifier).complete();
    if (mounted) context.go(Routes.home);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    Widget page({
      required Widget top,
      required String title,
      required String body,
      required Widget action,
    }) => Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        children: [
          const Spacer(),
          top,
          const SizedBox(height: 32),
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          Text(
            body,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge,
          ),
          const Spacer(),
          action,
        ],
      ),
    );

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pages,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (p) => setState(() => _page = p),
                children: [
                  page(
                    top: AlarmClock(
                      semanticLabel: l10n.alarmClockSemantics,
                      size: 180,
                    ),
                    title: l10n.onbConceptTitle,
                    body: l10n.onbConceptBody,
                    action: FilledButton(
                      onPressed: _next,
                      child: Text(l10n.onbNext),
                    ),
                  ),
                  page(
                    top: const Text('⏰', style: TextStyle(fontSize: 96)),
                    title: l10n.onbNotifTitle,
                    body: l10n.onbNotifBody,
                    action: Column(
                      children: [
                        FilledButton(
                          onPressed: () async {
                            await ref
                                .read(alarmNotificationsProvider)
                                .requestPermission();
                            _next();
                          },
                          child: Text(l10n.onbNotifButton),
                        ),
                        TextButton(onPressed: _next, child: Text(l10n.onbSkip)),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      children: [
                        const Spacer(),
                        Text(
                          l10n.onbPseudoTitle,
                          style: theme.textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 24),
                        PseudoField(onSaved: (_) => unawaited(_finish())),
                        const Spacer(),
                        TextButton(
                          onPressed: _finish,
                          child: Text(l10n.onbSkip),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < 3; i++)
                    Container(
                      width: 10,
                      height: 10,
                      margin: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i == _page
                            ? AppColors.alarmRed
                            : AppColors.missed,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Error message for a rejected pseudo.
String pseudoError(AppLocalizations l10n, String reason) => switch (reason) {
  'length' => l10n.pseudoErrorLength,
  'charset' => l10n.pseudoErrorCharset,
  'offensive' => l10n.pseudoErrorOffensive,
  'taken' => l10n.pseudoErrorTaken,
  'not-found' => l10n.pseudoErrorNotFound,
  _ => l10n.commonError,
};

/// Saves a pseudo, mapping errors to messages.
Future<String?> savePseudo(
  WidgetRef ref,
  AppLocalizations l10n,
  String value,
) async {
  try {
    await ref.read(socialRepositoryProvider).claimPseudo(value.trim());
    return null;
  } on PseudoRejected catch (e) {
    return pseudoError(l10n, e.reason);
  } on Object {
    return l10n.commonError;
  }
}
