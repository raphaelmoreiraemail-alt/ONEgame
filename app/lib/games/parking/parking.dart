import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../core/l10n/l10n.dart';
import '../../core/rng/seeded_random.dart';
import '../common/draw.dart';
import '../common/fingerprint.dart';
import '../common/game_sim.dart';
import '../common/game_types.dart';
import '../common/mini_game_definition.dart';

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

  void _drawCar(Canvas c, Obb o, Color color) {
    c
      ..save()
      ..translate(o.center.dx, o.center.dy)
      ..rotate(o.angle);
    drawBox(
      c,
      Rect.fromCenter(
        center: Offset.zero,
        width: o.halfL * 2,
        height: o.halfW * 2,
      ),
      color,
      radius: 6,
    );
    c
      ..drawRect(
        Rect.fromLTWH(
          o.halfL * 0.15,
          -o.halfW + 3,
          o.halfL * 0.5,
          o.halfW * 2 - 6,
        ),
        Paint()..color = const Color(0xAA90CAF9),
      )
      ..drawCircle(
        Offset(o.halfL - 3, -o.halfW + 4),
        2.5,
        Paint()..color = const Color(0xFFFFF59D),
      )
      ..drawCircle(
        Offset(o.halfL - 3, o.halfW - 4),
        2.5,
        Paint()..color = const Color(0xFFFFF59D),
      )
      ..restore();
  }

  @override
  void render(Canvas canvas) {
    canvas
      ..drawRect(Arena.rect, Paint()..color = const Color(0xFF263238))
      ..drawRect(lot, Paint()..color = const Color(0xFF546E7A));
    final s = _l.spot;
    final ok = car.corners.every((p) => s.inflate(2).contains(p));
    canvas
      ..drawRect(
        s,
        Paint()..color = ok ? const Color(0x5566BB6A) : const Color(0x33FFFFFF),
      )
      ..drawRect(
        s,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    for (final p in _l.parked) {
      _drawCar(canvas, p, const Color(0xFF90A4AE));
    }
    _drawCar(canvas, car, const Color(0xFFE8322F));
    // Steering wheel.
    canvas
      ..save()
      ..translate(wheelCenter.dx, wheelCenter.dy)
      ..rotate(_steer * 2.5)
      ..drawCircle(
        Offset.zero,
        50,
        Paint()
          ..color = const Color(0xFF212121)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 12,
      )
      ..drawLine(
        const Offset(-50, 0),
        const Offset(50, 0),
        Paint()
          ..color = const Color(0xFF212121)
          ..strokeWidth = 8,
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
      canvas.drawRRect(
        RRect.fromRectAndRadius(r, const Radius.circular(12)),
        Paint()..color = on ? const Color(0xFFFFD23F) : const Color(0xFF455A64),
      );
      drawText(
        canvas,
        label,
        r.center,
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
}
