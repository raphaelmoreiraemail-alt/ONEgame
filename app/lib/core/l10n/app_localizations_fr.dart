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

  @override
  String get playGo => 'GO !';

  @override
  String get playEnd => 'FIN';

  @override
  String get playOfficial => 'Partie officielle · une seule tentative';

  @override
  String get playTraining => 'Entraînement · ne compte pas';

  @override
  String get playQuit => 'Quitter';

  @override
  String get playTimeLeft => 'Temps restant';

  @override
  String get playScore => 'Score';

  @override
  String get resultsTitle => 'Résultats';

  @override
  String get resultsShare => 'Partager';

  @override
  String get resultsCopy => 'Copier le texte';

  @override
  String get resultsCopied => 'Copié !';

  @override
  String get resultsHome => 'Accueil';

  @override
  String get resultsReplay => 'Rejouer';

  @override
  String get resultsHighlights => 'Coups d\'éclat';

  @override
  String get resultsTimeUp => 'Temps écoulé';

  @override
  String get resultsDuration => 'Durée';

  @override
  String get resultsTrainingNote =>
      'Score d\'entraînement : il ne compte pas dans les classements.';

  @override
  String get gameLabGame => 'Jeu';

  @override
  String get gameLabSeed => 'Seed';

  @override
  String get gameLabModifier => 'Modificateur';

  @override
  String get gameLabNone => 'Aucun';

  @override
  String get gameLabPlay => 'Lancer';

  @override
  String get gameLabNext => 'Niveau suivant';

  @override
  String get gameLabRandom => 'Seed aléatoire';

  @override
  String gameLabFingerprint(Object value) {
    return 'Empreinte du niveau : $value';
  }

  @override
  String get gameLabDebug => 'Afficher FPS et corps physiques';

  @override
  String get trainingSubtitle =>
      'Rejoue les jeux déjà sortis avec un niveau aléatoire. Ça ne compte jamais.';

  @override
  String get modifierWind => 'Jour de vent';

  @override
  String get modifierNight => 'Nuit';

  @override
  String get modifierTurbo => 'Turbo';

  @override
  String get modifierMirror => 'Miroir';

  @override
  String get modifierIce => 'Glace';

  @override
  String get modifierGiant => 'Géant';

  @override
  String get modifierWindDesc => 'Le vent dévie tes tirs.';

  @override
  String get modifierNightDesc => 'Tu ne vois qu\'autour de toi.';

  @override
  String get modifierTurboDesc => 'Tout va 25 % plus vite.';

  @override
  String get modifierMirrorDesc => 'Contrôles inversés gauche / droite.';

  @override
  String get modifierIceDesc => 'Ça glisse deux fois plus.';

  @override
  String get modifierGiantDesc => 'Cibles plus grandes, adversaire plus fort.';

  @override
  String get categorySport => 'Sport';

  @override
  String get categoryAdresse => 'Adresse';

  @override
  String get categoryArcade => 'Arcade';

  @override
  String get categoryReflexion => 'Réflexion';

  @override
  String get highlightSurvivor => 'SURVIVANT !';

  @override
  String get gameSurvivalName => 'Survie 2:00';

  @override
  String get gameSurvivalRule =>
      'Glisse pour esquiver les blocs. Tiens 2 minutes !';

  @override
  String gameSurvivalShare(Object orbs, Object seconds) {
    return '☄️ $seconds s · $orbs orbes';
  }

  @override
  String get statSeconds => 'Secondes survécues';

  @override
  String get statOrbs => 'Orbes';
}
