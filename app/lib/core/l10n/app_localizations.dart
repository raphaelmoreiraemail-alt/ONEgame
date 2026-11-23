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

  /// No description provided for @gameBasketName.
  ///
  /// In fr, this message translates to:
  /// **'Basket'**
  String get gameBasketName;

  /// No description provided for @gameBasketRule.
  ///
  /// In fr, this message translates to:
  /// **'Swipe vers le haut pour tirer : la vitesse du geste fait la puissance.'**
  String get gameBasketRule;

  /// No description provided for @gameBasketShare.
  ///
  /// In fr, this message translates to:
  /// **'🏀 {baskets} paniers · {swishes} swish · série max {streak}'**
  String gameBasketShare(Object baskets, Object streak, Object swishes);

  /// No description provided for @statBaskets.
  ///
  /// In fr, this message translates to:
  /// **'Paniers'**
  String get statBaskets;

  /// No description provided for @statSwishes.
  ///
  /// In fr, this message translates to:
  /// **'Swish'**
  String get statSwishes;

  /// No description provided for @statMaxStreak.
  ///
  /// In fr, this message translates to:
  /// **'Série max'**
  String get statMaxStreak;

  /// No description provided for @highlightOnFire.
  ///
  /// In fr, this message translates to:
  /// **'EN FEU !'**
  String get highlightOnFire;

  /// No description provided for @gameBowlingName.
  ///
  /// In fr, this message translates to:
  /// **'Bowling'**
  String get gameBowlingName;

  /// No description provided for @gameBowlingRule.
  ///
  /// In fr, this message translates to:
  /// **'Glisse pour placer la boule, swipe vers le haut pour lancer. Une courbe = de l\'effet.'**
  String get gameBowlingRule;

  /// No description provided for @gameBowlingShare.
  ///
  /// In fr, this message translates to:
  /// **'🎳 {pins} · {strikes} strikes · {spares} spares'**
  String gameBowlingShare(Object pins, Object spares, Object strikes);

  /// No description provided for @statBowlingScore.
  ///
  /// In fr, this message translates to:
  /// **'Score bowling'**
  String get statBowlingScore;

  /// No description provided for @statStrikes.
  ///
  /// In fr, this message translates to:
  /// **'Strikes'**
  String get statStrikes;

  /// No description provided for @statSpares.
  ///
  /// In fr, this message translates to:
  /// **'Spares'**
  String get statSpares;

  /// No description provided for @highlightStrike.
  ///
  /// In fr, this message translates to:
  /// **'STRIKE !'**
  String get highlightStrike;

  /// No description provided for @highlightTurkey.
  ///
  /// In fr, this message translates to:
  /// **'TURKEY !'**
  String get highlightTurkey;

  /// No description provided for @gameStackName.
  ///
  /// In fr, this message translates to:
  /// **'Tour infinie'**
  String get gameStackName;

  /// No description provided for @gameStackRule.
  ///
  /// In fr, this message translates to:
  /// **'Tape pour poser le bloc. Ce qui dépasse est coupé !'**
  String get gameStackRule;

  /// No description provided for @gameStackShare.
  ///
  /// In fr, this message translates to:
  /// **'🧱 hauteur {height} · {perfects} poses parfaites'**
  String gameStackShare(Object height, Object perfects);

  /// No description provided for @statHeight.
  ///
  /// In fr, this message translates to:
  /// **'Hauteur'**
  String get statHeight;

  /// No description provided for @statPerfects.
  ///
  /// In fr, this message translates to:
  /// **'Poses parfaites'**
  String get statPerfects;

  /// No description provided for @statMaxCombo.
  ///
  /// In fr, this message translates to:
  /// **'Combo max'**
  String get statMaxCombo;

  /// No description provided for @highlightPerfectStreak.
  ///
  /// In fr, this message translates to:
  /// **'5 PARFAITS !'**
  String get highlightPerfectStreak;

  /// No description provided for @gameDartsName.
  ///
  /// In fr, this message translates to:
  /// **'Fléchettes'**
  String get gameDartsName;

  /// No description provided for @gameDartsRule.
  ///
  /// In fr, this message translates to:
  /// **'Maintiens pour viser (le viseur bouge), relâche pour lancer. 9 fléchettes.'**
  String get gameDartsRule;

  /// No description provided for @gameDartsShare.
  ///
  /// In fr, this message translates to:
  /// **'🎯 {points} pts · {triples} triples · {bulls} bulls'**
  String gameDartsShare(Object bulls, Object points, Object triples);

  /// No description provided for @statPoints.
  ///
  /// In fr, this message translates to:
  /// **'Points'**
  String get statPoints;

  /// No description provided for @statTriples.
  ///
  /// In fr, this message translates to:
  /// **'Triples'**
  String get statTriples;

  /// No description provided for @statBulls.
  ///
  /// In fr, this message translates to:
  /// **'Bulls'**
  String get statBulls;

  /// No description provided for @statBestTurn.
  ///
  /// In fr, this message translates to:
  /// **'Meilleure volée'**
  String get statBestTurn;

  /// No description provided for @highlightOneEighty.
  ///
  /// In fr, this message translates to:
  /// **'ONE HUNDRED AND EIGHTY !'**
  String get highlightOneEighty;

  /// No description provided for @homeRingingTitle.
  ///
  /// In fr, this message translates to:
  /// **'C\'EST L\'HEURE !'**
  String get homeRingingTitle;

  /// No description provided for @homePlay.
  ///
  /// In fr, this message translates to:
  /// **'JOUER'**
  String get homePlay;

  /// No description provided for @homeRingingLeft.
  ///
  /// In fr, this message translates to:
  /// **'Encore {time} pour lancer à l\'heure'**
  String homeRingingLeft(Object time);

  /// No description provided for @homeLateTitle.
  ///
  /// In fr, this message translates to:
  /// **'Tu es en retard'**
  String get homeLateTitle;

  /// No description provided for @homeLateBody.
  ///
  /// In fr, this message translates to:
  /// **'L\'alarme a sonné à {time}. Tu peux encore jouer : ton score comptera chez tes amis (marqué « en retard »), mais pas dans les classements mondiaux, et ta série repartira de zéro.'**
  String homeLateBody(Object time);

  /// No description provided for @homePlayAnyway.
  ///
  /// In fr, this message translates to:
  /// **'Jouer quand même'**
  String get homePlayAnyway;

  /// No description provided for @homePlayedTitle.
  ///
  /// In fr, this message translates to:
  /// **'Partie jouée'**
  String get homePlayedTitle;

  /// No description provided for @homePlayedLate.
  ///
  /// In fr, this message translates to:
  /// **'en retard'**
  String get homePlayedLate;

  /// No description provided for @homePlayedOnTime.
  ///
  /// In fr, this message translates to:
  /// **'à l\'heure'**
  String get homePlayedOnTime;

  /// No description provided for @homeNextAlarm.
  ///
  /// In fr, this message translates to:
  /// **'Prochaine alarme demain, entre 10h et 21h.'**
  String get homeNextAlarm;

  /// No description provided for @homeLostTitle.
  ///
  /// In fr, this message translates to:
  /// **'Partie interrompue'**
  String get homeLostTitle;

  /// No description provided for @homeLostBody.
  ///
  /// In fr, this message translates to:
  /// **'L\'application a été fermée pendant la partie : la tentative est perdue. Score retenu : {score}.'**
  String homeLostBody(Object score);

  /// No description provided for @homeUnavailable.
  ///
  /// In fr, this message translates to:
  /// **'Le défi du jour n\'est pas encore prêt.'**
  String get homeUnavailable;

  /// No description provided for @homeRetry.
  ///
  /// In fr, this message translates to:
  /// **'Réessayer'**
  String get homeRetry;

  /// No description provided for @homeError.
  ///
  /// In fr, this message translates to:
  /// **'Connexion impossible. Vérifie ton réseau.'**
  String get homeError;

  /// No description provided for @homeStreak.
  ///
  /// In fr, this message translates to:
  /// **'Série'**
  String get homeStreak;

  /// No description provided for @homeBestStreak.
  ///
  /// In fr, this message translates to:
  /// **'Record : {n}'**
  String homeBestStreak(Object n);

  /// No description provided for @homeJokers.
  ///
  /// In fr, this message translates to:
  /// **'Jokers'**
  String get homeJokers;

  /// No description provided for @homeUseJoker.
  ///
  /// In fr, this message translates to:
  /// **'Sauver ma série avec un joker'**
  String get homeUseJoker;

  /// No description provided for @homeJokerUsed.
  ///
  /// In fr, this message translates to:
  /// **'Série sauvée !'**
  String get homeJokerUsed;

  /// No description provided for @homeAlreadyPlayed.
  ///
  /// In fr, this message translates to:
  /// **'Tu as déjà lancé ta partie officielle aujourd\'hui.'**
  String get homeAlreadyPlayed;

  /// No description provided for @homeShare.
  ///
  /// In fr, this message translates to:
  /// **'Partager'**
  String get homeShare;

  /// No description provided for @homeTodayGame.
  ///
  /// In fr, this message translates to:
  /// **'Jeu du jour : {game}'**
  String homeTodayGame(Object game);

  /// No description provided for @notifTitle.
  ///
  /// In fr, this message translates to:
  /// **'⏰ C\'est l\'heure du OneGame !'**
  String get notifTitle;

  /// No description provided for @notifBody.
  ///
  /// In fr, this message translates to:
  /// **'Le jeu du jour : {game}. 2 minutes pour lancer.'**
  String notifBody(Object game);

  /// No description provided for @notifChannel.
  ///
  /// In fr, this message translates to:
  /// **'Alarme du jour'**
  String get notifChannel;

  /// No description provided for @resultsStreak.
  ///
  /// In fr, this message translates to:
  /// **'🔥 Série : {n}'**
  String resultsStreak(Object n);

  /// No description provided for @resultsNewBadges.
  ///
  /// In fr, this message translates to:
  /// **'Nouveaux badges'**
  String get resultsNewBadges;

  /// No description provided for @resultsOfficialLate.
  ///
  /// In fr, this message translates to:
  /// **'Partie jouée en retard : visible chez tes amis seulement.'**
  String get resultsOfficialLate;

  /// No description provided for @profileStreak.
  ///
  /// In fr, this message translates to:
  /// **'Série actuelle'**
  String get profileStreak;

  /// No description provided for @profileBest.
  ///
  /// In fr, this message translates to:
  /// **'Record'**
  String get profileBest;

  /// No description provided for @profileCalendar.
  ///
  /// In fr, this message translates to:
  /// **'Calendrier'**
  String get profileCalendar;

  /// No description provided for @profileLegendOnTime.
  ///
  /// In fr, this message translates to:
  /// **'À l\'heure'**
  String get profileLegendOnTime;

  /// No description provided for @profileLegendLate.
  ///
  /// In fr, this message translates to:
  /// **'En retard'**
  String get profileLegendLate;

  /// No description provided for @profileLegendMissed.
  ///
  /// In fr, this message translates to:
  /// **'Raté'**
  String get profileLegendMissed;

  /// No description provided for @profileLegendSaved.
  ///
  /// In fr, this message translates to:
  /// **'Sauvé (joker)'**
  String get profileLegendSaved;

  /// No description provided for @profileRecords.
  ///
  /// In fr, this message translates to:
  /// **'Records par jeu'**
  String get profileRecords;

  /// No description provided for @profileNoRecords.
  ///
  /// In fr, this message translates to:
  /// **'Joue ta première partie officielle pour établir un record.'**
  String get profileNoRecords;

  /// No description provided for @profileBadges.
  ///
  /// In fr, this message translates to:
  /// **'Badges'**
  String get profileBadges;

  /// No description provided for @badgeFirstDay.
  ///
  /// In fr, this message translates to:
  /// **'Premier pas'**
  String get badgeFirstDay;

  /// No description provided for @badgeWeek.
  ///
  /// In fr, this message translates to:
  /// **'Une semaine'**
  String get badgeWeek;

  /// No description provided for @badgeMonth.
  ///
  /// In fr, this message translates to:
  /// **'Un mois'**
  String get badgeMonth;

  /// No description provided for @badgeAce.
  ///
  /// In fr, this message translates to:
  /// **'Ace'**
  String get badgeAce;

  /// No description provided for @badgePanenka.
  ///
  /// In fr, this message translates to:
  /// **'Panenka'**
  String get badgePanenka;

  /// No description provided for @badgeCarreau.
  ///
  /// In fr, this message translates to:
  /// **'Carreau'**
  String get badgeCarreau;

  /// No description provided for @badgeOneEighty.
  ///
  /// In fr, this message translates to:
  /// **'180'**
  String get badgeOneEighty;

  /// No description provided for @badgeEarlyBird.
  ///
  /// In fr, this message translates to:
  /// **'Lève-tôt'**
  String get badgeEarlyBird;

  /// No description provided for @badgeAllGames.
  ///
  /// In fr, this message translates to:
  /// **'Touche-à-tout'**
  String get badgeAllGames;

  /// No description provided for @settingsRegion.
  ///
  /// In fr, this message translates to:
  /// **'Région'**
  String get settingsRegion;

  /// No description provided for @settingsRegionHelp.
  ///
  /// In fr, this message translates to:
  /// **'L\'alarme sonne à la même heure pour toute ta région. Modifiable une fois par 30 jours.'**
  String get settingsRegionHelp;

  /// No description provided for @settingsRegionCooldown.
  ///
  /// In fr, this message translates to:
  /// **'Changement possible à partir du {date}.'**
  String settingsRegionCooldown(Object date);

  /// No description provided for @regionEurope.
  ///
  /// In fr, this message translates to:
  /// **'Europe & Afrique'**
  String get regionEurope;

  /// No description provided for @regionAmericas.
  ///
  /// In fr, this message translates to:
  /// **'Amériques (Est)'**
  String get regionAmericas;

  /// No description provided for @regionAsia.
  ///
  /// In fr, this message translates to:
  /// **'Asie & Océanie'**
  String get regionAsia;

  /// No description provided for @regionWest.
  ///
  /// In fr, this message translates to:
  /// **'Amériques (Ouest)'**
  String get regionWest;

  /// No description provided for @settingsSound.
  ///
  /// In fr, this message translates to:
  /// **'Sons'**
  String get settingsSound;

  /// No description provided for @settingsHaptics.
  ///
  /// In fr, this message translates to:
  /// **'Vibrations'**
  String get settingsHaptics;

  /// No description provided for @settingsReduceMotion.
  ///
  /// In fr, this message translates to:
  /// **'Réduire les animations'**
  String get settingsReduceMotion;

  /// No description provided for @settingsNotifications.
  ///
  /// In fr, this message translates to:
  /// **'Autoriser les notifications'**
  String get settingsNotifications;

  /// No description provided for @settingsBackend.
  ///
  /// In fr, this message translates to:
  /// **'Serveur : {name}'**
  String settingsBackend(Object name);
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
