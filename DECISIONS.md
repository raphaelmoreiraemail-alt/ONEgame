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
