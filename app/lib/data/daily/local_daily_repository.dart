import 'dart:convert';
import 'dart:math' as math;

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/time/clock.dart';
import '../../core/time/regions.dart';
import '../../games/common/game_types.dart';
import '../../games/game_registry.dart';
import 'daily_logic.dart';
import 'daily_repository.dart';
import 'models.dart';
import 'streak.dart' as st;
import 'streak.dart' show StreakState;

/// On-device backend: the same rules as the Cloud Functions, with the daily
/// challenge derived from the day key. Used until the Firebase project
/// exists, and for offline demos. Not secret: anyone could compute the game
/// of tomorrow, which is fine for a demo.
class LocalDailyRepository implements DailyRepository {
  LocalDailyRepository(this._prefs, this._clock, Region initialRegion) {
    _region = Region.byName(_prefs.getString(_kRegion)) ?? initialRegion;
  }

  /// First day of the local schedule.
  static const epoch = '2026-11-01';
  static const onTimeWindow = Duration(seconds: 120);
  static const regionCooldown = Duration(days: 30);

  static const _kRegion = 'local.region';
  static const _kRegionChanged = 'local.regionChangedAt';
  static const _kAttempts = 'local.attempts';
  static const _kStreak = 'local.streak';
  static const _kBadges = 'local.badges';
  static const _kGames = 'local.gamesPlayed';

  final SharedPreferences _prefs;
  final Clock _clock;
  late Region _region;
  final Map<String, DailyChallenge> _cache = {};

  @override
  Region get region => _region;

  @override
  DateTime? get regionChangedAt {
    final ms = _prefs.getInt(_kRegionChanged);
    return ms == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
  }

  @override
  Future<void> setRegion(Region region) async {
    if (region == _region) return;
    final last = regionChangedAt;
    final now = _clock.now();
    if (last != null && now.difference(last) < regionCooldown) {
      throw RegionCooldown(last.add(regionCooldown));
    }
    _region = region;
    await _prefs.setString(_kRegion, region.name);
    await _prefs.setInt(_kRegionChanged, now.millisecondsSinceEpoch);
  }

  String get _today => dayKeyFor(_clock.now(), _region);

  DailyChallenge _daily(String dayKey) {
    final hit = _cache[dayKey];
    if (hit != null) return hit;
    for (final d in localSchedule(
      epoch,
      dayKey.compareTo(epoch) < 0 ? epoch : dayKey,
    )) {
      _cache[d.dayKey] = d;
    }
    return _cache[dayKey] ?? _cache[epoch]!;
  }

  Map<String, Map<String, dynamic>> _attempts() {
    final raw = _prefs.getString(_kAttempts);
    if (raw == null) return {};
    return (jsonDecode(raw) as Map<String, dynamic>).map(
      (k, v) => MapEntry(k, Map<String, dynamic>.from(v as Map)),
    );
  }

  Future<void> _saveAttempts(Map<String, Map<String, dynamic>> a) =>
      _prefs.setString(_kAttempts, jsonEncode(a));

  StreakState get _streak {
    final raw = _prefs.getString(_kStreak);
    return raw == null
        ? const StreakState()
        : StreakState.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> _saveStreak(StreakState s) =>
      _prefs.setString(_kStreak, jsonEncode(s.toJson()));

  List<String> get _badges => _prefs.getStringList(_kBadges) ?? const [];

  ProfileSummary _summary(String today) {
    final s = st.grantMonthlyJoker(_streak, today);
    return ProfileSummary(
      streak: st.effectiveStreak(s, today),
      bestStreak: s.bestStreak,
      jokers: s.jokers,
      jokerAvailable: st.jokerCase(s, today) != null,
      savedDays: s.savedDays,
      badges: _badges,
    );
  }

  @override
  Future<TodayInfo> getToday() async {
    final now = _clock.now();
    final today = _today;
    final d = _daily(today);
    await _finalizeLost(today, now);
    final alert = d.alertAt[_region]!;
    if (now.isBefore(alert)) {
      return TodayInfo(
        kind: TodayKind.waiting,
        serverNow: now,
        region: _region,
        dayKey: today,
        profile: _summary(today),
      );
    }
    final a = _attempts()[today];
    return TodayInfo(
      kind: TodayKind.open,
      serverNow: now,
      region: _region,
      dayKey: today,
      gameId: d.gameId,
      seed: d.seed,
      modifierId: d.modifierId,
      alertAt: alert,
      attempt: a == null ? null : AttemptInfo.fromJson(a),
      profile: _summary(today),
    );
  }

  Future<void> _finalizeLost(String today, DateTime now) async {
    final all = _attempts();
    final a = all[today];
    if (a == null || a['status'] != 'started') return;
    final game = GameRegistry.byId(a['gameId'] as String)!;
    final started = DateTime.fromMillisecondsSinceEpoch(
      a['startedAt'] as int,
      isUtc: true,
    );
    final limit = started.add(game.maxDuration + const Duration(seconds: 15));
    if (now.isAfter(limit)) {
      a
        ..['status'] = 'lost'
        ..['score'] = a['partialScore'] ?? 0;
      await _saveAttempts(all);
      await _record(
        today,
        a['onTime'] as bool,
        a['gameId'] as String,
        const [],
      );
    }
  }

  @override
  Future<StartedAttempt> startAttempt() async {
    final now = _clock.now();
    final today = _today;
    final d = _daily(today);
    final alert = d.alertAt[_region]!;
    if (now.isBefore(alert)) throw StateError('alarm-not-rung');
    final all = _attempts();
    if (all.containsKey(today)) throw const AttemptAlreadyExists();
    final onTime = now.difference(alert) <= onTimeWindow;
    all[today] = {
      'startedAt': now.millisecondsSinceEpoch,
      'onTime': onTime,
      'status': 'started',
      'gameId': d.gameId,
      'startDelayMs': now.difference(alert).inMilliseconds,
    };
    await _saveAttempts(all);
    return StartedAttempt(
      dayKey: today,
      gameId: d.gameId,
      seed: d.seed,
      modifierId: d.modifierId,
      onTime: onTime,
      startDelay: now.difference(alert),
    );
  }

  @override
  Future<SubmitOutcome?> submit(
    GameResult result, {
    bool partial = false,
  }) async {
    final today = _today;
    final all = _attempts();
    final a = all[today];
    if (a == null || a['status'] != 'started' || a['gameId'] != result.gameId) {
      return null;
    }
    if (partial) {
      a['partialScore'] = result.score;
      await _saveAttempts(all);
      return null;
    }
    a
      ..['status'] = 'finished'
      ..['score'] = result.score
      ..['finishedAt'] = _clock.now().millisecondsSinceEpoch;
    await _saveAttempts(all);
    return _record(
      today,
      a['onTime'] as bool,
      result.gameId,
      result.highlights,
      startDelayMs: a['startDelayMs'] as int? ?? 1 << 30,
    );
  }

  Future<SubmitOutcome> _record(
    String dayKey,
    bool onTime,
    String gameId,
    List<String> highlights, {
    int startDelayMs = 1 << 30,
  }) async {
    final s = st.recordPlay(_streak, dayKey, onTime);
    await _saveStreak(s);
    final games = {...?_prefs.getStringList(_kGames), gameId}.toList();
    await _prefs.setStringList(_kGames, games);
    final owned = _badges;
    final earned = <String>[];
    void add(String b, bool cond) {
      if (cond && !owned.contains(b) && !earned.contains(b)) earned.add(b);
    }

    add('first_day', true);
    add('week', s.streak >= 7);
    add('month', s.streak >= 30);
    const map = {
      'ace': 'ace',
      'panenka': 'panenka',
      'carreau': 'carreau',
      'oneEighty': 'one_eighty',
    };
    for (final h in highlights) {
      final b = map[h];
      if (b != null) add(b, true);
    }
    add('early_bird', onTime && startDelayMs <= 10000);
    add('all_games', games.length >= math.max(24, GameRegistry.all.length));
    await _prefs.setStringList(_kBadges, [...owned, ...earned]);
    return SubmitOutcome(
      streak: s.streak,
      bestStreak: s.bestStreak,
      newBadges: earned,
    );
  }

  @override
  Future<ProfileSummary> useJoker() async {
    final today = _today;
    await _saveStreak(st.useJoker(_streak, today));
    return _summary(today);
  }

  @override
  Future<List<DayRecord>> history({int days = 112}) async {
    final today = _today;
    final all = _attempts();
    final saved = _streak.savedDays.toSet();
    final out = <DayRecord>[];
    for (var i = 0; i < days; i++) {
      final k = addDays(today, -i);
      final a = all[k];
      if (a == null) {
        if (i == 0) continue; // today is not over yet
        out.add(
          DayRecord(
            dayKey: k,
            status: saved.contains(k) ? DayStatus.saved : DayStatus.missed,
          ),
        );
        continue;
      }
      if (a['status'] == 'started') continue;
      final onTime = a['onTime'] as bool;
      out.add(
        DayRecord(
          dayKey: k,
          status: saved.contains(k)
              ? DayStatus.saved
              : (onTime ? DayStatus.onTime : DayStatus.late),
          gameId: a['gameId'] as String?,
          score: a['score'] as int?,
        ),
      );
    }
    return out;
  }

  @override
  Future<Set<String>> releasedGames() async {
    final today = _today;
    final out = <String>{};
    for (var k = epoch; k.compareTo(today) < 0; k = addDays(k, 1)) {
      out.add(_daily(k).gameId);
    }
    if (_attempts()[today]?['status'] != null &&
        _attempts()[today]!['status'] != 'started') {
      out.add(_daily(today).gameId);
    }
    return out;
  }

  @override
  Future<List<(DateTime, String, String?)>> upcomingAlerts({
    int days = 7,
  }) async {
    final now = _clock.now();
    final today = _today;
    return [
      for (var i = 0; i < days; i++)
        if (_daily(addDays(today, i)).alertAt[_region]!.isAfter(now))
          (
            _daily(addDays(today, i)).alertAt[_region]!,
            _daily(addDays(today, i)).gameId,
            _daily(addDays(today, i)).modifierId,
          ),
    ];
  }
}
