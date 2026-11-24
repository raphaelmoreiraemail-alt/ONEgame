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

/// 7.2 Tirs au but — 5 shots + sudden death, then 5 saves as the keeper.
class PenaltyGame extends MiniGameDefinition {
  const PenaltyGame();

  @override
  String get id => 'penalty';
  @override
  String get emoji => '⚽';
  @override
  GameCategory get category => GameCategory.sport;
  @override
  int get rulesVersion => 1;
  @override
  Set<String> get supportedModifiers => {Modifiers.giant, Modifiers.night};
  @override
  ScoreBounds get scoreBounds => const ScoreBounds(
    0,
    PenaltySim.maxShots * 400 + PenaltySim.saveRounds * 250,
  );

  @override
  Map<String, num> get defaultTuning => const {
    'keeperReflex': 0.35,
    'keeperReach': 0.4,
    'keeperReaction': 0.22,
    'aiShotMinFlight': 0.5,
  };

  @override
  String name(AppLocalizations l10n) => l10n.gamePenaltyName;
  @override
  String rule(AppLocalizations l10n) => l10n.gamePenaltyRule;

  @override
  String shareLine(AppLocalizations l10n, Map<String, num> s) {
    final base = l10n.gamePenaltyShare(
      s['goals']?.toInt() ?? 0,
      s['shots']?.toInt() ?? 0,
      s['saves']?.toInt() ?? 0,
      PenaltySim.saveRounds,
    );
    final p = s['panenkas']?.toInt() ?? 0;
    return p > 0 ? '$base · ${l10n.gamePenaltySharePanenka(p)}' : base;
  }

  @override
  List<(String, String)> statRows(AppLocalizations l10n, Map<String, num> s) =>
      [
        (l10n.statGoals, '${s['goals'] ?? 0} / ${s['shots'] ?? 0}'),
        (l10n.statTopCorners, '${s['topCorners'] ?? 0}'),
        (l10n.statSaves, '${s['saves'] ?? 0} / ${PenaltySim.saveRounds}'),
        (l10n.statPanenkas, '${s['panenkas'] ?? 0}'),
      ];

  @override
  Map<String, String> highlightLabels(AppLocalizations l10n) => {
    'panenka': l10n.highlightPanenka,
    'superSave': l10n.highlightSuperSave,
  };

  @override
  GameSim createSim(GameContext ctx) => PenaltySim(ctx, this);

  @override
  String levelFingerprint(int seed, String? modifierId) {
    final plan = PenaltyPlan.generate(
      GameContext(seed: seed, modifierId: modifierId),
    );
    return fingerprint([
      for (final k in plan.keeper) ...[k.side, k.delay],
      for (final s in plan.aiShots) ...[s.u, s.v, s.flight, s.feintless],
      ...plan.postLuck,
    ]);
  }
}

/// Keeper behaviour for one of the player's shots.
class KeeperPlan {
  const KeeperPlan(this.side, this.delay);

  /// -1 left, 0 stays in the middle, 1 right.
  final int side;

  /// Seconds after the kick before the dive starts.
  final double delay;
}

/// An AI shot the player must save. (u, v) in goal space.
class AiShot {
  const AiShot(this.u, this.v, this.flight, this.feintless);

  final double u;
  final double v;
  final double flight;

  /// Always true in v1: the 0.4 s hint shows the real side.
  final bool feintless;
}

class PenaltyPlan {
  const PenaltyPlan(this.keeper, this.aiShots, this.postLuck);

  final List<KeeperPlan> keeper;
  final List<AiShot> aiShots;

  /// For shots hitting the post: true = goes in.
  final List<bool> postLuck;

  static PenaltyPlan generate(
    GameContext ctx, [
    Map<String, num> tuning = const {},
  ]) {
    final kr = SeededRandom.derive(ctx.seed, 'penalty:keeper');
    final sr = SeededRandom.derive(ctx.seed, 'penalty:aishots');
    final pr = SeededRandom.derive(ctx.seed, 'penalty:posts');
    final giant = ctx.has(Modifiers.giant);
    final minFlight = (tuning['aiShotMinFlight'] ?? 0.5).toDouble();
    return PenaltyPlan(
      [
        for (var i = 0; i < PenaltySim.maxShots; i++)
          KeeperPlan(
            kr.chance(0.16) ? 0 : (kr.chance(0.5) ? -1 : 1),
            kr.doubleInRange(0.04, 0.24),
          ),
      ],
      [
        for (var i = 0; i < PenaltySim.saveRounds; i++)
          AiShot(
            (sr.nextInt(3) - 1) * 0.72 + sr.doubleInRange(-0.18, 0.18),
            sr.pick(const [0.12, 0.45, 0.8]) + sr.doubleInRange(-0.06, 0.08),
            sr.doubleInRange(minFlight, minFlight + 0.3) / (giant ? 1.15 : 1),
            true,
          ),
      ],
      [for (var i = 0; i < PenaltySim.maxShots; i++) pr.chance(0.5)],
    );
  }
}

enum _Phase {
  shootReady,
  shotFlying,
  shotResult,
  keepRunup,
  keepFlying,
  keepResult,
  done,
}

enum ShotOutcome { goal, topCorner, postIn, panenka, saved, post, wide, over }

class PenaltySim extends GameSim {
  PenaltySim(super.ctx, PenaltyGame def)
    : plan = PenaltyPlan.generate(ctx, {...def.defaultTuning, ...ctx.tuning}),
      _giant = ctx.has(Modifiers.giant),
      _reflex =
          ctx.tune('keeperReflex', def.defaultTuning['keeperReflex']!) *
          (ctx.has(Modifiers.giant) ? 1.5 : 1),
      _reach = ctx.tune('keeperReach', def.defaultTuning['keeperReach']!),
      _reaction = ctx.tune(
        'keeperReaction',
        def.defaultTuning['keeperReaction']!,
      );

  static const int regularShots = 5;
  static const int maxShots = 10;
  static const int saveRounds = 5;

  final PenaltyPlan plan;
  final bool _giant;
  final double _reflex;
  final double _reach;
  final double _reaction;

  _Phase _phase = _Phase.shootReady;
  int shotIndex = 0;
  int saveIndex = 0;
  int goals = 0;
  int saves = 0;
  int topCorners = 0;
  int panenkas = 0;
  final List<ShotOutcome> outcomes = [];
  final List<bool> saveResults = [];
  int _phaseStep = 0;

  // Current shot.
  double _u = 0, _v = 0, _curve = 0, _flight = 0.6;
  bool _panenka = false;
  double _ku = 0, _kv = 0.3; // keeper position (goal space)
  double _kuTarget = 0, _kvTarget = 0.3;
  bool _keeperCommitted = false;
  ShotOutcome? _lastOutcome;
  bool? _lastSave;

  // Swipe tracking.
  int? _pointer;
  final List<Offset> _path = [];
  int _swipeStartStep = 0;

  static const Offset spot = Offset(180, 540);
  double get _halfW => _giant ? 156 : 130;
  static const double _groundY = 250;
  static const double _goalH = 110;

  Offset goalPoint(double u, double v) =>
      Offset(180 + u * _halfW, _groundY - v * _goalH);

  /// True while an AI shot is in the air (keeper part).
  bool get aiShotInFlight => _phase == _Phase.keepFlying;

  bool get _shooting =>
      shotIndex < maxShots && _phase.index <= _Phase.shotResult.index;

  @override
  Color get backgroundColor => const Color(0xFF1F7A3A);

  @override
  Offset get focus {
    final st = _stadium;
    final V3 p;
    if (_phase == _Phase.shotFlying || _phase == _Phase.keepFlying) {
      p = _ball3d();
    } else if (_shooting) {
      p = V3(180, 6, st.spotDistance);
    } else {
      p = st.goal(_ku, _kv);
    }
    return st.camera.project(p) ?? Arena.center;
  }

  @override
  void onPointer(PointerPhase phase, int pointer, Offset pos) {
    switch (phase) {
      case PointerPhase.down:
        if (_pointer != null) return;
        if (_phase == _Phase.shootReady && pos.dy > 330) {
          _pointer = pointer;
          _path
            ..clear()
            ..add(pos);
          _swipeStartStep = step;
        } else if ((_phase == _Phase.keepRunup ||
                _phase == _Phase.keepFlying) &&
            !_keeperCommitted) {
          _pointer = pointer;
          _path
            ..clear()
            ..add(pos);
        }
      case PointerPhase.move:
        if (pointer == _pointer) _path.add(pos);
      case PointerPhase.up:
        if (pointer != _pointer) return;
        _pointer = null;
        _path.add(pos);
        if (_phase == _Phase.shootReady) {
          _shoot();
        } else if (!_keeperCommitted &&
            (_phase == _Phase.keepRunup || _phase == _Phase.keepFlying)) {
          _dive();
        }
    }
  }

  void _shoot() {
    final start = _path.first;
    final end = _path.last;
    final d = end - start;
    final len = d.distance;
    final up = start.dy - end.dy;
    if (len < 18) return; // a tap is not a shot
    if (up < 10 && len >= 60) return;
    // Curvature: signed max deviation of the path from the straight line.
    var dev = 0.0;
    final n = len == 0 ? Offset.zero : Offset(-d.dy, d.dx) / len;
    for (final p in _path) {
      final off = (p - start).dx * n.dx + (p - start).dy * n.dy;
      if (off.abs() > dev.abs()) dev = off;
    }
    final dur = (step - _swipeStartStep).clamp(1, 120);
    if (len < 70 && d.dx.abs() < 25) {
      // Panenka chip: short, soft, straight down the middle.
      _panenka = true;
      _u = d.dx / 120;
      _v = 0.55;
      _curve = 0;
      _flight = 0.95;
    } else {
      _panenka = false;
      _curve = (dev / math.max(len, 1)).clamp(-0.5, 0.5);
      _u = (d.dx / math.max(up, 20)) * 1.5 - _curve * 0.9;
      _v = ((len - 100) / 170).clamp(0.0, 1.45);
      _flight = (0.32 + dur / stepsPerSecond * 1.1).clamp(0.38, 0.85);
    }
    final k = plan.keeper[shotIndex];
    _kuTarget = k.side * 0.62;
    _kvTarget = k.side == 0 ? 0.3 : 0.38;
    _ku = 0;
    _kv = 0.3;
    _phase = _Phase.shotFlying;
    _phaseStep = 0;
    cue(sfx: Sfx.whoosh, haptic: Haptic.light);
  }

  void _dive() {
    final d = _path.last - _path.first;
    if (d.distance < 25) {
      _kuTarget = 0;
      _kvTarget = 0.35;
    } else {
      _kuTarget = (d.dx / 110).clamp(-1.05, 1.05);
      _kvTarget = (0.3 + (-d.dy) / 160).clamp(0.05, 1.0);
    }
    _keeperCommitted = true;
    cue(haptic: Haptic.light);
  }

  @override
  void tick() {
    tickParticles();
    _phaseStep++;
    final t = _phaseStep / stepsPerSecond;
    switch (_phase) {
      case _Phase.shootReady:
      case _Phase.done:
        break;
      case _Phase.shotFlying:
        final k = plan.keeper[shotIndex];
        if (t > k.delay) _moveKeeper(t, k.delay);
        if (t >= _flight) _resolveShot();
      case _Phase.shotResult:
        _moveKeeper(t + 10, 0);
        if (t >= 1.1) _nextShot();
      case _Phase.keepRunup:
        if (t >= 1.2) {
          final s = plan.aiShots[saveIndex];
          _u = s.u * (_giant ? 1.1 : 1);
          _v = s.v;
          _flight = s.flight;
          _curve = 0;
          _panenka = false;
          _phase = _Phase.keepFlying;
          _phaseStep = 0;
          cue(sfx: Sfx.whoosh);
        }
      case _Phase.keepFlying:
        if (_keeperCommitted) _moveKeeper(t + 10, 0);
        if (t >= _flight) _resolveSave();
      case _Phase.keepResult:
        _moveKeeper(t + 10, 0);
        if (t >= 1.1) _nextSave();
    }
  }

  /// Keeper glides toward its target; while defending against the player,
  /// a partial reflex pulls the target toward the real ball.
  void _moveKeeper(double t, double delay) {
    var tu = _kuTarget, tv = _kvTarget;
    if (_shooting && !_panenka) {
      final react = ((t - delay - _reaction) / 0.4).clamp(0.0, 1.0) * _reflex;
      tu += (_u - tu) * react;
      tv += (_v - tv) * react;
    }
    const speed = 4.5 * stepDt;
    _ku += (tu - _ku).clamp(-speed, speed);
    _kv += (tv - _kv).clamp(-speed, speed);
  }

  bool _keeperReaches(double u, double v) {
    final du = u - _ku, dv = (v - _kv) * 0.8;
    return math.sqrt(du * du + dv * dv) < _reach;
  }

  void _resolveShot() {
    final k = plan.keeper[shotIndex];
    final au = _u.abs();
    ShotOutcome o;
    final onPost =
        (au > 0.95 && au < 1.05 && _v < 1.05) ||
        (_v > 0.95 && _v < 1.05 && au < 1.05);
    if (_panenka) {
      o = k.side != 0 ? ShotOutcome.panenka : ShotOutcome.saved;
    } else if (onPost) {
      o = plan.postLuck[shotIndex] ? ShotOutcome.postIn : ShotOutcome.post;
    } else if (au >= 1.05) {
      o = ShotOutcome.wide;
    } else if (_v >= 1.05) {
      o = ShotOutcome.over;
    } else if (_keeperReaches(_u, _v)) {
      o = ShotOutcome.saved;
    } else if (au > 0.62 && _v > 0.62) {
      o = ShotOutcome.topCorner;
    } else {
      o = ShotOutcome.goal;
    }
    outcomes.add(o);
    _lastOutcome = o;
    final pts = switch (o) {
      ShotOutcome.goal => 100,
      ShotOutcome.topCorner => 200,
      ShotOutcome.postIn => 250,
      ShotOutcome.panenka => 400,
      _ => 0,
    };
    if (pts > 0) {
      goals++;
      score += pts;
      particles.burst(goalPoint(_u, _v), const Color(0xFFFFD23F), count: 20);
      cue(sfx: Sfx.score, haptic: Haptic.medium);
      if (o == ShotOutcome.topCorner) topCorners++;
      if (o == ShotOutcome.panenka) {
        panenkas++;
        celebrate('panenka');
      }
    } else {
      cue(
        sfx: o == ShotOutcome.post ? Sfx.hit : Sfx.miss,
        haptic: Haptic.light,
      );
    }
    _phase = _Phase.shotResult;
    _phaseStep = 0;
  }

  void _nextShot() {
    shotIndex++;
    final suddenDeathOver = shotIndex > regularShots && !_lastScored;
    if (shotIndex >= maxShots ||
        suddenDeathOver ||
        (shotIndex >= regularShots && !_lastScored)) {
      _startKeeper();
    } else {
      _phase = _Phase.shootReady;
      _phaseStep = 0;
    }
  }

  bool get _lastScored => switch (_lastOutcome) {
    ShotOutcome.goal ||
    ShotOutcome.topCorner ||
    ShotOutcome.postIn ||
    ShotOutcome.panenka => true,
    _ => false,
  };

  void _startKeeper() {
    shotIndex = maxShots; // marks the end of the shooting part
    _phase = _Phase.keepRunup;
    _phaseStep = 0;
    _keeperCommitted = false;
    _ku = 0;
    _kv = 0.3;
    _kuTarget = 0;
    _kvTarget = 0.3;
  }

  void _resolveSave() {
    final inGoal = _u.abs() < 1 && _v < 1;
    final saved = _keeperCommitted && _keeperReaches(_u, _v);
    _lastSave = saved || !inGoal;
    saveResults.add(_lastSave!);
    if (saved) {
      saves++;
      final corner = _u.abs() > 0.62 && _v > 0.62;
      score += corner ? 250 : 150;
      particles.burst(goalPoint(_u, _v), Colors.white, count: 20);
      cue(sfx: Sfx.score, haptic: Haptic.heavy);
      if (corner) celebrate('superSave');
    } else if (!inGoal) {
      cue(sfx: Sfx.bounce);
    } else {
      cue(sfx: Sfx.miss, haptic: Haptic.light);
    }
    _phase = _Phase.keepResult;
    _phaseStep = 0;
  }

  void _nextSave() {
    saveIndex++;
    if (saveIndex >= saveRounds) {
      _phase = _Phase.done;
      over = true;
    } else {
      _startKeeper();
    }
  }

  @override
  Map<String, num> get stats => {
    'goals': goals,
    'shots': outcomes.length,
    'topCorners': topCorners,
    'saves': saves,
    'panenkas': panenkas,
  };

  // ---------------------------------------------------------------- render

  // ---------------------------------------------------------------- 3D

  late final Football3D _stadium = Football3D(
    halfWidth: _halfW,
    spotDistance: 390,
  );

  /// 3D ball position during a flight.
  V3 _ball3d() {
    final st = _stadium;
    final t = (_phaseStep / stepsPerSecond / _flight).clamp(0.0, 1.0);
    final e = Curves.easeOut.transform(t);
    final from = V3(180, 6, st.spotDistance);
    final to = st.goal(_u, _v);
    final base = from + (to - from) * e;
    final bend = math.sin(t * math.pi) * _curve * st.halfWidth * 0.9;
    final lift = math.sin(t * math.pi) * (_panenka ? 45 : 10 * _v);
    return V3(base.x + bend, math.max(6, base.y + lift), base.z);
  }

  @override
  void render(Canvas canvas) {
    final st = _stadium;
    st.sky(canvas);
    final s = st.scene();
    st.stadium(s, spotZ: st.spotDistance);
    // Keeper (player is red when keeping).
    final playerKeeps = !_shooting;
    final kp = st.goal(_ku, math.max(0, _kv - 0.3));
    s.figure(
      V3(kp.x, kp.y, 4),
      playerKeeps ? const Color(0xFFE8322F) : const Color(0xFF263238),
      roll: -_ku * 0.9,
      arms: 0.3 + (_kv - 0.3).abs() * 1.2,
      scale: 1.15,
      shorts: const Color(0xFF111111),
    );
    s.shadow(Offset(kp.x, 6), 14, stretch: 1.4);
    // AI shooter running up during the keeper part.
    if (playerKeeps && _phase == _Phase.keepRunup) {
      final t = (_phaseStep / stepsPerSecond / 1.2).clamp(0.0, 1.0);
      final feet = V3(150 + 22 * t, 0, st.spotDistance + 60 - 50 * t);
      s
        ..figure(feet, const Color(0xFF1565C0), scale: 1.1)
        ..shadow(feet.flat, 10);
    }
    // Ball.
    V3 ball;
    if (_phase == _Phase.shotFlying || _phase == _Phase.keepFlying) {
      ball = _ball3d();
    } else if (_phase == _Phase.shotResult || _phase == _Phase.keepResult) {
      final inside = _u.abs() < 1 && _v < 1;
      ball = st.goal(
        _u.clamp(-1.3, 1.3),
        _v.clamp(0.06, 1.3),
        inside ? -38 : 8,
      );
    } else {
      ball = V3(180, 6, st.spotDistance);
    }
    st.ball(s, ball);
    s.render(canvas);
    // Keeper-part hint: 0.4 s before the kick.
    if (playerKeeps && _phase == _Phase.keepRunup) {
      final t = _phaseStep / stepsPerSecond;
      if (t >= 0.8 && saveIndex < saveRounds) {
        final shot = plan.aiShots[saveIndex];
        final side = shot.u < -0.3 ? -1 : (shot.u > 0.3 ? 1 : 0);
        const a = Offset(180, 470);
        final p = Paint()
          ..color = const Color(0xFFFFD23F)
          ..strokeWidth = 6
          ..strokeCap = StrokeCap.round;
        final tip = a.translate(side * 50.0, side == 0 ? -40 : -20);
        canvas
          ..drawLine(a, tip, p)
          ..drawCircle(tip, 8, Paint()..color = const Color(0xFFFFD23F));
      }
    }
    // Swipe trail.
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
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round,
      );
    }
    // Scoreboard.
    final dots = StringBuffer();
    for (final o in outcomes) {
      dots.write(switch (o) {
        ShotOutcome.saved ||
        ShotOutcome.post ||
        ShotOutcome.wide ||
        ShotOutcome.over => '✗',
        _ => '●',
      });
    }
    final saveDots = saveResults.map((ok) => ok ? '●' : '✗').join();
    drawText(canvas, '⚽ $dots', const Offset(16, 96), size: 15);
    drawText(
      canvas,
      '🧤 $saveDots',
      const Offset(344, 96),
      size: 15,
      align: TextAlign.right,
    );
    String? banner;
    if (_phase == _Phase.shotResult && _lastOutcome != null) {
      banner = switch (_lastOutcome!) {
        ShotOutcome.saved => '✋',
        ShotOutcome.post || ShotOutcome.wide || ShotOutcome.over => '✗',
        _ => 'GOAL!',
      };
    } else if (_phase == _Phase.keepResult && _lastSave != null) {
      banner = _lastSave! ? '🧤' : '✗';
    }
    if (banner != null) {
      drawText(
        canvas,
        banner,
        const Offset(180, 380),
        size: 44,
        display: true,
        align: TextAlign.center,
        color: const Color(0xFFFFD23F),
      );
    }
  }
}
