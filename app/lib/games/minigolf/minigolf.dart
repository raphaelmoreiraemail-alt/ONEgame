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
import 'minigolf_level.dart';

/// 7.1 Mini-Golf — 3 holes in 2 minutes, slingshot shots.
class MinigolfGame extends MiniGameDefinition {
  const MinigolfGame();

  @override
  String get id => 'minigolf';
  @override
  String get emoji => '⛳';
  @override
  GameCategory get category => GameCategory.sport;
  @override
  int get rulesVersion => 1;
  @override
  Set<String> get supportedModifiers => {
    Modifiers.wind,
    Modifiers.night,
    Modifiers.ice,
  };
  @override
  ScoreBounds get scoreBounds =>
      const ScoreBounds(0, 1000 + 3 * 3 * 150 + 360 + 900);

  @override
  Map<String, num> get defaultTuning => const {
    'maxShotSpeed': 950,
    'grassDamping': 1.0,
    'sandFactor': 3,
    'cupCaptureSpeed': 320,
    'maxStrokes': 8,
  };

  @override
  String name(AppLocalizations l10n) => l10n.gameMinigolfName;
  @override
  String rule(AppLocalizations l10n) => l10n.gameMinigolfRule;

  @override
  String shareLine(AppLocalizations l10n, Map<String, num> s) {
    final toPar = s['toPar']?.toInt() ?? 0;
    final base = l10n.gameMinigolfShare(
      s['holes']?.toInt() ?? 0,
      s['strokes']?.toInt() ?? 0,
      toPar > 0 ? '+$toPar' : '$toPar',
    );
    final aces = s['aces']?.toInt() ?? 0;
    return aces > 0 ? '$base · ${l10n.gameMinigolfShareAces(aces)}' : base;
  }

  @override
  List<(String, String)> statRows(AppLocalizations l10n, Map<String, num> s) {
    final toPar = s['toPar']?.toInt() ?? 0;
    return [
      (l10n.statHoles, '${s['holes'] ?? 0} / 3'),
      (l10n.statStrokes, '${s['strokes'] ?? 0}'),
      (l10n.statToPar, toPar > 0 ? '+$toPar' : '$toPar'),
      (l10n.statAces, '${s['aces'] ?? 0}'),
    ];
  }

  @override
  GameSim createSim(GameContext ctx) => MinigolfSim(ctx, this);

  @override
  String levelFingerprint(int seed, String? modifierId) => fingerprint([
    for (final h in GolfLevel.generate(seed)) ...[
      h.tee.dx,
      h.cup.dx,
      h.par,
      ...h.modules,
      for (final o in h.obstacles) ...o.fingerprintParts,
    ],
    ...MinigolfSim.windFor(GameContext(seed: seed, modifierId: modifierId))
        .let((w) => [w.dx, w.dy]),
  ]);
}

extension _Let<T> on T {
  R let<R>(R Function(T) f) => f(this);
}

enum _State { aiming, rolling, transition, done }

class MinigolfSim extends GameSim {
  MinigolfSim(super.ctx, MinigolfGame def)
    : holes = GolfLevel.generate(ctx.seed),
      wind = windFor(ctx),
      _maxSpeed = ctx.tune('maxShotSpeed', def.defaultTuning['maxShotSpeed']!),
      _grassDamping =
          ctx.tune('grassDamping', def.defaultTuning['grassDamping']!) *
          (ctx.has(Modifiers.ice) ? 0.5 : 1),
      _sandFactor = ctx.tune('sandFactor', def.defaultTuning['sandFactor']!),
      _captureSpeed = ctx.tune(
        'cupCaptureSpeed',
        def.defaultTuning['cupCaptureSpeed']!,
      ),
      _maxStrokes = ctx
          .tune('maxStrokes', def.defaultTuning['maxStrokes']!)
          .toInt() {
    _buildHole();
  }

  /// Constant wind (px/s²) of the `wind` modifier, from the seed.
  static Offset windFor(GameContext ctx) {
    if (!ctx.has(Modifiers.wind)) return Offset.zero;
    final r = SeededRandom.derive(ctx.seed, 'minigolf:wind');
    final a = r.nextDouble() * math.pi * 2;
    final s = r.doubleInRange(25, 55);
    return Offset(math.cos(a) * s, math.sin(a) * s);
  }

  final List<GolfHole> holes;
  final Offset wind;
  final double _maxSpeed;
  final double _grassDamping;
  final double _sandFactor;
  final double _captureSpeed;
  final int _maxStrokes;

  int holeIndex = 0;
  int strokes = 0;
  final List<int> holeStrokes = [];
  int aces = 0;

  /// Seconds left when the 3 holes were finished (score bonus ×3).
  int timeBonusSeconds = 0;

  _State _state = _State.aiming;
  int _transitionSteps = 0;
  World? _world;
  late Body _ball;
  final List<(Obstacle, Body)> _dynamicObstacles = [];
  Offset _lastShotFrom = Offset.zero;
  int _portalCooldown = 0;
  int? _aimPointer;
  Offset? _aimFinger;

  GolfHole get hole => holes[holeIndex];

  @override
  Color get backgroundColor => const Color(0xFF2E7D32);

  @override
  Offset get focus => _world == null ? Arena.center : _ball.px;

  @override
  int get debugBodyCount => 1 + _dynamicObstacles.length;

  void _buildHole() {
    _world?.destroy();
    final w = _world = Phys.world();
    _dynamicObstacles.clear();
    const b = Course.bounds;
    for (final (p, q) in [
      (b.topLeft, b.topRight),
      (b.topRight, b.bottomRight),
      (b.bottomRight, b.bottomLeft),
      (b.bottomLeft, b.topLeft),
    ]) {
      Phys.staticSegment(w, p, q);
    }
    for (final o in hole.obstacles) {
      switch (o.kind) {
        case ObstacleKind.wall:
          Phys.staticBox(w, o.rect, angle: o.angle);
        case ObstacleKind.bumper:
          Phys.staticCircle(
            w,
            o.rect.center,
            o.rect.width / 2,
            restitution: 1.3,
          );
        case ObstacleKind.windmill:
          final body = w.createBody(
            BodyDef(
              type: BodyType.kinematic,
              position: Phys.v(o.rect.center),
              angularVelocity: o.period,
            ),
          );
          final r = Phys.m(o.rect.width / 2);
          body
            ..createShape(Polygon.box(r, Phys.m(5)))
            ..createShape(Polygon.box(Phys.m(5), r))
            ..createShape(Circle(radius: Phys.m(9)));
          _dynamicObstacles.add((o, body));
        case ObstacleKind.mover:
          final body = w.createBody(
            BodyDef(type: BodyType.kinematic, position: Phys.v(o.rect.center)),
          );
          body.createShape(
            Polygon.box(Phys.m(o.rect.width / 2), Phys.m(o.rect.height / 2)),
            ShapeDef(material: SurfaceMaterial(restitution: 0.7)),
          );
          _dynamicObstacles.add((o, body));
        case ObstacleKind.sand:
        case ObstacleKind.water:
        case ObstacleKind.slope:
        case ObstacleKind.portal:
          break;
      }
    }
    _ball = Phys.ball(
      w,
      hole.tee,
      Course.ballRadius,
      restitution: 0.7,
      linearDamping: _grassDamping,
    );
    _lastShotFrom = hole.tee;
    strokes = 0;
    _state = _State.aiming;
  }

  bool get _ballAtRest => _ball.velPx.distance < 6;

  @override
  void onPointer(PointerPhase phase, int pointer, Offset pos) {
    if (_state != _State.aiming) return;
    switch (phase) {
      case PointerPhase.down:
        if (_aimPointer == null && (pos - _ball.px).distance < 80) {
          _aimPointer = pointer;
          _aimFinger = pos;
        }
      case PointerPhase.move:
        if (pointer == _aimPointer) _aimFinger = pos;
      case PointerPhase.up:
        if (pointer != _aimPointer) return;
        _aimPointer = null;
        final pull = _ball.px - pos;
        _aimFinger = null;
        final power = math.min(pull.distance / 140, 1.0);
        if (power < 0.06) return;
        final dir = pull / pull.distance;
        _lastShotFrom = _ball.px;
        _ball.velPx = dir * power * _maxSpeed;
        strokes++;
        _state = _State.rolling;
        cue(sfx: Sfx.tap, haptic: Haptic.light);
    }
  }

  Offset? get _pull => _aimFinger == null ? null : _ball.px - _aimFinger!;

  @override
  void tick() {
    tickParticles();
    final w = _world;
    if (w == null || _state == _State.done) return;
    if (_state == _State.transition) {
      if (--_transitionSteps <= 0) {
        holeIndex++;
        if (holeIndex >= holes.length) {
          _finish();
        } else {
          _buildHole();
        }
      }
      return;
    }

    // Kinematic movers follow an exact sine (no drift).
    final t = elapsed;
    for (final (o, body) in _dynamicObstacles) {
      if (o.kind == ObstacleKind.mover) {
        final wv = 2 * math.pi / o.period;
        body
          ..moveTo(o.rect.center + o.vector * math.sin(wv * t))
          ..velPx = o.vector * (wv * math.cos(wv * t));
      }
    }

    final pos = _ball.px;
    var damping = _grassDamping;
    var accel = Offset.zero;
    for (final o in hole.obstacles) {
      if (!o.rect.contains(pos)) continue;
      switch (o.kind) {
        case ObstacleKind.sand:
          damping = _grassDamping * _sandFactor;
        case ObstacleKind.slope:
          accel += o.vector;
        case ObstacleKind.water:
          _splash();
          return;
        default:
          break;
      }
    }
    if (_portalCooldown > 0) _portalCooldown--;
    for (final o in hole.obstacles) {
      if (o.kind == ObstacleKind.portal &&
          _portalCooldown == 0 &&
          (pos - o.rect.center).distance < o.rect.width / 2) {
        _ball.moveTo(o.vector);
        _portalCooldown = 60;
        particles.burst(o.vector, const Color(0xFFB388FF), count: 10);
        cue(sfx: Sfx.whoosh);
      }
    }
    final moving = !_ballAtRest;
    if (moving) accel += wind;
    _ball.linearDamping = damping;
    if (accel != Offset.zero) {
      _ball.applyForce(Phys.v(accel) * _ball.mass);
    }

    Phys.step(w);
    for (final _ in w.contactEvents.hit) {
      cue(sfx: Sfx.bounce);
    }

    // Cup capture.
    final d = (_ball.px - hole.cup).distance;
    if (d < Course.cupRadius && _ball.velPx.distance < _captureSpeed) {
      _sink();
      return;
    }

    if (_state == _State.rolling && _ballAtRest && accel == wind) {
      _ball.velPx = Offset.zero;
      if (strokes >= _maxStrokes) {
        _endHole(hole.par + 3);
      } else {
        _state = _State.aiming;
      }
    }
    _updateScore();
  }

  void _splash() {
    particles.burst(_ball.px, const Color(0xFF90CAF9), count: 20, gravity: 0);
    cue(sfx: Sfx.miss, haptic: Haptic.medium);
    _ball
      ..moveTo(_lastShotFrom)
      ..velPx = Offset.zero;
    strokes++; // Penalty stroke.
    if (strokes >= _maxStrokes) {
      _endHole(hole.par + 3);
    } else {
      _state = _State.aiming;
    }
  }

  void _sink() {
    particles.burst(hole.cup, Colors.white, count: 18);
    cue(sfx: Sfx.score, haptic: Haptic.medium);
    if (strokes == 1) {
      aces++;
      celebrate('ace');
      particles.fireworks(hole.cup);
    }
    _endHole(strokes);
  }

  void _endHole(int counted) {
    holeStrokes.add(counted);
    _state = _State.transition;
    _transitionSteps = stepsPerSecond; // 1 s between holes.
    _ball.velPx = Offset.zero;
    _updateScore();
  }

  void _finish() {
    _state = _State.done;
    _world?.destroy();
    _world = null;
    timeBonusSeconds = math.max(0, 120 - elapsed.ceil());
    _updateScore(bonusSeconds: timeBonusSeconds);
    over = true;
  }

  int _parSoFar() {
    var p = 0;
    for (var i = 0; i < holeStrokes.length; i++) {
      p += holes[i].par;
    }
    return p;
  }

  int get totalStrokes => holeStrokes.fold(0, (a, b) => a + b);

  void _updateScore({int bonusSeconds = 0}) {
    final diff = _parSoFar() - totalStrokes;
    score = math.max(0, 1000 + diff * 150 + aces * 300 + bonusSeconds * 3);
  }

  @override
  void onTimeUp() {
    // Current and remaining holes count as par + 3 (section 7.1).
    while (holeStrokes.length < holes.length) {
      holeStrokes.add(holes[holeStrokes.length].par + 3);
    }
    _world?.destroy();
    _world = null;
    _state = _State.done;
    _updateScore();
  }

  @override
  void dispose() {
    _world?.destroy();
    _world = null;
  }

  @override
  Map<String, num> get stats {
    final finished = holeStrokes.length;
    return {
      'holes': finished,
      'strokes': totalStrokes,
      'toPar': totalStrokes - _parSoFar(),
      'aces': aces,
    };
  }

  // ---------------------------------------------------------------- render

  @override
  void render(Canvas canvas) {
    canvas.drawRect(Arena.rect, Paint()..color = const Color(0xFF1B5E20));
    const b = Course.bounds;
    for (var y = b.top; y < b.bottom; y += 40) {
      canvas.drawRect(
        Rect.fromLTRB(b.left, y, b.right, math.min(y + 40, b.bottom)),
        Paint()
          ..color = ((y - b.top) ~/ 40).isEven
              ? const Color(0xFF43A047)
              : const Color(0xFF4CAF50),
      );
    }
    final h = holeIndex < holes.length ? hole : holes.last;
    for (final o in h.obstacles) {
      _renderZone(canvas, o);
    }
    // Cup + flag.
    canvas
      ..drawCircle(
        h.cup,
        Course.cupRadius + 2,
        Paint()..color = const Color(0xFF2E7D32),
      )
      ..drawCircle(
        h.cup,
        Course.cupRadius,
        Paint()..color = const Color(0xFF111111),
      )
      ..drawLine(
        h.cup,
        h.cup.translate(0, -40),
        Paint()
          ..color = Colors.white
          ..strokeWidth = 2,
      );
    canvas.drawPath(
      Path()
        ..moveTo(h.cup.dx, h.cup.dy - 40)
        ..lineTo(h.cup.dx + 22, h.cup.dy - 33)
        ..lineTo(h.cup.dx, h.cup.dy - 26)
        ..close(),
      Paint()..color = const Color(0xFFE8322F),
    );
    // Tee mat.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: h.tee, width: 34, height: 20),
        const Radius.circular(4),
      ),
      Paint()..color = const Color(0x33000000),
    );
    for (final o in h.obstacles) {
      _renderSolid(canvas, o);
    }
    // Border.
    canvas.drawRect(
      b,
      Paint()
        ..color = const Color(0xFF795548)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8,
    );

    if (_world != null) {
      final ball = _ball.px;
      final pull = _pull;
      if (pull != null && pull.distance > 4) {
        final power = math.min(pull.distance / 140, 1.0);
        drawDashed(
          canvas,
          ball,
          pull,
          40,
          Paint()
            ..color = Colors.white
            ..strokeWidth = 3
            ..strokeCap = StrokeCap.round,
        );
        canvas.drawCircle(
          ball,
          14 + power * 18,
          Paint()
            ..color = Color.lerp(
              const Color(0xFFFFD23F),
              const Color(0xFFE8322F),
              power,
            )!
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3,
        );
      } else if (_state == _State.aiming) {
        final pulse = 12 + 3 * math.sin(elapsed * 6);
        canvas.drawCircle(
          ball,
          pulse,
          Paint()
            ..color = const Color(0x88FFFFFF)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      }
      drawBall(canvas, ball, Course.ballRadius, Colors.white);
    }

    if (wind != Offset.zero) drawWind(canvas, const Offset(312, 600), wind);
    drawText(
      canvas,
      '⛳ ${math.min(holeIndex + 1, holes.length)}/${holes.length} · PAR ${h.par} · '
      '${_state == _State.transition || _state == _State.done ? holeStrokes.last : strokes}',
      const Offset(180, 108),
      size: 14,
      align: TextAlign.center,
    );
  }

  void _renderZone(Canvas c, Obstacle o) {
    switch (o.kind) {
      case ObstacleKind.sand:
        c.drawRRect(
          RRect.fromRectAndRadius(o.rect, const Radius.circular(22)),
          Paint()..color = const Color(0xFFE6CF8B),
        );
      case ObstacleKind.water:
        c.drawRRect(
          RRect.fromRectAndRadius(o.rect, const Radius.circular(18)),
          Paint()..color = const Color(0xFF1E88E5),
        );
        final wave = Paint()
          ..color = const Color(0x66FFFFFF)
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke;
        for (var y = o.rect.top + 14; y < o.rect.bottom - 6; y += 16) {
          final dx = 6 * math.sin(elapsed * 2 + y);
          c.drawLine(
            Offset(o.rect.left + 20 + dx, y),
            Offset(o.rect.left + 40 + dx, y),
            wave,
          );
        }
      case ObstacleKind.slope:
        c.drawRect(o.rect, Paint()..color = const Color(0x2200332A));
        final dir = o.vector / o.vector.distance;
        final p = Paint()
          ..color = const Color(0x55FFFFFF)
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round;
        final phase = (elapsed * 30) % 40;
        for (var x = o.rect.left + 30; x < o.rect.right; x += 60) {
          for (var y = o.rect.top + 20; y < o.rect.bottom; y += 40) {
            final at = Offset(x, y) + dir * (phase - 20);
            final n = Offset(-dir.dy, dir.dx);
            c
              ..drawLine(at, at - dir * 8 + n * 6, p)
              ..drawLine(at, at - dir * 8 - n * 6, p);
          }
        }
      case ObstacleKind.portal:
        for (final p in [o.rect.center, o.vector]) {
          c
            ..drawCircle(p, 14, Paint()..color = const Color(0xFF4A148C))
            ..drawCircle(
              p,
              10 + 2 * math.sin(elapsed * 8),
              Paint()
                ..color = const Color(0xFFB388FF)
                ..style = PaintingStyle.stroke
                ..strokeWidth = 3,
            );
        }
      default:
        break;
    }
  }

  void _renderSolid(Canvas c, Obstacle o) {
    switch (o.kind) {
      case ObstacleKind.wall:
        c
          ..save()
          ..translate(o.rect.center.dx, o.rect.center.dy)
          ..rotate(o.angle);
        drawBox(
          c,
          Rect.fromCenter(
            center: Offset.zero,
            width: o.rect.width,
            height: o.rect.height,
          ),
          const Color(0xFF8D6E63),
          radius: 4,
        );
        c.restore();
      case ObstacleKind.bumper:
        drawBall(c, o.rect.center, o.rect.width / 2, const Color(0xFFE8322F));
        c.drawCircle(
          o.rect.center,
          o.rect.width / 4,
          Paint()..color = const Color(0xFFFFD23F),
        );
      case ObstacleKind.windmill || ObstacleKind.mover:
        final body = _dynamicObstacles
            .where((e) => identical(e.$1, o))
            .map((e) => e.$2)
            .firstOrNull;
        if (body == null || _world == null) return;
        final at = body.px;
        if (o.kind == ObstacleKind.mover) {
          drawBox(
            c,
            Rect.fromCenter(
              center: at,
              width: o.rect.width,
              height: o.rect.height,
            ),
            const Color(0xFFFF7043),
            radius: 4,
          );
        } else {
          final r = o.rect.width / 2;
          c
            ..save()
            ..translate(at.dx, at.dy)
            ..rotate(body.angle);
          final blade = Paint()..color = const Color(0xFFF4ECE4);
          c
            ..drawRect(
              Rect.fromCenter(center: Offset.zero, width: r * 2, height: 10),
              blade,
            )
            ..drawRect(
              Rect.fromCenter(center: Offset.zero, width: 10, height: r * 2),
              blade,
            )
            ..restore()
            ..drawCircle(at, 9, Paint()..color = const Color(0xFFE8322F));
        }
      default:
        break;
    }
  }
}
