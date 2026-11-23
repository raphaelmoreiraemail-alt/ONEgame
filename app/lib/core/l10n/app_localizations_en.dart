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

  @override
  String get gamePenaltyName => 'Penalty Shootout';

  @override
  String get gamePenaltyRule =>
      'Swipe the ball at the goal (curve = spin). Then swipe to dive!';

  @override
  String gamePenaltyShare(
    Object goals,
    Object rounds,
    Object saves,
    Object shots,
  ) {
    return '⚽ $goals/$shots shots · $saves/$rounds saves';
  }

  @override
  String gamePenaltySharePanenka(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count panenkas',
      one: '1 panenka',
    );
    return '$_temp0';
  }

  @override
  String get statGoals => 'Goals';

  @override
  String get statTopCorners => 'Top corners';

  @override
  String get statSaves => 'Saves';

  @override
  String get statPanenkas => 'Panenkas';

  @override
  String get highlightPanenka => 'PANENKA!';

  @override
  String get highlightSuperSave => 'TOP-CORNER SAVE!';

  @override
  String get gameBasketName => 'Basketball';

  @override
  String get gameBasketRule =>
      'Swipe up to shoot: the speed of your swipe sets the power.';

  @override
  String gameBasketShare(Object baskets, Object streak, Object swishes) {
    return '🏀 $baskets baskets · $swishes swishes · best streak $streak';
  }

  @override
  String get statBaskets => 'Baskets';

  @override
  String get statSwishes => 'Swishes';

  @override
  String get statMaxStreak => 'Best streak';

  @override
  String get highlightOnFire => 'ON FIRE!';

  @override
  String get gameBowlingName => 'Bowling';

  @override
  String get gameBowlingRule =>
      'Slide to place the ball, swipe up to bowl. A curve adds hook.';

  @override
  String gameBowlingShare(Object pins, Object spares, Object strikes) {
    return '🎳 $pins · $strikes strikes · $spares spares';
  }

  @override
  String get statBowlingScore => 'Bowling score';

  @override
  String get statStrikes => 'Strikes';

  @override
  String get statSpares => 'Spares';

  @override
  String get highlightStrike => 'STRIKE!';

  @override
  String get highlightTurkey => 'TURKEY!';

  @override
  String get gameStackName => 'Endless Tower';

  @override
  String get gameStackRule =>
      'Tap to drop the block. Whatever hangs over gets cut!';

  @override
  String gameStackShare(Object height, Object perfects) {
    return '🧱 height $height · $perfects perfect drops';
  }

  @override
  String get statHeight => 'Height';

  @override
  String get statPerfects => 'Perfect drops';

  @override
  String get statMaxCombo => 'Best combo';

  @override
  String get highlightPerfectStreak => '5 PERFECT!';

  @override
  String get gameDartsName => 'Darts';

  @override
  String get gameDartsRule =>
      'Hold to aim (the sight drifts), release to throw. 9 darts.';

  @override
  String gameDartsShare(Object bulls, Object points, Object triples) {
    return '🎯 $points pts · $triples triples · $bulls bulls';
  }

  @override
  String get statPoints => 'Points';

  @override
  String get statTriples => 'Triples';

  @override
  String get statBulls => 'Bulls';

  @override
  String get statBestTurn => 'Best turn';

  @override
  String get highlightOneEighty => 'ONE HUNDRED AND EIGHTY!';

  @override
  String get homeRingingTitle => 'IT\'S TIME!';

  @override
  String get homePlay => 'PLAY';

  @override
  String homeRingingLeft(Object time) {
    return '$time left to start on time';
  }

  @override
  String get homeLateTitle => 'You\'re late';

  @override
  String homeLateBody(Object time) {
    return 'The alarm rang at $time. You can still play: your score will count among friends (marked \"late\") but not in world rankings, and your streak will restart from zero.';
  }

  @override
  String get homePlayAnyway => 'Play anyway';

  @override
  String get homePlayedTitle => 'Game played';

  @override
  String get homePlayedLate => 'late';

  @override
  String get homePlayedOnTime => 'on time';

  @override
  String get homeNextAlarm => 'Next alarm tomorrow, between 10 AM and 9 PM.';

  @override
  String get homeLostTitle => 'Game interrupted';

  @override
  String homeLostBody(Object score) {
    return 'The app was closed during the game: the attempt is lost. Score kept: $score.';
  }

  @override
  String get homeUnavailable => 'Today\'s challenge isn\'t ready yet.';

  @override
  String get homeRetry => 'Retry';

  @override
  String get homeError => 'Can\'t connect. Check your network.';

  @override
  String get homeStreak => 'Streak';

  @override
  String homeBestStreak(Object n) {
    return 'Best: $n';
  }

  @override
  String get homeJokers => 'Jokers';

  @override
  String get homeUseJoker => 'Save my streak with a joker';

  @override
  String get homeJokerUsed => 'Streak saved!';

  @override
  String get homeAlreadyPlayed => 'You already started today\'s official game.';

  @override
  String get homeShare => 'Share';

  @override
  String homeTodayGame(Object game) {
    return 'Today\'s game: $game';
  }

  @override
  String get notifTitle => '⏰ It\'s OneGame time!';

  @override
  String notifBody(Object game) {
    return 'Today\'s game: $game. 2 minutes to start.';
  }

  @override
  String get notifChannel => 'Daily alarm';

  @override
  String resultsStreak(Object n) {
    return '🔥 Streak: $n';
  }

  @override
  String get resultsNewBadges => 'New badges';

  @override
  String get resultsOfficialLate =>
      'Played late: visible to your friends only.';

  @override
  String get profileStreak => 'Current streak';

  @override
  String get profileBest => 'Best';

  @override
  String get profileCalendar => 'Calendar';

  @override
  String get profileLegendOnTime => 'On time';

  @override
  String get profileLegendLate => 'Late';

  @override
  String get profileLegendMissed => 'Missed';

  @override
  String get profileLegendSaved => 'Saved (joker)';

  @override
  String get profileRecords => 'Records per game';

  @override
  String get profileNoRecords =>
      'Play your first official game to set a record.';

  @override
  String get profileBadges => 'Badges';

  @override
  String get badgeFirstDay => 'First step';

  @override
  String get badgeWeek => 'One week';

  @override
  String get badgeMonth => 'One month';

  @override
  String get badgeAce => 'Ace';

  @override
  String get badgePanenka => 'Panenka';

  @override
  String get badgeCarreau => 'Carreau';

  @override
  String get badgeOneEighty => '180';

  @override
  String get badgeEarlyBird => 'Early bird';

  @override
  String get badgeAllGames => 'Jack of all trades';

  @override
  String get settingsRegion => 'Region';

  @override
  String get settingsRegionHelp =>
      'The alarm rings at the same time for your whole region. Can be changed once every 30 days.';

  @override
  String settingsRegionCooldown(Object date) {
    return 'You can change it again from $date.';
  }

  @override
  String get regionEurope => 'Europe & Africa';

  @override
  String get regionAmericas => 'Americas (East)';

  @override
  String get regionAsia => 'Asia & Oceania';

  @override
  String get regionWest => 'Americas (West)';

  @override
  String get settingsSound => 'Sounds';

  @override
  String get settingsHaptics => 'Vibrations';

  @override
  String get settingsReduceMotion => 'Reduce motion';

  @override
  String get settingsNotifications => 'Allow notifications';

  @override
  String settingsBackend(Object name) {
    return 'Server: $name';
  }
}
