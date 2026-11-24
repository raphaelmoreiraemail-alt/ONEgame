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
import '../common/render3d.dart';

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

  // ---------------------------------------------------------------- 3D

  /// The simulation is a vertical plane (x, y down): drawn as the plane
  /// z = 0 of a 3D gym, floor at y = 600.
  static V3 _p(Offset o, [double z = 0]) => V3(o.dx, 600 - o.dy, z);

  static final Camera3D _camera = Camera3D(
    eye: const V3(165, 270, 660),
    target: const V3(180, 235, 0),
    fovDegrees: 56,
    center: const Offset(180, 330),
  );

  @override
  Camera3D get camera3d => _camera;

  @override
  Offset? touchToWorld(Offset screen) {
    final p = _camera.unprojectToPlaneZ(screen);
    return p == null ? null : Offset(p.x, 600 - p.y);
  }

  @override
  void render(Canvas canvas) {
    drawSky(
      canvas,
      Arena.rect,
      const Color(0xFF1C2833),
      const Color(0xFF34495E),
    );
    final s = Scene3D(
      _camera,
      fogColor: const Color(0xFF2C3E50),
      fogStart: 800,
      fogEnd: 1900,
      ambient: 0.55,
    );
    // Parquet, key paint, back wall with banners.
    s.ground(
      const Rect.fromLTRB(-260, -260, 620, 760),
      (i, j) => tint(
        i.isEven ? const Color(0xFFC68E4E) : const Color(0xFFB97F42),
        (cellNoise(i, j, 4) - 0.5) * 0.08,
      ),
      cell: 26,
    );
    s.ground(
      const Rect.fromLTRB(212, -70, 340, 120),
      (i, j) => const Color(0xFFB03A2E),
      cell: 64,
      height: 0.3,
      layer: Layer.surface,
    );
    for (var i = 0; i < level.spots.length; i++) {
      final sp = level.spots[i];
      s.shadow(
        Offset(sp.dx, 0),
        i == _spotIndex % level.spots.length ? 7 : 4,
        opacity: 0.8,
        height: 0.5,
      );
    }
    s.box(const V3(180, -1, -250), 900, 420, 10, const Color(0xFF2E4053));
    final h = hoopPos;
    final rim = _rimHalf;
    final hoop = _p(h);
    // Pole, arm, backboard with its red square.
    s
      ..cylinder(
        V3(hoop.x + rim + 30, 0, -40),
        6,
        hoop.y + 30,
        const Color(0xFF90A4AE),
        segments: 8,
      )
      ..box(
        V3(hoop.x + rim + 20, hoop.y + 20, -20),
        30,
        6,
        44,
        const Color(0xFF90A4AE),
      )
      ..box(
        V3(hoop.x + rim + 10, hoop.y - 10, 0),
        4,
        76,
        92,
        const Color(0xFFF5F5F5),
      )
      ..box(
        V3(hoop.x + rim + 7.5, hoop.y + 4, 0),
        1,
        26,
        32,
        const Color(0xFFE8322F),
      );
    // Net (translucent strings) then the orange rim ring.
    const segs = 16;
    for (var k = 0; k < segs; k++) {
      final a0 = k / segs * 2 * math.pi, a1 = (k + 1) / segs * 2 * math.pi;
      V3 top(double a) =>
          V3(hoop.x + math.cos(a) * rim, hoop.y, math.sin(a) * rim);
      V3 bot(double a) => V3(
        hoop.x + math.cos(a) * rim * 0.6,
        hoop.y - 40,
        math.sin(a) * rim * 0.6,
      );
      s.quad(
        top(a0),
        top(a0 + 0.06),
        bot(a1 + 0.06),
        bot(a1),
        const Color(0x99FFFFFF),
        doubleSided: true,
        lit: false,
      );
      final p0 = top(a0), p1 = top(a1);
      s.quad(
        p0,
        p1,
        p1 + const V3(0, 3, 0),
        p0 + const V3(0, 3, 0),
        const Color(0xFFFF5722),
        doubleSided: true,
      );
    }
    // Ball with seams, held by the shooter until the throw.
    final ball = _ball;
    if (ball != null) {
      final c = _p(ball.px);
      if (!_inFlight) {
        final scale = ((c.y - 8) / 46).clamp(0.9, 3.0);
        s
          ..figure(
            V3(c.x - 4, 0, 10),
            const Color(0xFFE8322F),
            arms: 1,
            scale: scale,
            shorts: const Color(0xFFE8322F),
          )
          ..shadow(Offset(c.x - 4, 10), 10 * scale);
      }
      s
        ..shadow(
          Offset(c.x, 0),
          ballRadius * (1 + c.y / 300),
          opacity: 0.35 / (1 + c.y / 200),
        )
        ..sphere(
          c,
          ballRadius,
          const Color(0xFFF57C00),
          lat: 8,
          lon: 14,
          stripe: const Color(0xFF3E1F00),
        );
    }
    s.render(canvas);
    // Swipe trail (screen space).
    if (_pointer != null && _samples.length > 1) {
      final pts = [for (final (_, w) in _samples) _camera.project(_p(w))]
          .whereType<Offset>()
          .toList();
      if (pts.length > 1) {
        final path = Path()..moveTo(pts.first.dx, pts.first.dy);
        for (final q in pts.skip(1)) {
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
