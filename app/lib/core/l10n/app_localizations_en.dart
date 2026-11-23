// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'OneGame';

  @override
  String get tagline => 'One alarm. Two minutes. One game.';

  @override
  String get navHome => 'Home';

  @override
  String get navLeaderboard => 'Leaderboards';

  @override
  String get navProfile => 'Profile';

  @override
  String get navSettings => 'Settings';

  @override
  String get homeWaitingTitle => 'The alarm hasn\'t rung yet.';

  @override
  String get homeWaitingBody => 'It will ring between 10 AM and 9 PM.';

  @override
  String get homeTraining => 'Training';

  @override
  String get homeGameLab => 'Game Lab';

  @override
  String get trainingTitle => 'Training';

  @override
  String get gameLabTitle => 'Game Lab';

  @override
  String get leaderboardTitle => 'Leaderboards';

  @override
  String get profileTitle => 'Profile';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get comingSoon => 'Coming soon';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get languageSystem => 'System language';

  @override
  String get languageFrench => 'Français';

  @override
  String get languageEnglish => 'English';

  @override
  String get alarmClockSemantics => 'OneGame alarm clock';
}
