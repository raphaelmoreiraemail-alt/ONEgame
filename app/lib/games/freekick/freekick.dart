import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../core/l10n/l10n.dart';
import '../../core/rng/seeded_random.dart';
import '../common/draw.dart';
import '../common/fingerprint.dart';
import '../common/football3d.dart';
import '../common/game_sim.dart';
import '../common/game_types.dart';
import '../common/mini_game_definition.dart';
import '../common/render3d.dart';

/// 7.3 Coup franc — 8 free kicks, a wall that may jump, a keeper.
class FreekickGame extends MiniGameDefinition {
  const FreekickGame();

  @override
  String get id => 'freekick';
  @override
  String get emoji => '🥅';
  @override
  GameCategory get category => GameCategory.sport;
  @override
  int get rulesVersion => 1;
  @override
  Set<String> get supportedModifiers => {Modifiers.wind};
  @override
  ScoreBounds get scoreBounds => const ScoreBounds(0, FreekickSim.kicks * 350);

  @override
  Map<String, num> get defaultTuning => const {
    'keeperReach': 0.38,
    'keeperReflex': 0.3,
  };

  @override
  String name(AppLocalizations l10n) => l10n.gameFreekickName;
  @override
  String rule(AppLocalizations l10n) => l10n.gameFreekickRule;

  @override
  String shareLine(AppLocalizations l10n, Map<String, num> s) =>
      l10n.gameFreekickShare(
        s['goals']?.toInt() ?? 0,
        FreekickSim.kicks,
        s['topCorners']?.toInt() ?? 0,
      );

  @override
  List<(String, String)> statRows(AppLocalizations l10n, Map<String, num> s) =>
      [
        (l10n.statGoals, '${s['goals'] ?? 0} / ${FreekickSim.kicks}'),
        (l10n.statTopCorners, '${s['topCorners'] ?? 0}'),
        (l10n.statWallHits, '${s['wall'] ?? 0}'),
      ];

  @override
  Map<String, String> highlightLabels(AppLocalizations l10n) => {
    'topBins': l10n.highlightTopBins,
  };

  @override
  GameSim createSim(GameContext ctx) => FreekickSim(ctx, this);

  @override
  String levelFingerprint(int seed, String? modifierId) => fingerprint([
    for (final k in FreekickPlan.generate(
      GameContext(seed: seed, modifierId: modifierId),
    )) ...[
      k.spot.dx,
      k.spot.dy,
      k.wallSize,
      k.wallJumps,
      k.jumpAt,
      k.keeperSide,
      k.wind,
    ],
  ]);
}

class FreekickPlan {
  const FreekickPlan(
    this.spot,
    this.wallSize,
    this.wallJumps,
    this.jumpAt,
    this.keeperSide,
    this.postIn,
    this.wind,
  );

  final Offset spot;
  final int wallSize;
  final bool wallJumps;

  /// Fraction of the flight when the wall is in the air.
  final double jumpAt;

  /// Keeper's lean: -1 left, 0 middle, 1 right.
  final int keeperSide;
  final bool postIn;

  /// Lateral wind (goal units).
  final double wind;

  static List<FreekickPlan> generate(GameContext ctx) {
    final r = SeededRandom.derive(ctx.seed, 'freekick:kicks');
    final w = SeededRandom.derive(ctx.seed, 'freekick:wind');
    final windy = ctx.has(Modifiers.wind);
    return [
      for (var i = 0; i < FreekickSim.kicks; i++)
        FreekickPlan(
          Offset(r.doubleInRange(70, 290), r.doubleInRange(440, 560)),
          r.intInRange(2, 5),
          r.chance(0.6),
          r.doubleInRange(0.2, 0.5),
          r.nextInt(3) - 1,
          r.chance(0.5),
          windy ? w.doubleInRange(-0.35, 0.35) : w.doubleInRange(-0.06, 0.06),
        ),
    ];
  }
}

enum KickOutcome { goal, topCorner, postIn, wall, saved, post, wide }

class FreekickSim extends GameSim {
  FreekickSim(super.ctx, FreekickGame def)
    : plan = FreekickPlan.generate(ctx),
      _reach = ctx.tune('keeperReach', def.defaultTuning['keeperReach']!),
      _reflex = ctx.tune('keeperReflex', def.defaultTuning['keeperReflex']!);

  static const int kicks = 8;
  static const double _groundY = 230;
  static const double _halfW = 120;
  static const double _goalH = 100;
  static const double _wallT = 0.35;

  final List<FreekickPlan> plan;
  final double _reach;
  final double _reflex;

  int index = 0;
  int goals = 0;
  int topCorners = 0;
  int wallHits = 0;
  final List<KickOutcome> outcomes = [];

  // Shot state.
  bool _flying = false;
  int _t = 0;
  int _resultSteps = 0;
  double _u = 0, _v = 0, _curve = 0, _lift = 0, _flight = 0.7, _u0 = 0;
  double _ku = 0, _kv = 0.3;
  KickOutcome? _last;
  int? _pointer;
  final List<Offset> _path = [];
  int _swipeStart = 0;

  FreekickPlan get _k => plan[math.min(index, kicks - 1)];

  Offset goalPoint(double u, double v) =>
      Offset(180 + u * _halfW, _groundY - v * _goalH);

  @override
  Color get backgroundColor => const Color(0xFF1F7A3A);

  @override
  void onPointer(PointerPhase phase, int pointer, Offset pos) {
    if (_flying || _resultSteps > 0 || index >= kicks) return;
    switch (phase) {
      case PointerPhase.down:
        if (_pointer != null || pos.dy < 300) return;
        _pointer = pointer;
        _path
          ..clear()
          ..add(pos);
        _swipeStart = step;
      case PointerPhase.move:
        if (pointer == _pointer) _path.add(pos);
      case PointerPhase.up:
        if (pointer != _pointer) return;
        _pointer = null;
        _path.add(pos);
        _shoot();
    }
  }

  void _shoot() {
    final d = _path.last - _path.first;
    final up = -d.dy;
    if (up < 40) return;
    final len = d.distance;
    var dev = 0.0;
    final n = Offset(-d.dy, d.dx) / len;
    for (final p in _path) {
      final off = (p - _path.first).dx * n.dx + (p - _path.first).dy * n.dy;
      if (off.abs() > dev.abs()) dev = off;
    }
    _u0 = (_k.spot.dx - 180) / _halfW;
    _curve = (dev / len).clamp(-0.5, 0.5);
    _u = _u0 + d.dx / up * 2.2 - _curve * 1.1 + _k.wind;
    _v = ((len - 110) / 160).clamp(0.0, 1.4);
    _lift = ((len - 120) / 150).clamp(0.0, 0.6);
    final dur = (step - _swipeStart).clamp(1, 120);
    _flight = (0.55 + dur / stepsPerSecond * 0.9).clamp(0.55, 1.1);
    _ku = 0;
    _kv = 0.3;
    _flying = true;
    _t = 0;
    cue(sfx: Sfx.whoosh, haptic: Haptic.light);
  }

  double _uAt(double t) =>
      _u0 + (_u - _u0) * t + _curve * math.sin(math.pi * t) * 0.9;
  double _hAt(double t) => _v * t + _lift * 4 * t * (1 - t);

  /// Wall span in goal units, between the ball and the near post.
  (double, double) get _wallSpan {
    final u0 = (_k.spot.dx - 180) / _halfW;
    final nearPost = u0 < 0 ? -0.75 : 0.75;
    final center = u0 + (nearPost - u0) * 0.55;
    final half = _k.wallSize * 0.09;
    return (center - half, center + half);
  }

  bool _wallUp(double t) => _k.wallJumps && (t - _k.jumpAt).abs() < 0.18;

  @override
  void tick() {
    tickParticles();
    if (_resultSteps > 0) {
      if (--_resultSteps == 0) {
        index++;
        if (index >= kicks) over = true;
      }
      return;
    }
    if (!_flying) return;
    _t++;
    final t = _t / stepsPerSecond / _flight;
    // Keeper: leans to its side, then reacts partially to the real ball.
    final react = ((t - 0.35) / 0.4).clamp(0.0, 1.0) * _reflex;
    final tu = _k.keeperSide * 0.35 + (_u - _k.keeperSide * 0.35) * react;
    final tv = 0.3 + (_v - 0.3) * react;
    _ku += (tu - _ku).clamp(-4 * stepDt, 4 * stepDt);
    _kv += (tv - _kv).clamp(-4 * stepDt, 4 * stepDt);
    if (t >= _wallT && t - stepDt / _flight < _wallT) {
      final (a, b) = _wallSpan;
      final uw = _uAt(_wallT);
      final wallH = _wallUp(_wallT) ? 0.75 : 0.5;
      if (uw > a && uw < b && _hAt(_wallT) < wallH) {
        _resolve(KickOutcome.wall);
        return;
      }
    }
    if (t >= 1) {
      final au = _u.abs();
      final onPost =
          (au > 0.95 && au < 1.05 && _v < 1.05) ||
          (_v > 0.95 && _v < 1.05 && au < 1.05);
      final du = _u - _ku, dv = (_v - _kv) * 0.8;
      if (onPost) {
        _resolve(_k.postIn ? KickOutcome.postIn : KickOutcome.post);
      } else if (au >= 1.05 || _v >= 1.05) {
        _resolve(KickOutcome.wide);
      } else if (math.sqrt(du * du + dv * dv) < _reach) {
        _resolve(KickOutcome.saved);
      } else if (au > 0.62 && _v > 0.62) {
        _resolve(KickOutcome.topCorner);
      } else {
        _resolve(KickOutcome.goal);
      }
    }
  }

  void _resolve(KickOutcome o) {
    _flying = false;
    _last = o;
    outcomes.add(o);
    _resultSteps = (1.1 * stepsPerSecond).round();
    final pts = switch (o) {
      KickOutcome.goal => 150,
      KickOutcome.topCorner => 300,
      KickOutcome.postIn => 350,
      _ => 0,
    };
    if (o == KickOutcome.wall) wallHits++;
    if (pts > 0) {
      goals++;
      score += pts;
      particles.burst(goalPoint(_u, _v), const Color(0xFFFFD23F), count: 20);
      cue(sfx: Sfx.score, haptic: Haptic.medium);
      if (o == KickOutcome.topCorner) {
        topCorners++;
        celebrate('topBins');
      }
    } else {
      cue(
        sfx: o == KickOutcome.wall || o == KickOutcome.post
            ? Sfx.hit
            : Sfx.miss,
        haptic: Haptic.light,
      );
    }
  }

  @override
  Map<String, num> get stats => {
    'goals': goals,
    'topCorners': topCorners,
    'wall': wallHits,
    'kicks': outcomes.length,
  };

  // ---------------------------------------------------------------- 3D

  /// Kick spot in 3D: the 2D spot's depth maps to 15–24 m from goal.
  V3 _spot3d(FreekickPlan k) => V3(k.spot.dx, 6, 380 + (k.spot.dy - 400) * 2.6);

  final Map<int, Football3D> _stadiums = {};

  Football3D _stadiumFor(int i) => _stadiums.putIfAbsent(i, () {
    final sp = _spot3d(plan[i]);
    return Football3D(
      halfWidth: _halfW,
      spotDistance: sp.z,
      camera: Camera3D(
        eye: V3(sp.x + (sp.x - 180) * 0.25, 100, sp.z + 230),
        target: const V3(180, 30, 0),
        fovDegrees: 50,
        center: const Offset(180, 250),
      ),
    );
  });

  @override
  void render(Canvas canvas) {
    final i = math.min(index, kicks - 1);
    final k = plan[i];
    final st = _stadiumFor(i);
    final sp = _spot3d(k);
    st.sky(canvas);
    final s = st.scene();
    st.stadium(s);
    // Keeper.
    final kp = st.goal(_ku, math.max(0, _kv - 0.3));
    s
      ..figure(
        V3(kp.x, kp.y, 4),
        const Color(0xFF263238),
        roll: -_ku * 0.9,
        arms: 0.4,
        scale: 1.1,
      )
      ..shadow(Offset(kp.x, 6), 14, stretch: 1.4);
    // Wall, 9.15 m from the ball toward its span.
    final t = _flying ? _t / stepsPerSecond / _flight : 0.0;
    final (a, b) = _wallSpan;
    final aim = st.goal((a + b) / 2, 0);
    final dir = (aim - sp).normalized;
    final wallBase = sp + dir * 300;
    final jump = _flying && _wallUp(t) ? 14.0 : 0.0;
    final side = V3(-dir.z, 0, dir.x).normalized;
    for (var p = 0; p < k.wallSize; p++) {
      final feet = wallBase + side * ((p - (k.wallSize - 1) / 2) * 20);
      s
        ..figure(
          V3(feet.x, jump, feet.z),
          const Color(0xFF1565C0),
          arms: jump > 0 ? 0.9 : 0,
          scale: 1.05,
        )
        ..shadow(Offset(feet.x, feet.z), 9);
    }
    // Ball.
    V3 ball;
    if (_flying) {
      final tt = t.clamp(0.0, 1.0);
      ball = V3(
        180 + _uAt(tt) * _halfW,
        6 + _hAt(tt) * st.height,
        sp.z * (1 - tt),
      );
    } else if (_resultSteps > 0) {
      final inside = _u.abs() < 1 && _v < 1;
      ball = st.goal(
        _u.clamp(-1.3, 1.3),
        _v.clamp(0.07, 1.3),
        inside ? -38 : 8,
      );
    } else {
      ball = sp;
    }
    st.ball(s, ball);
    s.render(canvas);
    if (_pointer != null && _path.length > 1) {
      final path = Path()..moveTo(_path.first.dx, _path.first.dy);
      for (final q in _path.skip(1)) {
        path.lineTo(q.dx, q.dy);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0x88FFD23F)
          ..strokeWidth = 6
          ..style = PaintingStyle.stroke,
      );
    }
    if (k.wind.abs() > 0.08) {
      drawWind(canvas, const Offset(320, 300), Offset(k.wind * 150, 0));
    }
    drawText(
      canvas,
      '${math.min(index + 1, kicks)}/$kicks',
      const Offset(16, 96),
      size: 15,
    );
    if (_resultSteps > 0 && _last != null) {
      drawText(
        canvas,
        switch (_last!) {
          KickOutcome.wall => '🧱',
          KickOutcome.saved => '✋',
          KickOutcome.post || KickOutcome.wide => '✗',
          _ => 'GOAL!',
        },
        const Offset(180, 380),
        size: 40,
        display: true,
        align: TextAlign.center,
        color: const Color(0xFFFFD23F),
      );
    }
  }
}
