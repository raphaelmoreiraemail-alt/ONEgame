import '../../core/rng/seeded_random.dart';

/// Stable fingerprint of level data, for "same seed ⇒ same level" tests.
String fingerprint(Iterable<Object?> parts) {
  final b = StringBuffer();
  for (final p in parts) {
    if (p is double) {
      b.write(p.toStringAsFixed(4));
    } else {
      b.write(p);
    }
    b.write('|');
  }
  return fnv1a32(b.toString()).toRadixString(16).padLeft(8, '0') +
      b.length.toRadixString(16);
}
