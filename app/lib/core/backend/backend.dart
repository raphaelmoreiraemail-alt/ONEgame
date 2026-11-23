import 'dart:convert';
import 'dart:io' show Platform;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/daily/daily_repository.dart';
import '../../data/daily/firebase_daily_repository.dart';
import '../../data/daily/local_daily_repository.dart';
import '../../data/social/firebase_social_repository.dart';
import '../../data/social/local_social_repository.dart';
import '../../data/social/social_repository.dart';
import '../time/clock.dart';
import '../time/regions.dart';

/// Which backend the app talks to, chosen at build time:
/// `flutter run --dart-define=ONEGAME_BACKEND=local|emulator|firebase`.
///
/// - `local` (default until the Firebase project exists): everything runs
///   on the device with the same rules as the server;
/// - `emulator`: Firebase emulators (`firebase emulators:start`);
/// - `firebase`: the real project (config files added in Phase 6).
enum BackendKind { local, emulator, firebase }

BackendKind get backendKind => BackendKind.values.byName(
  const String.fromEnvironment('ONEGAME_BACKEND', defaultValue: 'local'),
);

const _emulatorHost = String.fromEnvironment('ONEGAME_EMULATOR_HOST');

/// Demo project understood by the emulators (no credentials needed).
const _demoOptions = FirebaseOptions(
  apiKey: 'demo-key',
  appId: '1:1234567890:android:0000000000000000',
  messagingSenderId: '1234567890',
  projectId: 'demo-onegame',
);

class BackendServices {
  const BackendServices({
    required this.daily,
    required this.social,
    required this.kind,
    this.uid,
  });

  final DailyRepository daily;
  final SocialRepository social;
  final BackendKind kind;
  final String? uid;

  bool get usesFirebase => kind != BackendKind.local;
}

Future<BackendServices> createBackend({
  required SharedPreferences prefs,
  required Clock clock,
  required Region detectedRegion,
  required String lang,
  String? country,
}) async {
  final kind = backendKind;
  if (kind == BackendKind.local) {
    final daily = LocalDailyRepository(prefs, clock, detectedRegion);
    return BackendServices(
      kind: kind,
      daily: daily,
      social: LocalSocialRepository(
        prefs,
        daily,
        clock,
        await loadBannedWords(),
      ),
    );
  }
  await Firebase.initializeApp(
    options: kind == BackendKind.emulator ? _demoOptions : null,
  );
  final auth = FirebaseAuth.instance;
  final firestore = FirebaseFirestore.instance;
  final functions = FirebaseFunctions.instance;
  if (kind == BackendKind.emulator) {
    final host = _emulatorHost.isNotEmpty
        ? _emulatorHost
        : (Platform.isAndroid ? '10.0.2.2' : 'localhost');
    await auth.useAuthEmulator(host, 9099);
    firestore.useFirestoreEmulator(host, 8080);
    functions.useFunctionsEmulator(host, 5001);
  }
  final user = auth.currentUser ?? (await auth.signInAnonymously()).user!;
  await functions.httpsCallable('ensureProfile').call<Object?>({
    'region': detectedRegion.name,
    'lang': lang,
    'country': country,
  });
  final profile = (await firestore.doc('users/${user.uid}').get()).data() ?? {};
  final changed = profile['regionChangedAt'];
  return BackendServices(
    kind: kind,
    uid: user.uid,
    social: FirebaseSocialRepository(
      functions,
      user.uid,
      profile['pseudo'] as String?,
    ),
    daily: FirebaseDailyRepository(
      functions: functions,
      firestore: firestore,
      uid: user.uid,
      region: Region.byName(profile['region'] as String?) ?? detectedRegion,
      regionChangedAt: changed is Timestamp ? changed.toDate().toUtc() : null,
    ),
  );
}

/// Pseudo filter shared with the server (`shared/banned_words.json`).
Future<List<String>> loadBannedWords() async {
  final raw = await rootBundle.loadString('assets/data/banned_words.json');
  return [
    for (final w
        in (jsonDecode(raw) as Map<String, dynamic>)['words'] as List<dynamic>)
      '$w',
  ];
}

/// Overridden in `main()` with the services created at startup.
final backendProvider = Provider<BackendServices>(
  (ref) => throw UnimplementedError('backendProvider must be overridden'),
);

final dailyRepositoryProvider = Provider<DailyRepository>(
  (ref) => ref.watch(backendProvider).daily,
);

final socialRepositoryProvider = Provider<SocialRepository>(
  (ref) => ref.watch(backendProvider).social,
);
