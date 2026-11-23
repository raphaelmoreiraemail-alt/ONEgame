import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../backend/backend.dart';

/// Balancing values per game (Remote Config `games.<id>.*`).
///
/// The default implementation returns nothing, so every game uses its
/// built-in defaults. The Firebase implementation is plugged in Phase 6.
abstract class TuningRepository {
  Map<String, num> forGame(String gameId);

  /// Rotation weights (`gameWeights`), used server-side; exposed for the Lab.
  Map<String, num> get gameWeights;
}

class DefaultTuningRepository implements TuningRepository {
  const DefaultTuningRepository();

  @override
  Map<String, num> forGame(String gameId) => const {};

  @override
  Map<String, num> get gameWeights => const {};
}

final tuningProvider = Provider<TuningRepository>(
  (ref) => ref.watch(backendProvider).tuning,
);
