import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../core/l10n/l10n.dart';
import '../../core/rng/seeded_random.dart';
import '../common/draw.dart';
import '../common/fingerprint.dart';
import '../common/game_sim.dart';
import '../common/game_types.dart';
import '../common/mini_game_definition.dart';

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

  @override
  void render(Canvas canvas) {
    for (var i = 0; i < 16; i++) {
      canvas.drawRect(
        Rect.fromLTWH(0, i * 40.0, 360, 40),
        Paint()
          ..color = i.isEven
              ? const Color(0xFF2E8B47)
              : const Color(0xFF289040),
      );
    }
    final line = Paint()
      ..color = Colors.white70
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    canvas
      ..drawLine(const Offset(0, _groundY), const Offset(360, _groundY), line)
      ..drawRect(const Rect.fromLTRB(20, _groundY, 340, 380), line);
    final net = Paint()..color = Colors.white24;
    for (var x = 180 - _halfW; x <= 180 + _halfW; x += 12) {
      canvas.drawLine(Offset(x, _groundY - _goalH), Offset(x, _groundY), net);
    }
    final post = Paint()
      ..color = Colors.white
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    canvas
      ..drawLine(goalPoint(-1, 0), goalPoint(-1, 1), post)
      ..drawLine(goalPoint(1, 0), goalPoint(1, 1), post)
      ..drawLine(goalPoint(-1, 1), goalPoint(1, 1), post);
    // Keeper.
    final kp = goalPoint(_ku, _kv);
    drawBox(
      canvas,
      Rect.fromCenter(center: kp, width: 30, height: 40),
      const Color(0xFF212121),
      radius: 8,
    );
    canvas.drawCircle(
      kp.translate(0, -28),
      10,
      Paint()..color = const Color(0xFFFFCC80),
    );
    if (index < kicks) {
      final k = _k;
      // Wall, drawn on the ball → goal line.
      final (a, b) = _wallSpan;
      final t = _flying ? _t / stepsPerSecond / _flight : 0.0;
      final jump = _wallUp(t) && _flying ? 14.0 : 0.0;
      final wallBase = Offset.lerp(k.spot, goalPoint((a + b) / 2, 0), _wallT)!;
      final count = k.wallSize;
      for (var i = 0; i < count; i++) {
        final x = wallBase.dx + (i - (count - 1) / 2) * 20;
        drawBox(
          canvas,
          Rect.fromCenter(
            center: Offset(x, wallBase.dy - jump),
            width: 18,
            height: 30,
          ),
          const Color(0xFF1565C0),
          radius: 6,
        );
        canvas.drawCircle(
          Offset(x, wallBase.dy - 20 - jump),
          7,
          Paint()..color = const Color(0xFFFFCC80),
        );
      }
      // Ball + shadow (height read from the shadow distance).
      Offset ground;
      var h = 0.0;
      if (_flying) {
        final tt = t.clamp(0.0, 1.0);
        ground = Offset.lerp(k.spot, goalPoint(_uAt(tt), 0), tt)!;
        h = _hAt(tt) * _goalH;
      } else if (_resultSteps > 0) {
        ground = goalPoint(_u, 0);
        h = _v * _goalH;
      } else {
        ground = k.spot;
      }
      canvas.drawOval(
        Rect.fromCenter(center: ground, width: 16, height: 6),
        Paint()..color = const Color(0x55000000),
      );
      drawBall(canvas, ground.translate(0, -h), 9, Colors.white, shadow: false);
    }
    if (_pointer != null && _path.length > 1) {
      final p = Path()..moveTo(_path.first.dx, _path.first.dy);
      for (final q in _path.skip(1)) {
        p.lineTo(q.dx, q.dy);
      }
      canvas.drawPath(
        p,
        Paint()
          ..color = const Color(0x88FFD23F)
          ..strokeWidth = 6
          ..style = PaintingStyle.stroke,
      );
    }
    if (_k.wind.abs() > 0.08) {
      drawWind(canvas, const Offset(320, 300), Offset(_k.wind * 150, 0));
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
        const Offset(180, 330),
        size: 40,
        display: true,
        align: TextAlign.center,
        color: const Color(0xFFFFD23F),
      );
    }
  }
}
