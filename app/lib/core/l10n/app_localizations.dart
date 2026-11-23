import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('fr'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In fr, this message translates to:
  /// **'OneGame'**
  String get appTitle;

  /// Main slogan, shown on onboarding and home.
  ///
  /// In fr, this message translates to:
  /// **'Une alarme. Deux minutes. Un jeu.'**
  String get tagline;

  /// No description provided for @navHome.
  ///
  /// In fr, this message translates to:
  /// **'Accueil'**
  String get navHome;

  /// No description provided for @navLeaderboard.
  ///
  /// In fr, this message translates to:
  /// **'Classements'**
  String get navLeaderboard;

  /// No description provided for @navProfile.
  ///
  /// In fr, this message translates to:
  /// **'Profil'**
  String get navProfile;

  /// No description provided for @navSettings.
  ///
  /// In fr, this message translates to:
  /// **'Réglages'**
  String get navSettings;

  /// No description provided for @homeWaitingTitle.
  ///
  /// In fr, this message translates to:
  /// **'L\'alarme n\'a pas encore sonné.'**
  String get homeWaitingTitle;

  /// No description provided for @homeWaitingBody.
  ///
  /// In fr, this message translates to:
  /// **'Elle tombera entre 10h et 21h.'**
  String get homeWaitingBody;

  /// No description provided for @homeTraining.
  ///
  /// In fr, this message translates to:
  /// **'Entraînement'**
  String get homeTraining;

  /// No description provided for @homeGameLab.
  ///
  /// In fr, this message translates to:
  /// **'Game Lab'**
  String get homeGameLab;

  /// No description provided for @trainingTitle.
  ///
  /// In fr, this message translates to:
  /// **'Entraînement'**
  String get trainingTitle;

  /// No description provided for @gameLabTitle.
  ///
  /// In fr, this message translates to:
  /// **'Game Lab'**
  String get gameLabTitle;

  /// No description provided for @leaderboardTitle.
  ///
  /// In fr, this message translates to:
  /// **'Classements'**
  String get leaderboardTitle;

  /// No description provided for @profileTitle.
  ///
  /// In fr, this message translates to:
  /// **'Profil'**
  String get profileTitle;

  /// No description provided for @settingsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Réglages'**
  String get settingsTitle;

  /// No description provided for @comingSoon.
  ///
  /// In fr, this message translates to:
  /// **'Bientôt disponible'**
  String get comingSoon;

  /// No description provided for @settingsLanguage.
  ///
  /// In fr, this message translates to:
  /// **'Langue'**
  String get settingsLanguage;

  /// No description provided for @languageSystem.
  ///
  /// In fr, this message translates to:
  /// **'Langue du système'**
  String get languageSystem;

  /// No description provided for @languageFrench.
  ///
  /// In fr, this message translates to:
  /// **'Français'**
  String get languageFrench;

  /// No description provided for @languageEnglish.
  ///
  /// In fr, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// Accessibility label of the central alarm clock.
  ///
  /// In fr, this message translates to:
  /// **'Réveil OneGame'**
  String get alarmClockSemantics;

  /// No description provided for @playGo.
  ///
  /// In fr, this message translates to:
  /// **'GO !'**
  String get playGo;

  /// No description provided for @playEnd.
  ///
  /// In fr, this message translates to:
  /// **'FIN'**
  String get playEnd;

  /// No description provided for @playOfficial.
  ///
  /// In fr, this message translates to:
  /// **'Partie officielle · une seule tentative'**
  String get playOfficial;

  /// No description provided for @playTraining.
  ///
  /// In fr, this message translates to:
  /// **'Entraînement · ne compte pas'**
  String get playTraining;

  /// No description provided for @playQuit.
  ///
  /// In fr, this message translates to:
  /// **'Quitter'**
  String get playQuit;

  /// No description provided for @playTimeLeft.
  ///
  /// In fr, this message translates to:
  /// **'Temps restant'**
  String get playTimeLeft;

  /// No description provided for @playScore.
  ///
  /// In fr, this message translates to:
  /// **'Score'**
  String get playScore;

  /// No description provided for @resultsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Résultats'**
  String get resultsTitle;

  /// No description provided for @resultsShare.
  ///
  /// In fr, this message translates to:
  /// **'Partager'**
  String get resultsShare;

  /// No description provided for @resultsCopy.
  ///
  /// In fr, this message translates to:
  /// **'Copier le texte'**
  String get resultsCopy;

  /// No description provided for @resultsCopied.
  ///
  /// In fr, this message translates to:
  /// **'Copié !'**
  String get resultsCopied;

  /// No description provided for @resultsHome.
  ///
  /// In fr, this message translates to:
  /// **'Accueil'**
  String get resultsHome;

  /// No description provided for @resultsReplay.
  ///
  /// In fr, this message translates to:
  /// **'Rejouer'**
  String get resultsReplay;

  /// No description provided for @resultsHighlights.
  ///
  /// In fr, this message translates to:
  /// **'Coups d\'éclat'**
  String get resultsHighlights;

  /// No description provided for @resultsTimeUp.
  ///
  /// In fr, this message translates to:
  /// **'Temps écoulé'**
  String get resultsTimeUp;

  /// No description provided for @resultsDuration.
  ///
  /// In fr, this message translates to:
  /// **'Durée'**
  String get resultsDuration;

  /// No description provided for @resultsTrainingNote.
  ///
  /// In fr, this message translates to:
  /// **'Score d\'entraînement : il ne compte pas dans les classements.'**
  String get resultsTrainingNote;

  /// No description provided for @gameLabGame.
  ///
  /// In fr, this message translates to:
  /// **'Jeu'**
  String get gameLabGame;

  /// No description provided for @gameLabSeed.
  ///
  /// In fr, this message translates to:
  /// **'Seed'**
  String get gameLabSeed;

  /// No description provided for @gameLabModifier.
  ///
  /// In fr, this message translates to:
  /// **'Modificateur'**
  String get gameLabModifier;

  /// No description provided for @gameLabNone.
  ///
  /// In fr, this message translates to:
  /// **'Aucun'**
  String get gameLabNone;

  /// No description provided for @gameLabPlay.
  ///
  /// In fr, this message translates to:
  /// **'Lancer'**
  String get gameLabPlay;

  /// No description provided for @gameLabNext.
  ///
  /// In fr, this message translates to:
  /// **'Niveau suivant'**
  String get gameLabNext;

  /// No description provided for @gameLabRandom.
  ///
  /// In fr, this message translates to:
  /// **'Seed aléatoire'**
  String get gameLabRandom;

  /// No description provided for @gameLabFingerprint.
  ///
  /// In fr, this message translates to:
  /// **'Empreinte du niveau : {value}'**
  String gameLabFingerprint(Object value);

  /// No description provided for @gameLabDebug.
  ///
  /// In fr, this message translates to:
  /// **'Afficher FPS et corps physiques'**
  String get gameLabDebug;

  /// No description provided for @trainingSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Rejoue les jeux déjà sortis avec un niveau aléatoire. Ça ne compte jamais.'**
  String get trainingSubtitle;

  /// No description provided for @modifierWind.
  ///
  /// In fr, this message translates to:
  /// **'Jour de vent'**
  String get modifierWind;

  /// No description provided for @modifierNight.
  ///
  /// In fr, this message translates to:
  /// **'Nuit'**
  String get modifierNight;

  /// No description provided for @modifierTurbo.
  ///
  /// In fr, this message translates to:
  /// **'Turbo'**
  String get modifierTurbo;

  /// No description provided for @modifierMirror.
  ///
  /// In fr, this message translates to:
  /// **'Miroir'**
  String get modifierMirror;

  /// No description provided for @modifierIce.
  ///
  /// In fr, this message translates to:
  /// **'Glace'**
  String get modifierIce;

  /// No description provided for @modifierGiant.
  ///
  /// In fr, this message translates to:
  /// **'Géant'**
  String get modifierGiant;

  /// No description provided for @modifierWindDesc.
  ///
  /// In fr, this message translates to:
  /// **'Le vent dévie tes tirs.'**
  String get modifierWindDesc;

  /// No description provided for @modifierNightDesc.
  ///
  /// In fr, this message translates to:
  /// **'Tu ne vois qu\'autour de toi.'**
  String get modifierNightDesc;

  /// No description provided for @modifierTurboDesc.
  ///
  /// In fr, this message translates to:
  /// **'Tout va 25 % plus vite.'**
  String get modifierTurboDesc;

  /// No description provided for @modifierMirrorDesc.
  ///
  /// In fr, this message translates to:
  /// **'Contrôles inversés gauche / droite.'**
  String get modifierMirrorDesc;

  /// No description provided for @modifierIceDesc.
  ///
  /// In fr, this message translates to:
  /// **'Ça glisse deux fois plus.'**
  String get modifierIceDesc;

  /// No description provided for @modifierGiantDesc.
  ///
  /// In fr, this message translates to:
  /// **'Cibles plus grandes, adversaire plus fort.'**
  String get modifierGiantDesc;

  /// No description provided for @categorySport.
  ///
  /// In fr, this message translates to:
  /// **'Sport'**
  String get categorySport;

  /// No description provided for @categoryAdresse.
  ///
  /// In fr, this message translates to:
  /// **'Adresse'**
  String get categoryAdresse;

  /// No description provided for @categoryArcade.
  ///
  /// In fr, this message translates to:
  /// **'Arcade'**
  String get categoryArcade;

  /// No description provided for @categoryReflexion.
  ///
  /// In fr, this message translates to:
  /// **'Réflexion'**
  String get categoryReflexion;

  /// No description provided for @highlightSurvivor.
  ///
  /// In fr, this message translates to:
  /// **'SURVIVANT !'**
  String get highlightSurvivor;

  /// No description provided for @gameSurvivalName.
  ///
  /// In fr, this message translates to:
  /// **'Survie 2:00'**
  String get gameSurvivalName;

  /// No description provided for @gameSurvivalRule.
  ///
  /// In fr, this message translates to:
  /// **'Glisse pour esquiver les blocs. Tiens 2 minutes !'**
  String get gameSurvivalRule;

  /// No description provided for @gameSurvivalShare.
  ///
  /// In fr, this message translates to:
  /// **'☄️ {seconds} s · {orbs} orbes'**
  String gameSurvivalShare(Object orbs, Object seconds);

  /// No description provided for @statSeconds.
  ///
  /// In fr, this message translates to:
  /// **'Secondes survécues'**
  String get statSeconds;

  /// No description provided for @statOrbs.
  ///
  /// In fr, this message translates to:
  /// **'Orbes'**
  String get statOrbs;

  /// No description provided for @gameMinigolfName.
  ///
  /// In fr, this message translates to:
  /// **'Mini-Golf'**
  String get gameMinigolfName;

  /// No description provided for @gameMinigolfRule.
  ///
  /// In fr, this message translates to:
  /// **'Tire la balle en arrière comme un lance-pierre. 3 trous, 2 minutes.'**
  String get gameMinigolfRule;

  /// No description provided for @gameMinigolfShare.
  ///
  /// In fr, this message translates to:
  /// **'⛳ {holes} trous · {strokes} coups ({toPar})'**
  String gameMinigolfShare(Object holes, Object strokes, Object toPar);

  /// No description provided for @gameMinigolfShareAces.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 trou en un} other{{count} trous en un}}'**
  String gameMinigolfShareAces(int count);

  /// No description provided for @statHoles.
  ///
  /// In fr, this message translates to:
  /// **'Trous joués'**
  String get statHoles;

  /// No description provided for @statStrokes.
  ///
  /// In fr, this message translates to:
  /// **'Coups'**
  String get statStrokes;

  /// No description provided for @statToPar.
  ///
  /// In fr, this message translates to:
  /// **'Par rapport au par'**
  String get statToPar;

  /// No description provided for @statAces.
  ///
  /// In fr, this message translates to:
  /// **'Trous en un'**
  String get statAces;

  /// No description provided for @highlightAce.
  ///
  /// In fr, this message translates to:
  /// **'ACE !'**
  String get highlightAce;

  /// No description provided for @gamePenaltyName.
  ///
  /// In fr, this message translates to:
  /// **'Tirs au but'**
  String get gamePenaltyName;

  /// No description provided for @gamePenaltyRule.
  ///
  /// In fr, this message translates to:
  /// **'Swipe le ballon vers le but (courbe = effet). Puis swipe pour plonger !'**
  String get gamePenaltyRule;

  /// No description provided for @gamePenaltyShare.
  ///
  /// In fr, this message translates to:
  /// **'⚽ {goals}/{shots} tirs · {saves}/{rounds} arrêts'**
  String gamePenaltyShare(
    Object goals,
    Object rounds,
    Object saves,
    Object shots,
  );

  /// No description provided for @gamePenaltySharePanenka.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 panenka} other{{count} panenkas}}'**
  String gamePenaltySharePanenka(int count);

  /// No description provided for @statGoals.
  ///
  /// In fr, this message translates to:
  /// **'Buts'**
  String get statGoals;

  /// No description provided for @statTopCorners.
  ///
  /// In fr, this message translates to:
  /// **'Lucarnes'**
  String get statTopCorners;

  /// No description provided for @statSaves.
  ///
  /// In fr, this message translates to:
  /// **'Arrêts'**
  String get statSaves;

  /// No description provided for @statPanenkas.
  ///
  /// In fr, this message translates to:
  /// **'Panenkas'**
  String get statPanenkas;

  /// No description provided for @highlightPanenka.
  ///
  /// In fr, this message translates to:
  /// **'PANENKA !'**
  String get highlightPanenka;

  /// No description provided for @highlightSuperSave.
  ///
  /// In fr, this message translates to:
  /// **'ARRÊT EN LUCARNE !'**
  String get highlightSuperSave;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
