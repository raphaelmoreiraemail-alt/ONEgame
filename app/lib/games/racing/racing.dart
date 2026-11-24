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

/// 7.21 Course de karts — 3 laps against 3 AI karts.
class RacingGame extends MiniGameDefinition {
  const RacingGame();

  @override
  String get id => 'racing';
  @override
  String get emoji => '🏎️';
  @override
  GameCategory get category => GameCategory.arcade;
  @override
  int get rulesVersion => 1;
  @override
  Set<String> get supportedModifiers => {Modifiers.mirror, Modifiers.ice};
  @override
  ScoreBounds get scoreBounds => const ScoreBounds(0, 3000 + 1000 + 30 * 50);

  @override
  Map<String, num> get defaultTuning => const {
    'maxSpeed': 330,
    'grip': 5,
    'aiMin': 0.84,
    'aiMax': 0.95,
  };

  @override
  String name(AppLocalizations l10n) => l10n.gameRacingName;
  @override
  String rule(AppLocalizations l10n) => l10n.gameRacingRule;

  @override
  String shareLine(AppLocalizations l10n, Map<String, num> s) =>
      l10n.gameRacingShare(
        s['position']?.toInt() ?? 4,
        RacingGame.fmt(s['bestLapMs']?.toInt() ?? 0),
      );

  static String fmt(int ms) => ms <= 0
      ? '—'
      : '${ms ~/ 1000}.${((ms % 1000) ~/ 10).toString().padLeft(2, '0')}';

  @override
  List<(String, String)> statRows(AppLocalizations l10n, Map<String, num> s) =>
      [
        (l10n.statPosition, '${s['position'] ?? 4} / 4'),
        (l10n.statBestLap, fmt(s['bestLapMs']?.toInt() ?? 0)),
        (l10n.statBoosts, '${s['boosts'] ?? 0}'),
      ];

  @override
  Map<String, String> highlightLabels(AppLocalizations l10n) => {
    'victory': l10n.highlightVictory,
  };

  @override
  GameSim createSim(GameContext ctx) => RacingSim(ctx, this);

  @override
  String levelFingerprint(int seed, String? modifierId) {
    final t = RaceTrack.generate(seed);
    return fingerprint([
      for (final p in t.center.where((_) => true).take(60)) ...[p.dx, p.dy],
      ...t.pads,
      ...t.aiSpeeds,
    ]);
  }
}

/// Closed circuit assembled from seeded control points (Catmull-Rom).
class RaceTrack {
  RaceTrack(this.center, this.pads, this.aiSpeeds);

  final List<Offset> center;

  /// Indexes of boost pads on the centerline.
  final List<int> pads;
  final List<double> aiSpeeds;

  static const double width = 96;

  late final List<double> _cum = () {
    final c = <double>[0];
    for (var i = 1; i <= center.length; i++) {
      c.add(c.last + (center[i % center.length] - center[i - 1]).distance);
    }
    return c;
  }();

  double get length => _cum.last;
  double distAt(int i) => _cum[i];

  static RaceTrack generate(
    int seed, [
    double aiMin = 0.84,
    double aiMax = 0.95,
  ]) {
    final r = SeededRandom.derive(seed, 'racing:track');
    const n = 10;
    final ctrl = <Offset>[
      for (var i = 0; i < n; i++)
        Offset.fromDirection(
              i / n * 2 * math.pi + r.doubleInRange(-0.15, 0.15),
              r.doubleInRange(620, 980),
            ) *
            1.0,
    ];
    final pts = <Offset>[];
    for (var i = 0; i < n; i++) {
      final p0 = ctrl[(i - 1 + n) % n],
          p1 = ctrl[i],
          p2 = ctrl[(i + 1) % n],
          p3 = ctrl[(i + 2) % n];
      for (var k = 0; k < 24; k++) {
        final t = k / 24, t2 = t * t, t3 = t2 * t;
        pts.add(
          (p1 * 2 +
                  (p2 - p0) * t +
                  (p0 * 2 - p1 * 5 + p2 * 4 - p3) * t2 +
                  (p1 * 3 - p0 - p2 * 3 + p3) * t3) *
              0.5,
        );
      }
    }
    final a = SeededRandom.derive(seed, 'racing:ai');
    return RaceTrack(
      pts,
      [for (var i = 0; i < 4; i++) r.nextInt(pts.length)],
      [for (var i = 0; i < 3; i++) a.doubleInRange(aiMin, aiMax)],
    );
  }

  /// Nearest centerline index around [hint].
  int nearest(Offset p, int hint) {
    var best = hint;
    var bestD = double.infinity;
    for (var k = -30; k <= 30; k++) {
      final i = (hint + k) % center.length;
      final d = (center[i] - p).distanceSquared;
      if (d < bestD) {
        bestD = d;
        best = i;
      }
    }
    return best;
  }
}

class _Kart {
  _Kart(this.pos, this.heading, this.color);

  Offset pos;
  double heading;
  double speed = 0;
  Offset vel = Offset.zero;
  int index = 0;
  int laps = 0;
  bool finished = false;
  int finishStep = 0;
  final Color color;
  double lane = 0;
}

class RacingSim extends GameSim {
  RacingSim(super.ctx, RacingGame def)
    : track = RaceTrack.generate(
        ctx.seed,
        ctx.tune('aiMin', def.defaultTuning['aiMin']!),
        ctx.tune('aiMax', def.defaultTuning['aiMax']!),
      ),
      _max = ctx.tune('maxSpeed', def.defaultTuning['maxSpeed']!),
      _grip =
          ctx.tune('grip', def.defaultTuning['grip']!) *
          (ctx.has(Modifiers.ice) ? 0.45 : 1),
      _mirror = ctx.has(Modifiers.mirror) {
    final start = track.center[0];
    final dir = track.center[1] - start;
    final h = math.atan2(dir.dy, dir.dx);
    final side = Offset(-math.sin(h), math.cos(h));
    const colors = [Color(0xFF1E88E5), Color(0xFF43A047), Color(0xFFFFB300)];
    for (var i = 0; i < 3; i++) {
      final k = _Kart(
        start + side * ((i - 1) * 30.0) - dir / dir.distance * 40,
        h,
        colors[i],
      )..lane = (i - 1) * 22.0;
      _ai.add(k);
    }
    _me = _Kart(start - dir / dir.distance * 90, h, const Color(0xFFE8322F));
  }

  static const int laps = 3;
  final RaceTrack track;
  final double _max;
  final double _grip;
  final bool _mirror;
  late final _Kart _me;
  final List<_Kart> _ai = [];

  int boosts = 0;
  int _boostSteps = 0;
  double _driftTime = 0;
  int _lapStart = 0;
  int bestLapSteps = 0;
  int position = 4;
  bool finished = false;
  final Map<int, Offset> _pointers = {};
  int? _steerPointer;
  double _steerFrom = 0;
  double _steer = 0;
  int _countdown = stepsPerSecond * 2;

  bool get _drifting => _pointers.length >= 2;

  @visibleForTesting
  Offset get debugPos => _me.pos;

  @visibleForTesting
  double get debugHeading => _me.heading;

  @override
  Color get backgroundColor => const Color(0xFF558B2F);

  @override
  Offset get focus => const Offset(180, 420);

  @override
  void onPointer(PointerPhase phase, int pointer, Offset pos) {
    switch (phase) {
      case PointerPhase.down:
        _pointers[pointer] = pos;
        if (_steerPointer == null) {
          _steerPointer = pointer;
          _steerFrom = pos.dx;
        }
      case PointerPhase.move:
        _pointers[pointer] = pos;
        if (pointer == _steerPointer) {
          final s = ((pos.dx - _steerFrom) / 70).clamp(-1.0, 1.0);
          _steer = _mirror ? -s : s;
        }
      case PointerPhase.up:
        _pointers.remove(pointer);
        if (pointer == _steerPointer) {
          _steerPointer = null;
          _steer = 0;
        }
        if (_pointers.length < 2 && _driftTime > 0.8) {
          // A long drift gives a boost on release.
          _boostSteps = stepsPerSecond;
          boosts++;
          cue(sfx: Sfx.whoosh, haptic: Haptic.medium);
        }
        if (_pointers.length < 2) _driftTime = 0;
    }
  }

  double _progress(_Kart k) => k.laps * track.length + track.distAt(k.index);

  @override
  void tick() {
    tickParticles();
    if (_countdown > 0) {
      _countdown--;
      return;
    }
    _driveMe();
    for (final k in _ai) {
      _driveAi(k);
    }
    if (!finished) {
      position =
          1 +
          _ai.where((k) => k.finished || _progress(k) > _progress(_me)).length;
    }
  }

  void _driveMe() {
    final k = _me;
    final off = (k.pos - track.center[k.index]).distance > RaceTrack.width / 2;
    final boost = _boostSteps > 0 ? 1.4 : 1.0;
    if (_boostSteps > 0) _boostSteps--;
    final target = (off ? _max * 0.42 : _max) * boost * (_drifting ? 0.85 : 1);
    k.speed += (target - k.speed) * 1.6 * stepDt;
    k.heading +=
        _steer *
        (_drifting ? 3.0 : 2.2) *
        stepDt *
        (k.speed / _max).clamp(0.2, 1.0);
    final want = Offset(math.cos(k.heading), math.sin(k.heading)) * k.speed;
    final grip = (_drifting ? _grip * 0.35 : _grip) * stepDt;
    k.vel = Offset.lerp(k.vel, want, grip.clamp(0.0, 1.0))!;
    k.pos += k.vel * stepDt;
    if (_drifting && k.speed > 120) _driftTime += stepDt;
    for (final p in track.pads) {
      if ((k.pos - track.center[p]).distance < 26 &&
          _boostSteps < stepsPerSecond ~/ 2) {
        _boostSteps = stepsPerSecond;
        cue(sfx: Sfx.whoosh);
      }
    }
    _advance(k, mine: true);
  }

  void _driveAi(_Kart k) {
    if (k.finished) return;
    final i = _ai.indexOf(k);
    final ahead = track.center[(k.index + 8) % track.center.length];
    final dir = track.center[(k.index + 9) % track.center.length] - ahead;
    final side = Offset(-dir.dy, dir.dx) / math.max(1, dir.distance);
    final target = ahead + side * k.lane;
    final d = target - k.pos;
    final h = math.atan2(d.dy, d.dx);
    var dh = h - k.heading;
    while (dh > math.pi) {
      dh -= 2 * math.pi;
    }
    while (dh < -math.pi) {
      dh += 2 * math.pi;
    }
    k.heading += dh.clamp(-3 * stepDt, 3 * stepDt);
    final want =
        _max * track.aiSpeeds[i] * (1 - dh.abs().clamp(0.0, 0.6) * 0.5);
    k.speed += (want - k.speed) * 1.5 * stepDt;
    k.vel = Offset(math.cos(k.heading), math.sin(k.heading)) * k.speed;
    k.pos += k.vel * stepDt;
    _advance(k, mine: false);
  }

  void _advance(_Kart k, {required bool mine}) {
    final prev = k.index;
    k.index = track.nearest(k.pos, k.index);
    final n = track.center.length;
    if (prev > n * 0.8 && k.index < n * 0.2) {
      k.laps++;
      if (mine) {
        final lap = step - _lapStart;
        _lapStart = step;
        if (bestLapSteps == 0 || lap < bestLapSteps) bestLapSteps = lap;
        cue(sfx: Sfx.score, haptic: Haptic.medium);
      }
      if (k.laps >= laps) {
        k.finished = true;
        k.finishStep = step;
        if (mine) _finish();
      }
    } else if (prev < n * 0.2 && k.index > n * 0.8) {
      k.laps--; // went backwards over the line
    }
  }

  void _finish() {
    finished = true;
    position = 1 + _ai.where((k) => k.finished).length;
    if (position == 1) {
      celebrate('victory');
      particles.fireworks(const Offset(180, 300));
    }
    _rescore();
    over = true;
  }

  void _rescore() {
    final int base = switch (position) {
      1 => 3000,
      2 => 2000,
      3 => 1200,
      _ => 600,
    };
    final int lapBonus = bestLapSteps == 0
        ? 0
        : math.max(0.0, (40 - bestLapSteps / stepsPerSecond) * 40).round();
    score = base + math.min<int>(1000, lapBonus) + boosts * 50;
  }

  @override
  void onTimeUp() => _rescore();

  @override
  Map<String, num> get stats => {
    'position': position,
    'bestLapMs': bestLapSteps * 1000 ~/ stepsPerSecond,
    'boosts': boosts,
    'laps': math.min(_me.laps, laps),
  };

  // ── 3D rendering ──────────────────────────────────────────────────────
  // Sim (x, y) → V3(x, h, y); chase camera behind the player's kart.
  static const double _drawRange = 1700;

  late final List<Offset> _normals = [
    for (var i = 0; i < track.center.length; i++)
      () {
        final n = track.center.length;
        final t = track.center[(i + 1) % n] - track.center[(i - 1 + n) % n];
        final d = t / t.distance;
        return Offset(-d.dy, d.dx);
      }(),
  ];

  /// Trees placed once, away from the asphalt.
  late final List<(Offset, double)> _trees = () {
    final out = <(Offset, double)>[];
    for (var gx = -1300; gx <= 1300; gx += 140) {
      for (var gy = -1300; gy <= 1300; gy += 140) {
        final i = gx ~/ 140, j = gy ~/ 140;
        if (cellNoise(i, j, 31) < 0.45) continue;
        final p = Offset(
          gx + (cellNoise(i, j, 32) - 0.5) * 110,
          gy + (cellNoise(i, j, 33) - 0.5) * 110,
        );
        final near = track.center.any(
          (c) => (c - p).distance < RaceTrack.width / 2 + 70,
        );
        if (!near) out.add((p, 0.8 + cellNoise(i, j, 34) * 0.7));
      }
    }
    return out;
  }();

  @override
  void render(Canvas canvas) {
    final me = _me;
    final fwd = Offset(math.cos(me.heading), math.sin(me.heading));
    final eye = me.pos - fwd * 150;
    final look = me.pos + fwd * 220;
    final cam = Camera3D(
      eye: V3(eye.dx, 78, eye.dy),
      target: V3(look.dx, 0, look.dy),
      fovDegrees: 60,
      center: const Offset(180, 300),
    );
    final horizon =
        cam.project(V3.ground(me.pos + fwd * 100000, 78))?.dy ?? 200;
    drawSky(
      canvas,
      Rect.fromLTWH(0, 0, 360, horizon + 2),
      const Color(0xFF3F88D6),
      const Color(0xFFCDE6F7),
    );
    final hills = Path()..moveTo(0, horizon + 1);
    for (var x = 0.0; x <= 360; x += 8) {
      final a = me.heading * 120 + x;
      hills.lineTo(
        x,
        horizon - 10 - 14 * math.sin(a / 41).abs() - 6 * math.sin(a / 17),
      );
    }
    hills
      ..lineTo(360, horizon + 1)
      ..close();
    canvas
      ..drawPath(hills, Paint()..color = const Color(0xFF6E9A6A))
      ..drawRect(
        Rect.fromLTWH(0, horizon, 360, 640 - horizon),
        Paint()..color = const Color(0xFF6E9A5A),
      );
    final s = Scene3D(
      cam,
      light: const V3(-0.4, 1, 0.3),
      ambient: 0.5,
      fogColor: const Color(0xFFB9D3C2),
      fogStart: 700,
      fogEnd: _drawRange,
    );
    // Grass around the car, on a fixed grid so it does not swim.
    const cell = 220.0;
    final gx0 = ((me.pos.dx - _drawRange) / cell).floor() * cell;
    final gz0 = ((me.pos.dy - _drawRange) / cell).floor() * cell;
    s.ground(
      Rect.fromLTWH(gx0, gz0, _drawRange * 2 + cell, _drawRange * 2 + cell),
      (i, j) {
        final gi = (gx0 / cell).round() + i, gj = (gz0 / cell).round() + j;
        return tint(
          (gi + gj).isEven ? const Color(0xFF5E9E45) : const Color(0xFF68A84D),
          (cellNoise(gi, gj, 5) - 0.5) * 0.05,
        );
      },
      cell: cell,
    );
    bool near(Offset p) =>
        (p - me.pos).distanceSquared < _drawRange * _drawRange;
    final n = track.center.length;
    const hw = RaceTrack.width / 2;
    for (var i = 0; i < n; i++) {
      final a = track.center[i], b = track.center[(i + 1) % n];
      if (!near(a)) continue;
      final na = _normals[i], nb = _normals[(i + 1) % n];
      V3 at(Offset c, Offset nrm, double off, [double h = 0]) =>
          V3.ground(c + nrm * off, h);
      s.quad(
        at(a, na, -hw),
        at(a, na, hw),
        at(b, nb, hw),
        at(b, nb, -hw),
        tint(const Color(0xFF55595C), (cellNoise(i, 0, 9) - 0.5) * 0.04),
        layer: Layer.surface,
        doubleSided: true,
      );
      final kerb = (i ~/ 2).isEven
          ? const Color(0xFFE53935)
          : const Color(0xFFF5F5F5);
      for (final side in [-1.0, 1.0]) {
        s
          ..quad(
            at(a, na, side * hw),
            at(a, na, side * (hw + 9)),
            at(b, nb, side * (hw + 9)),
            at(b, nb, side * hw),
            kerb,
            layer: Layer.decal,
            doubleSided: true,
          )
          // Low tyre-and-board barrier further out.
          ..quad(
            at(a, na, side * (hw + 46)),
            at(b, nb, side * (hw + 46)),
            at(b, nb, side * (hw + 46), 14),
            at(a, na, side * (hw + 46), 14),
            (i ~/ 3).isEven ? const Color(0xFF1565C0) : const Color(0xFFECEFF1),
            doubleSided: true,
          );
      }
      // Dashed centre line.
      if (i.isEven) {
        s.quad(
          at(a, na, -1.2, 0.2),
          at(a, na, 1.2, 0.2),
          at(b, nb, 1.2, 0.2),
          at(b, nb, -1.2, 0.2),
          const Color(0xCCFFFFFF),
          layer: Layer.decal,
          doubleSided: true,
        );
      }
    }
    // Start / finish line, gantry and grandstand.
    final st = track.center[0], sn = _normals[0];
    final sd = Offset(sn.dy, -sn.dx);
    for (var k = 0; k < 12; k++) {
      for (var r = 0; r < 2; r++) {
        final o0 = -hw + k * (RaceTrack.width / 12);
        final o1 = o0 + RaceTrack.width / 12;
        final f0 = r * 6.0 - 6, f1 = f0 + 6;
        s.quad(
          V3.ground(st + sn * o0 + sd * f0, 0.3),
          V3.ground(st + sn * o1 + sd * f0, 0.3),
          V3.ground(st + sn * o1 + sd * f1, 0.3),
          V3.ground(st + sn * o0 + sd * f1, 0.3),
          (k + r).isEven ? const Color(0xFF111111) : const Color(0xFFF5F5F5),
          layer: Layer.decal,
          doubleSided: true,
        );
      }
    }
    if (near(st)) {
      for (final side in [-1.0, 1.0]) {
        s.box(
          V3.ground(st + sn * side * (hw + 20)),
          8,
          70,
          8,
          const Color(0xFF37474F),
        );
      }
      s.boxAxes(
        V3.ground(st, 62),
        V3(sn.dx, 0, sn.dy),
        const V3(0, 1, 0),
        V3(sd.dx, 0, sd.dy),
        RaceTrack.width + 48,
        14,
        4,
        const Color(0xFFE8322F),
      );
      final stand = st + sn * (hw + 120);
      s.boxAxes(
        V3.ground(stand),
        V3(sd.dx, 0, sd.dy),
        const V3(0, 1, 0),
        V3(sn.dx, 0, sn.dy),
        260,
        50,
        60,
        const Color(0xFF90A4AE),
      );
      for (var k = 0; k < 14; k++) {
        final p = stand + sd * (-120 + k * 18.5) + sn * 6;
        s.box(
          V3.ground(p, 50),
          12,
          10 + cellNoise(k, 1, 3) * 6,
          10,
          Color.lerp(
            const Color(0xFFE53935),
            const Color(0xFF1E88E5),
            cellNoise(k, 2, 3),
          )!,
        );
      }
    }
    for (final p in track.pads) {
      final c = track.center[p];
      if (!near(c)) continue;
      final nn = _normals[p], dd = Offset(nn.dy, -nn.dx);
      for (var k = 0; k < 3; k++) {
        final o = c - dd * (k * 12.0 - 12);
        s.tri(
          V3.ground(o + nn * 16 - dd * 6, 0.4),
          V3.ground(o - dd * -8, 0.4),
          V3.ground(o - nn * 16 - dd * 6, 0.4),
          const Color(0xFFFFD23F),
          layer: Layer.decal,
          doubleSided: true,
          lit: false,
        );
      }
    }
    for (final (p, sz) in _trees) {
      if (!near(p)) continue;
      final base = V3.ground(p);
      s
        ..shadow(p.translate(8, 4), 26 * sz, opacity: 0.25)
        ..tube(
          base,
          base + V3(0, 26 * sz, 0),
          4 * sz,
          3 * sz,
          const Color(0xFF5D4037),
          segments: 5,
        )
        ..sphere(
          base + V3(0, 46 * sz, 0),
          24 * sz,
          tint(const Color(0xFF3E7B3A), (sz - 1.1) * 0.3),
          lat: 5,
          lon: 8,
        );
    }
    for (final k in [..._ai, _me]) {
      if (near(k.pos)) _kart3d(s, k);
    }
    s.render(canvas);

    drawText(
      canvas,
      'P$position',
      const Offset(16, 100),
      size: 26,
      display: true,
      color: const Color(0xFFFFD23F),
    );
    drawText(
      canvas,
      '${math.min(_me.laps + 1, laps)}/$laps',
      const Offset(344, 100),
      size: 18,
      display: true,
      align: TextAlign.right,
    );
    if (_countdown > 0) {
      drawText(
        canvas,
        '${_countdown ~/ stepsPerSecond + 1}',
        const Offset(180, 300),
        size: 60,
        display: true,
        align: TextAlign.center,
        color: const Color(0xFFE8322F),
      );
    }
    if (_driftTime > 0.8) {
      drawText(
        canvas,
        '🔥',
        const Offset(180, 470),
        size: 22,
        align: TextAlign.center,
      );
    }
  }

  /// Go-kart: chassis, side pods, four wheels, driver with helmet.
  void _kart3d(Scene3D s, _Kart k) {
    final h = k.heading;
    final f = V3(math.cos(h), 0, math.sin(h));
    final r = V3(-math.sin(h), 0, math.cos(h));
    final base = V3.ground(k.pos);
    s
      ..shadow(k.pos, 22, opacity: 0.35, stretch: 1.3)
      ..box(
        base + const V3(0, 4, 0),
        34,
        5,
        20,
        const Color(0xFF263238),
        yaw: h,
      )
      ..box(base + f * 4 + const V3(0, 6, 0), 26, 6, 24, k.color, yaw: h)
      ..box(base + f * 18 + const V3(0, 5, 0), 6, 6, 22, k.color, yaw: h);
    for (final (fx, rx) in [
      (12.0, 12.0),
      (12.0, -12.0),
      (-12.0, 13.0),
      (-12.0, -13.0),
    ]) {
      final c = base + f * fx + r * rx + const V3(0, 5, 0);
      s.tube(
        c - r * 3,
        c + r * 3,
        5,
        5,
        const Color(0xFF1A1A1A),
        segments: 8,
        capped: true,
      );
    }
    final seat = base + f * -4 + const V3(0, 10, 0);
    s
      ..box(
        seat,
        9,
        10,
        10,
        k.color == const Color(0xFFE8322F)
            ? const Color(0xFF212121)
            : tint(k.color, -0.4),
        yaw: h,
      )
      ..sphere(
        seat + const V3(0, 16, 0) + f * 1,
        6,
        tint(k.color, 0.35),
        lat: 5,
        lon: 8,
      )
      ..box(
        base + f * -16 + const V3(0, 14, 0),
        4,
        2,
        24,
        const Color(0xFF212121),
        yaw: h,
      );
  }
}
