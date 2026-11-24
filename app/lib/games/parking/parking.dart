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

/// 7.16 Créneau — park 4 cars in tighter and tighter spots.
class ParkingGame extends MiniGameDefinition {
  const ParkingGame();

  @override
  String get id => 'parking';
  @override
  String get emoji => '🚗';
  @override
  GameCategory get category => GameCategory.adresse;
  @override
  int get rulesVersion => 1;
  @override
  Set<String> get supportedModifiers => const {};
  @override
  ScoreBounds get scoreBounds => const ScoreBounds(0, 4 * 800);

  @override
  Map<String, num> get defaultTuning => const {
    'maxSpeed': 110,
    'reverseSpeed': 70,
  };

  @override
  String name(AppLocalizations l10n) => l10n.gameParkingName;
  @override
  String rule(AppLocalizations l10n) => l10n.gameParkingRule;

  @override
  String shareLine(AppLocalizations l10n, Map<String, num> s) => l10n
      .gameParkingShare(s['parked']?.toInt() ?? 0, s['bumps']?.toInt() ?? 0);

  @override
  List<(String, String)> statRows(AppLocalizations l10n, Map<String, num> s) =>
      [
        (l10n.statParked, '${s['parked'] ?? 0} / 4'),
        (l10n.statPrecision, '${s['precision'] ?? 0}'),
        (l10n.statBumps, '${s['bumps'] ?? 0}'),
      ];

  @override
  Map<String, String> highlightLabels(AppLocalizations l10n) => {
    'perfectPark': l10n.highlightPerfectPark,
  };

  @override
  GameSim createSim(GameContext ctx) => ParkingSim(ctx, this);

  @override
  String levelFingerprint(int seed, String? modifierId) => fingerprint([
    for (final l in ParkingLevel.generate(seed)) ...[
      l.parallel,
      l.spot.center.dx,
      l.spot.center.dy,
      l.margin,
    ],
  ]);
}

/// Oriented box.
class Obb {
  const Obb(this.center, this.halfW, this.halfL, this.angle);

  final Offset center;
  final double halfW;
  final double halfL;

  /// Heading of the long axis.
  final double angle;

  List<Offset> get corners {
    final f = Offset(math.cos(angle), math.sin(angle));
    final s = Offset(-f.dy, f.dx);
    return [
      center + f * halfL + s * halfW,
      center + f * halfL - s * halfW,
      center - f * halfL - s * halfW,
      center - f * halfL + s * halfW,
    ];
  }

  /// Separating axis test.
  bool overlaps(Obb o) {
    final a = corners, b = o.corners;
    for (final poly in [a, b]) {
      for (var i = 0; i < 2; i++) {
        final e = poly[i + 1] - poly[i];
        final axis = Offset(-e.dy, e.dx);
        double minA = double.infinity,
            maxA = -double.infinity,
            minB = double.infinity,
            maxB = -double.infinity;
        for (final p in a) {
          final v = p.dx * axis.dx + p.dy * axis.dy;
          minA = math.min(minA, v);
          maxA = math.max(maxA, v);
        }
        for (final p in b) {
          final v = p.dx * axis.dx + p.dy * axis.dy;
          minB = math.min(minB, v);
          maxB = math.max(maxB, v);
        }
        if (maxA < minB || maxB < minA) return false;
      }
    }
    return true;
  }
}

class ParkingLevel {
  const ParkingLevel(
    this.parallel,
    this.spot,
    this.parked,
    this.start,
    this.startAngle,
    this.margin,
    this.spotAngle,
  );

  final bool parallel;
  final Rect spot;
  final List<Obb> parked;
  final Offset start;
  final double startAngle;
  final double margin;

  /// Expected orientation of the parked car (axis, modulo π).
  final double spotAngle;

  static const double carW = 26, carL = 48;
  static const margins = [26.0, 20.0, 14.0, 10.0];

  static List<ParkingLevel> generate(int seed) {
    final r = SeededRandom.derive(seed, 'parking:levels');
    return [
      for (var i = 0; i < 4; i++)
        () {
          final m = margins[i];
          final parallel = i.isOdd ? r.chance(0.7) : r.chance(0.3);
          if (parallel) {
            final len = carL + 2 * m + 8;
            final cx = r.doubleInRange(130, 230);
            final spot = Rect.fromCenter(
              center: Offset(cx, 190),
              width: len,
              height: carW + 10,
            );
            return ParkingLevel(
              true,
              spot,
              [
                Obb(
                  Offset(spot.left - carL / 2 - 4, 190),
                  carW / 2,
                  carL / 2,
                  0,
                ),
                Obb(
                  Offset(spot.right + carL / 2 + 4, 190),
                  carW / 2,
                  carL / 2,
                  0,
                ),
              ],
              Offset(r.doubleInRange(60, 110), 300),
              0,
              m,
              0,
            );
          }
          final cx = r.doubleInRange(110, 250);
          final spot = Rect.fromCenter(
            center: Offset(cx, 200),
            width: carW + 2 * m,
            height: carL + 16,
          );
          return ParkingLevel(
            false,
            spot,
            [
              Obb(
                Offset(spot.left - carW / 2 - 6, 200),
                carW / 2,
                carL / 2,
                math.pi / 2,
              ),
              Obb(
                Offset(spot.right + carW / 2 + 6, 200),
                carW / 2,
                carL / 2,
                math.pi / 2,
              ),
            ],
            Offset(r.doubleInRange(50, 90), 360),
            0,
            m,
            math.pi / 2,
          );
        }(),
    ];
  }
}

class ParkingSim extends GameSim {
  ParkingSim(super.ctx, ParkingGame def)
    : levels = ParkingLevel.generate(ctx.seed),
      _vmax = ctx.tune('maxSpeed', def.defaultTuning['maxSpeed']!),
      _vrev = ctx.tune('reverseSpeed', def.defaultTuning['reverseSpeed']!) {
    _load();
  }

  static const Rect lot = Rect.fromLTRB(16, 140, 344, 470);
  static const Rect forward = Rect.fromLTRB(250, 490, 344, 560);
  static const Rect reverse = Rect.fromLTRB(250, 566, 344, 636);
  static const Offset wheelCenter = Offset(110, 560);

  final List<ParkingLevel> levels;
  final double _vmax, _vrev;

  int level = 0;
  int parked = 0, bumps = 0, precisionTotal = 0;
  Offset _pos = Offset.zero;
  double _angle = 0, _speed = 0, _steer = 0;
  int _still = 0, _bumpCooldown = 0, _transition = 0;
  final Map<int, Offset> _pointers = {};
  int? _wheel;
  double _wheelFrom = 0, _steerFrom = 0;

  ParkingLevel get _l => levels[math.min(level, levels.length - 1)];

  Obb get car =>
      Obb(_pos, ParkingLevel.carW / 2, ParkingLevel.carL / 2, _angle);

  bool get _fwd => _pointers.values.any(forward.contains);
  bool get _rev => _pointers.values.any(reverse.contains);

  void _load() {
    _pos = _l.start;
    _angle = _l.startAngle;
    _speed = 0;
    _steer = 0;
    _still = 0;
  }

  @visibleForTesting
  void debugPlace(Offset pos, double angle) {
    _pos = pos;
    _angle = angle;
    _speed = 0;
  }

  @visibleForTesting
  ParkingLevel get debugLevel => _l;

  @override
  Color get backgroundColor => const Color(0xFF37474F);

  @override
  Offset get focus => _pos;

  @override
  void onPointer(PointerPhase phase, int pointer, Offset pos) {
    switch (phase) {
      case PointerPhase.down:
        _pointers[pointer] = pos;
        if (_wheel == null &&
            !forward.contains(pos) &&
            !reverse.contains(pos)) {
          _wheel = pointer;
          _wheelFrom = pos.dx;
          _steerFrom = _steer;
        }
      case PointerPhase.move:
        _pointers[pointer] = pos;
        if (pointer == _wheel) {
          _steer = (_steerFrom + (pos.dx - _wheelFrom) / 120).clamp(-0.6, 0.6);
        }
      case PointerPhase.up:
        _pointers.remove(pointer);
        if (pointer == _wheel) _wheel = null;
    }
  }

  bool _collides(Obb c) {
    for (final p in _l.parked) {
      if (c.overlaps(p)) return true;
    }
    return c.corners.any((p) => !lot.contains(p));
  }

  @override
  void tick() {
    tickParticles();
    if (_transition > 0) {
      if (--_transition == 0) {
        level++;
        if (level >= levels.length) {
          over = true;
        } else {
          _load();
        }
      }
      return;
    }
    if (_bumpCooldown > 0) _bumpCooldown--;
    if (_fwd) {
      _speed = math.min(_vmax, _speed + 170 * stepDt);
    } else if (_rev) {
      _speed = math.max(-_vrev, _speed - 170 * stepDt);
    } else {
      const f = 220 * stepDt;
      _speed = _speed.abs() < f ? 0 : _speed - f * _speed.sign;
    }
    final prevPos = _pos, prevAngle = _angle;
    _angle += _speed / 34 * math.tan(_steer) * stepDt;
    _pos += Offset(math.cos(_angle), math.sin(_angle)) * _speed * stepDt;
    if (_collides(car)) {
      _pos = prevPos;
      _angle = prevAngle;
      _speed = 0;
      if (_bumpCooldown == 0) {
        bumps++;
        score = math.max(0, score - 100);
        _bumpCooldown = (0.6 * stepsPerSecond).round();
        particles.burst(
          _pos,
          const Color(0xFFFFD23F),
          count: 10,
          gravity: 0,
          speed: 80,
        );
        cue(sfx: Sfx.hit, haptic: Haptic.heavy);
      }
    }
    final inside = car.corners.every((p) => _l.spot.inflate(2).contains(p));
    _still = inside && _speed.abs() < 5 ? _still + 1 : 0;
    if (_still > (0.4 * stepsPerSecond).round()) _park();
  }

  void _park() {
    var da = ((_angle - _l.spotAngle) % math.pi).abs();
    da = math.min(da, math.pi - da) * 180 / math.pi;
    final dc = (_pos - _l.spot.center).distance;
    final precision =
        (150 * (1 - da / 15).clamp(0.0, 1.0) +
                150 * (1 - dc / (_l.margin + 6)).clamp(0.0, 1.0))
            .round();
    parked++;
    precisionTotal += precision;
    score += 500 + precision;
    if (precision >= 270) {
      celebrate('perfectPark');
      particles.fireworks(_pos);
    } else {
      cue(sfx: Sfx.score, haptic: Haptic.medium);
      particles.burst(_pos, const Color(0xFF66BB6A), count: 20, gravity: 0);
    }
    _transition = stepsPerSecond;
  }

  @override
  Map<String, num> get stats => {
    'parked': parked,
    'bumps': bumps,
    'precision': precisionTotal,
  };

  // ── 3D rendering ──────────────────────────────────────────────────────
  // The lot (x, y) → V3(x, h, y), seen from above the entrance; the wheel
  // and pedals below stay flat on-screen controls.
  static final Camera3D _camera = Camera3D(
    eye: const V3(180, 640, 1010),
    target: const V3(180, 0, 300),
    fovDegrees: 40,
    center: const Offset(180, 292),
  );

  @override
  void render(Canvas canvas) {
    drawSky(
      canvas,
      Arena.rect,
      const Color(0xFF1C262B),
      const Color(0xFF2B3A42),
    );
    final s = Scene3D(_camera, light: const V3(-0.4, 1, 0.35), ambient: 0.5);
    // Pavement around, asphalt lot with low concrete kerbs.
    s
      ..ground(
        lot.inflate(420),
        (i, j) =>
            tint(const Color(0xFF9E9E9E), (cellNoise(i, j, 2) - 0.5) * 0.06),
        cell: 70,
        height: -2,
      )
      ..ground(
        lot,
        (i, j) =>
            tint(const Color(0xFF4A5056), (cellNoise(i, j, 3) - 0.5) * 0.05),
        cell: 41,
        layer: Layer.surface,
      );
    final k = lot.inflate(6);
    for (final r in [
      Rect.fromLTRB(k.left, k.top, k.right, lot.top),
      Rect.fromLTRB(k.left, lot.bottom, k.right, k.bottom),
      Rect.fromLTRB(k.left, lot.top, lot.left, lot.bottom),
      Rect.fromLTRB(lot.right, lot.top, k.right, lot.bottom),
    ]) {
      s.box(
        V3(r.center.dx, -2, r.center.dy),
        r.width,
        8,
        r.height,
        const Color(0xFFBDBDBD),
        layer: Layer.surface,
      );
    }
    // Painted bays around the parked cars, the target spot highlighted.
    void outline(List<Offset> c, Color col, double w) {
      for (var i = 0; i < 4; i++) {
        final a = c[i], b = c[(i + 1) % 4];
        final d = b - a;
        final n = Offset(-d.dy, d.dx) / d.distance * (w / 2);
        s.quad(
          V3.ground(a - n, 0.3),
          V3.ground(b - n, 0.3),
          V3.ground(b + n, 0.3),
          V3.ground(a + n, 0.3),
          col,
          layer: Layer.decal,
          doubleSided: true,
          lit: false,
        );
      }
    }

    for (final p in _l.parked) {
      outline(
        Obb(p.center, p.halfW + 6, p.halfL + 8, p.angle).corners,
        const Color(0xFFE0E0E0),
        2,
      );
    }
    final spot = _l.spot;
    final ok = car.corners.every((p) => spot.inflate(2).contains(p));
    s.ground(
      spot,
      (_, _) => ok ? const Color(0xFF4CAF50) : const Color(0xFF5A6B4A),
      cell: 400,
      height: 0.2,
      layer: Layer.decal,
    );
    outline(
      [spot.topLeft, spot.topRight, spot.bottomRight, spot.bottomLeft],
      const Color(0xFFFFFFFF),
      2.5,
    );
    final pp = _camera.project(V3.ground(spot.center, 0.5));
    for (final p in _l.parked) {
      _car3d(s, p, const Color(0xFF90A4AE), braking: false);
    }
    _car3d(s, car, const Color(0xFFE8322F), braking: _speed.abs() < 1 || _rev);
    // Lamp posts at the corners.
    for (final c in [lot.topLeft, lot.topRight]) {
      final b = V3.ground(c + Offset(c.dx < 180 ? -14 : 14, -14));
      s
        ..tube(
          b,
          b + const V3(0, 120, 0),
          2.2,
          1.6,
          const Color(0xFF37474F),
          segments: 5,
        )
        ..box(b + const V3(0, 118, 0), 16, 4, 8, const Color(0xFFFFF3C4));
    }
    s.render(canvas);
    if (pp != null && !ok) {
      drawText(
        canvas,
        'P',
        pp,
        size: 20,
        display: true,
        align: TextAlign.center,
        color: const Color(0x99FFFFFF),
      );
    }

    // Controls: steering wheel and pedals.
    canvas
      ..drawRect(
        const Rect.fromLTRB(0, 480, 360, 640),
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1A1F23), Color(0xFF0E1214)],
          ).createShader(const Rect.fromLTRB(0, 480, 360, 640)),
      )
      ..save()
      ..translate(wheelCenter.dx, wheelCenter.dy)
      ..rotate(_steer * 2.5);
    final rim = Paint()
      ..shader = const SweepGradient(
        colors: [
          Color(0xFF424242),
          Color(0xFF1B1B1B),
          Color(0xFF555555),
          Color(0xFF1B1B1B),
          Color(0xFF424242),
        ],
      ).createShader(Rect.fromCircle(center: Offset.zero, radius: 56))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 13;
    final spoke = Paint()
      ..color = const Color(0xFF2B2B2B)
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round;
    canvas
      ..drawCircle(
        const Offset(2, 4),
        50,
        Paint()
          ..color = const Color(0x55000000)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 13,
      )
      ..drawCircle(Offset.zero, 50, rim)
      ..drawLine(const Offset(-44, 0), const Offset(44, 0), spoke)
      ..drawLine(Offset.zero, const Offset(0, 44), spoke)
      ..drawCircle(
        Offset.zero,
        14,
        Paint()
          ..shader = const RadialGradient(
            colors: [Color(0xFF616161), Color(0xFF212121)],
          ).createShader(Rect.fromCircle(center: Offset.zero, radius: 14)),
      )
      ..drawCircle(
        const Offset(0, -50),
        6,
        Paint()..color = const Color(0xFFFFD23F),
      )
      ..restore();
    for (final (r, label, on) in [
      (forward, '▲', _fwd),
      (reverse, '▼ R', _rev),
    ]) {
      final rr = RRect.fromRectAndRadius(r, const Radius.circular(12));
      canvas
        ..drawRRect(
          rr.shift(const Offset(0, 3)),
          Paint()..color = const Color(0xFF050708),
        )
        ..drawRRect(
          on ? rr.shift(const Offset(0, 2)) : rr,
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: on
                  ? const [Color(0xFFFFE27A), Color(0xFFE6B800)]
                  : const [Color(0xFF5B6B74), Color(0xFF37444B)],
            ).createShader(r),
        );
      drawText(
        canvas,
        label,
        r.center.translate(0, on ? 2 : 0),
        size: 20,
        display: true,
        align: TextAlign.center,
        color: on ? Colors.black : Colors.white,
      );
    }
    drawText(
      canvas,
      '🅿️ ${math.min(level + 1, 4)}/4',
      const Offset(16, 100),
      size: 16,
    );
  }

  /// Small hatchback: body, glass cabin with painted roof, wheels, lights.
  static void _car3d(Scene3D s, Obb o, Color color, {required bool braking}) {
    final a = o.angle;
    final f = V3(math.cos(a), 0, math.sin(a));
    final r = V3(-math.sin(a), 0, math.cos(a));
    final c = V3.ground(o.center);
    final l = o.halfL, w = o.halfW;
    s
      ..shadow(o.center.translate(4, 4), l * 1.05, opacity: 0.4, stretch: 1)
      ..box(
        c + const V3(0, 3, 0),
        l * 2,
        10,
        w * 2,
        color,
        yaw: a,
        top: tint(color, 0.1),
      )
      ..box(
        c - f * (l * 0.12) + const V3(0, 13, 0),
        l * 1.05,
        9,
        w * 1.7,
        const Color(0xFF22313A),
        yaw: a,
        top: tint(color, 0.05),
      );
    for (final fx in [l * 0.62, -l * 0.62]) {
      for (final side in [-1.0, 1.0]) {
        final h = c + f * fx + r * (side * w) + const V3(0, 5, 0);
        s.tube(
          h - r * 2.4,
          h + r * 2.4,
          5,
          5,
          const Color(0xFF151515),
          segments: 8,
          capped: true,
        );
      }
    }
    for (final side in [-1.0, 1.0]) {
      s
        ..sphere(
          c + f * (l - 0.5) + r * (side * w * 0.62) + const V3(0, 9, 0),
          2.2,
          const Color(0xFFFFF8D6),
          lat: 3,
          lon: 5,
        )
        ..sphere(
          c - f * (l - 0.5) + r * (side * w * 0.62) + const V3(0, 9, 0),
          2,
          braking ? const Color(0xFFFF1744) : const Color(0xFF8E1B1B),
          lat: 3,
          lon: 5,
        );
    }
  }
}
