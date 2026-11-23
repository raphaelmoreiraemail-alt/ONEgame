/// What to play: passed to the play route.
class PlayRequest {
  const PlayRequest({
    required this.gameId,
    required this.seed,
    this.modifierId,
    this.official = false,
    this.dayKey,
    this.debug = false,
  });

  final String gameId;
  final int seed;
  final String? modifierId;

  /// Official daily attempt (one shot, never paused).
  final bool official;
  final String? dayKey;

  /// Game Lab: show FPS / bodies.
  final bool debug;
}
