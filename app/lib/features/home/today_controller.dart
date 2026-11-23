import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/backend/backend.dart';
import '../../core/time/clock.dart';
import '../../data/daily/models.dart';
import '../../games/common/game_types.dart';

/// Loads `getToday`, corrects the device clock with the server time and
/// starts / submits the official attempt.
class TodayController extends AsyncNotifier<TodayInfo> {
  Duration _offset = Duration.zero;

  /// Device clock corrected with the server time.
  DateTime now() => ref.read(clockProvider).now().add(_offset);

  @override
  Future<TodayInfo> build() async {
    final t = await ref.read(dailyRepositoryProvider).getToday();
    _offset = t.serverNow.difference(ref.read(clockProvider).now());
    return t;
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(build);
  }

  Future<StartedAttempt> start() =>
      ref.read(dailyRepositoryProvider).startAttempt();

  Future<SubmitOutcome?> submit(GameResult r, {bool partial = false}) async {
    final out = await ref
        .read(dailyRepositoryProvider)
        .submit(r, partial: partial);
    if (!partial) {
      ref.read(lastOutcomeProvider.notifier).set(out);
      unawaited(refresh());
    }
    return out;
  }

  Future<void> spendJoker() async {
    await ref.read(dailyRepositoryProvider).useJoker();
    await refresh();
  }
}

final todayProvider = AsyncNotifierProvider<TodayController, TodayInfo>(
  TodayController.new,
);

class LastOutcome extends Notifier<SubmitOutcome?> {
  @override
  SubmitOutcome? build() => null;

  void set(SubmitOutcome? v) => state = v;
}

/// Outcome of the last official submission (streak, new badges).
final lastOutcomeProvider = NotifierProvider<LastOutcome, SubmitOutcome?>(
  LastOutcome.new,
);
