import 'package:firebase_analytics/firebase_analytics.dart';

/// Product analytics (section 18): alarm seen, game started (on time /
/// late), score, share. No-op without Firebase.
abstract class Analytics {
  Future<void> alarmSeen({required String region, required String dayKey});
  Future<void> gameStarted({
    required String gameId,
    required bool official,
    bool? onTime,
  });
  Future<void> gameEnded({
    required String gameId,
    required int score,
    required bool official,
  });
  Future<void> shared({required String gameId, required String kind});
}

class NoopAnalytics implements Analytics {
  const NoopAnalytics();

  @override
  Future<void> alarmSeen({
    required String region,
    required String dayKey,
  }) async {}
  @override
  Future<void> gameStarted({
    required String gameId,
    required bool official,
    bool? onTime,
  }) async {}
  @override
  Future<void> gameEnded({
    required String gameId,
    required int score,
    required bool official,
  }) async {}
  @override
  Future<void> shared({required String gameId, required String kind}) async {}
}

class FirebaseAnalyticsService implements Analytics {
  FirebaseAnalyticsService(this._fa);

  final FirebaseAnalytics _fa;

  @override
  Future<void> alarmSeen({required String region, required String dayKey}) =>
      _fa.logEvent(
        name: 'alarm_seen',
        parameters: {'region': region, 'day': dayKey},
      );

  @override
  Future<void> gameStarted({
    required String gameId,
    required bool official,
    bool? onTime,
  }) => _fa.logEvent(
    name: 'game_start',
    parameters: {
      'game': gameId,
      'official': official ? 1 : 0,
      if (onTime != null) 'on_time': onTime ? 1 : 0,
    },
  );

  @override
  Future<void> gameEnded({
    required String gameId,
    required int score,
    required bool official,
  }) => _fa.logEvent(
    name: 'game_end',
    parameters: {'game': gameId, 'score': score, 'official': official ? 1 : 0},
  );

  @override
  Future<void> shared({required String gameId, required String kind}) =>
      _fa.logShare(contentType: kind, itemId: gameId, method: 'system_share');
}
