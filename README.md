# OneGame

> Une alarme. Deux minutes. Un jeu.

Une fois par jour, à une heure surprise, une alarme sonne : tout le monde a 2 minutes
pour lancer le mini-jeu du jour — le même jeu, le même niveau, pour toute la planète.

## Structure

| Dossier | Contenu |
|---|---|
| `app/` | Application Flutter (Flame, Riverpod, go_router) |
| `functions/` | Cloud Functions TypeScript (Node 22) |
| `shared/` | Données partagées Dart ↔ TS (vecteurs de référence du PRNG) |
| `firestore.rules`, `firestore.indexes.json`, `firebase.json` | Config Firebase (émulateurs en local) |

## Démarrer

Prérequis : Flutter stable, Node 22.

```bash
cd app && flutter pub get && flutter run
```

### Choisir le serveur

| Mode | Commande | Usage |
|---|---|---|
| `local` (défaut) | `flutter run` | Tout tourne sur le téléphone, mêmes règles que le serveur. Idéal pour tester. |
| `emulator` | `flutter run --dart-define=ONEGAME_BACKEND=emulator` | Émulateurs Firebase lancés sur l'ordinateur (`--dart-define=ONEGAME_EMULATOR_HOST=<ip>` pour un vrai téléphone). |
| `firebase` | `flutter run --dart-define=ONEGAME_BACKEND=firebase` | Vrai projet Firebase (Phase 6). |

Tests et analyse :

```bash
cd app && flutter analyze && flutter test
cd functions && npm ci && npm run lint && npm test
cd functions && npm run test:emulators   # règles Firestore + handlers (Java requis)
```

Tout vérifier d'un coup : `tools/check.sh`.

Émulateurs Firebase (projet de démo `demo-onegame`, aucun identifiant requis) :

```bash
npx firebase-tools emulators:start
```

## Documents

- [`PROGRESS.md`](PROGRESS.md) — avancement par phase
- [`DECISIONS.md`](DECISIONS.md) — choix non couverts par le cahier des charges
- [`ASSETS.md`](ASSETS.md) — polices, sons et autres ressources, avec leurs licences
