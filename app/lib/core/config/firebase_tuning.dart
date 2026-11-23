import 'dart:convert';

import 'package:firebase_remote_config/firebase_remote_config.dart';

import 'tuning.dart';

/// Remote Config: parameter `games` = JSON `{ "<gameId>": { "<key>": n } }`
/// (Remote Config keys cannot contain dots, hence `games.<id>.*` is stored as
/// one JSON parameter) and `gameWeights` = JSON `{ "<gameId>": weight }`.
class FirebaseTuningRepository implements TuningRepository {
  FirebaseTuningRepository(this._rc);

  final FirebaseRemoteConfig _rc;

  static Future<FirebaseTuningRepository> create() async {
    final rc = FirebaseRemoteConfig.instance;
    await rc.setConfigSettings(
      RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 8),
        minimumFetchInterval: const Duration(hours: 1),
      ),
    );
    await rc.setDefaults({'games': '{}', 'gameWeights': '{}'});
    try {
      await rc.fetchAndActivate();
    } on Object {
      // Offline: keep the last activated values / defaults.
    }
    return FirebaseTuningRepository(rc);
  }

  Map<String, dynamic> _json(String key) {
    try {
      return jsonDecode(_rc.getString(key)) as Map<String, dynamic>;
    } on Object {
      return const {};
    }
  }

  @override
  Map<String, num> forGame(String gameId) {
    final g = _json('games')[gameId];
    if (g is! Map) return const {};
    return {
      for (final e in g.entries)
        if (e.value is num) '${e.key}': e.value as num,
    };
  }

  @override
  Map<String, num> get gameWeights => {
    for (final e in _json('gameWeights').entries)
      if (e.value is num) e.key: e.value as num,
  };
}
