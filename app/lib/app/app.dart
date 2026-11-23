import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../core/l10n/l10n.dart';
import '../core/theme/app_theme.dart';
import '../features/home/alarm_scheduler.dart';
import 'locale_controller.dart';
import 'router.dart';

class OneGameApp extends ConsumerWidget {
  const OneGameApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      onGenerateTitle: (context) => context.l10n.appTitle,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      locale: ref.watch(localeProvider),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: appLocalizationsDelegates,
      routerConfig: ref.watch(routerProvider),
      builder: (context, child) => AlarmScheduler(child: child!),
    );
  }
}
