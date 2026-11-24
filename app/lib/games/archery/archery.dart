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
import '../darts/darts.dart' show Drift;

/// 7.10 Tir à l'arc — 10 arrows, wind, targets further away, moving at the end.
class ArcheryGame extends MiniGameDefinition {
  const ArcheryGame();

  @override
  String get id => 'archery';
  @override
  String get emoji => '🏹';
  @override
  GameCategory get category => GameCategory.sport;
  @override
  int get rulesVersion => 1;
  @override
  Set<String> get supportedModifiers => {Modifiers.wind};
  @override
  ScoreBounds get scoreBounds => const ScoreBounds(0, ArcherySim.arrows * 150);

  @override
  Map<String, num> get defaultTuning => const {
    'drift': 7,
    'driftHz': 1.1,
    'minDraw': 70,
  };

  @override
  String name(AppLocalizations l10n) => l10n.gameArcheryName;
  @override
  String rule(AppLocalizations l10n) => l10n.gameArcheryRule;

  @override
  String shareLine(AppLocalizations l10n, Map<String, num> s) =>
      l10n.gameArcheryShare(
        s['points']?.toInt() ?? 0,
        s['bullseyes']?.toInt() ?? 0,
      );

  @override
  List<(String, String)> statRows(AppLocalizations l10n, Map<String, num> s) =>
      [
        (l10n.statPoints, '${s['points'] ?? 0} / 100'),
        (l10n.statBullseyes, '${s['bullseyes'] ?? 0}'),
        (l10n.statArrows, '${s['arrows'] ?? 0} / ${ArcherySim.arrows}'),
      ];

  @override
  Map<String, String> highlightLabels(AppLocalizations l10n) => {
    'mouche': l10n.highlightMouche,
  };

  @override
  GameSim createSim(GameContext ctx) => ArcherySim(ctx, this);

  @override
  String levelFingerprint(int seed, String? modifierId) => fingerprint([
    for (final e in ArcheryRange.generate(
      GameContext(seed: seed, modifierId: modifierId),
    )) ...[e.radius, e.wind.dx, e.wind.dy, e.swing, e.period],
  ]);
}

/// One end: target size (distance), wind, movement.
class ArcheryRange {
  const ArcheryRange(this.radius, this.wind, this.swing, this.period);

  final double radius;

  /// Deflection (px) at full flight.
  final Offset wind;

  /// Horizontal movement amplitude (0 = still).
  final double swing;
  final double period;

  static List<ArcheryRange> generate(GameContext ctx) {
    final r = SeededRandom.derive(ctx.seed, 'archery:range');
    final strong = ctx.has(Modifiers.wind) ? 2.0 : 1.0;
    return [
      for (var i = 0; i < ArcherySim.arrows; i++)
        ArcheryRange(
          72 - i * 4.0,
          Offset(r.doubleInRange(-12, 12), r.doubleInRange(-5, 5)) * strong,
          i >= ArcherySim.arrows - 3 ? r.doubleInRange(40, 80) : 0,
          r.doubleInRange(1.6, 2.6),
        ),
    ];
  }
}

class ArcherySim extends GameSim {
  ArcherySim(super.ctx, ArcheryGame def)
    : range = ArcheryRange.generate(ctx),
      _drift = Drift(
        ctx,
        ctx.tune('drift', def.defaultTuning['drift']!),
        ctx.tune('driftHz', def.defaultTuning['driftHz']!),
      ),
      _minDraw = ctx.tune('minDraw', def.defaultTuning['minDraw']!);

  static const int arrows = 10;
  static const Offset targetHome = Offset(180, 250);

  final List<ArcheryRange> range;
  final Drift _drift;
  final double _minDraw;

  int shot = 0;
  int points = 0;
  int bullseyes = 0;
  final List<(Offset, int)> _hits = [];

  int? _pointer;
  Offset _start = Offset.zero;
  Offset _finger = Offset.zero;
  int _drawStart = 0;
  int _flight = 0;
  Offset _landing = Offset.zero;
  bool _short = false;
  int _show = 0;

  ArcheryRange get _r => range[math.min(shot, arrows - 1)];

  Offset get targetCenter => targetHome.translate(
    _r.swing * math.sin(2 * math.pi * elapsed / _r.period),
    0,
  );

  double get _draw => (_finger - _start).distance;

  /// Nominal draw: pulling exactly this far down aims at the center height;
  /// less aims low, more aims high. Left / right are mirrored like a bow.
  static const double nominalDraw = 110;

  Offset get _sight {
    final pull = _finger - _start;
    return targetHome +
        Offset(-pull.dx * 0.9, -(pull.dy - nominalDraw) * 0.9) +
        _drift.at(shot, (step - _drawStart) / stepsPerSecond);
  }

  @override
  Color get backgroundColor => const Color(0xFF81C784);

  @override
  void onPointer(PointerPhase phase, int pointer, Offset pos) {
    if (shot >= arrows || _flight > 0 || _show > 0) return;
    switch (phase) {
      case PointerPhase.down:
        if (_pointer != null) return;
        _pointer = pointer;
        _start = pos;
        _finger = pos;
        _drawStart = step;
      case PointerPhase.move:
        if (pointer == _pointer) _finger = pos;
      case PointerPhase.up:
        if (pointer != _pointer) return;
        _pointer = null;
        _finger = pos;
        _short = _draw < _minDraw;
        // Pulling down moves the sight up (like a bow); a weak draw drops.
        final aim = _sight;
        _landing = Offset(aim.dx, aim.dy + (_short ? 140 : 0)) + _r.wind;
        _flight = (0.45 * stepsPerSecond).round();
        cue(sfx: Sfx.whoosh, haptic: Haptic.light);
    }
  }

  @override
  void tick() {
    tickParticles();
    if (_show > 0 && --_show == 0) {
      shot++;
      if (shot >= arrows) over = true;
    }
    if (_flight > 0 && --_flight == 0) _land();
  }

  void _land() {
    // Ring from the distance to the (possibly moving) target center.
    final d = (_landing - targetCenter).distance / _r.radius;
    int pts;
    if (d <= 0.06) {
      pts = 150;
      bullseyes++;
      celebrate('mouche');
      particles.fireworks(_landing);
    } else if (d <= 1) {
      final ring = 10 - (d * 10).floor();
      pts = ring.clamp(1, 10) * 10;
      cue(sfx: ring >= 8 ? Sfx.score : Sfx.hit, haptic: Haptic.light);
    } else {
      pts = 0;
      cue(sfx: Sfx.miss);
    }
    points += pts == 150 ? 10 : pts ~/ 10;
    score += pts;
    _hits.add((_landing - targetCenter, pts));
    _show = (0.8 * stepsPerSecond).round();
  }

  @override
  Map<String, num> get stats => {
    'points': points,
    'bullseyes': bullseyes,
    'arrows': math.min(shot, arrows),
  };

  // ── 3D rendering ──────────────────────────────────────────────────────
  // Telephoto view down the range. The target face (plane z = 0) maps 1:1
  // to arena coordinates, so the game logic stays in screen space.
  static const double _horizon = 300;
  static const double _groundY = -92;
  static final double _focal = 320 / math.tan(15 * math.pi / 180);
  static final Camera3D _camera = Camera3D(
    eye: V3(180, 0, _focal),
    target: const V3(180, 0, 0),
    fovDegrees: 30,
    center: const Offset(180, _horizon),
  );
  static V3 _p(Offset o, [double z = 0]) => V3(o.dx, _horizon - o.dy, z);
  static const V3 _arrowDir = V3(0.08, 0.12, 1);

  @override
  void render(Canvas canvas) {
    _drawScenery(canvas);
    final c = targetCenter;
    final rad = _r.radius;
    final s = Scene3D(
      _camera,
      light: const V3(-0.5, 0.9, 0.6),
      fogColor: const Color(0xFFB8D8E8),
      fogStart: 2500,
      fogEnd: 9000,
    );
    // Mown grass with stripes, lane lines converging to the horizon.
    s.ground(
      Rect.fromLTRB(-1400, -9000, 1760, _focal - 10),
      (i, j) => tint(
        j.isEven ? const Color(0xFF5E9B45) : const Color(0xFF6FAE52),
        (cellNoise(i, j) - 0.5) * 0.06,
      ),
      cell: 160,
      height: _groundY,
    );
    for (final x in [-260.0, 20, 340, 620]) {
      s.quad(
        V3(x - 2.5, _groundY, -9000),
        V3(x - 2.5, _groundY, _focal - 10),
        V3(x + 2.5, _groundY, _focal - 10),
        V3(x + 2.5, _groundY, -9000),
        const Color(0xFFF5F5F5),
        layer: Layer.surface,
      );
    }
    // Neighbouring lanes' targets far away, and the wind flag.
    for (final (x, z) in [
      (-420.0, -2400.0),
      (780.0, -1800.0),
      (-90.0, -5200.0),
    ]) {
      _boss(s, V3(x, _groundY, z), 90, withFace: true);
    }
    const pole = V3(330, _groundY, -260);
    s.tube(pole, pole + const V3(0, 260, 0), 2.2, 1.6, const Color(0xFFECEFF1));
    final w = _r.wind;
    final lean = (w.dx / 24).clamp(-1.0, 1.0);
    final top = pole + const V3(0, 258, 0);
    final flap = math.sin(elapsed * 9) * 6;
    final fly = V3(
      lean * 70 + (lean.abs() < 0.1 ? 14 : 0),
      -30 + lean.abs() * 24,
      flap,
    );
    s
      ..tri(
        top,
        top + const V3(0, -40, 0),
        top + fly,
        const Color(0xFFFFC107),
        doubleSided: true,
      )
      ..shadow(pole.flat, 18, height: _groundY + 0.5);
    // This lane's straw boss on its stand (moves with the target).
    _boss(
      s,
      V3(c.dx, _groundY, -14),
      rad,
      withFace: false,
      faceY: _horizon - c.dy,
    );
    s.render(canvas);

    // Target face (FITA colours) painted on the boss front, then arrows.
    const colors = [
      Color(0xFFF5F5F5),
      Color(0xFFF5F5F5),
      Color(0xFF212121),
      Color(0xFF212121),
      Color(0xFF1E88E5),
      Color(0xFF1E88E5),
      Color(0xFFE53935),
      Color(0xFFE53935),
      Color(0xFFFFD23F),
      Color(0xFFFFD23F),
    ];
    final line = Paint()
      ..color = const Color(0x55000000)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6;
    for (var i = 0; i < 10; i++) {
      final r = rad * (1 - i / 10);
      canvas
        ..drawCircle(c, r, Paint()..color = colors[i])
        ..drawCircle(c, r, line);
    }
    canvas
      ..drawCircle(c, rad * 0.06, line)
      ..drawCircle(
        c,
        rad,
        Paint()
          ..shader = const RadialGradient(
            center: Alignment(-0.4, -0.5),
            colors: [Color(0x22FFFFFF), Color(0x00FFFFFF), Color(0x33000000)],
            stops: [0, 0.6, 1],
          ).createShader(Rect.fromCircle(center: c, radius: rad)),
      );
    final a = Scene3D(_camera, light: const V3(-0.5, 0.9, 0.6));
    final shade = Paint()
      ..color = const Color(0x55000000)
      ..strokeWidth = 2
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    for (final (off, _)
        in _hits.length > 3 ? _hits.sublist(_hits.length - 3) : _hits) {
      final hit = c + off;
      canvas.drawLine(hit, hit.translate(6, 10), shade);
      _arrow3d(a, _p(hit), _arrowDir);
    }
    if (_flight > 0) {
      final t = 1 - _flight / (0.45 * stepsPerSecond);
      final to = _p(_landing);
      final from = V3(150, -40, _focal - 230);
      final arc = math.sin(t * math.pi) * 30;
      final tip = from + (to - from) * t + V3(0, arc, 0);
      final dir =
          (from - to).normalized + V3(0, -math.cos(t * math.pi) * 0.04, 0);
      _arrow3d(a, tip, dir);
    }
    _bow3d(a);
    a.render(canvas);

    if (_pointer != null) {
      final sight = _sight;
      final p = Paint()
        ..color = _draw < _minDraw ? Colors.white54 : const Color(0xFFE8322F)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;
      canvas
        ..drawCircle(sight, 9, p)
        ..drawLine(sight.translate(-14, 0), sight.translate(14, 0), p)
        ..drawLine(sight.translate(0, -14), sight.translate(0, 14), p);
    } else if (shot < arrows && _flight == 0 && _show == 0) {
      drawText(
        canvas,
        '👇',
        const Offset(220, 540),
        size: 32,
        align: TextAlign.center,
      );
    }
    if (_r.wind.distance > 4) {
      drawWind(canvas, const Offset(320, 110), _r.wind, max: 24);
    }
    drawText(
      canvas,
      '🏹 ${math.max(0, arrows - shot)}',
      const Offset(16, 100),
      size: 16,
    );
    if (_show > 0 && _hits.isNotEmpty) {
      drawText(
        canvas,
        _hits.last.$2 == 150 ? '★' : '${_hits.last.$2 ~/ 10}',
        const Offset(180, 420),
        size: 40,
        display: true,
        align: TextAlign.center,
        color: const Color(0xFFFFD23F),
      );
    }
  }

  /// Sky, clouds, distant hills and a tree line on the horizon.
  void _drawScenery(Canvas c) {
    drawSky(
      c,
      const Rect.fromLTWH(0, 0, 360, _horizon + 2),
      const Color(0xFF4F9FDE),
      const Color(0xFFCFE8F5),
    );
    final cloud = Paint()..color = const Color(0xCCFFFFFF);
    for (var k = 0; k < 4; k++) {
      final x = (cellNoise(k, 1, 5) * 420 + elapsed * 3) % 460 - 50;
      final y = 30 + cellNoise(k, 2, 5) * 110;
      final w = 50 + cellNoise(k, 3, 5) * 60;
      c
        ..drawOval(
          Rect.fromCenter(center: Offset(x, y), width: w, height: w * 0.32),
          cloud,
        )
        ..drawOval(
          Rect.fromCenter(
            center: Offset(x + w * 0.2, y - w * 0.1),
            width: w * 0.55,
            height: w * 0.3,
          ),
          cloud,
        );
    }
    final hills = Path()..moveTo(0, _horizon);
    for (var x = 0.0; x <= 360; x += 12) {
      hills.lineTo(
        x,
        _horizon - 22 - math.sin(x / 47) * 9 - math.sin(x / 19 + 1) * 4,
      );
    }
    hills
      ..lineTo(360, _horizon)
      ..close();
    c.drawPath(hills, Paint()..color = const Color(0xFF8FB3A6));
    final trees = Path()..moveTo(0, _horizon + 1);
    for (var k = 0; k <= 60; k++) {
      final x = k * 6.0;
      trees.lineTo(x, _horizon - 6 - cellNoise(k, 4, 9) * 9);
    }
    trees
      ..lineTo(360, _horizon + 1)
      ..close();
    c.drawPath(trees, Paint()..color = const Color(0xFF4C7A4E));
  }

  /// Straw boss on a wooden A-frame; [base] = ground point under the face.
  static void _boss(
    Scene3D s,
    V3 base,
    double rad, {
    required bool withFace,
    double? faceY,
  }) {
    const straw = Color(0xFFD9B26A);
    const wood = Color(0xFF7B5236);
    final size = rad * 2 + 20;
    final cy = faceY ?? base.y + rad + 70;
    final bottom = cy - size / 2;
    s.box(V3(base.x, bottom, base.z - 14), size, size, 28, straw);
    for (final dx in [-size * 0.38, size * 0.38]) {
      s
        ..tube(
          V3(base.x + dx, base.y, base.z + 6),
          V3(base.x + dx, bottom + 4, base.z - 4),
          3.5,
          3.5,
          wood,
        )
        ..tube(
          V3(base.x + dx, base.y, base.z - size * 0.6),
          V3(base.x + dx, bottom + size * 0.8, base.z - 28),
          3.5,
          3.5,
          wood,
        );
    }
    s.shadow(
      Offset(base.x + 18, base.z - 20),
      size * 0.6,
      height: base.y + 0.5,
      stretch: 1.2,
    );
    if (withFace) {
      for (final (i, col) in const [
        Color(0xFFF5F5F5),
        Color(0xFF212121),
        Color(0xFF1E88E5),
        Color(0xFFE53935),
        Color(0xFFFFD23F),
      ].indexed) {
        final r = rad * (1 - i / 5);
        const n = 16;
        for (var k = 0; k < n; k++) {
          final a0 = k / n * 2 * math.pi, a1 = (k + 1) / n * 2 * math.pi;
          s.tri(
            V3(base.x, cy, base.z + 0.5 + i * 0.3),
            V3(
              base.x + math.cos(a0) * r,
              cy + math.sin(a0) * r,
              base.z + 0.5 + i * 0.3,
            ),
            V3(
              base.x + math.cos(a1) * r,
              cy + math.sin(a1) * r,
              base.z + 0.5 + i * 0.3,
            ),
            col,
            doubleSided: true,
          );
        }
      }
    }
  }

  /// Carbon arrow: [tip] in the target, [dir] from the tip towards the nock.
  static void _arrow3d(Scene3D s, V3 tip, V3 dir) {
    final d = dir.normalized;
    V3 at(double l) => tip + d * l;
    s
      ..tube(at(0), at(84), 0.9, 0.9, const Color(0xFF263238), segments: 6)
      ..tube(at(84), at(88), 1.2, 1.2, const Color(0xFFFF6F00), segments: 6);
    final helper = d.y.abs() < 0.9 ? const V3(0, 1, 0) : const V3(1, 0, 0);
    final u = d.cross(helper).normalized;
    final v = d.cross(u);
    for (final (k, side) in [
      u,
      (u * -0.5 + v * 0.87),
      (u * -0.5 - v * 0.87),
    ].indexed) {
      s.quad(
        at(70),
        at(74) + side * 4.5,
        at(83) + side * 4.5,
        at(84),
        k == 0 ? const Color(0xFFE53935) : const Color(0xFFF5F5F5),
        doubleSided: true,
      );
    }
  }

  /// The archer's recurve bow in the foreground; the string follows the
  /// draw and an arrow is nocked while aiming.
  void _bow3d(Scene3D s) {
    final aiming = _pointer != null;
    final pull = aiming ? ((_finger - _start).dy.clamp(0.0, 140.0) / 140) : 0.0;
    final z = _focal - 600;
    final grip = V3(122, -112 + (aiming ? 22 : 0), z);
    const riser = Color(0xFF37474F);
    const limb = Color(0xFF1A1A1A);
    final pts = <V3>[];
    for (var k = -6; k <= 6; k++) {
      final t = k / 6;
      final y = t * 120;
      // Recurve shape: limbs bend towards the target, tips flip back.
      final bend =
          -32 * t * t + (t.abs() > 0.85 ? 26 * (t.abs() - 0.85) / 0.15 : 0);
      pts.add(grip + V3(-bend * 0.8, y, -bend * 0.6));
    }
    for (var k = 0; k < pts.length - 1; k++) {
      final mid = (k - 5.5).abs() < 2;
      s.tube(
        pts[k],
        pts[k + 1],
        mid ? 5 : 3.2,
        mid ? 5 : 3.2,
        mid ? riser : limb,
      );
    }
    final nock = grip + V3(10, 0, 10 + pull * 150);
    s
      ..tube(pts.first, nock, 0.5, 0.5, const Color(0xFFEEEEEE), segments: 4)
      ..tube(nock, pts.last, 0.5, 0.5, const Color(0xFFEEEEEE), segments: 4);
    if (aiming || (_flight == 0 && _show == 0 && shot < arrows)) {
      final aim = _p(_pointer != null ? _sight : targetHome);
      final dir = (nock - aim).normalized;
      _arrow3d(s, nock - dir * 88, dir);
    }
  }
}
