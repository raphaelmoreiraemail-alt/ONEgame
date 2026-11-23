import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/locale_controller.dart';
import '../../core/l10n/l10n.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final current = ref.watch(localeProvider)?.languageCode;
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
        ],
      ),
    );
  }
}
