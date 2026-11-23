import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../core/l10n/l10n.dart';
import '../../core/rng/seeded_random.dart';
import '../common/draw.dart';
import '../common/fingerprint.dart';
import '../common/game_sim.dart';
import '../common/game_types.dart';
import '../common/mini_game_definition.dart';

/// 7.11 Slalom — pass every gate, as fast as possible.
class SkiGame extends MiniGameDefinition {
  const SkiGame();

  @override
  String get id => 'ski';
  @override
  String get emoji => '⛷️';
  @override
  GameCategory get category => GameCategory.sport;
  @override
  int get rulesVersion => 1;
  @override
  Set<String> get supportedModifiers => {Modifiers.mirror};
  @override
  ScoreBounds get scoreBounds => const ScoreBounds(0, 5000);

  @override
  Map<String, num> get defaultTuning => const {
    'baseSpeed': 340,
    'tuckSpeed': 480,
    'gates': 70,
  };

  @override
  String name(AppLocalizations l10n) => l10n.gameSkiName;
  @override
  String rule(AppLocalizations l10n) => l10n.gameSkiRule;

  @override
  String shareLine(AppLocalizations l10n, Map<String, num> s) {
    final cs = s['centis']?.toInt() ?? 0;
    return l10n.gameSkiShare(_fmt(cs), s['missed']?.toInt() ?? 0);
  }

  static String _fmt(int centis) =>
      '${centis ~/ 6000}:${((centis ~/ 100) % 60).toString().padLeft(2, '0')}.${(centis % 100).toString().padLeft(2, '0')}';

  @override
  List<(String, String)> statRows(AppLocalizations l10n, Map<String, num> s) =>
      [
        (l10n.statTime, _fmt(s['centis']?.toInt() ?? 0)),
        (l10n.statGatesMissed, '${s['missed'] ?? 0}'),
        (l10n.statCrashes, '${s['crashes'] ?? 0}'),
      ];

  @override
  Map<String, String> highlightLabels(AppLocalizations l10n) => {
    'cleanRun': l10n.highlightCleanRun,
  };

  @override
  GameSim createSim(GameContext ctx) => SkiSim(ctx, this);

  @override
  String levelFingerprint(int seed, String? modifierId) {
    final c = SkiCourse.generate(seed, 70);
    return fingerprint([
      for (final g in c.gates) g,
      for (final t in c.trees) ...[t.dx, t.dy],
      c.length,
    ]);
  }
}

class SkiCourse {
  const SkiCourse(this.gates, this.trees, this.bumps, this.length);

  /// Center x of each gate; gate i is at y = (i + 1) * spacing.
  final List<double> gates;
  final List<Offset> trees;
  final List<Offset> bumps;
  final double length;

  static const double spacing = 210;
  static const double gateHalf = 34;

  static SkiCourse generate(int seed, int gateCount) {
    final r = SeededRandom.derive(seed, 'ski:course');
    final gates = <double>[];
    for (var i = 0; i < gateCount; i++) {
      final side = i.isEven ? -1 : 1;
      gates.add(180 + side * r.doubleInRange(40, 105));
    }
    final length = (gateCount + 1) * spacing;
    final trees = <Offset>[];
    for (var y = 300.0; y < length; y += r.doubleInRange(60, 140)) {
      trees.add(
        Offset(
          r.chance(0.5) ? r.doubleInRange(10, 40) : r.doubleInRange(320, 350),
          y,
        ),
      );
      if (r.chance(0.18)) {
        // Occasional tree between gates, never on a gate line.
        final gy = (y / spacing).round() * spacing;
        if ((y - gy).abs() > 60) trees.add(Offset(r.doubleInRange(90, 270), y));
      }
    }
    final bumps = [
      for (var i = 0; i < gateCount ~/ 4; i++)
        Offset(r.doubleInRange(60, 300), r.doubleInRange(400, length)),
    ];
    return SkiCourse(gates, trees, bumps, length);
  }
}

class SkiSim extends GameSim {
  SkiSim(super.ctx, SkiGame def)
    : course = SkiCourse.generate(
        ctx.seed,
        ctx.tune('gates', def.defaultTuning['gates']!).toInt(),
      ),
      _base = ctx.tune('baseSpeed', def.defaultTuning['baseSpeed']!),
      _tuck = ctx.tune('tuckSpeed', def.defaultTuning['tuckSpeed']!),
      _mirror = ctx.has(Modifiers.mirror);

  static const double skierY = 200;

  final SkiCourse course;
  final double _base;
  final double _tuck;
  final bool _mirror;

  double _x = 180, _targetX = 180;
  double _y = 0; // distance travelled
  double _speed = 120;
  int _nextGate = 0;
  int missed = 0, crashes = 0;
  int _crashSteps = 0;
  bool finished = false;
  int _finishStep = 0;
  final Map<int, Offset> _pointers = {};
  int? _steer;
  double _steerFrom = 0, _targetFrom = 0;

  bool get _tucking => _pointers.length >= 2;

  /// Elapsed race time in centiseconds, penalties included.
  int get centis =>
      ((finished ? _finishStep : step) * 100 / stepsPerSecond).round() +
      missed * 300;

  @override
  Color get backgroundColor => const Color(0xFFF5F9FC);

  @override
  Offset get focus => Offset(_x, skierY);

  @override
  void onPointer(PointerPhase phase, int pointer, Offset pos) {
    switch (phase) {
      case PointerPhase.down:
        _pointers[pointer] = pos;
        if (_steer == null) {
          _steer = pointer;
          _steerFrom = pos.dx;
          _targetFrom = _targetX;
        }
      case PointerPhase.move:
        _pointers[pointer] = pos;
        if (pointer == _steer) {
          final dx = pos.dx - _steerFrom;
          _targetX = (_targetFrom + (_mirror ? -dx : dx) * 1.3).clamp(
            20.0,
            340.0,
          );
        }
      case PointerPhase.up:
        _pointers.remove(pointer);
        if (pointer == _steer) _steer = null;
    }
  }

  @override
  void tick() {
    tickParticles();
    if (finished) return;
    if (_crashSteps > 0) {
      _crashSteps--;
      _speed = 60;
    } else {
      final target = _tucking ? _tuck : _base;
      _speed += (target - _speed) * 0.8 * stepDt;
    }
    // Lateral movement: tucking turns less; turning costs speed.
    final maxLat = (_tucking ? 160.0 : 320.0) * stepDt;
    final dx = (_targetX - _x).clamp(-maxLat, maxLat);
    _x += dx;
    _speed -= dx.abs() * 0.6;
    _speed = _speed.clamp(40.0, 520.0);
    _y += _speed * stepDt;

    for (final b in course.bumps) {
      if ((Offset(_x, _y) - b).distance < 22) _speed *= 0.995;
    }
    if (_crashSteps == 0) {
      for (final t in course.trees) {
        if ((Offset(_x, _y) - t).distance < 16) {
          crashes++;
          _crashSteps = (0.8 * stepsPerSecond).round();
          particles.burst(Offset(_x, skierY), Colors.white, count: 24);
          cue(sfx: Sfx.hit, haptic: Haptic.heavy);
          break;
        }
      }
    }
    // Gates.
    while (_nextGate < course.gates.length &&
        _y >= (_nextGate + 1) * SkiCourse.spacing) {
      final gx = course.gates[_nextGate];
      if ((_x - gx).abs() <= SkiCourse.gateHalf) {
        cue(sfx: Sfx.tap, haptic: Haptic.selection);
      } else {
        missed++;
        cue(sfx: Sfx.miss, haptic: Haptic.light);
      }
      _nextGate++;
    }
    if (_y >= course.length) {
      finished = true;
      _finishStep = step;
      score = math.max(0, 5000 - centis ~/ 2);
      if (missed == 0 && crashes == 0) {
        celebrate('cleanRun');
        particles.fireworks(Offset(_x, skierY + 60));
      }
      over = true;
    }
  }

  @override
  void onTimeUp() {
    // Not finished in 2 minutes: no time bonus.
    score = 0;
  }

  @override
  Map<String, num> get stats => {
    'centis': centis,
    'missed': missed,
    'crashes': crashes,
    'gates': _nextGate,
    'finished': finished ? 1 : 0,
  };

  double _screenY(double worldY) => skierY + (worldY - _y);

  @override
  void render(Canvas canvas) {
    canvas.drawRect(Arena.rect, Paint()..color = const Color(0xFFF5F9FC));
    // Ski tracks.
    final trail = Paint()
      ..color = const Color(0x22000000)
      ..strokeWidth = 2;
    for (var i = 0; i < 8; i++) {
      final y = (i * 90 - _y % 90) + 0.0;
      canvas.drawLine(Offset(30, y), Offset(40, y + 20), trail);
    }
    for (final b in course.bumps) {
      final sy = _screenY(b.dy);
      if (sy < -30 || sy > 680) continue;
      canvas.drawOval(
        Rect.fromCenter(center: Offset(b.dx, sy), width: 46, height: 22),
        Paint()..color = const Color(0x1A3949AB),
      );
    }
    for (var i = 0; i < course.gates.length; i++) {
      final sy = _screenY((i + 1) * SkiCourse.spacing);
      if (sy < -30 || sy > 680) continue;
      final gx = course.gates[i];
      final color = i.isEven
          ? const Color(0xFFE53935)
          : const Color(0xFF1E88E5);
      for (final px in [gx - SkiCourse.gateHalf, gx + SkiCourse.gateHalf]) {
        canvas
          ..drawLine(
            Offset(px, sy - 22),
            Offset(px, sy),
            Paint()
              ..color = color
              ..strokeWidth = 4,
          )
          ..drawRect(
            Rect.fromLTWH(px - (px < gx ? 0 : 14), sy - 22, 14, 10),
            Paint()..color = color,
          );
      }
    }
    for (final t in course.trees) {
      final sy = _screenY(t.dy);
      if (sy < -30 || sy > 680) continue;
      canvas.drawPath(
        Path()
          ..moveTo(t.dx, sy - 22)
          ..lineTo(t.dx - 13, sy + 8)
          ..lineTo(t.dx + 13, sy + 8)
          ..close(),
        Paint()..color = const Color(0xFF2E7D32),
      );
    }
    final fy = _screenY(course.length);
    if (fy > -10 && fy < 680) {
      for (var x = 0.0; x < 360; x += 20) {
        canvas.drawRect(
          Rect.fromLTWH(x, fy, 10, 10),
          Paint()..color = Colors.black,
        );
      }
    }
    // Skier.
    final lean = ((_targetX - _x) / 80).clamp(-0.5, 0.5);
    canvas
      ..save()
      ..translate(_x, skierY)
      ..rotate(lean);
    canvas
      ..drawLine(
        const Offset(-7, 12),
        const Offset(-7, -14),
        Paint()
          ..color = Colors.black87
          ..strokeWidth = 3,
      )
      ..drawLine(
        const Offset(7, 12),
        const Offset(7, -14),
        Paint()
          ..color = Colors.black87
          ..strokeWidth = 3,
      );
    drawBox(
      canvas,
      Rect.fromCenter(
        center: Offset(0, _tucking ? 2 : -2),
        width: 16,
        height: _tucking ? 14 : 20,
      ),
      const Color(0xFFE8322F),
      radius: 5,
    );
    canvas
      ..drawCircle(
        Offset(0, _tucking ? -8 : -14),
        6,
        Paint()..color = const Color(0xFFFFD23F),
      )
      ..restore();
    final s = centis;
    drawText(
      canvas,
      '${s ~/ 100}.${(s % 100).toString().padLeft(2, '0')}',
      const Offset(344, 100),
      size: 18,
      display: true,
      align: TextAlign.right,
      color: Colors.black87,
    );
    drawText(
      canvas,
      '🚩 $_nextGate/${course.gates.length}',
      const Offset(16, 100),
      size: 14,
      color: Colors.black87,
    );
    if (missed > 0) {
      drawText(
        canvas,
        '+${missed * 3}s',
        const Offset(344, 124),
        size: 14,
        align: TextAlign.right,
        color: const Color(0xFFE53935),
      );
    }
  }
}
