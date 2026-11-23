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

/// 7.4 Basket — 60 s of shooting, then 60 s of "moneyball" (moving hoop).
class BasketGame extends MiniGameDefinition {
  const BasketGame();

  @override
  String get id => 'basket';
  @override
  String get emoji => '🏀';
  @override
  GameCategory get category => GameCategory.sport;
  @override
  int get rulesVersion => 1;
  @override
  Set<String> get supportedModifiers => {Modifiers.wind, Modifiers.giant};
  @override
  ScoreBounds get scoreBounds => const ScoreBounds(0, 1200);

  @override
  Map<String, num> get defaultTuning => const {
    'swipeGain': 0.42,
    'maxSpeed': 1350,
    'gravity': 1500,
    'hoopAmplitude': 60,
  };

  @override
  String name(AppLocalizations l10n) => l10n.gameBasketName;
  @override
  String rule(AppLocalizations l10n) => l10n.gameBasketRule;

  @override
  String shareLine(AppLocalizations l10n, Map<String, num> s) =>
      l10n.gameBasketShare(
        s['baskets']?.toInt() ?? 0,
        s['swishes']?.toInt() ?? 0,
        s['maxStreak']?.toInt() ?? 0,
      );

  @override
  List<(String, String)> statRows(AppLocalizations l10n, Map<String, num> s) =>
      [
        (l10n.statBaskets, '${s['baskets'] ?? 0} / ${s['shots'] ?? 0}'),
        (l10n.statSwishes, '${s['swishes'] ?? 0}'),
        (l10n.statMaxStreak, '${s['maxStreak'] ?? 0}'),
      ];

  @override
  Map<String, String> highlightLabels(AppLocalizations l10n) => {
    'onFire': l10n.highlightOnFire,
  };

  @override
  GameSim createSim(GameContext ctx) => BasketSim(ctx, this);

  @override
  String levelFingerprint(int seed, String? modifierId) {
    final l = BasketLevel.generate(
      GameContext(seed: seed, modifierId: modifierId),
    );
    return fingerprint([
      for (final s in l.spots) ...[s.dx, s.dy],
      l.hoopAmpX,
      l.hoopAmpY,
      l.hoopPeriod,
      l.wind.dx,
    ]);
  }
}

class BasketLevel {
  const BasketLevel(
    this.spots,
    this.hoopAmpX,
    this.hoopAmpY,
    this.hoopPeriod,
    this.wind,
  );

  final List<Offset> spots;
  final double hoopAmpX;
  final double hoopAmpY;
  final double hoopPeriod;

  /// Horizontal wind (px/s²) during the second minute (`wind` modifier).
  final Offset wind;

  static BasketLevel generate(GameContext ctx) {
    final r = SeededRandom.derive(ctx.seed, 'basket:spots');
    final h = SeededRandom.derive(ctx.seed, 'basket:hoop');
    final w = SeededRandom.derive(ctx.seed, 'basket:wind');
    return BasketLevel(
      [
        for (var i = 0; i < 5; i++)
          Offset(r.doubleInRange(50, 190), r.doubleInRange(470, 560)),
      ],
      h.doubleInRange(20, 50),
      h.doubleInRange(30, 70),
      h.doubleInRange(2.4, 4.0),
      ctx.has(Modifiers.wind)
          ? Offset(w.doubleInRange(-90, 90), 0)
          : Offset.zero,
    );
  }
}

class BasketSim extends GameSim {
  BasketSim(super.ctx, BasketGame def)
    : level = BasketLevel.generate(ctx),
      _gain = ctx.tune('swipeGain', def.defaultTuning['swipeGain']!),
      _maxSpeed = ctx.tune('maxSpeed', def.defaultTuning['maxSpeed']!),
      _giant = ctx.has(Modifiers.giant) {
    final g = ctx.tune('gravity', def.defaultTuning['gravity']!);
    _world = Phys.world(gravity: Offset(0, g));
    _ampScale =
        ctx.tune('hoopAmplitude', def.defaultTuning['hoopAmplitude']!) / 60;
    _floor = Phys.staticBox(
      _world,
      const Rect.fromLTWH(0, 600, 360, 40),
      restitution: 0.5,
    );
    Phys.staticBox(_world, const Rect.fromLTWH(-20, 0, 20, 640));
    _hoop = _world.createBody(
      BodyDef(type: BodyType.kinematic, position: Phys.v(hoopHome)),
    );
    final rim = _giant ? 34.0 : 27.0;
    _rimHalf = rim;
    final mat = SurfaceMaterial(restitution: 0.45, friction: 0.3);
    _hoop
      ..createShape(
        Circle(radius: Phys.m(4), center: Phys.v(Offset(-rim, 0))),
        ShapeDef(material: mat, enableHitEvents: true),
      )
      ..createShape(
        Circle(radius: Phys.m(4), center: Phys.v(Offset(rim, 0))),
        ShapeDef(material: mat, enableHitEvents: true),
      )
      ..createShape(
        Polygon.offsetBox(
          Phys.m(4),
          Phys.m(48),
          center: Phys.v(Offset(rim + 10, -38)),
        ),
        ShapeDef(
          material: SurfaceMaterial(restitution: 0.5),
          enableHitEvents: true,
        ),
      );
    _spawnBall();
  }

  static const Offset hoopHome = Offset(272, 250);
  static const double ballRadius = 13;

  final BasketLevel level;
  final double _gain;
  final double _maxSpeed;
  final bool _giant;
  late final double _ampScale;
  late final World _world;
  late final Body _hoop;
  late final Body _floor;
  late double _rimHalf;
  Body? _ball;

  int shots = 0;
  int baskets = 0;
  int swishes = 0;
  int streak = 0;
  int maxStreak = 0;
  int _spotIndex = 0;

  bool _inFlight = false;
  bool _touched = false;
  bool _scored = false;
  int _flightSteps = 0;
  int _respawnIn = 0;
  Offset? _prevBall;

  int? _pointer;
  final List<(int, Offset)> _samples = [];
  Offset? _dragStart;

  bool get moneyball => elapsed >= 60;

  Offset get hoopPos => _hoop.px;

  @override
  Color get backgroundColor => const Color(0xFF3E2723);

  @override
  int get debugBodyCount => 4;

  void _spawnBall() {
    final spot = level.spots[_spotIndex % level.spots.length];
    _ball?.destroy();
    _ball =
        Phys.ball(
            _world,
            spot,
            ballRadius,
            restitution: 0.62,
            friction: 0.5,
            density: 0.6,
          )
          ..gravityScale = 0
          ..velPx = Offset.zero;
    _inFlight = false;
    _touched = false;
    _scored = false;
    _flightSteps = 0;
  }

  @override
  void onPointer(PointerPhase phase, int pointer, Offset pos) {
    final ball = _ball;
    if (ball == null || _inFlight) return;
    switch (phase) {
      case PointerPhase.down:
        if (_pointer == null && (pos - ball.px).distance < 80) {
          _pointer = pointer;
          _dragStart = pos;
          _samples
            ..clear()
            ..add((step, pos));
        }
      case PointerPhase.move:
        if (pointer == _pointer) _samples.add((step, pos));
      case PointerPhase.up:
        if (pointer != _pointer) return;
        _pointer = null;
        _samples.add((step, pos));
        _throw();
    }
  }

  void _throw() {
    // Swipe velocity over the last ~0.1 s.
    final last = _samples.last;
    var first = _samples.first;
    for (final s in _samples.reversed) {
      if (last.$1 - s.$1 > 12) break;
      first = s;
    }
    final dt = math.max(1, last.$1 - first.$1) / stepsPerSecond;
    final v = (last.$2 - first.$2) / dt * _gain;
    final total = last.$2 - (_dragStart ?? last.$2);
    if (total.dy > -30 || v.dy > -100) return; // must swipe upward
    final speed = math.min(v.distance, _maxSpeed);
    final dir = v / v.distance;
    _ball!
      ..gravityScale = 1
      ..velPx = dir * speed
      ..angularVelocity = -8;
    shots++;
    _inFlight = true;
    _prevBall = _ball!.px;
    cue(sfx: Sfx.whoosh, haptic: Haptic.light);
  }

  @override
  void tick() {
    tickParticles();
    // Hoop: still for 60 s, then moneyball motion.
    if (moneyball) {
      final t = elapsed - 60;
      final w = 2 * math.pi / level.hoopPeriod;
      final ax = level.hoopAmpX * _ampScale * (_giant ? 1.3 : 1);
      final ay = level.hoopAmpY * _ampScale * (_giant ? 1.3 : 1);
      final p =
          hoopHome + Offset(-ax * math.sin(w * t), ay * math.sin(2 * w * t));
      _hoop
        ..moveTo(p)
        ..velPx = Offset(
          -ax * w * math.cos(w * t),
          ay * 2 * w * math.cos(2 * w * t),
        );
    }
    final ball = _ball;
    if (ball != null && _inFlight && moneyball && level.wind != Offset.zero) {
      ball.applyForce(Phys.v(level.wind) * ball.mass);
    }
    Phys.step(_world);
    if (ball == null) return;
    for (final h in _world.contactEvents.hit) {
      final other = h.shapeA.body == ball ? h.shapeB.body : h.shapeA.body;
      if (other == _hoop) {
        _touched = true;
        cue(sfx: Sfx.bounce);
      } else if (other == _floor) {
        cue(sfx: Sfx.bounce);
      }
    }
    if (_inFlight) {
      _flightSteps++;
      final p = ball.px;
      final prev = _prevBall ?? p;
      final rimY = hoopPos.dy;
      // Basket: crosses the rim plane downward between the rim edges.
      if (!_scored &&
          prev.dy < rimY &&
          p.dy >= rimY &&
          ball.velPx.dy > 0 &&
          (p.dx - hoopPos.dx).abs() < _rimHalf - 4) {
        _basket();
      }
      _prevBall = p;
      if (p.dy > 700 || p.dx > 400 || _flightSteps > 4 * stepsPerSecond) {
        _endShot();
      } else if (_scored && _respawnIn-- <= 0) {
        _endShot();
      } else if (!_scored && ball.velPx.distance < 15 && _flightSteps > 60) {
        _endShot();
      }
    }
  }

  void _basket() {
    _scored = true;
    _respawnIn = 50;
    baskets++;
    final swish = !_touched;
    if (swish) swishes++;
    final mult = streak >= 3 ? 2 : 1;
    streak++;
    maxStreak = math.max(maxStreak, streak);
    score += (swish ? 3 : 2) * mult;
    particles.burst(
      hoopPos.translate(0, 20),
      const Color(0xFFFF9800),
      count: swish ? 24 : 14,
    );
    cue(sfx: Sfx.score, haptic: swish ? Haptic.medium : Haptic.light);
    if (streak == 5) {
      celebrate('onFire');
      particles.fireworks(hoopPos);
    }
  }

  void _endShot() {
    if (!_scored) {
      streak = 0;
      cue(sfx: Sfx.miss);
    }
    _spotIndex++;
    _spawnBall();
  }

  @override
  void dispose() => _world.destroy();

  @override
  Map<String, num> get stats => {
    'shots': shots,
    'baskets': baskets,
    'swishes': swishes,
    'maxStreak': maxStreak,
  };

  @override
  void render(Canvas canvas) {
    // Wall + parquet floor.
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 360, 600),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF263238), Color(0xFF37474F)],
        ).createShader(const Rect.fromLTWH(0, 0, 360, 600)),
    );
    for (var i = 0; i < 9; i++) {
      canvas.drawRect(
        Rect.fromLTWH(i * 40.0, 600, 40, 40),
        Paint()
          ..color = i.isEven
              ? const Color(0xFFC68E4E)
              : const Color(0xFFB97F42),
      );
    }
    // Shot spots.
    for (var i = 0; i < level.spots.length; i++) {
      final s = level.spots[i];
      canvas.drawCircle(
        Offset(s.dx, 602),
        i == _spotIndex % level.spots.length ? 6 : 3,
        Paint()..color = const Color(0x99FFFFFF),
      );
    }
    final h = hoopPos;
    final rim = _rimHalf;
    // Pole + board.
    canvas.drawRect(
      Rect.fromLTWH(h.dx + rim + 14, h.dy - 20, 8, 640),
      Paint()..color = const Color(0xFF90A4AE),
    );
    drawBox(
      canvas,
      Rect.fromCenter(
        center: h.translate(rim + 10, -38),
        width: 10,
        height: 96,
      ),
      Colors.white,
      radius: 2,
    );
    // Net.
    final net = Paint()
      ..color = Colors.white70
      ..strokeWidth = 1.5;
    for (var i = 0; i <= 6; i++) {
      final x = h.dx - rim + i * rim / 3;
      canvas.drawLine(
        Offset(x, h.dy),
        Offset(h.dx - rim * 0.6 + i * rim * 0.2, h.dy + 44),
        net,
      );
    }
    // Ball (behind the rim front).
    final ball = _ball;
    if (ball != null) {
      final p = ball.px;
      drawBall(canvas, p, ballRadius, const Color(0xFFF57C00));
      final seam = Paint()
        ..color = const Color(0xFF4E2600)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;
      canvas
        ..save()
        ..translate(p.dx, p.dy)
        ..rotate(ball.angle)
        ..drawLine(
          const Offset(-ballRadius, 0),
          const Offset(ballRadius, 0),
          seam,
        )
        ..drawArc(
          Rect.fromCircle(center: Offset.zero, radius: ballRadius * 0.8),
          -math.pi / 2,
          math.pi,
          false,
          seam,
        )
        ..restore();
    }
    // Rim.
    canvas.drawLine(
      h.translate(-rim, 0),
      h.translate(rim, 0),
      Paint()
        ..color = const Color(0xFFFF5722)
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round,
    );
    // Swipe trail.
    if (_pointer != null && _samples.length > 1) {
      final path = Path()..moveTo(_samples.first.$2.dx, _samples.first.$2.dy);
      for (final s in _samples.skip(1)) {
        path.lineTo(s.$2.dx, s.$2.dy);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0x88FFD23F)
          ..strokeWidth = 6
          ..style = PaintingStyle.stroke,
      );
    }
    if (streak >= 3) {
      drawText(
        canvas,
        '🔥 ×2',
        const Offset(16, 100),
        size: 20,
        display: true,
        color: const Color(0xFFFFD23F),
      );
    }
    if (moneyball) {
      drawText(
        canvas,
        'MONEYBALL',
        const Offset(180, 100),
        size: 16,
        display: true,
        align: TextAlign.center,
        color: const Color(0xFFFFD23F),
      );
      if (level.wind != Offset.zero) {
        drawWind(canvas, const Offset(60, 160), level.wind, max: 90);
      }
    }
  }
}
