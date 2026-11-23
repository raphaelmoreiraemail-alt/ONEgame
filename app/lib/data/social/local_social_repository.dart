import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/rng/seeded_random.dart';
import '../../core/time/clock.dart';
import '../../core/time/regions.dart';
import '../../games/game_registry.dart';
import '../daily/daily_logic.dart';
import '../daily/daily_repository.dart';
import '../daily/local_daily_repository.dart';
import '../daily/models.dart';
import 'models.dart';
import 'pseudo.dart';
import 'social_repository.dart';

/// Local demo of the social features: simulated players (clearly flagged
/// as demo) so that leaderboards and the feed can be tried without a server.
class LocalSocialRepository implements SocialRepository {
  LocalSocialRepository(this._prefs, this._daily, this._clock, this._banned);

  static const _kPseudo = 'local.pseudo';
  static const _kFriends = 'local.friends';
  static const _kReactions = 'local.reactions';
  static const meUid = 'me';
  static const _frenchSpeaking = {'FR', 'BE', 'CH', 'CA', 'MA', 'SN'};
  static const _countries = [
    'FR',
    'FR',
    'FR',
    'BE',
    'CH',
    'CA',
    'US',
    'GB',
    'DE',
    'ES',
    'JP',
    'MA',
    'SN',
  ];

  final SharedPreferences _prefs;
  final DailyRepository _daily;
  final Clock _clock;
  final List<String> _banned;

  /// 240 deterministic demo players.
  static final List<
    ({String uid, String pseudo, String country, Region region, double skill})
  >
  demoPlayers = () {
    const a = [
      'Lu',
      'Ma',
      'Za',
      'No',
      'Ti',
      'Ka',
      'Ro',
      'Be',
      'Sa',
      'Fe',
      'Mi',
      'Jo',
      'Pa',
      'Li',
      'Vi',
      'Ga',
    ];
    const b = [
      'na',
      'lo',
      'ri',
      'xo',
      'mi',
      'ne',
      'ka',
      'tou',
      'zo',
      'ly',
      'ra',
      'nou',
      'vi',
      'do',
    ];
    final r = SeededRandom(424242);
    return List.generate(240, (i) {
      final name =
          '${r.pick(a)}${r.pick(b)}${r.chance(0.5) ? r.pick(b) : ''}${r.intInRange(1, 99)}';
      return (
        uid: 'demo$i',
        pseudo: name,
        country: _countries[r.nextInt(_countries.length)],
        region: r.chance(0.7) ? Region.europe : Region.values[r.nextInt(4)],
        skill: r.doubleInRange(0.12, 0.8),
      );
    });
  }();

  @override
  bool get isDemo => true;

  @override
  String? get pseudo => _prefs.getString(_kPseudo);

  @override
  Future<void> claimPseudo(String p) async {
    final problem = checkPseudo(p, _banned);
    if (problem != null) throw PseudoRejected(problem.name);
    if (demoPlayers.any((d) => d.pseudo.toLowerCase() == p.toLowerCase())) {
      throw const PseudoRejected('taken');
    }
    await _prefs.setString(_kPseudo, p);
  }

  Map<String, String> get _friendStatus {
    final raw = _prefs.getString(_kFriends);
    if (raw == null) {
      // Five demo friends to start with.
      return {for (final d in demoPlayers.take(5)) d.uid: 'accepted'};
    }
    return Map<String, String>.from(jsonDecode(raw) as Map);
  }

  Future<void> _saveFriends(Map<String, String> m) =>
      _prefs.setString(_kFriends, jsonEncode(m));

  @override
  Future<List<Friend>> friends() async => [
    for (final e in _friendStatus.entries)
      Friend(
        uid: e.key,
        pseudo: demoPlayers.firstWhere((d) => d.uid == e.key).pseudo,
        status: e.value == 'accepted'
            ? FriendStatus.accepted
            : FriendStatus.pending,
        demo: true,
      ),
  ];

  @override
  Future<bool> sendRequest(String p) async {
    final d = demoPlayers.where(
      (d) => d.pseudo.toLowerCase() == p.toLowerCase(),
    );
    if (d.isEmpty) throw const PseudoRejected('not-found');
    final m = _friendStatus..[d.first.uid] = 'accepted';
    await _saveFriends(m);
    return true;
  }

  @override
  Future<void> respond(String uid, {required bool accept}) async {
    final m = _friendStatus;
    if (accept) {
      m[uid] = 'accepted';
    } else {
      m.remove(uid);
    }
    await _saveFriends(m);
  }

  @override
  Future<void> removeFriend(String uid) async {
    await _saveFriends(_friendStatus..remove(uid));
  }

  @override
  Future<String> createInvite() async {
    final r = SeededRandom(_clock.now().millisecondsSinceEpoch & 0xFFFFFFFF);
    const alphabet = '23456789ABCDEFGHJKLMNPQRSTUVWXYZ';
    return List.generate(8, (_) => alphabet[r.nextInt(alphabet.length)]).join();
  }

  @override
  Future<String?> acceptInvite(String code) async =>
      throw const PseudoRejected('not-found');

  @override
  Future<void> registerPhone(String hash) async {}

  @override
  Future<int> matchContacts(List<String> hashes) async => 0;

  final Map<String, DailyChallenge> _challenges = {};

  DailyChallenge _challenge(String dayKey) => _challenges.putIfAbsent(
    dayKey,
    () => localSchedule(LocalDailyRepository.epoch, dayKey).last,
  );

  /// Simulated official result of a demo player, null if they did not play.
  ({int score, bool onTime})? _demoScore(int index, String dayKey) {
    final d = demoPlayers[index];
    final c = _challenge(dayKey);
    final def = GameRegistry.byId(c.gameId)!;
    final now = _clock.now();
    if (now.isBefore(c.alertAt[d.region]!.add(const Duration(minutes: 2)))) {
      return null;
    }
    final r = SeededRandom.derive(fnv1a32(dayKey), d.uid);
    if (!r.chance(0.82)) return null;
    final onTime = r.chance(0.85);
    final b = def.scoreBounds;
    final span = (b.max - b.min) * 0.6;
    final v = (d.skill * r.doubleInRange(0.6, 1.25)).clamp(0.0, 1.0);
    return (score: (b.min + span * v).round(), onTime: onTime);
  }

  Future<({int score, bool onTime})?> _myScore(String dayKey) async {
    for (final rec in await _daily.history(days: 30)) {
      if (rec.dayKey == dayKey && rec.score != null) {
        return (score: rec.score!, onTime: rec.status != DayStatus.late);
      }
    }
    final t = await _daily.getToday();
    final a = t.attempt;
    if (t.dayKey == dayKey && a != null && a.status != AttemptStatus.started) {
      return (score: a.score ?? 0, onTime: a.onTime);
    }
    return null;
  }

  List<BoardRow> _rank(List<BoardRow> rows) {
    rows.sort((a, b) => b.score.compareTo(a.score));
    final out = <BoardRow>[];
    for (var i = 0; i < rows.length; i++) {
      final rank = i > 0 && rows[i].score == rows[i - 1].score
          ? out[i - 1].rank
          : i + 1;
      final r = rows[i];
      out.add(
        BoardRow(
          uid: r.uid,
          pseudo: r.pseudo,
          score: r.score,
          rank: rank,
          onTime: r.onTime,
          country: r.country,
          isMe: r.isMe,
          demo: r.demo,
        ),
      );
    }
    return out;
  }

  @override
  Future<Board> leaderboard(Scope scope, String dayKey) async {
    final friends = {
      for (final e in _friendStatus.entries)
        if (e.value == 'accepted') e.key,
    };
    const myCountry = 'FR';
    final myRegion = _daily.region;
    final rows = <BoardRow>[];

    Future<void> addMe(String day, {bool weekly = false}) async {
      final s = await _myScore(day);
      if (s == null) return;
      if (!weekly && scope != Scope.friends && !s.onTime) return;
      rows.add(
        BoardRow(
          uid: meUid,
          pseudo: pseudo,
          score: s.score,
          rank: 0,
          onTime: s.onTime,
          country: myCountry,
          isMe: true,
        ),
      );
    }

    if (scope == Scope.weekly) {
      final (y, m, d) = parseDayKey(dayKey);
      final monday = DateTime.utc(
        y,
        m,
        d,
      ).subtract(Duration(days: DateTime.utc(y, m, d).weekday - 1));
      final days =
          [
            for (var i = 0; i < 7; i++)
              dayKeyOf(
                monday.add(Duration(days: i)).year,
                monday.add(Duration(days: i)).month,
                monday.add(Duration(days: i)).day,
              ),
          ].where(
            (k) =>
                k.compareTo(dayKey) <= 0 &&
                k.compareTo(LocalDailyRepository.epoch) >= 0,
          );
      final totals = <String, int>{};
      for (final day in days) {
        for (var i = 0; i < demoPlayers.length; i++) {
          final s = _demoScore(i, day);
          if (s != null && s.onTime) {
            totals[demoPlayers[i].uid] =
                (totals[demoPlayers[i].uid] ?? 0) + s.score;
          }
        }
        final me = await _myScore(day);
        if (me != null && me.onTime) {
          totals[meUid] = (totals[meUid] ?? 0) + me.score;
        }
      }
      for (final e in totals.entries) {
        final d = demoPlayers.where((p) => p.uid == e.key).firstOrNull;
        rows.add(
          BoardRow(
            uid: e.key,
            pseudo: d?.pseudo ?? pseudo,
            score: e.value,
            rank: 0,
            country: d?.country ?? myCountry,
            isMe: e.key == meUid,
            demo: d != null,
          ),
        );
      }
    } else {
      for (var i = 0; i < demoPlayers.length; i++) {
        final d = demoPlayers[i];
        if (scope == Scope.friends && !friends.contains(d.uid)) continue;
        if (scope == Scope.country && d.country != myCountry) continue;
        if (scope == Scope.region && d.region != myRegion) continue;
        if (scope == Scope.language && !_frenchSpeaking.contains(d.country)) {
          continue;
        }
        final s = _demoScore(i, dayKey);
        if (s == null || (scope != Scope.friends && !s.onTime)) continue;
        rows.add(
          BoardRow(
            uid: d.uid,
            pseudo: d.pseudo,
            score: s.score,
            rank: 0,
            onTime: s.onTime,
            country: d.country,
            demo: true,
          ),
        );
      }
      await addMe(dayKey);
    }
    final ranked = _rank(rows);
    final me = ranked.where((r) => r.isMe).firstOrNull;
    int? pct;
    if (me != null && scope != Scope.friends && ranked.length > 1) {
      final above = ranked.where((r) => r.score > me.score).length;
      pct = ((ranked.length - 1 - above) * 100 / (ranked.length - 1)).floor();
    }
    return Board(
      top: ranked.take(100).toList(),
      me: me,
      total: ranked.length,
      percentile: pct,
    );
  }

  Map<String, String> get _myReactions {
    final raw = _prefs.getString(_kReactions);
    return raw == null ? {} : Map<String, String>.from(jsonDecode(raw) as Map);
  }

  @override
  Future<Feed> feed(String dayKey) async {
    if (await _myScore(dayKey) == null) return const Feed(locked: true);
    final mine = _myReactions;
    final c = _challenge(dayKey);
    final items = <FeedItem>[];
    for (var i = 0; i < demoPlayers.length; i++) {
      final d = demoPlayers[i];
      if (_friendStatus[d.uid] != 'accepted') continue;
      final s = _demoScore(i, dayKey);
      if (s == null) continue;
      final r = SeededRandom.derive(fnv1a32(dayKey), 'react:${d.uid}');
      final counts = <String, int>{
        for (final e in reactionEmojis)
          if (r.chance(0.3)) e: r.intInRange(1, 3),
      };
      final my = mine['$dayKey/${d.uid}'];
      if (my != null) counts[my] = (counts[my] ?? 0) + 1;
      items.add(
        FeedItem(
          uid: d.uid,
          pseudo: d.pseudo,
          score: s.score,
          onTime: s.onTime,
          gameId: c.gameId,
          reactions: counts,
          myReaction: my,
        ),
      );
    }
    items.sort((a, b) => b.score.compareTo(a.score));
    return Feed(locked: false, items: items);
  }

  @override
  Future<void> react(String dayKey, String target, String? emoji) async {
    final m = _myReactions;
    if (emoji == null) {
      m.remove('$dayKey/$target');
    } else {
      m['$dayKey/$target'] = emoji;
    }
    await _prefs.setString(_kReactions, jsonEncode(m));
  }

  @override
  Future<void> report(String dayKey, String target) async {}
}
