import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../core/l10n/l10n.dart';
import '../../core/rng/seeded_random.dart';
import '../common/draw.dart';
import '../common/fingerprint.dart';
import '../common/game_sim.dart';
import '../common/game_types.dart';
import '../common/mini_game_definition.dart';

/// 7.23 Mémoire flash — Simon-like: repeat a growing sequence.
class MemoryGame extends MiniGameDefinition {
  const MemoryGame();

  @override
  String get id => 'memory';
  @override
  String get emoji => '🧠';
  @override
  GameCategory get category => GameCategory.reflexion;
  @override
  int get rulesVersion => 1;
  @override
  Set<String> get supportedModifiers => const {};
  @override
  ScoreBounds get scoreBounds => const ScoreBounds(0, 60 * 100 + 60 * 600);

  @override
  Map<String, num> get defaultTuning => const {'startLength': 3, 'flash': 0.45};

  @override
  String name(AppLocalizations l10n) => l10n.gameMemoryName;
  @override
  String rule(AppLocalizations l10n) => l10n.gameMemoryRule;

  @override
  String shareLine(AppLocalizations l10n, Map<String, num> s) =>
      l10n.gameMemoryShare(s['length']?.toInt() ?? 0);

  @override
  List<(String, String)> statRows(AppLocalizations l10n, Map<String, num> s) =>
      [
        (l10n.statSequence, '${s['length'] ?? 0}'),
        (l10n.statSpeedBonus, '${s['bonus'] ?? 0}'),
      ];

  @override
  Map<String, String> highlightLabels(AppLocalizations l10n) => {
    'memoryTen': l10n.highlightMemoryTen,
  };

  @override
  GameSim createSim(GameContext ctx) => MemorySim(ctx, this);

  @override
  String levelFingerprint(int seed, String? modifierId) =>
      fingerprint(MemorySim.sequence(seed));
}

enum _Phase { show, input, success, done }

class MemorySim extends GameSim {
  MemorySim(super.ctx, MemoryGame def)
    : _seq = sequence(ctx.seed),
      _length = ctx
          .tune('startLength', def.defaultTuning['startLength']!)
          .toInt(),
      _flash = ctx.tune('flash', def.defaultTuning['flash']!);

  static List<int> sequence(int seed) {
    final r = SeededRandom.derive(seed, 'memory:sequence');
    return [for (var i = 0; i < 60; i++) r.nextInt(4)];
  }

  static const pads = [
    Rect.fromLTWH(24, 250, 150, 150),
    Rect.fromLTWH(186, 250, 150, 150),
    Rect.fromLTWH(24, 412, 150, 150),
    Rect.fromLTWH(186, 412, 150, 150),
  ];
  static const colors = [
    Color(0xFF43A047),
    Color(0xFFE53935),
    Color(0xFFFDD835),
    Color(0xFF1E88E5),
  ];

  final List<int> _seq;
  int _length;
  final double _flash;
  _Phase _phase = _Phase.show;
  int _phaseSteps = 0;
  int _inputIndex = 0;
  int _inputStart = 0;
  int _lit = -1;
  int _litUntil = 0;
  int completed = 0, bonus = 0;

  double get _period =>
      math.max(0.3, _flash * math.pow(0.95, completed)) + 0.15;

  @override
  Color get backgroundColor => const Color(0xFF1A1A2E);

  @override
  void onPointer(PointerPhase phase, int pointer, Offset pos) {
    if (phase != PointerPhase.down || _phase != _Phase.input) return;
    final pad = pads.indexWhere((r) => r.contains(pos));
    if (pad < 0) return;
    _lit = pad;
    _litUntil = step + 24;
    if (pad != _seq[_inputIndex]) {
      _phase = _Phase.done;
      over = true;
      cue(sfx: Sfx.miss, haptic: Haptic.heavy);
      return;
    }
    cue(sfx: Sfx.tap, haptic: Haptic.selection);
    _inputIndex++;
    if (_inputIndex == _length) {
      // Round done: length × 100 overall, plus a speed bonus.
      completed = _length;
      final used = (step - _inputStart) / stepsPerSecond;
      final b = math.max(0, ((_length * 0.7 - used) * 30).round());
      bonus += b;
      score = completed * 100 + bonus;
      particles.burst(
        const Offset(180, 405),
        const Color(0xFFFFD23F),
        count: 16,
        gravity: 0,
      );
      cue(sfx: Sfx.score, haptic: Haptic.medium);
      if (completed == 10) celebrate('memoryTen');
      _phase = _Phase.success;
      _phaseSteps = 0;
    }
  }

  @override
  void tick() {
    tickParticles();
    _phaseSteps++;
    if (step > _litUntil && _phase != _Phase.show) _lit = -1;
    switch (_phase) {
      case _Phase.show:
        final per = (_period * stepsPerSecond).round();
        final k = (_phaseSteps - 30) ~/ per;
        final within = (_phaseSteps - 30) % per;
        if (_phaseSteps < 30) {
          _lit = -1;
        } else if (k < _length) {
          final on = within < per - (0.15 * stepsPerSecond).round();
          _lit = on ? _seq[k] : -1;
          if (within == 0) cue(sfx: Sfx.countdown);
        } else {
          _lit = -1;
          _phase = _Phase.input;
          _inputIndex = 0;
          _inputStart = step;
        }
      case _Phase.input:
        break;
      case _Phase.success:
        if (_phaseSteps > 60) {
          _length = math.min(_length + 1, _seq.length);
          _phase = _Phase.show;
          _phaseSteps = 0;
        }
      case _Phase.done:
        break;
    }
  }

  @override
  Map<String, num> get stats => {'length': completed, 'bonus': bonus};

  @override
  void render(Canvas canvas) {
    canvas.drawRect(Arena.rect, Paint()..color = const Color(0xFF1A1A2E));
    for (var i = 0; i < 4; i++) {
      final on = _lit == i;
      final c = on
          ? Color.lerp(colors[i], Colors.white, 0.45)!
          : colors[i].withValues(alpha: 0.45);
      drawBox(canvas, pads[i], c, radius: 24);
      if (on) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            pads[i].inflate(4),
            const Radius.circular(28),
          ),
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4,
        );
      }
    }
    final label = switch (_phase) {
      _Phase.show => '👀  $_length',
      _Phase.input => '👆  ${_inputIndex + 1}/$_length',
      _Phase.success => '✓',
      _Phase.done => '✗',
    };
    drawText(
      canvas,
      label,
      const Offset(180, 170),
      size: 30,
      display: true,
      align: TextAlign.center,
      color: const Color(0xFFFFD23F),
    );
  }
}
