import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../../core/time/regions.dart';
import '../../games/common/game_types.dart';
import 'daily_repository.dart';
import 'models.dart';

/// Cloud Functions backend (section 10.2).
class FirebaseDailyRepository implements DailyRepository {
  FirebaseDailyRepository({
    required this._functions,
    required FirebaseFirestore firestore,
    required this.uid,
    required this._region,
    this._regionChangedAt,
  }) : _db = firestore;

  final FirebaseFunctions _functions;
  final FirebaseFirestore _db;
  final String uid;
  Region _region;
  DateTime? _regionChangedAt;

  Future<Map<String, dynamic>> _call(String name, [Object? data]) async {
    final r = await _functions.httpsCallable(name).call<Object?>(data);
    return Map<String, dynamic>.from(r.data! as Map);
  }

  @override
  Region get region => _region;

  @override
  DateTime? get regionChangedAt => _regionChangedAt;

  @override
  Future<void> setRegion(Region region) async {
    try {
      await _call('setRegion', {'region': region.name});
      _region = region;
      _regionChangedAt = DateTime.now().toUtc();
    } on FirebaseFunctionsException catch (e) {
      if (e.message == 'region-cooldown') {
        throw RegionCooldown(
          (_regionChangedAt ?? DateTime.now().toUtc()).add(
            const Duration(days: 30),
          ),
        );
      }
      rethrow;
    }
  }

  @override
  Future<TodayInfo> getToday() async =>
      TodayInfo.fromJson(await _call('getToday'), _region);

  @override
  Future<StartedAttempt> startAttempt() async {
    try {
      final j = await _call('startAttempt');
      return StartedAttempt(
        dayKey: j['dayKey'] as String,
        gameId: j['gameId'] as String,
        seed: (j['seed'] as num).toInt(),
        modifierId: j['modifierId'] as String?,
        onTime: j['onTime'] as bool,
        startDelay: Duration(milliseconds: (j['startDelayMs'] as num).toInt()),
      );
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'already-exists') throw const AttemptAlreadyExists();
      rethrow;
    }
  }

  @override
  Future<SubmitOutcome?> submit(GameResult r, {bool partial = false}) async {
    final j = await _call('submitScore', {
      'score': r.score,
      'playedMs': r.playedTime.inMilliseconds,
      'inputLog': [for (final e in r.inputLog) e.toCompact()],
      'stats': r.stats,
      'highlights': r.highlights,
      'partial': partial,
    });
    if (partial) return null;
    return SubmitOutcome(
      streak: (j['streak'] as num).toInt(),
      bestStreak: (j['bestStreak'] as num).toInt(),
      newBadges: [for (final b in j['newBadges'] as List<dynamic>) '$b'],
    );
  }

  @override
  Future<ProfileSummary> useJoker() async =>
      ProfileSummary.fromJson(await _call('useJoker'));

  @override
  Future<List<DayRecord>> history({int days = 112}) async {
    final today = dayKeyFor(DateTime.now(), _region);
    final from = addDays(today, -days);
    final snap = await _db
        .collection('attempts')
        .where('uid', isEqualTo: uid)
        .where('dayKey', isGreaterThanOrEqualTo: from)
        .get();
    final user = await _db.doc('users/$uid').get();
    final streakState = user.data()?['streakState'];
    final savedRaw = streakState is Map ? streakState['savedDays'] : null;
    final saved = {
      for (final d in (savedRaw is List ? savedRaw : const <Object?>[])) '$d',
    };
    final byDay = {
      for (final d in snap.docs) d.data()['dayKey'] as String: d.data(),
    };
    final out = <DayRecord>[];
    for (var i = 0; i < days; i++) {
      final k = addDays(today, -i);
      final a = byDay[k];
      if (a == null) {
        if (i > 0) {
          out.add(
            DayRecord(
              dayKey: k,
              status: saved.contains(k) ? DayStatus.saved : DayStatus.missed,
            ),
          );
        }
        continue;
      }
      if (a['status'] == 'started') continue;
      out.add(
        DayRecord(
          dayKey: k,
          status: saved.contains(k)
              ? DayStatus.saved
              : (a['onTime'] == true ? DayStatus.onTime : DayStatus.late),
          gameId: a['gameId'] as String?,
          score: (a['score'] as num?)?.toInt(),
        ),
      );
    }
    return out;
  }

  @override
  Future<Set<String>> releasedGames() async {
    final j = await _call('releasedGames');
    return {for (final g in j['games'] as List<dynamic>) '$g'};
  }

  @override
  Future<List<(DateTime, String, String?)>> upcomingAlerts({
    int days = 7,
  }) async => const [];
}
