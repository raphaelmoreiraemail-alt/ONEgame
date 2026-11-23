import 'package:cupertino_ui/cupertino_ui.dart'
    show GlobalCupertinoLocalizations;
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart'
    show GlobalWidgetsLocalizations;
import 'package:material_ui/material_ui.dart' show GlobalMaterialLocalizations;

import 'app_localizations.dart';

export 'app_localizations.dart';

/// Delegates to use instead of the generated
/// `AppLocalizations.localizationsDelegates`, which still points at the
/// deprecated `flutter_localizations` Material / Cupertino classes.
const List<LocalizationsDelegate<dynamic>> appLocalizationsDelegates = [
  AppLocalizations.delegate,
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

extension L10nX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
