/// Official ten-pin scoring, generalised to [frames] frames (the last frame
/// follows 10th-frame rules: up to 3 rolls after a strike or spare).
///
/// Returns the cumulative total after each frame, or null when a frame is
/// not resolved yet (pending rolls or bonus).
List<int?> bowlingTotals(List<int> rolls, {int frames = 5}) {
  final out = <int?>[];
  var i = 0;
  var total = 0;
  for (var f = 0; f < frames; f++) {
    final last = f == frames - 1;
    if (i >= rolls.length) {
      out.add(null);
      continue;
    }
    if (rolls[i] == 10 && !last) {
      if (i + 2 < rolls.length) {
        total += 10 + rolls[i + 1] + rolls[i + 2];
        out.add(total);
      } else {
        out.add(null);
      }
      i += 1;
      continue;
    }
    if (last) {
      final need =
          (rolls[i] == 10 ||
              (i + 1 < rolls.length && rolls[i] + rolls[i + 1] >= 10))
          ? 3
          : 2;
      if (i + need <= rolls.length) {
        for (var k = 0; k < need; k++) {
          total += rolls[i + k];
        }
        out.add(total);
      } else {
        out.add(null);
      }
      i += need;
      continue;
    }
    if (i + 1 >= rolls.length) {
      out.add(null);
      i += 2;
      continue;
    }
    final frame = rolls[i] + rolls[i + 1];
    if (frame == 10) {
      if (i + 2 < rolls.length) {
        total += 10 + rolls[i + 2];
        out.add(total);
      } else {
        out.add(null);
      }
    } else {
      total += frame;
      out.add(total);
    }
    i += 2;
  }
  return out;
}

/// Latest resolved total.
int bowlingResolved(List<int> rolls, {int frames = 5}) {
  var best = 0;
  for (final t in bowlingTotals(rolls, frames: frames)) {
    if (t == null) break;
    best = t;
  }
  return best;
}
