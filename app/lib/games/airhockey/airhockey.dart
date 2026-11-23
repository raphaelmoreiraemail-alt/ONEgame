import 'dart:math' as math;

import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/l10n/l10n.dart';
import '../../core/rng/seeded_random.dart';
import '../common/draw.dart';
import '../common/fingerprint.dart';
import '../common/game_sim.dart';
import '../common/game_types.dart';
import '../common/mini_game_definition.dart';
import '../common/physics.dart';

/// 7.8 Air hockey — first to 5 goals against an AI, 2 minutes max.
class AirhockeyGame extends MiniGameDefinition {
  const AirhockeyGame();

  @override
  String get id => 'airhockey';
  @override
  String get emoji => '🏒';
  @override
  GameCategory get category => GameCategory.sport;
  @override
  int get rulesVersion => 1;
  @override
  Set<String> get supportedModifiers => {Modifiers.giant};
  @override
  ScoreBounds get scoreBounds => const ScoreBounds(0, 5 * 300 + 500);

  @override
  Map<String, num> get defaultTuning => const {
    'aiSpeed': 520,
    'malletSpeed': 2200,
    'puckDamping': 0.25,
  };

  @override
  String name(AppLocalizations l10n) => l10n.gameAirhockeyName;
  @override
  String rule(AppLocalizations l10n) => l10n.gameAirhockeyRule;

  @override
  String shareLine(AppLocalizations l10n, Map<String, num> s) {
    final me = s['me']?.toInt() ?? 0, ai = s['ai']?.toInt() ?? 0;
    return me > ai
        ? l10n.gameAirhockeyWin(me, ai)
        : l10n.gameAirhockeyLoss(me, ai);
  }

  @override
  List<(String, String)> statRows(AppLocalizations l10n, Map<String, num> s) =>
      [
        (l10n.statMatch, '${s['me'] ?? 0} – ${s['ai'] ?? 0}'),
        (l10n.statDirectGoals, '${s['direct'] ?? 0}'),
      ];

  @override
  Map<String, String> highlightLabels(AppLocalizations l10n) => {
    'directGoal': l10n.highlightDirectGoal,
  };

  @override
  GameSim createSim(GameContext ctx) => AirhockeySim(ctx, this);

  @override
  String levelFingerprint(int seed, String? modifierId) {
    final l = AirhockeyLevel.generate(
      GameContext(seed: seed, modifierId: modifierId),
    );
    return fingerprint([
      l.pegs.length,
      for (final p in l.pegs) ...[p.dx, p.dy],
      l.aiSpeedFactor,
      l.aiAggression,
      l.goalHalf,
    ]);
  }
}

class AirhockeyLevel {
  const AirhockeyLevel(
    this.pegs,
    this.aiSpeedFactor,
    this.aiAggression,
    this.goalHalf,
    this.kickoff,
  );

  /// 0, 1 or 2 pegs in the middle (section 7.8).
  final List<Offset> pegs;
  final double aiSpeedFactor;

  /// How far the AI comes forward to attack (0 = goalkeeper, 1 = rusher).
  final double aiAggression;
  final double goalHalf;

  /// Lateral speed of the opening face-off.
  final double kickoff;

  static AirhockeyLevel generate(GameContext ctx) {
    final r = SeededRandom.derive(ctx.seed, 'airhockey:level');
    final n = r.nextInt(3);
    final giant = ctx.has(Modifiers.giant);
    return AirhockeyLevel(
      switch (n) {
        0 => const [],
        1 => const [Offset(180, 355)],
        _ => [
          Offset(180 - r.doubleInRange(50, 80), 355),
          Offset(180 + r.doubleInRange(50, 80), 355),
        ],
      },
      r.doubleInRange(0.85, 1.15) * (giant ? 1.3 : 1),
      r.doubleInRange(0.2, 0.8),
      giant ? 80 : 60,
      r.doubleInRange(-120, 120),
    );
  }
}

class AirhockeySim extends GameSim {
  AirhockeySim(super.ctx, AirhockeyGame def)
    : level = AirhockeyLevel.generate(ctx),
      _aiSpeed = ctx.tune('aiSpeed', def.defaultTuning['aiSpeed']!),
      _malletSpeed = ctx.tune(
        'malletSpeed',
        def.defaultTuning['malletSpeed']!,
      ) {
    final w = _world = Phys.world();
    final damping = ctx.tune('puckDamping', def.defaultTuning['puckDamping']!);
    const r = rink;
    final gh = level.goalHalf;
    for (final (a, b) in [
      (r.topLeft, Offset(180 - gh, r.top)),
      (Offset(180 + gh, r.top), r.topRight),
      (r.topRight, r.bottomRight),
      (r.bottomLeft, Offset(180 - gh, r.bottom)),
      (Offset(180 + gh, r.bottom), r.bottomRight),
      (r.topLeft, r.bottomLeft),
    ]) {
      _walls.add(Phys.staticSegment(w, a, b, restitution: 0.9));
    }
    for (final p in level.pegs) {
      _walls.add(Phys.staticCircle(w, p, 14, restitution: 0.9));
    }
    _puck = Phys.ball(
      w,
      const Offset(180, 360),
      puckR,
      density: 0.5,
      restitution: 0.9,
      friction: 0,
      linearDamping: damping,
    )..velPx = Offset(level.kickoff, 160);
  }

  static const Rect rink = Rect.fromLTRB(16, 92, 344, 620);
  static const double puckR = 13;
  static const double malletR = 24;
  static const int winGoals = 5;

  final AirhockeyLevel level;
  final double _aiSpeed;
  final double _malletSpeed;
  late final World _world;
  late final Body _puck;
  final List<Body> _walls = [];

  /// Mallets are not Box2D bodies: their hits are resolved by hand so that a
  /// fast swing transfers its speed to the puck (Box2D v3 pushes kinematic
  /// overlaps out too softly for air hockey).
  Offset _me = const Offset(180, 560);
  Offset _meVel = Offset.zero;
  Offset _ai = const Offset(180, 150);
  Offset _aiVel = Offset.zero;

  int me = 0, opp = 0, direct = 0;
  bool _touchedWall = false;
  bool _lastTouchMine = false;
  int _pause = 0;
  Offset _target = const Offset(180, 560);
  int? _pointer;

  @override
  Color get backgroundColor => const Color(0xFF0D1B2A);

  @override
  int get debugBodyCount => 1 + _walls.length;

  @override
  Offset get focus => _puck.px;

  @override
  void onPointer(PointerPhase phase, int pointer, Offset pos) {
    switch (phase) {
      case PointerPhase.down:
        _pointer ??= pointer;
        if (pointer == _pointer) _target = pos;
      case PointerPhase.move:
        if (pointer == _pointer) _target = pos;
      case PointerPhase.up:
        if (pointer == _pointer) _pointer = null;
    }
  }

  /// Moves a mallet toward [to] with a speed cap, inside [area].
  (Offset, Offset) _drive(Offset m, Offset to, Rect area, double maxSpeed) {
    final goal = Offset(
      to.dx.clamp(area.left, area.right),
      to.dy.clamp(area.top, area.bottom),
    );
    final d = goal - m;
    final max = maxSpeed * stepDt;
    final move = d.distance > max ? d / d.distance * max : d;
    return (m + move, move / stepDt);
  }

  /// Mallet ↔ puck hit: push the puck out, reflect its relative velocity
  /// and add the mallet's own speed.
  bool _hit(Offset mallet, Offset malletVel) {
    final p = _puck.px;
    final d = p - mallet;
    final dist = d.distance;
    if (dist >= malletR + puckR || dist == 0) return false;
    final n = d / dist;
    _puck.moveTo(mallet + n * (malletR + puckR + 0.5));
    final rel = _puck.velPx - malletVel;
    final along = rel.dx * n.dx + rel.dy * n.dy;
    if (along < 0) _puck.velPx = rel - n * (1.9 * along) + malletVel;
    final out = _puck.velPx.dx * n.dx + _puck.velPx.dy * n.dy;
    if (out < 120) _puck.velPx += n * (120 - out);
    return true;
  }

  @override
  void tick() {
    tickParticles();
    if (_pause > 0) {
      if (--_pause == 0 && (me >= winGoals || opp >= winGoals)) {
        over = true;
        return;
      }
      Phys.step(_world);
      return;
    }
    const half = 360.0;
    final (me1, meV) = _drive(
      _me,
      _target,
      Rect.fromLTRB(
        rink.left + malletR,
        half + malletR,
        rink.right - malletR,
        rink.bottom - malletR,
      ),
      _malletSpeed,
    );
    _me = me1;
    _meVel = meV;
    // AI: defends its goal, attacks when the puck is in its half.
    final p = _puck.px;
    final inAiHalf = p.dy < half;
    final aiGoal = inAiHalf && _puck.velPx.dy < 200
        ? p.translate(0, -malletR * (1 - level.aiAggression))
        : Offset(
            180 + (p.dx - 180) * 0.5,
            rink.top + 50 + 60 * level.aiAggression,
          );
    final (ai1, aiV) = _drive(
      _ai,
      aiGoal,
      Rect.fromLTRB(
        rink.left + malletR,
        rink.top + malletR,
        rink.right - malletR,
        half - malletR,
      ),
      _aiSpeed * level.aiSpeedFactor,
    );
    _ai = ai1;
    _aiVel = aiV;
    if (_hit(_me, _meVel)) {
      if (!_lastTouchMine || _touchedWall) {
        cue(sfx: Sfx.hit, haptic: Haptic.light);
      }
      _lastTouchMine = true;
      _touchedWall = false;
    }
    if (_hit(_ai, _aiVel)) {
      if (_lastTouchMine) cue(sfx: Sfx.hit);
      _lastTouchMine = false;
    }
    Phys.step(_world);
    for (final _ in _world.contactEvents.hit) {
      _touchedWall = true;
      cue(sfx: Sfx.bounce);
    }
    final v = _puck.velPx;
    if (v.distance > 1600) _puck.velPx = v / v.distance * 1600;
    final q = _puck.px;
    if (q.dy < rink.top - puckR) {
      _goal(mine: true);
    } else if (q.dy > rink.bottom + puckR) {
      _goal(mine: false);
    } else if (!rink.inflate(40).contains(q)) {
      _reset(towardMe: true);
    }
  }

  void _goal({required bool mine}) {
    if (mine) {
      me++;
      final isDirect = _lastTouchMine && !_touchedWall;
      score += isDirect ? 300 : 200;
      if (isDirect) {
        direct++;
        celebrate('directGoal');
      }
      if (me >= winGoals) score += 500;
      particles.fireworks(const Offset(180, 120));
      cue(sfx: Sfx.score, haptic: Haptic.heavy);
    } else {
      opp++;
      score = math.max(0, score - 100);
      cue(sfx: Sfx.miss, haptic: Haptic.medium);
    }
    _reset(towardMe: mine);
  }

  void _reset({required bool towardMe}) {
    _puck
      ..moveTo(Offset(180, towardMe ? 420 : 300))
      ..velPx = Offset(0, towardMe ? 60 : -60);
    _touchedWall = false;
    _pause = (0.8 * stepsPerSecond).round();
  }

  @override
  void onTimeUp() {
    if (me > opp && me < winGoals) score += 500;
  }

  @override
  void dispose() => _world.destroy();

  @override
  Map<String, num> get stats => {'me': me, 'ai': opp, 'direct': direct};

  @override
  void render(Canvas canvas) {
    canvas
      ..drawRect(Arena.rect, Paint()..color = const Color(0xFF0D1B2A))
      ..drawRRect(
        RRect.fromRectAndRadius(rink, const Radius.circular(24)),
        Paint()..color = const Color(0xFFE3F2FD),
      );
    final line = Paint()
      ..color = const Color(0x66E8322F)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    canvas
      ..drawLine(Offset(rink.left, 360), Offset(rink.right, 360), line)
      ..drawCircle(const Offset(180, 360), 50, line);
    final goal = Paint()..color = const Color(0xFF212121);
    final gh = level.goalHalf;
    canvas
      ..drawRect(
        Rect.fromLTRB(180 - gh, rink.top - 6, 180 + gh, rink.top + 4),
        goal,
      )
      ..drawRect(
        Rect.fromLTRB(180 - gh, rink.bottom - 4, 180 + gh, rink.bottom + 6),
        goal,
      );
    for (final p in level.pegs) {
      drawBall(canvas, p, 14, const Color(0xFF546E7A));
    }
    drawBall(canvas, _puck.px, puckR, const Color(0xFF212121));
    for (final (m, c) in [
      (_me, const Color(0xFFE8322F)),
      (_ai, const Color(0xFF1E88E5)),
    ]) {
      drawBall(canvas, m, malletR, c);
      canvas.drawCircle(m, malletR * 0.45, Paint()..color = Colors.white24);
    }
    drawText(
      canvas,
      '$me',
      const Offset(30, 380),
      size: 30,
      display: true,
      color: const Color(0xFFE8322F),
    );
    drawText(
      canvas,
      '$opp',
      const Offset(30, 310),
      size: 30,
      display: true,
      color: const Color(0xFF1E88E5),
    );
  }
}
