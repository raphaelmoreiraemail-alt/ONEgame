/// Dart port of `functions/src/core/pseudo.ts` (instant feedback in the
/// app; the server always re-checks).
library;

const pseudoMin = 3;
const pseudoMax = 16;
final _allowed = RegExp(r'^[A-Za-z0-9_.-]+$');

const _accents = {
  'à': 'a',
  'á': 'a',
  'â': 'a',
  'ä': 'a',
  'ã': 'a',
  'å': 'a',
  'ç': 'c',
  'è': 'e',
  'é': 'e',
  'ê': 'e',
  'ë': 'e',
  'ì': 'i',
  'í': 'i',
  'î': 'i',
  'ï': 'i',
  'ñ': 'n',
  'ò': 'o',
  'ó': 'o',
  'ô': 'o',
  'ö': 'o',
  'õ': 'o',
  'ù': 'u',
  'ú': 'u',
  'û': 'u',
  'ü': 'u',
  'ý': 'y',
  'ÿ': 'y',
};
const _leet = {
  '0': 'o',
  '1': 'i',
  '3': 'e',
  '4': 'a',
  '5': 's',
  '7': 't',
  '@': 'a',
  r'$': 's',
};

String normalizeForFilter(String s) {
  final b = StringBuffer();
  for (final ch in s.toLowerCase().split('')) {
    final c = _accents[ch] ?? _leet[ch] ?? ch;
    if (RegExp('[a-z]').hasMatch(c)) b.write(c);
  }
  return b.toString();
}

enum PseudoProblem { length, charset, offensive, taken }

PseudoProblem? checkPseudo(String p, List<String> banned) {
  if (p.length < pseudoMin || p.length > pseudoMax) return PseudoProblem.length;
  if (!_allowed.hasMatch(p)) return PseudoProblem.charset;
  final n = normalizeForFilter(p);
  for (final w in banned) {
    if (w.length <= 3 ? n == w : n.contains(w)) return PseudoProblem.offensive;
  }
  return null;
}
