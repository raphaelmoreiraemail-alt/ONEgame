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
- [ ] 18. App Check, Crashlytics, Analytics.
- [ ] 19. Icône, écran de lancement, fiches stores, confidentialité.
- [ ] 20. Builds release, checklist de publication.
