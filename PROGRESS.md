# Avancement

## Phase 0 — Fondations
- [x] 1. Projet Flutter (Android + iOS) + Firebase en émulateurs (`demo-onegame`), Functions TS, règles Firestore de base, CI GitHub Actions.
- [x] 2. Thème (couleurs, Bungee + Inter, clair/sombre), l10n FR/EN (ARB), navigation go_router (4 onglets + Entraînement + Game Lab debug), Riverpod.
- [x] 3. `SeededRandom` (mulberry32) en Dart et TS + tests de parité ; `Clock` injectable + tests.

## Phase 1 — Le cadre de jeu
- [x] 4. `MiniGameDefinition`, `GameRegistry`, écran de règle + 3-2-1-GO, HUD, chrono, Résultats.
- [x] 5. Game Lab.
- [x] 6. Premier jeu : `survival` (validé de bout en bout par un test d'intégration).

## Phase 2 — Les 6 jeux phares
- [x] 7. `minigolf` · [x] 8. `penalty` · [x] 9. `basket` · [x] 10. `bowling` · [x] 11. `stack` · [x] 12. `darts`

## Phase 3 — Le quotidien
- [x] 13. Functions `createDaily`, `getToday`, `startAttempt`, `submitScore`, `pickGame`.
- [x] 14. Accueil 5 états, FCM (topics) + alarmes locales, son d'alarme.
- [x] 15. Série, joker, calendrier, records, badges.

## Phase 4 — Social
- [x] 16. Onboarding (3 écrans), pseudos, amis (pseudo, lien / QR, contacts hachés), classements (amis / pays / région / monde / hebdo), fil + réactions, carte de partage image, compte (liaison, suppression).

## Phase 5 — Reste du catalogue
- [x] 17. Les 17 jeux restants (catalogue complet : 24 jeux) + les 6 modificateurs (vent, nuit, turbo, miroir, glace, géant) sur tous les jeux listés en section 8.

## Phase 6 — Production
- [x] 18. App Check (Play Integrity / App Attest), Crashlytics, Analytics (alarm_seen, game_start, game_end, share), Remote Config (`games`, `gameWeights`). Activation finale : voir `RELEASE.md`.
- [x] 19. Icône (réveil rouge, `tools/gen_icons.py`), écran de lancement Android / iOS, fiches stores FR / EN (`docs/store/`), politique de confidentialité FR / EN (`docs/`).
- [~] 20. Signature release Android prête (`key.properties`), checklist de publication (`RELEASE.md`). **Reste à faire sur ta machine** : builds `appbundle` / `ipa` (le conteneur n'a ni SDK Android ni Xcode, et Google Maven y est bloqué).

## Après la v1 — Rendu réaliste
- [x] 21. Les 24 jeux en 3D (moteur maison `render3d.dart`, décisions 58 à 60), test d'orientation des primitives et test de rendu de chaque jeu (avec chaque modificateur). Outil d'aperçu : `PREVIEW_DIR=… PREVIEW_GAMES=… PREVIEW_SCRIPT=… flutter test test/render/preview_test.dart`.
