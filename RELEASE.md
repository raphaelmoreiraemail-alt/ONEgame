# Mise en production — checklist

Tout le code est prêt : il reste les étapes qui demandent **tes comptes**
(Firebase / Google Cloud, Apple Developer, Google Play Console). Coche au fur
et à mesure.

## 1. Projet Firebase

- [ ] Créer le projet sur console.firebase.google.com, passer au forfait
      **Blaze** (nécessaire pour Cloud Functions, Cloud Tasks et Scheduler).
- [ ] Installer les outils : `npm i -g firebase-tools` puis
      `dart pub global activate flutterfire_cli`, `firebase login`.
- [ ] Dans `app/` : `flutterfire configure --project=<ID_DU_PROJET>
      --platforms=android,ios --android-package-name=com.raphaelmoreira.onegame
      --ios-bundle-id=com.raphaelmoreira.onegame`
      → crée `android/app/google-services.json` et
      `ios/Runner/GoogleService-Info.plist` (les plugins Gradle Firebase
      s'activent automatiquement quand le fichier est présent).
- [ ] Remplacer `demo-onegame` par l'ID du projet dans `.firebaserc`.
- [ ] Authentication → activer **Anonyme**, **Google**, **Apple**, **E-mail /
      mot de passe**.
- [ ] Firestore → créer la base (région `eur3` conseillée) puis
      `firebase deploy --only firestore` (règles + index).
- [ ] Functions → `cd functions && npm ci && firebase deploy --only functions`.
      Créer `functions/.env.<ID_DU_PROJET>` avec `ENFORCE_APP_CHECK=true`
      une fois App Check configuré (étape 2).
- [ ] Créer le premier défi sans attendre 00:05 UTC : exécuter la fonction
      planifiée `createDaily` depuis Cloud Scheduler (« Forcer l'exécution »).
- [ ] Remote Config → paramètres `games` (JSON, ex.
      `{"minigolf": {"maxShotSpeed": 900}}`) et `gameWeights` (JSON, ex.
      `{"motflash": 2, "snake": 0}`), valeurs par défaut `{}`.

## 2. Sécurité, crashs, statistiques

- [ ] App Check : Android → **Play Integrity** (empreinte SHA-256 de la clé
      d'application Play) ; iOS → **App Attest** (+ DeviceCheck en secours).
      Puis `ENFORCE_APP_CHECK=true` et redéployer les Functions.
- [ ] Crashlytics : activer dans la console. iOS : ajouter la phase de build
      d'envoi des dSYM proposée par `flutterfire configure`.
- [ ] Analytics : activé par défaut. Événements : `alarm_seen`, `game_start`
      (`official`, `on_time`), `game_end` (`score`), `share`.

## 3. Notifications (alarme)

- [ ] Apple Developer → clé **APNs** (.p8) → la téléverser dans Firebase
      (Paramètres du projet › Cloud Messaging).
- [ ] Xcode → Runner › Signing & Capabilities : **Push Notifications**,
      **Background Modes › Remote notifications**, **Time Sensitive
      Notifications**.
- [ ] Vérifier que `alarm.wav` est bien dans la cible Runner (déjà ajouté au
      projet Xcode).

## 4. Android

- [ ] Clé d'upload :
      `keytool -genkey -v -keystore ~/onegame-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload`
- [ ] `app/android/key.properties` (jamais commité) :
      `storePassword=…`, `keyPassword=…`, `keyAlias=upload`,
      `storeFile=/chemin/vers/onegame-upload.jks`.
- [ ] Build : `cd app && flutter build appbundle --release --dart-define=ONEGAME_BACKEND=firebase`.
- [ ] Play Console : fiche (`docs/store/listing-*.md`), icône
      (`docs/store/icon-1024.png` redimensionnée en 512×512), captures,
      questionnaire de classification, **sécurité des données** (voir la
      politique de confidentialité), **URL de suppression de compte**
      (exigée par Google : page web qui explique la suppression dans l'app).
- [ ] Autoriser les « alarmes exactes » : l'app déclare
      `SCHEDULE_EXACT_ALARM` (mode local) ; avec Firebase, l'alarme vient de
      FCM et cette permission peut être retirée si Google la refuse.

## 5. iOS

- [ ] App Store Connect : créer l'app (bundle `com.raphaelmoreira.onegame`).
- [ ] Build : `cd app && flutter build ipa --release --dart-define=ONEGAME_BACKEND=firebase`
      puis envoi avec Transporter / Xcode.
- [ ] Fiche, captures (6,7" et 5,5"), confidentialité (« étiquettes
      nutritionnelles » : identifiants, contenu utilisateur, données d'usage,
      diagnostics ; aucune donnée liée au suivi publicitaire).
- [ ] « Connexion avec Apple » obligatoire si Google est proposé : déjà géré.

## 6. Textes légaux

- [ ] Compléter `docs/privacy-policy-fr.md` / `-en.md` (éditeur, contact,
      date) et les publier sur une URL publique (ex. GitHub Pages).
- [ ] Renseigner cette URL dans les deux stores.

## 7. Avant d'ouvrir au public

- [ ] Tester une journée complète sur deux téléphones (une région chacun) en
      mode `firebase` : alarme reçue app fermée, JOUER dans les 2 minutes,
      retard, partie interrompue, fil des amis, partage.
- [ ] Vérifier les quotas Firestore / Functions et poser une alerte de budget
      Google Cloud.
