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

  @override
  String get playGo => 'GO!';

  @override
  String get playEnd => 'END';

  @override
  String get playOfficial => 'Official game · one attempt only';

  @override
  String get playTraining => 'Training · doesn\'t count';

  @override
  String get playQuit => 'Quit';

  @override
  String get playTimeLeft => 'Time left';

  @override
  String get playScore => 'Score';

  @override
  String get resultsTitle => 'Results';

  @override
  String get resultsShare => 'Share';

  @override
  String get resultsCopy => 'Copy text';

  @override
  String get resultsCopied => 'Copied!';

  @override
  String get resultsHome => 'Home';

  @override
  String get resultsReplay => 'Play again';

  @override
  String get resultsHighlights => 'Highlights';

  @override
  String get resultsTimeUp => 'Time\'s up';

  @override
  String get resultsDuration => 'Duration';

  @override
  String get resultsTrainingNote =>
      'Training score: it doesn\'t count in leaderboards.';

  @override
  String get gameLabGame => 'Game';

  @override
  String get gameLabSeed => 'Seed';

  @override
  String get gameLabModifier => 'Modifier';

  @override
  String get gameLabNone => 'None';

  @override
  String get gameLabPlay => 'Play';

  @override
  String get gameLabNext => 'Next level';

  @override
  String get gameLabRandom => 'Random seed';

  @override
  String gameLabFingerprint(Object value) {
    return 'Level fingerprint: $value';
  }

  @override
  String get gameLabDebug => 'Show FPS and physics bodies';

  @override
  String get trainingSubtitle =>
      'Replay released games on a random level. It never counts.';

  @override
  String get modifierWind => 'Windy day';

  @override
  String get modifierNight => 'Night';

  @override
  String get modifierTurbo => 'Turbo';

  @override
  String get modifierMirror => 'Mirror';

  @override
  String get modifierIce => 'Ice';

  @override
  String get modifierGiant => 'Giant';

  @override
  String get modifierWindDesc => 'The wind bends your shots.';

  @override
  String get modifierNightDesc => 'You only see around you.';

  @override
  String get modifierTurboDesc => 'Everything is 25% faster.';

  @override
  String get modifierMirrorDesc => 'Left / right controls are flipped.';

  @override
  String get modifierIceDesc => 'Twice as slippery.';

  @override
  String get modifierGiantDesc => 'Bigger targets, tougher opponent.';

  @override
  String get categorySport => 'Sport';

  @override
  String get categoryAdresse => 'Skill';

  @override
  String get categoryArcade => 'Arcade';

  @override
  String get categoryReflexion => 'Brain';

  @override
  String get highlightSurvivor => 'SURVIVOR!';

  @override
  String get gameSurvivalName => 'Survive 2:00';

  @override
  String get gameSurvivalRule => 'Slide to dodge the blocks. Last 2 minutes!';

  @override
  String gameSurvivalShare(Object orbs, Object seconds) {
    return '☄️ ${seconds}s · $orbs orbs';
  }

  @override
  String get statSeconds => 'Seconds survived';

  @override
  String get statOrbs => 'Orbs';

  @override
  String get gameMinigolfName => 'Mini Golf';

  @override
  String get gameMinigolfRule =>
      'Pull the ball back like a slingshot. 3 holes, 2 minutes.';

  @override
  String gameMinigolfShare(Object holes, Object strokes, Object toPar) {
    return '⛳ $holes holes · $strokes strokes ($toPar)';
  }

  @override
  String gameMinigolfShareAces(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count holes-in-one',
      one: '1 hole-in-one',
    );
    return '$_temp0';
  }

  @override
  String get statHoles => 'Holes played';

  @override
  String get statStrokes => 'Strokes';

  @override
  String get statToPar => 'To par';

  @override
  String get statAces => 'Holes-in-one';

  @override
  String get highlightAce => 'ACE!';
}
