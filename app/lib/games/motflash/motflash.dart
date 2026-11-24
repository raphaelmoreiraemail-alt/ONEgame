import 'dart:math' as math;

import 'package:flutter/services.dart' show rootBundle;
import 'package:material_ui/material_ui.dart';

import '../../core/l10n/l10n.dart';
import '../../core/rng/seeded_random.dart';
import '../common/draw.dart';
import '../common/fingerprint.dart';
import '../common/game_sim.dart';
import '../common/game_types.dart';
import '../common/mini_game_definition.dart';

/// Embedded word lists (3–7 letters, accents removed), per language.
abstract final class Dictionary {
  static final Map<String, List<String>> _words = {};
  static final Map<String, Set<String>> _sets = {};

  static bool isLoaded(String lang) => _words.containsKey(lang);

  static void register(String lang, Iterable<String> words) {
    final list = [
      for (final w in words)
        if (w.isNotEmpty) w,
    ];
    _words[lang] = list;
    _sets[lang] = list.toSet();
  }

  static Future<void> load(String lang) async {
    if (isLoaded(lang)) return;
    register(
      lang,
      (await rootBundle.loadString('assets/data/words_$lang.txt')).split('\n'),
    );
  }

  static List<String> words(String lang) => _words[lang] ?? const [];
  static bool contains(String lang, String w) =>
      _sets[lang]?.contains(w) ?? false;
}

/// 7.22 Mot éclair — 7 letters, find as many words as possible.
class MotflashGame extends MiniGameDefinition {
  const MotflashGame();

  @override
  String get id => 'motflash';
  @override
  String get emoji => '🔤';
  @override
  GameCategory get category => GameCategory.reflexion;
  @override
  int get rulesVersion => 1;
  @override
  Set<String> get supportedModifiers => const {};
  @override
  ScoreBounds get scoreBounds => const ScoreBounds(0, 60000);

  static const points = {3: 30, 4: 60, 5: 120, 6: 250, 7: 500};

  @override
  String name(AppLocalizations l10n) => l10n.gameMotflashName;
  @override
  String rule(AppLocalizations l10n) => l10n.gameMotflashRule;

  @override
  String shareLine(AppLocalizations l10n, Map<String, num> s) => l10n
      .gameMotflashShare(s['words']?.toInt() ?? 0, s['longest']?.toInt() ?? 0);

  @override
  List<(String, String)> statRows(AppLocalizations l10n, Map<String, num> s) =>
      [
        (l10n.statWords, '${s['words'] ?? 0}'),
        (l10n.statLongest, '${s['longest'] ?? 0}'),
      ];

  @override
  Map<String, String> highlightLabels(AppLocalizations l10n) => {
    'fullWord': l10n.highlightFullWord,
  };

  @override
  Future<void> prepare(GameContext ctx) => Dictionary.load(ctx.lang);

  @override
  GameSim createSim(GameContext ctx) => MotflashSim(ctx);

  @override
  String levelFingerprint(int seed, String? modifierId) => fingerprint([
    for (final l in ['fr', 'en']) MotflashSim.lettersFor(seed, l).join(),
  ]);
}

class MotflashSim extends GameSim {
  MotflashSim(super.ctx) : letters = lettersFor(ctx.seed, ctx.lang);

  /// Same seed for every language, each with its own list: a 7-letter word
  /// is drawn (so one always exists), then its letters are shuffled.
  static List<String> lettersFor(int seed, String lang) {
    final r = SeededRandom.derive(seed, 'motflash:$lang');
    final sevens = Dictionary.words(lang).where((w) => w.length == 7).toList();
    if (sevens.isEmpty) return 'ONEGAME'.split('');
    return r.shuffled(sevens[r.nextInt(sevens.length)].split(''));
  }

  static List<Rect> get tiles => [
    for (var i = 0; i < 7; i++)
      Rect.fromLTWH(
        i < 4 ? 30 + i * 78.0 : 69 + (i - 4) * 78.0,
        i < 4 ? 400 : 476,
        66,
        66,
      ),
  ];
  static const Rect submitButton = Rect.fromLTWH(220, 560, 110, 56);
  static const Rect clearButton = Rect.fromLTWH(30, 560, 80, 56);
  static const Rect shuffleButton = Rect.fromLTWH(125, 560, 80, 56);

  List<String> letters;
  final List<int> _picked = [];
  final List<String> found = [];
  int _flash = 0;
  bool _flashOk = false;

  String get current => _picked.map((i) => letters[i]).join();

  @override
  Color get backgroundColor => const Color(0xFF1A1A2E);

  @override
  void onPointer(PointerPhase phase, int pointer, Offset pos) {
    if (phase != PointerPhase.down) return;
    if (submitButton.contains(pos)) return submit();
    if (clearButton.contains(pos)) {
      _picked.clear();
      return;
    }
    if (shuffleButton.contains(pos)) {
      // Visual only: does not change which words exist.
      final r = SeededRandom(step);
      final order = r.shuffled(List.generate(7, (i) => i));
      letters = [for (final i in order) letters[i]];
      _picked.clear();
      return;
    }
    final t = tiles.indexWhere((r) => r.contains(pos));
    if (t >= 0 && !_picked.contains(t)) {
      _picked.add(t);
      cue(sfx: Sfx.tap, haptic: Haptic.selection);
    } else if (t >= 0 && _picked.isNotEmpty && _picked.last == t) {
      _picked.removeLast();
    }
  }

  /// Validates the current word (also used by tests).
  void submit() {
    final w = current;
    final ok =
        w.length >= 3 && !found.contains(w) && Dictionary.contains(ctx.lang, w);
    _flash = (0.4 * stepsPerSecond).round();
    _flashOk = ok;
    if (ok) {
      found.add(w);
      score += MotflashGame.points[w.length]!;
      cue(sfx: Sfx.score, haptic: Haptic.light);
      particles.burst(
        const Offset(180, 300),
        const Color(0xFFFFD23F),
        count: 6 + w.length * 3,
        gravity: 0,
      );
      if (w.length == 7) {
        celebrate('fullWord');
        particles.fireworks(const Offset(180, 260));
      }
    } else {
      cue(sfx: Sfx.miss, haptic: Haptic.light);
    }
    _picked.clear();
  }

  /// Types a whole word (tests).
  void type(String word) {
    _picked.clear();
    for (final ch in word.split('')) {
      for (var i = 0; i < 7; i++) {
        if (letters[i] == ch && !_picked.contains(i)) {
          _picked.add(i);
          break;
        }
      }
    }
  }

  @override
  void tick() {
    tickParticles();
    if (_flash > 0) _flash--;
  }

  @override
  Map<String, num> get stats => {
    'words': found.length,
    'longest': found.fold(0, (m, w) => math.max(m, w.length)),
  };

  @override
  void render(Canvas canvas) {
    drawTabletop(canvas, const Color(0xFF2E5D4B));
    // Found words on a paper notepad, newest first.
    const pad = Rect.fromLTRB(18, 96, 342, 262);
    canvas
      ..drawRect(
        pad.shift(const Offset(3, 5)),
        Paint()
          ..color = const Color(0x66000000)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      )
      ..drawRect(pad, Paint()..color = const Color(0xFFFBF6E9));
    for (var k = 0; k < 7; k++) {
      final y = pad.top + 18 + k * 24.0;
      canvas.drawLine(
        Offset(pad.left + 8, y + 10),
        Offset(pad.right - 8, y + 10),
        Paint()
          ..color = const Color(0x332F80ED)
          ..strokeWidth = 1,
      );
    }
    final recent = found.reversed.take(18).toList();
    for (var i = 0; i < recent.length; i++) {
      drawText(
        canvas,
        recent[i],
        Offset(30 + (i % 3) * 105.0, 110 + (i ~/ 3) * 24.0),
        size: 14,
        color: recent[i].length == 7
            ? const Color(0xFFB8860B)
            : const Color(0xFF2B2B2B),
      );
    }
    final shown = current.isEmpty ? '…' : current;
    drawText(
      canvas,
      shown,
      const Offset(180, 340),
      size: 36,
      display: true,
      align: TextAlign.center,
      color: _flash > 0
          ? (_flashOk ? const Color(0xFF66BB6A) : const Color(0xFFE53935))
          : Colors.white,
    );
    // Wooden letter tiles.
    for (var i = 0; i < 7; i++) {
      final used = _picked.contains(i);
      final top = drawKey3d(
        canvas,
        tiles[i],
        used ? const Color(0xFF8A7A62) : const Color(0xFFE9C98F),
        radius: 8,
        depth: used ? 3 : 8,
        pressed: used,
      );
      final grain = Paint()
        ..color = const Color(0x1F6B3E14)
        ..strokeWidth = 1;
      for (var k = 1; k < 4; k++) {
        final y = top.top + top.height * k / 4 + (k.isEven ? 2 : -1);
        canvas.drawLine(
          Offset(top.left + 6, y),
          Offset(top.right - 6, y + 1.5),
          grain,
        );
      }
      drawText(
        canvas,
        letters[i],
        top.center,
        size: 30,
        display: true,
        align: TextAlign.center,
        color: used ? const Color(0x88120D0E) : const Color(0xFF2A1A0E),
      );
    }
    for (final (r, label, c) in [
      (clearButton, '⌫', const Color(0xFF455A64)),
      (shuffleButton, '🔀', const Color(0xFF455A64)),
      (submitButton, '✓', const Color(0xFFE8322F)),
    ]) {
      final top = drawKey3d(canvas, r, c, radius: 14, depth: 7);
      drawText(
        canvas,
        label,
        top.center,
        size: 24,
        display: true,
        align: TextAlign.center,
      );
    }
  }
}
