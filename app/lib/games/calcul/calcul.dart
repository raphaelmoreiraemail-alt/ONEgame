import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../core/l10n/l10n.dart';
import '../../core/rng/seeded_random.dart';
import '../common/draw.dart';
import '../common/fingerprint.dart';
import '../common/game_sim.dart';
import '../common/game_types.dart';
import '../common/mini_game_definition.dart';

/// 7.24 Calcul mental — harder and harder, pick the right answer among 4.
class CalculGame extends MiniGameDefinition {
  const CalculGame();

  @override
  String get id => 'calcul';
  @override
  String get emoji => '➗';
  @override
  GameCategory get category => GameCategory.reflexion;
  @override
  int get rulesVersion => 1;
  @override
  Set<String> get supportedModifiers => const {};
  @override
  ScoreBounds get scoreBounds => const ScoreBounds(0, 40000);

  @override
  Map<String, num> get defaultTuning => const {'perLevel': 4};

  @override
  String name(AppLocalizations l10n) => l10n.gameCalculName;
  @override
  String rule(AppLocalizations l10n) => l10n.gameCalculRule;

  @override
  String shareLine(AppLocalizations l10n, Map<String, num> s) =>
      l10n.gameCalculShare(
        s['correct']?.toInt() ?? 0,
        s['bestStreak']?.toInt() ?? 0,
      );

  @override
  List<(String, String)> statRows(AppLocalizations l10n, Map<String, num> s) =>
      [
        (l10n.statCorrect, '${s['correct'] ?? 0}'),
        (l10n.statWrong, '${s['wrong'] ?? 0}'),
        (l10n.statMaxStreak, '${s['bestStreak'] ?? 0}'),
      ];

  @override
  Map<String, String> highlightLabels(AppLocalizations l10n) => {
    'streak10': l10n.highlightStreak10,
  };

  @override
  GameSim createSim(GameContext ctx) => CalculSim(ctx, this);

  @override
  String levelFingerprint(int seed, String? modifierId) => fingerprint([
    for (var i = 0; i < 40; i++) ...[
      Question.generate(seed, i, 4).text,
      ...Question.generate(seed, i, 4).choices,
    ],
  ]);
}

class Question {
  const Question(this.text, this.answer, this.choices);

  final String text;
  final int answer;
  final List<int> choices;

  static Question generate(int seed, int index, int perLevel) {
    final r = SeededRandom.derive(seed, 'calcul:q$index');
    final level = index ~/ perLevel;
    String text;
    int ans;
    int n(int a, int b) => r.intInRange(a, b);
    switch (level) {
      case 0:
        final a = n(1, 20), b = n(1, 20);
        text = '$a + $b';
        ans = a + b;
      case 1:
        final a = n(10, 40), b = n(1, a);
        text = '$a − $b';
        ans = a - b;
      case 2:
        final a = n(2, 9), b = n(2, 9);
        text = '$a × $b';
        ans = a * b;
      case 3:
        final b = n(2, 9), q = n(2, 12);
        text = '${b * q} ÷ $b';
        ans = q;
      case 4:
        final a = n(15, 99), b = n(15, 99);
        final plus = r.chance(0.5);
        text = plus ? '$a + $b' : '${math.max(a, b)} − ${math.min(a, b)}';
        ans = plus ? a + b : (a - b).abs();
      case 5:
        final a = n(2, 9), b = n(2, 9), c = n(2, 30);
        text = '$a × $b + $c';
        ans = a * b + c;
      case 6:
        final a = n(11, 25), b = n(3, 9);
        text = '$a × $b';
        ans = a * b;
      default:
        final a = n(2, 12), b = n(2, 12), c = n(2, 9);
        if (r.chance(0.5)) {
          text = '($a + $b) × $c';
          ans = (a + b) * c;
        } else {
          final c2 = math.min(c, a * b);
          text = '$a × $b − $c2';
          ans = a * b - c2;
        }
    }
    // Plausible distractors: ±1, ±2, ±10, digits swapped.
    final cands = <int>{ans + 1, ans - 1, ans + 2, ans - 2, ans + 10, ans - 10};
    final s = '$ans';
    if (ans >= 10 && ans < 100) cands.add(int.parse('${s[1]}${s[0]}'));
    cands
      ..remove(ans)
      ..removeWhere((v) => v < 0);
    final wrong = r.shuffled(cands.toList()..sort()).take(3).toList();
    return Question(text, ans, r.shuffled([ans, ...wrong]));
  }
}

class CalculSim extends GameSim {
  CalculSim(super.ctx, CalculGame def)
    : _perLevel = ctx.tune('perLevel', def.defaultTuning['perLevel']!).toInt() {
    _q = Question.generate(ctx.seed, 0, _perLevel);
  }

  static List<Rect> get buttons => [
    const Rect.fromLTWH(24, 330, 150, 110),
    const Rect.fromLTWH(186, 330, 150, 110),
    const Rect.fromLTWH(24, 452, 150, 110),
    const Rect.fromLTWH(186, 452, 150, 110),
  ];

  final int _perLevel;
  late Question _q;
  int index = 0;
  int correct = 0, wrong = 0, streak = 0, bestStreak = 0;
  int _askedAt = 0;
  int _feedback = 0;
  int? _picked;
  bool _lastOk = false;

  Question get question => _q;

  @override
  Color get backgroundColor => const Color(0xFF0D1B2A);

  @override
  void onPointer(PointerPhase phase, int pointer, Offset pos) {
    if (phase != PointerPhase.down || _feedback > 0) return;
    final i = buttons.indexWhere((r) => r.contains(pos));
    if (i < 0) return;
    answer(i);
  }

  /// Answers with the choice at [i] (also used by tests).
  void answer(int i) {
    _picked = i;
    final ok = _q.choices[i] == _q.answer;
    _lastOk = ok;
    if (ok) {
      correct++;
      streak++;
      bestStreak = math.max(bestStreak, streak);
      final t = (step - _askedAt) / stepsPerSecond;
      final int base = 100 + math.max<int>(0, ((5 - t) * 20).round());
      score += streak > 5 ? (base * 1.5).round() : base;
      cue(sfx: Sfx.score, haptic: Haptic.light);
      if (streak == 10) celebrate('streak10');
    } else {
      wrong++;
      streak = 0;
      score = math.max(0, score - 50);
      cue(sfx: Sfx.miss, haptic: Haptic.medium);
    }
    _feedback = (0.35 * stepsPerSecond).round();
  }

  @override
  void tick() {
    tickParticles();
    if (_feedback > 0 && --_feedback == 0) {
      index++;
      _q = Question.generate(ctx.seed, index, _perLevel);
      _askedAt = step;
      _picked = null;
    }
  }

  @override
  Map<String, num> get stats => {
    'correct': correct,
    'wrong': wrong,
    'bestStreak': bestStreak,
  };

  @override
  void render(Canvas canvas) {
    drawTabletop(canvas, const Color(0xFF6B4A33), grain: true);
    // Calculator body with an LCD screen showing the question.
    const body = Rect.fromLTRB(10, 140, 350, 590);
    drawKey3d(canvas, body, const Color(0xFF2C3440), radius: 26, depth: 10);
    const lcd = Rect.fromLTRB(28, 160, 332, 300);
    canvas
      ..drawRRect(
        RRect.fromRectAndRadius(lcd.inflate(4), const Radius.circular(14)),
        Paint()..color = const Color(0xFF14181E),
      )
      ..drawRRect(
        RRect.fromRectAndRadius(lcd, const Radius.circular(10)),
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFB9C9A0), Color(0xFF8FA37A)],
          ).createShader(lcd),
      )
      ..drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(lcd.left + 6, lcd.top + 6, lcd.right - 6, lcd.top + 20),
          const Radius.circular(6),
        ),
        Paint()..color = const Color(0x22FFFFFF),
      );
    drawText(
      canvas,
      '${_q.text} = ?',
      const Offset(180, 210),
      size: 38,
      display: true,
      align: TextAlign.center,
      maxWidth: 290,
      color: const Color(0xFF1E2A16),
    );
    if (streak >= 5) {
      drawText(
        canvas,
        '🔥 ×1.5',
        const Offset(180, 272),
        size: 16,
        display: true,
        align: TextAlign.center,
        color: const Color(0xFF6B2A10),
      );
    }
    for (var i = 0; i < 4; i++) {
      var c = const Color(0xFF3E5F8A);
      if (_picked != null && _feedback > 0) {
        if (_q.choices[i] == _q.answer) c = const Color(0xFF43A047);
        if (i == _picked && !_lastOk) c = const Color(0xFFE53935);
      }
      final top = drawKey3d(
        canvas,
        buttons[i].deflate(3),
        c,
        radius: 18,
        depth: 9,
        pressed: i == _picked && _feedback > 0,
      );
      drawText(
        canvas,
        '${_q.choices[i]}',
        top.center,
        size: 32,
        display: true,
        align: TextAlign.center,
      );
    }
    drawText(canvas, '✓ $correct  ✗ $wrong', const Offset(16, 100), size: 15);
  }
}
