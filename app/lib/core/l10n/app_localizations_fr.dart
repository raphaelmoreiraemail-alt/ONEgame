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

  @override
  String get gameMinigolfName => 'Mini-Golf';

  @override
  String get gameMinigolfRule =>
      'Tire la balle en arrière comme un lance-pierre. 3 trous, 2 minutes.';

  @override
  String gameMinigolfShare(Object holes, Object strokes, Object toPar) {
    return '⛳ $holes trous · $strokes coups ($toPar)';
  }

  @override
  String gameMinigolfShareAces(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count trous en un',
      one: '1 trou en un',
    );
    return '$_temp0';
  }

  @override
  String get statHoles => 'Trous joués';

  @override
  String get statStrokes => 'Coups';

  @override
  String get statToPar => 'Par rapport au par';

  @override
  String get statAces => 'Trous en un';

  @override
  String get highlightAce => 'ACE !';

  @override
  String get gamePenaltyName => 'Tirs au but';

  @override
  String get gamePenaltyRule =>
      'Swipe le ballon vers le but (courbe = effet). Puis swipe pour plonger !';

  @override
  String gamePenaltyShare(
    Object goals,
    Object rounds,
    Object saves,
    Object shots,
  ) {
    return '⚽ $goals/$shots tirs · $saves/$rounds arrêts';
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
  String get statGoals => 'Buts';

  @override
  String get statTopCorners => 'Lucarnes';

  @override
  String get statSaves => 'Arrêts';

  @override
  String get statPanenkas => 'Panenkas';

  @override
  String get highlightPanenka => 'PANENKA !';

  @override
  String get highlightSuperSave => 'ARRÊT EN LUCARNE !';

  @override
  String get gameBasketName => 'Basket';

  @override
  String get gameBasketRule =>
      'Swipe vers le haut pour tirer : la vitesse du geste fait la puissance.';

  @override
  String gameBasketShare(Object baskets, Object streak, Object swishes) {
    return '🏀 $baskets paniers · $swishes swish · série max $streak';
  }

  @override
  String get statBaskets => 'Paniers';

  @override
  String get statSwishes => 'Swish';

  @override
  String get statMaxStreak => 'Série max';

  @override
  String get highlightOnFire => 'EN FEU !';

  @override
  String get gameBowlingName => 'Bowling';

  @override
  String get gameBowlingRule =>
      'Glisse pour placer la boule, swipe vers le haut pour lancer. Une courbe = de l\'effet.';

  @override
  String gameBowlingShare(Object pins, Object spares, Object strikes) {
    return '🎳 $pins · $strikes strikes · $spares spares';
  }

  @override
  String get statBowlingScore => 'Score bowling';

  @override
  String get statStrikes => 'Strikes';

  @override
  String get statSpares => 'Spares';

  @override
  String get highlightStrike => 'STRIKE !';

  @override
  String get highlightTurkey => 'TURKEY !';

  @override
  String get gameStackName => 'Tour infinie';

  @override
  String get gameStackRule =>
      'Tape pour poser le bloc. Ce qui dépasse est coupé !';

  @override
  String gameStackShare(Object height, Object perfects) {
    return '🧱 hauteur $height · $perfects poses parfaites';
  }

  @override
  String get statHeight => 'Hauteur';

  @override
  String get statPerfects => 'Poses parfaites';

  @override
  String get statMaxCombo => 'Combo max';

  @override
  String get highlightPerfectStreak => '5 PARFAITS !';

  @override
  String get gameDartsName => 'Fléchettes';

  @override
  String get gameDartsRule =>
      'Maintiens pour viser (le viseur bouge), relâche pour lancer. 9 fléchettes.';

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
  String get statBestTurn => 'Meilleure volée';

  @override
  String get highlightOneEighty => 'ONE HUNDRED AND EIGHTY !';

  @override
  String get homeRingingTitle => 'C\'EST L\'HEURE !';

  @override
  String get homePlay => 'JOUER';

  @override
  String homeRingingLeft(Object time) {
    return 'Encore $time pour lancer à l\'heure';
  }

  @override
  String get homeLateTitle => 'Tu es en retard';

  @override
  String homeLateBody(Object time) {
    return 'L\'alarme a sonné à $time. Tu peux encore jouer : ton score comptera chez tes amis (marqué « en retard »), mais pas dans les classements mondiaux, et ta série repartira de zéro.';
  }

  @override
  String get homePlayAnyway => 'Jouer quand même';

  @override
  String get homePlayedTitle => 'Partie jouée';

  @override
  String get homePlayedLate => 'en retard';

  @override
  String get homePlayedOnTime => 'à l\'heure';

  @override
  String get homeNextAlarm => 'Prochaine alarme demain, entre 10h et 21h.';

  @override
  String get homeLostTitle => 'Partie interrompue';

  @override
  String homeLostBody(Object score) {
    return 'L\'application a été fermée pendant la partie : la tentative est perdue. Score retenu : $score.';
  }

  @override
  String get homeUnavailable => 'Le défi du jour n\'est pas encore prêt.';

  @override
  String get homeRetry => 'Réessayer';

  @override
  String get homeError => 'Connexion impossible. Vérifie ton réseau.';

  @override
  String get homeStreak => 'Série';

  @override
  String homeBestStreak(Object n) {
    return 'Record : $n';
  }

  @override
  String get homeJokers => 'Jokers';

  @override
  String get homeUseJoker => 'Sauver ma série avec un joker';

  @override
  String get homeJokerUsed => 'Série sauvée !';

  @override
  String get homeAlreadyPlayed =>
      'Tu as déjà lancé ta partie officielle aujourd\'hui.';

  @override
  String get homeShare => 'Partager';

  @override
  String homeTodayGame(Object game) {
    return 'Jeu du jour : $game';
  }

  @override
  String get notifTitle => '⏰ C\'est l\'heure du OneGame !';

  @override
  String notifBody(Object game) {
    return 'Le jeu du jour : $game. 2 minutes pour lancer.';
  }

  @override
  String get notifChannel => 'Alarme du jour';

  @override
  String resultsStreak(Object n) {
    return '🔥 Série : $n';
  }

  @override
  String get resultsNewBadges => 'Nouveaux badges';

  @override
  String get resultsOfficialLate =>
      'Partie jouée en retard : visible chez tes amis seulement.';

  @override
  String get profileStreak => 'Série actuelle';

  @override
  String get profileBest => 'Record';

  @override
  String get profileCalendar => 'Calendrier';

  @override
  String get profileLegendOnTime => 'À l\'heure';

  @override
  String get profileLegendLate => 'En retard';

  @override
  String get profileLegendMissed => 'Raté';

  @override
  String get profileLegendSaved => 'Sauvé (joker)';

  @override
  String get profileRecords => 'Records par jeu';

  @override
  String get profileNoRecords =>
      'Joue ta première partie officielle pour établir un record.';

  @override
  String get profileBadges => 'Badges';

  @override
  String get badgeFirstDay => 'Premier pas';

  @override
  String get badgeWeek => 'Une semaine';

  @override
  String get badgeMonth => 'Un mois';

  @override
  String get badgeAce => 'Ace';

  @override
  String get badgePanenka => 'Panenka';

  @override
  String get badgeCarreau => 'Carreau';

  @override
  String get badgeOneEighty => '180';

  @override
  String get badgeEarlyBird => 'Lève-tôt';

  @override
  String get badgeAllGames => 'Touche-à-tout';

  @override
  String get settingsRegion => 'Région';

  @override
  String get settingsRegionHelp =>
      'L\'alarme sonne à la même heure pour toute ta région. Modifiable une fois par 30 jours.';

  @override
  String settingsRegionCooldown(Object date) {
    return 'Changement possible à partir du $date.';
  }

  @override
  String get regionEurope => 'Europe & Afrique';

  @override
  String get regionAmericas => 'Amériques (Est)';

  @override
  String get regionAsia => 'Asie & Océanie';

  @override
  String get regionWest => 'Amériques (Ouest)';

  @override
  String get settingsSound => 'Sons';

  @override
  String get settingsHaptics => 'Vibrations';

  @override
  String get settingsReduceMotion => 'Réduire les animations';

  @override
  String get settingsNotifications => 'Autoriser les notifications';

  @override
  String settingsBackend(Object name) {
    return 'Serveur : $name';
  }

  @override
  String get navFriends => 'Amis';

  @override
  String get onbConceptTitle => 'Une alarme. Deux minutes. Un jeu.';

  @override
  String get onbConceptBody =>
      'Chaque jour, à une heure surprise entre 10h et 21h, ton téléphone sonne. Tout le monde a 2 minutes pour lancer le même mini-jeu. Une seule tentative compte.';

  @override
  String get onbNotifTitle => 'Autorise l\'alarme';

  @override
  String get onbNotifBody =>
      'Sans notifications, tu rateras l\'alarme du jour : c\'est elle qui te prévient qu\'il est l\'heure de jouer. On ne t\'envoie rien d\'autre.';

  @override
  String get onbNotifButton => 'Autoriser les notifications';

  @override
  String get onbPseudoTitle => 'Choisis ton pseudo';

  @override
  String get onbPseudoHint => '3 à 16 caractères : lettres, chiffres, . _ -';

  @override
  String get onbNext => 'Suivant';

  @override
  String get onbStart => 'C\'est parti !';

  @override
  String get onbSkip => 'Plus tard';

  @override
  String get pseudoErrorLength => 'Entre 3 et 16 caractères.';

  @override
  String get pseudoErrorCharset =>
      'Lettres, chiffres, point, tiret et tiret bas uniquement.';

  @override
  String get pseudoErrorOffensive => 'Ce pseudo n\'est pas autorisé.';

  @override
  String get pseudoErrorTaken => 'Ce pseudo est déjà pris.';

  @override
  String get pseudoErrorNotFound => 'Aucun joueur avec ce pseudo.';

  @override
  String get lbTitle => 'Classements';

  @override
  String get lbFriends => 'Amis';

  @override
  String get lbCountry => 'Pays';

  @override
  String get lbRegion => 'Région';

  @override
  String get lbWorld => 'Monde';

  @override
  String get lbWeekly => 'Hebdo';

  @override
  String get lbEmpty => 'Personne n\'a encore joué.';

  @override
  String get lbYou => 'Toi';

  @override
  String lbYourRank(Object rank, Object total) {
    return 'Ta position : $rank / $total';
  }

  @override
  String lbPercentile(Object pct) {
    return 'Meilleur que $pct % des joueurs';
  }

  @override
  String get lbLate => 'en retard';

  @override
  String get lbReport => 'Signaler ce score';

  @override
  String get lbReported => 'Merci, le score sera vérifié.';

  @override
  String get lbDemo => 'Mode démo : joueurs simulés';

  @override
  String get lbWeeklyHelp =>
      'Somme des 7 jours de la semaine, parties à l\'heure uniquement.';

  @override
  String get feedTitle => 'Fil';

  @override
  String get feedLocked =>
      'Joue ta partie du jour pour voir les résultats de tes amis.';

  @override
  String get feedEmpty => 'Aucun ami n\'a encore joué aujourd\'hui.';

  @override
  String get friendsTitle => 'Amis';

  @override
  String get friendsAddByPseudo => 'Ajouter par pseudo';

  @override
  String get friendsAdd => 'Ajouter';

  @override
  String get friendsRequestSent => 'Demande envoyée.';

  @override
  String get friendsNowFriends => 'Vous êtes amis !';

  @override
  String get friendsRequests => 'Demandes reçues';

  @override
  String get friendsPendingOut => 'En attente';

  @override
  String get friendsAccept => 'Accepter';

  @override
  String get friendsDecline => 'Refuser';

  @override
  String get friendsRemove => 'Retirer';

  @override
  String get friendsNone => 'Pas encore d\'amis. Invite-les !';

  @override
  String get friendsInvite => 'Inviter (lien / QR code)';

  @override
  String friendsInviteText(Object link) {
    return 'Rejoins-moi sur OneGame ! Une alarme, deux minutes, un jeu. $link';
  }

  @override
  String friendsInviteCode(Object code) {
    return 'Code : $code';
  }

  @override
  String get friendsEnterCode => 'J\'ai un code d\'invitation';

  @override
  String friendsCodeAccepted(Object pseudo) {
    return 'Tu es maintenant ami avec $pseudo !';
  }

  @override
  String get friendsContacts => 'Trouver mes contacts';

  @override
  String get friendsContactsConsent =>
      'OneGame va lire les numéros de ton carnet, les transformer en empreintes illisibles (hachage) sur ton téléphone, et seulement ensuite les comparer aux joueurs inscrits. Les numéros ne quittent jamais ton téléphone en clair.';

  @override
  String get friendsContactsMine =>
      'Ton numéro (pour que tes contacts te trouvent, facultatif)';

  @override
  String friendsContactsFound(Object n) {
    return '$n contact(s) trouvé(s), demandes envoyées.';
  }

  @override
  String get friendsContactsDenied => 'Accès aux contacts refusé.';

  @override
  String get friendsDemo =>
      'Mode démo : amis simulés. Les vrais amis arrivent avec le serveur.';

  @override
  String get commonCancel => 'Annuler';

  @override
  String get commonContinue => 'Continuer';

  @override
  String get commonOk => 'OK';

  @override
  String get commonError => 'Une erreur est survenue.';

  @override
  String get shareImage => 'Partager l\'image';

  @override
  String shareCardStreak(Object n) {
    return '🔥 série de $n';
  }

  @override
  String resultsFriendsRank(Object rank, Object total) {
    return '${rank}e sur $total chez tes amis';
  }

  @override
  String get accountTitle => 'Compte';

  @override
  String get accountPseudo => 'Pseudo';

  @override
  String get accountChangePseudo => 'Changer de pseudo';

  @override
  String get accountLinkGoogle => 'Lier un compte Google';

  @override
  String get accountLinkApple => 'Lier un compte Apple';

  @override
  String get accountLinkEmail => 'Lier une adresse e-mail';

  @override
  String get accountLinked => 'Compte lié.';

  @override
  String get accountLinkHelp =>
      'Lier un compte permet de retrouver ta série si tu changes de téléphone.';

  @override
  String get accountLocalOnly =>
      'Disponible quand l\'app est connectée au serveur.';

  @override
  String get accountEmail => 'E-mail';

  @override
  String get accountPassword => 'Mot de passe (6 caractères min.)';

  @override
  String get accountDelete => 'Supprimer mon compte';

  @override
  String get accountDeleteConfirm =>
      'Toutes tes données (série, scores, amis) seront définitivement supprimées. Continuer ?';

  @override
  String get accountDeleted => 'Compte supprimé.';

  @override
  String get gameFreekickName => 'Coup franc';

  @override
  String get gameFreekickRule =>
      'Swipe en courbe pour contourner le mur. 8 coups francs.';

  @override
  String gameFreekickShare(Object corners, Object goals, Object kicks) {
    return '⚽ $goals/$kicks coups francs · $corners lucarnes';
  }

  @override
  String get statWallHits => 'Dans le mur';

  @override
  String get highlightTopBins => 'LUCARNE !';

  @override
  String get gamePetanqueName => 'Pétanque';

  @override
  String get gamePetanqueRule =>
      'Glisse pour viser (vers le haut = tirer), maintiens pour la force, relâche !';

  @override
  String gamePetanqueShareWin(Object ai, Object me) {
    return '🔵 Victoire $me-$ai';
  }

  @override
  String gamePetanqueShareLoss(Object ai, Object me) {
    return '🔵 Défaite $me-$ai';
  }

  @override
  String gamePetanqueShareDraw(Object ai, Object me) {
    return '🔵 Égalité $me-$ai';
  }

  @override
  String gamePetanqueShareCarreau(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count carreaux',
      one: '1 carreau',
    );
    return '$_temp0';
  }

  @override
  String get statMatch => 'Score du match';

  @override
  String get statEnds => 'Mènes';

  @override
  String get statCarreaux => 'Carreaux';

  @override
  String get highlightCarreau => 'CARREAU !';

  @override
  String get gameTennisName => 'Tennis de table';

  @override
  String get gameTennisRule =>
      'Glisse la raquette. Geste rapide au contact = smash, de côté = effet. Premier à 7 !';

  @override
  String gameTennisWin(Object ai, Object me) {
    return '🏓 Victoire $me-$ai';
  }

  @override
  String gameTennisLoss(Object ai, Object me) {
    return '🏓 Défaite $me-$ai';
  }

  @override
  String gameTennisRally(Object n) {
    return 'rallye max $n';
  }

  @override
  String get statBestRally => 'Plus long échange';

  @override
  String get statSmashes => 'Smashs';

  @override
  String get highlightSmash => 'SMASH !';

  @override
  String get gameAirhockeyName => 'Air hockey';

  @override
  String get gameAirhockeyRule =>
      'Ta palette suit ton doigt. Premier à 5 buts !';

  @override
  String gameAirhockeyWin(Object ai, Object me) {
    return '🏒 Victoire $me-$ai';
  }

  @override
  String gameAirhockeyLoss(Object ai, Object me) {
    return '🏒 Défaite $me-$ai';
  }

  @override
  String get statDirectGoals => 'Buts directs';

  @override
  String get highlightDirectGoal => 'BUT DIRECT !';

  @override
  String get gameArcheryName => 'Tir à l\'arc';

  @override
  String get gameArcheryRule =>
      'Tire vers le bas pour bander l\'arc et viser, relâche. Attention au vent !';

  @override
  String gameArcheryShare(Object bulls, Object points) {
    return '🏹 $points pts · $bulls mouches';
  }

  @override
  String get statBullseyes => 'Mouches';

  @override
  String get statArrows => 'Flèches';

  @override
  String get highlightMouche => 'MOUCHE !';

  @override
  String get gameBillardName => 'Billard';

  @override
  String get gameBillardRule =>
      'Tire en arrière depuis la blanche pour viser, relâche. Empoche tout !';

  @override
  String gameBillardShare(Object potted, Object series) {
    return '🎱 $potted billes · série de $series';
  }

  @override
  String get statPotted => 'Billes rentrées';

  @override
  String get statBestSeries => 'Meilleure série';

  @override
  String get statScratches => 'Blanches rentrées';

  @override
  String get highlightDoublePot => 'DOUBLÉ !';

  @override
  String get gameCurlingName => 'Curling';

  @override
  String get gameCurlingRule =>
      'Swipe pour lancer (une courbe = de la rotation), puis tapote pour balayer !';

  @override
  String gameCurlingShare(Object inHouse, Object knocked) {
    return '🥌 $inHouse pierres dans la maison · $knocked sorties';
  }

  @override
  String get statInHouse => 'Pierres dans la maison';

  @override
  String get statKnockedOut => 'Pierres adverses sorties';

  @override
  String get statButtons => 'Bouton';

  @override
  String get highlightButton => 'PILE AU BOUTON !';

  @override
  String get gameSkiName => 'Slalom';

  @override
  String get gameSkiRule =>
      'Glisse pour tourner, passe toutes les portes. Deux doigts = recherche de vitesse.';

  @override
  String gameSkiShare(Object missed, Object time) {
    return '⛷️ $time · $missed porte(s) manquée(s)';
  }

  @override
  String get statTime => 'Temps';

  @override
  String get statGatesMissed => 'Portes manquées (+3 s)';

  @override
  String get statCrashes => 'Chutes';

  @override
  String get highlightCleanRun => 'SANS FAUTE !';

  @override
  String get gameFlappyName => 'Vol';

  @override
  String get gameFlappyRule =>
      'Tape pour battre des ailes et passe entre les tuyaux.';

  @override
  String gameFlappyShare(Object perfect, Object pipes) {
    return '🐦 $pipes tuyaux · $perfect pile au centre';
  }

  @override
  String get statPipes => 'Tuyaux passés';

  @override
  String get statCenterPasses => 'Passages au centre';

  @override
  String get highlightPerfectFlight => 'VOL PARFAIT !';

  @override
  String get gameRunnerName => 'Course';

  @override
  String get gameRunnerRule =>
      'Tape = saut, swipe bas = glissade, swipe gauche/droite = changer de voie.';

  @override
  String gameRunnerShare(Object coins, Object meters) {
    return '🏃 $meters m · $coins pièces';
  }

  @override
  String get statDistance => 'Distance';

  @override
  String get statCoins => 'Pièces';

  @override
  String get highlightMarathon => 'MARATHONIEN !';

  @override
  String get gameSnakeName => 'Serpent';

  @override
  String get gameSnakeRule =>
      'Swipe pour tourner. Mange les fruits, évite les murs et ta queue !';

  @override
  String gameSnakeShare(Object fruits, Object golden, Object length) {
    return '🐍 $fruits fruits · $golden dorés · longueur $length';
  }

  @override
  String get statFruits => 'Fruits';

  @override
  String get statGolden => 'Fruits dorés';

  @override
  String get statLength => 'Longueur';

  @override
  String get highlightBigSnake => 'SERPENT GÉANT !';

  @override
  String get gameRacingName => 'Karts';

  @override
  String get gameRacingRule =>
      'Glisse pour tourner. Deux doigts = dérapage, un long dérapage donne un boost. 3 tours !';

  @override
  String gameRacingShare(Object lap, Object position) {
    return '🏎️ ${position}e · meilleur tour $lap';
  }

  @override
  String get statPosition => 'Position';

  @override
  String get statBestLap => 'Meilleur tour';

  @override
  String get statBoosts => 'Boosts';

  @override
  String get highlightVictory => 'VICTOIRE !';

  @override
  String get gameFishingName => 'Pêche';

  @override
  String get gameFishingRule =>
      'Swipe pour lancer, tape à la touche, maintiens pour remonter… sans casser la ligne !';

  @override
  String gameFishingShare(Object fish, Object kg) {
    return '🎣 $fish poissons · $kg kg';
  }

  @override
  String get statFish => 'Poissons';

  @override
  String get statWeight => 'Poids total';

  @override
  String get statBiggest => 'Plus gros';

  @override
  String get statLineBreaks => 'Lignes cassées';

  @override
  String get highlightLegendary => 'POISSON LÉGENDAIRE !';

  @override
  String get gameParkingName => 'Créneau';

  @override
  String get gameParkingRule =>
      'Tourne le volant, appuie sur ▲ ou ▼ et gare-toi dans la place sans toucher.';

  @override
  String gameParkingShare(Object bumps, Object parked) {
    return '🚗 $parked/4 garées · $bumps accrochage(s)';
  }

  @override
  String get statParked => 'Voitures garées';

  @override
  String get statPrecision => 'Précision';

  @override
  String get statBumps => 'Accrochages';

  @override
  String get highlightPerfectPark => 'CRÉNEAU PARFAIT !';

  @override
  String get gameMemoryName => 'Mémoire flash';

  @override
  String get gameMemoryRule =>
      'Regarde la séquence, puis reproduis-la. Une case de plus à chaque fois !';

  @override
  String gameMemoryShare(Object length) {
    return '🧠 séquence de $length';
  }

  @override
  String get statSequence => 'Plus longue séquence';

  @override
  String get statSpeedBonus => 'Bonus de vitesse';

  @override
  String get highlightMemoryTen => 'MÉMOIRE D\'ÉLÉPHANT !';

  @override
  String get gameCalculName => 'Calcul mental';

  @override
  String get gameCalculRule =>
      'Trouve la bonne réponse parmi 4. Ça va de plus en plus vite !';

  @override
  String gameCalculShare(Object correct, Object streak) {
    return '➗ $correct bonnes réponses · série de $streak';
  }

  @override
  String get statCorrect => 'Bonnes réponses';

  @override
  String get statWrong => 'Erreurs';

  @override
  String get highlightStreak10 => '10 D\'AFFILÉE !';

  @override
  String get gameMotflashName => 'Mot éclair';

  @override
  String get gameMotflashRule =>
      'Forme un maximum de mots avec ces 7 lettres. Un mot de 7 lettres existe !';

  @override
  String gameMotflashShare(Object longest, Object words) {
    return '🔤 $words mots · le plus long : $longest lettres';
  }

  @override
  String get statWords => 'Mots trouvés';

  @override
  String get statLongest => 'Mot le plus long';

  @override
  String get highlightFullWord => 'LE MOT DE 7 LETTRES !';

  @override
  String get lbLanguage => 'Langue';

  @override
  String get profileAvatar => 'Avatar';

  @override
  String get profileNewAvatar => 'Nouvel avatar';
}
