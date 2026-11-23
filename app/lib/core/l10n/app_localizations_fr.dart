// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'OneGame';

  @override
  String get tagline => 'Une alarme. Deux minutes. Un jeu.';

  @override
  String get navHome => 'Accueil';

  @override
  String get navLeaderboard => 'Classements';

  @override
  String get navProfile => 'Profil';

  @override
  String get navSettings => 'Réglages';

  @override
  String get homeWaitingTitle => 'L\'alarme n\'a pas encore sonné.';

  @override
  String get homeWaitingBody => 'Elle tombera entre 10h et 21h.';

  @override
  String get homeTraining => 'Entraînement';

  @override
  String get homeGameLab => 'Game Lab';

  @override
  String get trainingTitle => 'Entraînement';

  @override
  String get gameLabTitle => 'Game Lab';

  @override
  String get leaderboardTitle => 'Classements';

  @override
  String get profileTitle => 'Profil';

  @override
  String get settingsTitle => 'Réglages';

  @override
  String get comingSoon => 'Bientôt disponible';

  @override
  String get settingsLanguage => 'Langue';

  @override
  String get languageSystem => 'Langue du système';

  @override
  String get languageFrench => 'Français';

  @override
  String get languageEnglish => 'English';

  @override
  String get alarmClockSemantics => 'Réveil OneGame';
}
