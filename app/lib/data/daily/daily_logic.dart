/// Dart port of `functions/src/core/daily.ts`, used by the local / demo
/// backend. Kept identical to the server through `shared/daily_vectors.json`.
library;

import 'dart:math' as math;

import '../../core/rng/seeded_random.dart';
import '../../core/time/regions.dart';
import '../../games/common/game_types.dart';
import '../../games/common/mini_game_definition.dart';
import '../../games/game_registry.dart';

class DailyChallenge {
  const DailyChallenge({
    required this.dayKey,
    required this.gameId,
    required this.seed,
    required this.modifierId,
    required this.alertAt,
    required this.gameVersion,
  });

  final String dayKey;
  final String gameId;
  final int seed;
  final String? modifierId;
  final Map<Region, DateTime> alertAt;
  final int gameVersion;
}

typedef HistoryEntry = ({String dayKey, String gameId});

const int alertStartHour = 10;
const int alertEndHour = 21;
const double modifierChance = 1 / 3;

GameCategory? _categoryOf(String id, List<MiniGameDefinition> catalog) {
  for (final g in catalog) {
    if (g.id == id) return g.category;
  }
  return null;
}

/// See `pickGame` in daily.ts for the rules.
String pickGame(
  String dayKey,
  List<HistoryEntry> history,
  SeededRandom rng, {
  Map<String, num> weights = const {},
  List<MiniGameDefinition> catalog = GameRegistry.all,
}) {
  num w(String id) => weights[id] ?? 1;
  final enabled = catalog.where((g) => w(g.id) > 0).toList();
  final dow = dayOfWeek(dayKey);
  final recent6 = {
    for (final h in history.skip(math.max(0, history.length - 6))) h.gameId,
  };
  final last = history.isEmpty ? null : history.last;
  GameCategory? twoSameCat;
  if (history.length >= 2) {
    final a = _categoryOf(history[history.length - 2].gameId, catalog);
    final b = _categoryOf(history.last.gameId, catalog);
    if (a == b) twoSameCat = b;
  }
  final lastIsSport =
      last != null && _categoryOf(last.gameId, catalog) == GameCategory.sport;

  bool hard(MiniGameDefinition g) =>
      (dow != 0 || g.category == GameCategory.sport) && g.id != last?.gameId;
  bool rule3(MiniGameDefinition g) => !recent6.contains(g.id);
  bool rule4(MiniGameDefinition g) => g.category != twoSameCat;
  bool rule5(MiniGameDefinition g) =>
      !(dow == 6 && lastIsSport && g.category == GameCategory.sport);

  final attempts = <bool Function(MiniGameDefinition)>[
    (g) => hard(g) && rule3(g) && rule4(g) && rule5(g),
    (g) => hard(g) && rule3(g) && rule4(g),
    (g) => hard(g) && rule4(g),
    hard,
    (g) => dow != 0 || g.category == GameCategory.sport,
    (_) => true,
  ];
  for (var i = 0; i < attempts.length; i++) {
    var pool = enabled.where(attempts[i]).toList();
    if (pool.isEmpty) continue;
    if (i >= 2) {
      int lastSeen(String id) {
        for (var k = history.length - 1; k >= 0; k--) {
          if (history[k].gameId == id) return k;
        }
        return -1;
      }

      final oldest = pool.map((g) => lastSeen(g.id)).reduce(math.min);
      pool = pool.where((g) => lastSeen(g.id) == oldest).toList();
    }
    pool.sort((a, b) => _jsCompare(a.id, b.id));
    final total = pool.fold<num>(0, (s, g) => s + w(g.id));
    var x = rng.nextDouble() * total;
    for (final g in pool) {
      x -= w(g.id);
      if (x < 0) return g.id;
    }
    return pool.last.id;
  }
  throw StateError('empty catalog');
}

/// `localeCompare` on ASCII ids behaves like a plain comparison.
int _jsCompare(String a, String b) => a.compareTo(b);

DateTime alertTime(String dayKey, Region region, SeededRandom rng) {
  final (y, m, d) = parseDayKey(dayKey);
  const span = (alertEndHour - alertStartHour) * 3600;
  final s = rng.nextInt(span);
  return zonedToUtc(
    region.location,
    y,
    m,
    d,
    alertStartHour + s ~/ 3600,
    (s % 3600) ~/ 60,
    s % 60,
  );
}

DailyChallenge generateDaily(
  String dayKey,
  List<HistoryEntry> history,
  int masterSeed, {
  Map<String, num> weights = const {},
  List<MiniGameDefinition> catalog = GameRegistry.all,
}) {
  final gameId = pickGame(
    dayKey,
    history,
    SeededRandom.derive(masterSeed, 'pick'),
    weights: weights,
    catalog: catalog,
  );
  final game = catalog.firstWhere((g) => g.id == gameId);
  final mr = SeededRandom.derive(masterSeed, 'modifier');
  String? modifier;
  final mods = game.supportedModifiers.toList()..sort();
  if (mr.chance(modifierChance) && mods.isNotEmpty) modifier = mr.pick(mods);
  return DailyChallenge(
    dayKey: dayKey,
    gameId: gameId,
    seed: SeededRandom.derive(masterSeed, 'seed').nextUint32(),
    modifierId: modifier,
    alertAt: {
      for (final r in Region.values)
        r: alertTime(
          dayKey,
          r,
          SeededRandom.derive(masterSeed, 'alert:${r.name}'),
        ),
    },
    gameVersion: game.rulesVersion,
  );
}

int localMasterSeed(String dayKey) => fnv1a32('onegame:local:$dayKey');

/// Local / demo schedule from [epoch] to [dayKey] (inclusive).
List<DailyChallenge> localSchedule(String epoch, String dayKey) {
  final out = <DailyChallenge>[];
  final history = <HistoryEntry>[];
  for (var k = epoch; k.compareTo(dayKey) <= 0; k = addDays(k, 1)) {
    final d = generateDaily(
      k,
      history.sublist(math.max(0, history.length - 14)),
      localMasterSeed(k),
    );
    out.add(d);
    history.add((dayKey: k, gameId: d.gameId));
  }
  return out;
}
