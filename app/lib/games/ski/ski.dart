import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../core/l10n/l10n.dart';
import '../../core/rng/seeded_random.dart';
import '../common/draw.dart';
import '../common/fingerprint.dart';
import '../common/game_sim.dart';
import '../common/game_types.dart';
import '../common/mini_game_definition.dart';
import '../common/render3d.dart';

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

  // ── 3D rendering ──────────────────────────────────────────────────────
  // Chase camera behind the skier. A course point (x, wy) sits at
  // z = _y − wy (ahead is −z) on a slope going down the hill.
  static const double _slope = 0.28;
  static const Color _snow = Color(0xFFF4F8FC);

  V3 _w(double x, double wy, [double h = 0]) {
    final z = _y - wy;
    return V3(x, z * _slope + h, z);
  }

  @override
  void render(Canvas canvas) {
    final cx = 180 + (_x - 180) * 0.55;
    final cam = Camera3D(
      eye: V3(cx, 250, 320),
      target: V3(180 + (_x - 180) * 0.75, -110, -360),
      fovDegrees: 56,
      center: const Offset(180, 305),
    );
    final horizon =
        cam.project(V3(cx, 250 - 100000 * _slope, 320 - 100000))?.dy ?? 120;
    drawSky(
      canvas,
      Rect.fromLTWH(0, 0, 360, horizon + 1),
      const Color(0xFF2F6FBF),
      const Color(0xFFBFDDF2),
    );
    // Distant peaks with snowy tops, then the far snowfield.
    final far = Path()..moveTo(0, horizon);
    final near = Path()..moveTo(0, horizon);
    for (var x = 0.0; x <= 360; x += 10) {
      final sx = x - (_x - 180) * 0.1;
      far.lineTo(
        x,
        horizon - 40 - 34 * (math.sin(sx / 37).abs()) - 12 * math.sin(sx / 13),
      );
      near.lineTo(x, horizon - 14 - 16 * math.sin(sx / 23 + 2).abs());
    }
    for (final pth in [far, near]) {
      pth
        ..lineTo(360, horizon)
        ..close();
    }
    canvas
      ..drawPath(far, Paint()..color = const Color(0xFF9FB4CC))
      ..drawPath(near, Paint()..color = const Color(0xFF7D93AE))
      ..drawRect(
        Rect.fromLTWH(0, horizon, 360, 640 - horizon),
        Paint()..color = const Color(0xFFDDE8F2),
      );

    final s = Scene3D(
      cam,
      light: const V3(-0.4, 1, 0.3),
      ambient: 0.55,
      fogColor: const Color(0xFFDDE8F2),
      fogStart: 700,
      fogEnd: 2100,
    );
    // Groomed piste (corduroy rows) and deeper snow off-piste.
    const ahead = 1900.0, behind = 260.0;
    const cell = 70.0;
    final j0 = ((_y - behind) / cell).floor();
    final j1 = ((_y + ahead) / cell).ceil();
    for (var j = j0; j < j1; j++) {
      final y0 = j * cell, y1 = y0 + cell;
      for (var i = -9; i < 15; i++) {
        final x0 = i * 60.0, x1 = x0 + 60;
        final onPiste = x0 >= 0 && x1 <= 360;
        final n = cellNoise(i, j, 4) - 0.5;
        final col = onPiste
            ? tint(_snow, (j.isEven ? -0.02 : 0.0) + n * 0.02)
            : tint(const Color(0xFFE6EEF6), n * 0.05);
        s.quad(
          _w(x0, y0),
          _w(x0, y1),
          _w(x1, y1),
          _w(x1, y0),
          col,
          layer: Layer.ground,
        );
      }
    }
    bool visible(double wy) => wy > _y - behind && wy < _y + ahead;

    for (final b in course.bumps) {
      if (!visible(b.dy)) continue;
      s
        ..shadow(
          _w(b.dx + 8, b.dy + 10).flat,
          26,
          height: _w(0, b.dy + 10).y + 0.3,
          opacity: 0.1,
          stretch: 1.6,
        )
        ..shadow(
          _w(b.dx - 6, b.dy - 8).flat,
          18,
          height: _w(0, b.dy - 8).y + 0.35,
          opacity: 0.05,
          stretch: 1.6,
        );
    }
    for (var i = 0; i < course.gates.length; i++) {
      final wy = (i + 1) * SkiCourse.spacing;
      if (!visible(wy)) continue;
      final gx = course.gates[i];
      final color = i.isEven
          ? const Color(0xFFE53935)
          : const Color(0xFF1E88E5);
      for (final side in [-1.0, 1.0]) {
        final inner = gx + side * SkiCourse.gateHalf;
        final outer = inner + side * 24;
        for (final px in [inner, outer]) {
          s.tube(_w(px, wy), _w(px, wy, 58), 1.4, 1.4, color, segments: 5);
        }
        s
          ..quad(
            _w(inner, wy, 24),
            _w(outer, wy, 24),
            _w(outer, wy, 52),
            _w(inner, wy, 52),
            color,
            doubleSided: true,
          )
          ..shadow(
            _w(inner + side * 12, wy).flat,
            14,
            height: _w(0, wy).y + 0.4,
            opacity: 0.12,
          );
      }
    }
    void pine(double x, double wy, double size) {
      final base = _w(x, wy);
      s
        ..shadow(
          Offset(x + 10, base.z),
          20 * size,
          height: base.y + 0.3,
          opacity: 0.2,
        )
        ..tube(
          base,
          base + V3(0, 14 * size, 0),
          3 * size,
          3 * size,
          const Color(0xFF5D4037),
          segments: 5,
        );
      for (final (k, r) in [24.0, 19.0, 13.0].indexed) {
        final y0 = (12 + k * 18) * size;
        s
          ..tube(
            base + V3(0, y0, 0),
            base + V3(0, y0 + 30 * size, 0),
            r * size,
            0,
            tint(const Color(0xFF1F5E3A), k * 0.06),
            segments: 7,
          )
          ..tube(
            base + V3(0, y0 + 14 * size, 0),
            base + V3(0, y0 + 30 * size, 0),
            r * size * 0.45,
            0,
            const Color(0xFFF2F6FA),
            segments: 7,
          );
      }
    }

    for (final t in course.trees) {
      if (visible(t.dy)) pine(t.dx, t.dy, 1);
    }
    // Forest along both sides of the piste.
    for (var k = (_y - behind) ~/ 90; k < (_y + ahead) ~/ 90; k++) {
      final wy = k * 90.0;
      pine(
        -40 - cellNoise(k, 1, 6) * 220,
        wy + cellNoise(k, 2, 6) * 60,
        1.2 + cellNoise(k, 3, 6) * 0.6,
      );
      pine(
        400 + cellNoise(k, 4, 6) * 220,
        wy + cellNoise(k, 5, 6) * 60,
        1.2 + cellNoise(k, 6, 6) * 0.6,
      );
    }
    // Finish arch and chequered line.
    if (visible(course.length)) {
      final wy = course.length;
      for (var k = 0; k < 18; k++) {
        s.quad(
          _w(k * 20.0, wy - 6),
          _w(k * 20.0, wy + 6),
          _w(k * 20.0 + 20, wy + 6),
          _w(k * 20.0 + 20, wy - 6),
          k.isEven ? const Color(0xFF212121) : _snow,
          layer: Layer.surface,
        );
      }
      for (final x in [-12.0, 372.0]) {
        s.box(_w(x, wy), 14, 120, 14, const Color(0xFFE8322F));
      }
      s.boxAxes(
        _w(180, wy, 104),
        const V3(1, 0, 0),
        const V3(0, 1, 0),
        const V3(0, 0, 1),
        398,
        28,
        6,
        const Color(0xFFE8322F),
      );
    }
    _skier(s);
    s.render(canvas);

    final c = centis;
    drawText(
      canvas,
      '${c ~/ 100}.${(c % 100).toString().padLeft(2, '0')}',
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

  /// The racer: carving skis, poles, crouched when tucking, tumbling on a
  /// crash.
  void _skier(Scene3D s) {
    final lean = ((_targetX - _x) / 80).clamp(-0.5, 0.5);
    final feet = _w(_x, _y);
    final yaw = -lean * 0.6;
    s.shadow(
      Offset(_x + 6, feet.z - 4),
      16,
      height: feet.y + 0.3,
      opacity: 0.25,
      stretch: 0.8,
    );
    final crash = _crashSteps > 0;
    for (final dx in [-6.0, 6.0]) {
      s.box(
        feet + V3(dx, 0.5, -6),
        4,
        1.5,
        72,
        const Color(0xFF263238),
        yaw: yaw,
        top: const Color(0xFFFFD23F),
      );
    }
    final scale = _tucking ? 0.9 : 1.05;
    final body = feet + V3(0, _tucking ? -12 : 0, 0);
    s.figure(
      body,
      const Color(0xFFE8322F),
      roll: crash ? lean.sign * 1.2 + 0.4 : -lean * 0.8,
      arms: 0,
      scale: scale,
      shorts: const Color(0xFF1A237E),
    );
    s.sphere(
      body +
          V3(
            -math.sin(-lean * 0.8) * 40 * scale,
            40 * scale * math.cos(lean * 0.8),
            0,
          ),
      6.8 * scale,
      const Color(0xFFFFD23F),
      lat: 5,
      lon: 8,
    );
    for (final dx in [-15.0, 15.0]) {
      final hand = body + V3(dx * 0.75 * scale, 18 * scale, 0);
      s.tube(
        hand,
        hand + V3(dx * 0.3, -32, 20),
        0.8,
        0.8,
        const Color(0xFFB0BEC5),
        segments: 4,
      );
    }
  }
}
