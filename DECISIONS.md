# Décisions

Choix non couverts (ou ajustés) par le cahier des charges. Le plus simple l'emporte.

| # | Date | Décision | Raison |
|---|---|---|---|
| 1 | 2026-11-23 | Bundle ID / package name provisoire : `com.raphaelmoreira.onegame`. | Pas encore confirmé. Modifiable sans coût jusqu'à la première publication (Phase 6). |
| 2 | 2026-11-23 | Cloud Functions sur **Node 22** au lieu de Node 20. | Node 20 est en fin de vie depuis avril 2026 et n'est plus accepté durablement par Cloud Functions. |
| 3 | 2026-11-23 | Flutter 3.50 : import `package:material_ui/material_ui.dart` (et `cupertino_ui`) au lieu de `package:flutter/material.dart`. | Material et Cupertino sont sortis du framework ; les anciens imports sont dépréciés. |
| 4 | 2026-11-23 | Hash des labels de sous-seeds : **FNV-1a 32 bits** sur les octets UTF-8. | Simple, identique en Dart et TS, sans dépendance. |
| 5 | 2026-11-23 | `nextInt(n) = floor(nextDouble() * n)` (pas de rejet). | Biais négligeable pour n petit ; trivial à garder identique entre Dart et TS. |
| 6 | 2026-11-23 | Vecteurs de référence du PRNG dans `shared/rng_vectors.json`, générés par TS, vérifiés par les deux suites de tests. | Une seule source de vérité pour la parité Dart ↔ TS. |
| 7 | 2026-11-23 | Fichiers ARB dans `lib/core/l10n/`, le français est la langue modèle. | Langue principale du produit. Le code généré (`app_localizations*.dart`) est commis pour que le projet compile sans étape préalable. |
| 8 | 2026-11-23 | Choix de langue gardé en mémoire (Riverpod) en Phase 0. | Il sera persisté sur le profil utilisateur en Phase 3. |
| 9 | 2026-11-23 | Polices embarquées dans `assets/fonts/` (pas de `google_fonts`). | Pas de téléchargement au lancement, démarrage < 2 s, fonctionne hors ligne. |
| 10 | 2026-11-23 | Projet Firebase local `demo-onegame`. | Les émulateurs tournent sans identifiants. Le vrai projet n'arrive qu'en Phase 6. |
| 11 | 2026-11-23 | Chaque mini-jeu = une simulation **Dart pure** (`GameSim`, testable sans Flame) + un rendu Canvas. Flame sert de boucle de jeu (`MiniGame`), de surface de rendu et d'audio. | Tests headless de score et de déterminisme, rejeu serveur possible en v2. |
| 12 | 2026-11-23 | Monde logique fixe **360 × 640** (9:16) mis à l'échelle et centré (letterbox). | Même niveau et même géométrie pour tous les écrans = équité. |
| 13 | 2026-11-23 | Entrées brutes (`Listener` Flutter) mises en file puis appliquées **au début du pas fixe suivant**, journalisées avec le numéro de pas. | Déterminisme : la simulation ne voit les entrées qu'aux frontières de pas. |
| 14 | 2026-11-23 | Pas d'interpolation du rendu : la logique tourne à 120 Hz, au-dessus de la fréquence d'affichage. | Interpolation inutile à 120 Hz ; simplicité. |
| 15 | 2026-11-23 | Application en arrière-plan pendant une partie : au retour, la simulation est rattrapée (`fastForward`) sans entrée jusqu'au temps écoulé. | « Pause interdite, le chrono continue » (5.2). |
| 16 | 2026-11-23 | Noms, règles et lignes de partage via des méthodes `name(l10n)`, `rule(l10n)`, `shareLine(l10n, stats)` au lieu de clés l10n en chaîne. | Le gen-l10n Dart ne permet pas la recherche par clé ; le compilateur vérifie tout. |
| 17 | 2026-11-23 | Remote Config abstrait derrière `TuningRepository` ; valeurs par défaut dans `defaultTuning` de chaque jeu. | Le vrai Remote Config arrive avec les identifiants Firebase (Phase 6). |
| 18 | 2026-11-23 | Préférences (son, vibrations, réduire les animations) stockées avec `shared_preferences`. | Réglages locaux à l'appareil. |
| 19 | 2026-11-23 | Les délégués de localisation sont fournis par `appLocalizationsDelegates` (et non `AppLocalizations.localizationsDelegates`). | Le code généré pointe encore vers les classes Material/Cupertino dépréciées de `flutter_localizations`. |
| 20 | 2026-11-23 | Forge2D 0.15 = liaison native vers **Box2D v3** (compilée par les build hooks). Échelle 40 px = 1 m. `initializeForge2D()` appelé dans `main()` et dans `test/flutter_test_config.dart`. | Box2D v3 vise le déterminisme multiplateforme ; il demande des objets de 0,1 à 10 m. |
| 21 | 2026-11-23 | Mini-golf : 24 modules de parcours (miroir possible ⇒ 48 variantes), 2 bandes au trou 1, 3 aux trous 2 et 3 ; par = 2 + ⌈difficulté / 2⌉ borné à [2, 4] ; 8 coups max par trou (au-delà : par + 3). | Partie bornée dans le temps ; le plafond de coups évite qu'un trou bloque la partie. |
| 22 | 2026-11-23 | Les textes affichés *dans* le canvas des jeux sont neutres (chiffres, « PAR », emoji). | Les simulations n'ont pas accès à la localisation ; tout le reste passe par l'ARB. |
| 23 | 2026-11-23 | Penalty : 5 tirs puis **mort subite = on continue tant qu'on marque** (10 tirs max), puis 5 arrêts. Espace du but normalisé (u ∈ [-1, 1], v ∈ [0, 1]) ; lucarne = \|u\| > 0,62 et v > 0,62 ; poteau = bande ±0,05 autour des montants / de la barre, rentrant ou non selon la seed. | « Mort subite » sans adversaire tireur : version la plus simple qui récompense la régularité. |
| 24 | 2026-11-23 | Basket : vue de profil, gravité Box2D, panier = franchissement du plan de l'arceau vers le bas entre les deux bords ; swish = aucun contact avec arceau / planche ; multiplicateur ×2 actif dès que la série atteint 3 (avant le tir) ; coup d'éclat « EN FEU » à 5 paniers d'affilée. Le spot change à chaque tir. | Le cahier des charges ne nomme pas de coup d'éclat pour le basket. |
| 25 | 2026-11-23 | Les libellés de coups d'éclat sont déclarés par chaque jeu (`highlightLabels`), et un test vérifie que chaque dossier de `lib/games/` est enregistré dans `GameRegistry`. | Un registre central modifié à la main s'était désynchronisé (mini-golf et penalty non enregistrés jusqu'à ce commit). |
| 26 | 2026-11-23 | Bowling : vue de dessus, quilles = disques Box2D ; une quille est « tombée » si elle a bougé de plus de 6 px ou quitté la piste. 5e frame = règles de la 10e frame (jusqu'à 3 lancers). Pas de modificateur (aucun listé en section 8). | Lecture simple et crédible en 2D vue de dessus. |
