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
  Map<String, String> highlightLabels(AppLocalizations l10n) => {
    'ace': l10n.highlightAce,
  };

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

  // ---------------------------------------------------------------- 3D

  /// Elevated camera behind the tee, looking down the course.
  static final Camera3D _camera = Camera3D(
    eye: const V3(180, 520, 930),
    target: const V3(180, 0, 330),
    fovDegrees: 46,
    center: const Offset(180, 330),
  );

  @override
  Camera3D get camera3d => _camera;

  static const _grassA = Color(0xFF4CAF50);
  static const _grassB = Color(0xFF43A047);
  static const _wood = Color(0xFF8D6E63);
  static const _woodTop = Color(0xFFBCAAA4);

  @override
  void render(Canvas canvas) {
    drawSky(
      canvas,
      Arena.rect,
      const Color(0xFF7EC8F2),
      const Color(0xFFD7F0FF),
    );
    final scene = Scene3D(
      _camera,
      fogColor: const Color(0xFFD7F0FF),
      fogStart: 1100,
      fogEnd: 2600,
    );
    final h = holeIndex < holes.length ? hole : holes.last;
    const b = Course.bounds;
    // Surrounding lawn, then the striped putting green.
    scene.ground(
      const Rect.fromLTRB(-400, -900, 760, 1000),
      (i, j) => tint(const Color(0xFF2E7D32), (cellNoise(i, j) - 0.5) * 0.04),
      cell: 80,
      height: -2,
    );
    scene.ground(
      b,
      (i, j) =>
          tint(j.isEven ? _grassA : _grassB, (cellNoise(i, j, 3) - 0.5) * 0.08),
      cell: 20,
      layer: Layer.surface,
    );
    _scenery(scene);
    for (final o in h.obstacles) {
      _zone3d(scene, o);
    }
    // Cup: dark hole + white rim, flag on its pole.
    scene
      ..cylinder(
        V3.ground(h.cup, -6),
        Course.cupRadius + 1.5,
        6.4,
        const Color(0xFFF4ECE4),
        top: const Color(0xFF111111),
      )
      ..cylinder(
        V3.ground(h.cup, -6),
        Course.cupRadius - 0.5,
        6.5,
        const Color(0xFF111111),
      )
      ..cylinder(
        V3.ground(h.cup),
        1.4,
        70,
        const Color(0xFFF4ECE4),
        segments: 6,
      );
    final flapping = 4 * math.sin(elapsed * 5);
    scene
      ..tri(
        V3.ground(h.cup, 70),
        V3(h.cup.dx + 30, 62 + flapping, h.cup.dy),
        V3.ground(h.cup, 54),
        const Color(0xFFE8322F),
        doubleSided: true,
      )
      ..shadow(h.cup.translate(12, 6), 10, opacity: 0.2, stretch: 2.2);
    // Tee mat.
    scene.box(V3.ground(h.tee, 0), 36, 1.5, 22, const Color(0xFF1B5E20));
    // Border: wooden rails.
    const t = 8.0, rail = 14.0;
    scene
      ..box(
        V3(b.center.dx, 0, b.top - t / 2),
        b.width + 2 * t,
        rail,
        t,
        _wood,
        top: _woodTop,
      )
      ..box(
        V3(b.center.dx, 0, b.bottom + t / 2),
        b.width + 2 * t,
        rail,
        t,
        _wood,
        top: _woodTop,
      )
      ..box(
        V3(b.left - t / 2, 0, b.center.dy),
        t,
        rail,
        b.height,
        _wood,
        top: _woodTop,
      )
      ..box(
        V3(b.right + t / 2, 0, b.center.dy),
        t,
        rail,
        b.height,
        _wood,
        top: _woodTop,
      );
    for (final o in h.obstacles) {
      _solid3d(scene, o);
    }
    if (_world != null) {
      final ball = _ball.px;
      final pull = _pull;
      if (pull != null && pull.distance > 4) {
        final power = math.min(pull.distance / 140, 1.0);
        final dir = pull / pull.distance;
        // Short dotted guide on the grass (40 px, section 7.1).
        for (var d = 10.0; d < 50; d += 10) {
          scene.shadow(ball + dir * d, 2.2, height: 0.6, opacity: 0.9);
        }
        final ring = Color.lerp(
          const Color(0xFFFFD23F),
          const Color(0xFFE8322F),
          power,
        )!;
        for (var i = 0; i < 24; i++) {
          final a0 = i / 24 * 2 * math.pi, a1 = (i + 0.6) / 24 * 2 * math.pi;
          final r = 14 + power * 18;
          scene.quad(
            V3(ball.dx + math.cos(a0) * r, 0.8, ball.dy + math.sin(a0) * r),
            V3(ball.dx + math.cos(a1) * r, 0.8, ball.dy + math.sin(a1) * r),
            V3(
              ball.dx + math.cos(a1) * (r + 3),
              0.8,
              ball.dy + math.sin(a1) * (r + 3),
            ),
            V3(
              ball.dx + math.cos(a0) * (r + 3),
              0.8,
              ball.dy + math.sin(a0) * (r + 3),
            ),
            ring,
            lit: false,
            doubleSided: true,
          );
        }
      }
      scene
        ..shadow(ball.translate(4, 3), Course.ballRadius * 1.1, stretch: 1.4)
        ..sphere(
          V3.ground(ball, Course.ballRadius),
          Course.ballRadius,
          Colors.white,
          lat: 7,
          lon: 12,
        );
    }
    scene.render(canvas);
    // Specular glint on the ball.
    if (_world != null) {
      final p = _camera.project(V3.ground(_ball.px, Course.ballRadius * 1.6));
      if (p != null) {
        canvas.drawCircle(
          p.translate(-1.5, 0),
          1.6,
          Paint()..color = Colors.white,
        );
      }
    }
    if (wind != Offset.zero) drawWind(canvas, const Offset(312, 600), wind);
    drawText(
      canvas,
      '⛳ ${math.min(holeIndex + 1, holes.length)}/${holes.length} · PAR ${h.par} · '
      '${_state == _State.transition || _state == _State.done ? holeStrokes.last : strokes}',
      const Offset(180, 104),
      size: 15,
      align: TextAlign.center,
      color: const Color(0xFF0D3B12),
    );
  }

  /// Trees and bushes around the course (fixed, purely decorative).
  static final List<(Offset, double, int)> _trees = () {
    final out = <(Offset, double, int)>[];
    for (var i = 0; i < 26; i++) {
      final side = i.isEven ? -1 : 1;
      final x = side < 0
          ? -40 - cellNoise(i, 1) * 260
          : 400 + cellNoise(i, 1) * 260;
      final z = -700 + i * 60 + cellNoise(i, 2) * 40;
      out.add((Offset(x, z), 0.7 + cellNoise(i, 3) * 0.6, i % 3));
    }
    for (var i = 0; i < 9; i++) {
      out.add((
        Offset(
          -200 + i * 95.0 + cellNoise(i, 4) * 30,
          -120 - cellNoise(i, 5) * 500,
        ),
        0.8 + cellNoise(i, 6) * 0.7,
        i % 3,
      ));
    }
    return out;
  }();

  void _scenery(Scene3D s) {
    for (final (p, k, kind) in _trees) {
      if (kind == 2) {
        s.sphere(
          V3.ground(p, 14 * k),
          22 * k,
          const Color(0xFF388E3C),
          lat: 5,
          lon: 8,
        );
        continue;
      }
      s
        ..cylinder(
          V3.ground(p),
          6 * k,
          40 * k,
          const Color(0xFF6D4C41),
          segments: 6,
        )
        ..sphere(
          V3.ground(p, 62 * k),
          34 * k,
          kind == 0 ? const Color(0xFF2E7D32) : const Color(0xFF558B2F),
          lat: 5,
          lon: 8,
        );
    }
  }

  void _zone3d(Scene3D s, Obstacle o) {
    switch (o.kind) {
      case ObstacleKind.sand:
        s.ground(
          o.rect.deflate(2),
          (i, j) =>
              tint(const Color(0xFFE6CF8B), (cellNoise(i, j, 7) - 0.5) * 0.15),
          cell: 12,
          height: 0.4,
          layer: Layer.decal,
        );
      case ObstacleKind.water:
        final w = math.sin(elapsed * 2);
        s.ground(
          o.rect,
          (i, j) => tint(
            const Color(0xFF1E88E5),
            0.15 * math.sin(i * 0.9 + j * 0.7 + elapsed * 3) + w * 0.03,
          ),
          cell: 14,
          height: 0.5,
          layer: Layer.decal,
        );
      case ObstacleKind.slope:
        s.ground(
          o.rect,
          (i, j) => const Color(0x2200332A),
          cell: 40,
          height: 0.3,
          layer: Layer.decal,
        );
        final dir = o.vector / o.vector.distance;
        final n = Offset(-dir.dy, dir.dx);
        final phase = (elapsed * 30) % 40;
        for (var x = o.rect.left + 30; x < o.rect.right; x += 60) {
          for (var y = o.rect.top + 20; y < o.rect.bottom; y += 40) {
            final at = Offset(x, y) + dir * (phase - 20);
            s.tri(
              V3.ground(at + dir * 8, 0.7),
              V3.ground(at - n * 6, 0.7),
              V3.ground(at + n * 6, 0.7),
              const Color(0x88FFFFFF),
              lit: false,
              doubleSided: true,
              layer: Layer.decal,
            );
          }
        }
      case ObstacleKind.portal:
        for (final p in [o.rect.center, o.vector]) {
          s
            ..cylinder(
              V3.ground(p, -2),
              14,
              2.6,
              const Color(0xFF4A148C),
              top: const Color(0xFF7B1FA2),
            )
            ..cylinder(
              V3.ground(p, 0),
              9 + 2 * math.sin(elapsed * 8),
              1,
              const Color(0xFFB388FF),
            );
        }
      default:
        break;
    }
  }

  void _solid3d(Scene3D s, Obstacle o) {
    switch (o.kind) {
      case ObstacleKind.wall:
        s.box(
          V3.ground(o.rect.center),
          o.rect.width,
          14,
          o.rect.height,
          _wood,
          yaw: o.angle,
          top: _woodTop,
        );
      case ObstacleKind.bumper:
        final r = o.rect.width / 2;
        s
          ..shadow(o.rect.center.translate(5, 4), r * 1.1)
          ..cylinder(
            V3.ground(o.rect.center),
            r,
            16,
            const Color(0xFFE8322F),
            top: const Color(0xFFFFD23F),
          );
      case ObstacleKind.windmill || ObstacleKind.mover:
        final body = _dynamicObstacles
            .where((e) => identical(e.$1, o))
            .map((e) => e.$2)
            .firstOrNull;
        if (body == null || _world == null) return;
        final at = body.px;
        if (o.kind == ObstacleKind.mover) {
          s
            ..shadow(at.translate(6, 5), o.rect.width / 2, stretch: 0.3)
            ..box(
              V3.ground(at),
              o.rect.width,
              12,
              o.rect.height,
              const Color(0xFFFF7043),
              top: const Color(0xFFFFAB91),
            );
        } else {
          final r = o.rect.width / 2;
          s
            ..cylinder(
              V3.ground(at),
              10,
              18,
              const Color(0xFFE8322F),
              top: const Color(0xFFB71C1C),
            )
            ..box(
              V3.ground(at, 4),
              r * 2,
              8,
              10,
              const Color(0xFFF4ECE4),
              yaw: body.angle,
            )
            ..box(
              V3.ground(at, 4),
              10,
              8,
              r * 2,
              const Color(0xFFF4ECE4),
              yaw: body.angle,
            );
        }
      default:
        break;
    }
  }
}
