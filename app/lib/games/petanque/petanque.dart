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

/// 7.6 Pétanque — 3 ends against an AI, 3 boules each.
class PetanqueGame extends MiniGameDefinition {
  const PetanqueGame();

  @override
  String get id => 'petanque';
  @override
  String get emoji => '🔵';
  @override
  GameCategory get category => GameCategory.sport;
  @override
  int get rulesVersion => 1;
  @override
  Set<String> get supportedModifiers => {Modifiers.wind};
  @override
  ScoreBounds get scoreBounds =>
      const ScoreBounds(0, 3 * 300 + 3 * 100 + 9 * 500);

  @override
  Map<String, num> get defaultTuning => const {
    'damping': 2.2,
    'maxThrow': 520,
    'aiSkill': 18,
  };

  @override
  String name(AppLocalizations l10n) => l10n.gamePetanqueName;
  @override
  String rule(AppLocalizations l10n) => l10n.gamePetanqueRule;

  @override
  String shareLine(AppLocalizations l10n, Map<String, num> s) {
    final me = s['me']?.toInt() ?? 0, ai = s['ai']?.toInt() ?? 0;
    final base = me > ai
        ? l10n.gamePetanqueShareWin(me, ai)
        : (me == ai
              ? l10n.gamePetanqueShareDraw(me, ai)
              : l10n.gamePetanqueShareLoss(me, ai));
    final c = s['carreaux']?.toInt() ?? 0;
    return c > 0 ? '$base · ${l10n.gamePetanqueShareCarreau(c)}' : base;
  }

  @override
  List<(String, String)> statRows(AppLocalizations l10n, Map<String, num> s) =>
      [
        (l10n.statMatch, '${s['me'] ?? 0} – ${s['ai'] ?? 0}'),
        (l10n.statEnds, '${s['ends'] ?? 0} / 3'),
        (l10n.statCarreaux, '${s['carreaux'] ?? 0}'),
      ];

  @override
  Map<String, String> highlightLabels(AppLocalizations l10n) => {
    'carreau': l10n.highlightCarreau,
  };

  @override
  GameSim createSim(GameContext ctx) => PetanqueSim(ctx, this);

  @override
  String levelFingerprint(int seed, String? modifierId) {
    final t = PetanqueTerrain.generate(
      GameContext(seed: seed, modifierId: modifierId),
    );
    return fingerprint([
      for (final j in t.jacks) ...[j.dx, j.dy],
      for (final b in t.bumps) ...[b.dx, b.dy],
      t.wind.dx,
      for (final a in t.aiTargets) ...[a.dx, a.dy],
    ]);
  }
}

class PetanqueTerrain {
  const PetanqueTerrain(
    this.jacks,
    this.bumps,
    this.wind,
    this.aiTargets,
    this.aiShootChance,
  );

  /// Cochonnet position for each end.
  final List<Offset> jacks;

  /// Small mounds: boules roll away from their center.
  final List<Offset> bumps;
  final Offset wind;

  /// AI aiming error (offset from the target) for each of its 9 boules.
  final List<Offset> aiTargets;
  final List<bool> aiShootChance;

  static PetanqueTerrain generate(GameContext ctx, [double skill = 18]) {
    final r = SeededRandom.derive(ctx.seed, 'petanque:terrain');
    final a = SeededRandom.derive(ctx.seed, 'petanque:ai');
    final w = SeededRandom.derive(ctx.seed, 'petanque:wind');
    return PetanqueTerrain(
      [
        for (var i = 0; i < 3; i++)
          Offset(r.doubleInRange(110, 250), r.doubleInRange(170, 280)),
      ],
      [
        for (var i = 0; i < 4; i++)
          Offset(r.doubleInRange(60, 300), r.doubleInRange(150, 480)),
      ],
      ctx.has(Modifiers.wind)
          ? Offset(w.doubleInRange(-30, 30), w.doubleInRange(-10, 10))
          : Offset.zero,
      [
        for (var i = 0; i < 9; i++)
          Offset(a.doubleInRange(-1, 1), a.doubleInRange(-1, 1)) * skill,
      ],
      [for (var i = 0; i < 9; i++) a.chance(0.4)],
    );
  }
}

class _Boule {
  _Boule(this.body, this.mine);

  final Body body;
  final bool mine;
  bool dead = false;
}

enum _Phase { aim, power, flying, rolling, endOfEnd, done }

class PetanqueSim extends GameSim {
  PetanqueSim(super.ctx, PetanqueGame def)
    : _damping = ctx.tune('damping', def.defaultTuning['damping']!),
      _maxThrow = ctx.tune('maxThrow', def.defaultTuning['maxThrow']!),
      terrain = PetanqueTerrain.generate(
        ctx,
        ctx.tune('aiSkill', def.defaultTuning['aiSkill']!),
      ) {
    _startEnd();
  }

  static const Offset circle = Offset(180, 585);
  static const double bouleR = 9;
  static const double jackR = 4.5;
  static const Rect field = Rect.fromLTRB(16, 96, 344, 620);

  final double _damping;
  final double _maxThrow;
  final PetanqueTerrain terrain;

  World? _world;
  Body? _jack;
  final List<_Boule> _boules = [];
  int end = 0;
  int myLeft = 3, aiLeft = 3;
  int myPoints = 0, aiPoints = 0;
  int carreaux = 0;
  int proximityBonus = 0;
  int _aiThrown = 0;
  bool _myTurn = true;
  _Phase _phase = _Phase.aim;
  int _phaseSteps = 0;
  final List<(int, int)> endResults = []; // (my points, ai points)

  // Throw state.
  double _angle = 0;
  bool _shoot = false;
  double _power = 0;
  int? _pointer;
  Offset _downAt = Offset.zero;
  int _downStep = 0;
  bool _dragging = false;
  Offset _flyFrom = Offset.zero, _flyTo = Offset.zero;
  int _flySteps = 0, _flyTotal = 1;
  double _landSpeed = 0;
  _Boule? _target; // for carreau detection
  Offset _targetFrom = Offset.zero;

  @override
  Color get backgroundColor => const Color(0xFF8D6E63);

  @override
  int get debugBodyCount => _boules.length + 1;

  @override
  Offset get focus => _jack?.px ?? Arena.center;

  void _startEnd() {
    _world?.destroy();
    final w = _world = Phys.world();
    _boules.clear();
    _jack = Phys.ball(
      w,
      terrain.jacks[end],
      jackR,
      density: 0.4,
      restitution: 0.5,
      linearDamping: _damping,
    );
    myLeft = 3;
    aiLeft = 3;
    // The AI opens even ends, the player odd ones.
    _myTurn = end.isOdd;
    _phase = _Phase.aim;
    _phaseSteps = 0;
    if (!_myTurn) _aiThrow();
  }

  double _dist(Body b) => (b.px - _jack!.px).distance;

  /// Closest live boule: (isMine, distance), or null.
  (bool, double)? _closest() {
    _Boule? best;
    for (final b in _boules) {
      if (b.dead) continue;
      if (best == null || _dist(b.body) < _dist(best.body)) best = b;
    }
    return best == null ? null : (best.mine, _dist(best.body));
  }

  void _nextTurn() {
    if (myLeft == 0 && aiLeft == 0) {
      _phase = _Phase.endOfEnd;
      _phaseSteps = 0;
      _scoreEnd();
      return;
    }
    final c = _closest();
    // The side that does not hold the point plays.
    bool mine;
    if (myLeft == 0) {
      mine = false;
    } else if (aiLeft == 0) {
      mine = true;
    } else {
      mine = c == null ? true : !c.$1;
    }
    _myTurn = mine;
    _phase = _Phase.aim;
    _phaseSteps = 0;
    _shoot = false;
    _angle = 0;
    if (!mine) _aiThrow();
  }

  void _aiThrow() {
    final i = math.min(_aiThrown++, 8);
    final c = _closest();
    final shoot = c != null && c.$1 && aiLeft >= 2 && terrain.aiShootChance[i];
    Offset target = _jack!.px;
    if (shoot) {
      final mine = _boules.where((b) => b.mine && !b.dead).toList()
        ..sort((a, b) => _dist(a.body).compareTo(_dist(b.body)));
      target = mine.first.body.px;
    }
    target += terrain.aiTargets[i];
    final d = target - circle;
    _angle = math.atan2(d.dx, -d.dy);
    _shoot = shoot;
    _power = (d.distance / (_shoot ? 0.92 : 1) / _maxThrow).clamp(0.05, 1.0);
    _launch(mine: false);
  }

  @override
  void onPointer(PointerPhase phase, int pointer, Offset pos) {
    if (!_myTurn || (_phase != _Phase.aim && _phase != _Phase.power)) return;
    switch (phase) {
      case PointerPhase.down:
        if (_pointer != null) return;
        _pointer = pointer;
        _downAt = pos;
        _downStep = step;
        _dragging = false;
      case PointerPhase.move:
        if (pointer != _pointer) return;
        final d = pos - _downAt;
        if (_phase == _Phase.aim && (d.distance > 14 || _dragging)) {
          // Drag: horizontal = aim, up = "tirer", down = "pointer".
          _dragging = true;
          _angle = (d.dx / 300).clamp(-0.45, 0.45);
          if (d.dy < -30) _shoot = true;
          if (d.dy > 30) _shoot = false;
        }
      case PointerPhase.up:
        if (pointer != _pointer) return;
        _pointer = null;
        if (_phase == _Phase.power) {
          _launch(mine: true);
        }
    }
  }

  double get _gauge {
    // Oscillates 0 → 1 → 0 with a 1.4 s period.
    final t = ((step - _downStep - 18) / stepsPerSecond / 0.7) % 2;
    return t < 1 ? t : 2 - t;
  }

  void _launch({required bool mine}) {
    if (mine) {
      _power = _gauge.clamp(0.03, 1.0);
      myLeft--;
    } else {
      aiLeft--;
    }
    final dir = Offset(math.sin(_angle), -math.cos(_angle));
    final dist = _power * _maxThrow;
    final flyFraction = _shoot ? 0.92 : 0.4;
    final throwIndex = 6 * end + (3 - myLeft) + (3 - aiLeft);
    final g = SeededRandom.derive(ctx.seed, 'petanque:gravel$throwIndex');
    _flyFrom = circle;
    _flyTo =
        circle +
        dir * dist * flyFraction +
        Offset(g.doubleInRange(-1, 1), g.doubleInRange(-1, 1)) * 8 +
        terrain.wind * (0.6 + _power);
    _flyTotal = ((0.45 + _power * 0.5) * stepsPerSecond).round();
    _flySteps = 0;
    _landSpeed = _shoot ? 420 : dist * (1 - flyFraction) * _damping;
    _phase = _Phase.flying;
    _target = null;
    _flyingIsMine = mine;
    cue(sfx: Sfx.whoosh, haptic: Haptic.light);
  }

  /// Owner of the boule in the air.
  bool _flyingIsMine = true;

  @override
  void tick() {
    tickParticles();
    _phaseSteps++;
    final w = _world;
    if (w == null) return;
    switch (_phase) {
      case _Phase.aim:
        if (_pointer != null && !_dragging && step - _downStep > 18) {
          _phase = _Phase.power;
        }
      case _Phase.power:
      case _Phase.done:
        break;
      case _Phase.flying:
        if (++_flySteps >= _flyTotal) _land();
      case _Phase.rolling:
        _applyBumps();
        final moving =
            _boules.any((b) => !b.dead && b.body.velPx.distance > 4) ||
            _jack!.velPx.distance > 4;
        for (final b in _boules) {
          if (!b.dead && !field.contains(b.body.px)) {
            b.dead = true;
            b.body.isEnabled = false;
          }
        }
        if ((!moving && _phaseSteps > 30) || _phaseSteps > 6 * stepsPerSecond) {
          _checkCarreau();
          _nextTurn();
        }
      case _Phase.endOfEnd:
        if (_phaseSteps > (1.6 * stepsPerSecond).round()) {
          end++;
          if (end >= 3) {
            _phase = _Phase.done;
            over = true;
            _world?.destroy();
            _world = null;
          } else {
            _startEnd();
          }
        }
        return;
    }
    Phys.step(w);
    for (final _ in w.contactEvents.hit) {
      cue(sfx: Sfx.hit, haptic: Haptic.light);
    }
  }

  void _applyBumps() {
    for (final b in [
      ..._boules.where((b) => !b.dead).map((b) => b.body),
      _jack!,
    ]) {
      for (final c in terrain.bumps) {
        final d = b.px - c;
        if (d.distance < 30 && d.distance > 0.1 && b.velPx.distance > 2) {
          b.applyForce(Phys.v(d / d.distance * 160) * b.mass);
        }
      }
    }
  }

  void _land() {
    final mine = _flyingIsMine;
    final body = Phys.ball(
      _world!,
      _flyTo,
      bouleR,
      density: 2,
      restitution: 0.85,
      friction: 0.3,
      linearDamping: _damping,
    )..angularDamping = 4;
    final dir = Offset(math.sin(_angle), -math.cos(_angle));
    body.velPx = dir * _landSpeed;
    if (_shoot) {
      // Remember the opponent boule closest to the landing point.
      _Boule? hit;
      for (final b in _boules) {
        if (b.dead || b.mine == mine) continue;
        if ((b.body.px - _flyTo).distance < 40 &&
            (hit == null ||
                (b.body.px - _flyTo).distance <
                    (hit.body.px - _flyTo).distance)) {
          hit = b;
        }
      }
      _target = hit;
      _targetFrom = hit?.body.px ?? Offset.zero;
    }
    _boules.add(_Boule(body, mine));
    particles.burst(_flyTo, const Color(0xFFD7CCC8), count: 10, speed: 80);
    cue(sfx: Sfx.hit);
    _phase = _Phase.rolling;
    _phaseSteps = 0;
  }

  void _checkCarreau() {
    final t = _target;
    if (t == null || _boules.isEmpty) return;
    final shooter = _boules.last;
    final moved = (t.body.px - _targetFrom).distance > 30 || t.dead;
    if (moved &&
        (shooter.body.px - _targetFrom).distance < 16 &&
        shooter.mine) {
      carreaux++;
      score += 500;
      celebrate('carreau');
      particles.fireworks(shooter.body.px);
    }
    _target = null;
  }

  void _scoreEnd() {
    final live = _boules.where((b) => !b.dead).toList()
      ..sort((a, b) => _dist(a.body).compareTo(_dist(b.body)));
    var me = 0, ai = 0;
    if (live.isNotEmpty) {
      final winner = live.first.mine;
      final otherBest = live
          .where((b) => b.mine != winner)
          .map((b) => _dist(b.body))
          .fold(double.infinity, math.min);
      final pts = live
          .where((b) => b.mine == winner && _dist(b.body) < otherBest)
          .length;
      if (winner) {
        me = pts;
      } else {
        ai = pts;
      }
    }
    final myBest = live
        .where((b) => b.mine)
        .map((b) => _dist(b.body))
        .fold(double.infinity, math.min);
    if (myBest.isFinite) proximityBonus += math.max(0, 100 - myBest.round());
    myPoints += me;
    aiPoints += ai;
    endResults.add((me, ai));
    score = myPoints * 100 + proximityBonus + carreaux * 500;
    cue(sfx: me > 0 ? Sfx.score : Sfx.miss, haptic: Haptic.medium);
  }

  @override
  void onTimeUp() {
    if (_phase != _Phase.endOfEnd && _phase != _Phase.done && _world != null) {
      _scoreEnd();
    }
  }

  @override
  void dispose() => _world?.destroy();

  @override
  Map<String, num> get stats => {
    'me': myPoints,
    'ai': aiPoints,
    'ends': endResults.length,
    'carreaux': carreaux,
  };

  // ---------------------------------------------------------------- 3D

  static final Camera3D _camera = Camera3D(
    eye: const V3(180, 220, 840),
    target: const V3(180, 0, 300),
    fovDegrees: 46,
    center: const Offset(180, 300),
  );

  @override
  Camera3D get camera3d => _camera;

  void _boule3d(Scene3D s, V3 c, bool mine) {
    s
      ..shadow(
        c.flat.translate(3, 3),
        bouleR * (1 + c.y / 60),
        opacity: 0.35 / (1 + c.y / 80),
      )
      ..sphere(
        c,
        bouleR,
        mine ? const Color(0xFFB0BEC5) : const Color(0xFFA1887F),
        lat: 7,
        lon: 12,
        stripe: mine ? const Color(0xFFE8322F) : const Color(0xFF4E342E),
      );
  }

  @override
  void render(Canvas canvas) {
    drawSky(
      canvas,
      Arena.rect,
      const Color(0xFF81D4FA),
      const Color(0xFFFFF3E0),
    );
    final s = Scene3D(
      _camera,
      fogColor: const Color(0xFFFFF3E0),
      fogStart: 800,
      fogEnd: 1900,
    );
    s.ground(
      const Rect.fromLTRB(-500, -500, 860, 1100),
      (i, j) => tint(const Color(0xFF8BC34A), (cellNoise(i, j) - 0.5) * 0.06),
      cell: 90,
      height: -1,
    );
    s.ground(
      field,
      (i, j) =>
          tint(const Color(0xFFD7B98E), (cellNoise(i, j, 12) - 0.5) * 0.07),
      cell: 16,
      layer: Layer.surface,
    );
    for (final b in terrain.bumps) {
      s.shadow(b, 30, height: 0.4, opacity: 0.15);
    }
    // Wooden boards around the terrain, plane trees at the back.
    const board = Color(0xFF8D6E63);
    s
      ..box(
        V3(field.center.dx, 0, field.top - 4),
        field.width + 8,
        10,
        8,
        board,
      )
      ..box(V3(field.left - 4, 0, field.center.dy), 8, 10, field.height, board)
      ..box(
        V3(field.right + 4, 0, field.center.dy),
        8,
        10,
        field.height,
        board,
      );
    for (var i = 0; i < 7; i++) {
      final x = -120.0 + i * 100;
      s
        ..cylinder(V3(x, 0, -60), 9, 70, const Color(0xFF8D6E63), segments: 6)
        ..sphere(V3(x, 110, -60), 55, const Color(0xFF558B2F), lat: 5, lon: 8);
    }
    // Throwing circle.
    for (var k = 0; k < 24; k++) {
      final a0 = k / 24 * 2 * math.pi, a1 = (k + 1) / 24 * 2 * math.pi;
      s.quad(
        V3.ground(circle + Offset(math.cos(a0), math.sin(a0)) * 22, 0.5),
        V3.ground(circle + Offset(math.cos(a1), math.sin(a1)) * 22, 0.5),
        V3.ground(circle + Offset(math.cos(a1), math.sin(a1)) * 25, 0.5),
        V3.ground(circle + Offset(math.cos(a0), math.sin(a0)) * 25, 0.5),
        Colors.white,
        doubleSided: true,
        layer: Layer.decal,
      );
    }
    final jack = _jack;
    if (jack != null) {
      s
        ..shadow(jack.px.translate(2, 2), jackR)
        ..sphere(
          V3.ground(jack.px, jackR),
          jackR,
          const Color(0xFFFFB300),
          lat: 5,
          lon: 8,
        );
    }
    for (final b in _boules) {
      if (b.dead) continue;
      _boule3d(s, V3.ground(b.body.px, bouleR), b.mine);
    }
    if (_phase == _Phase.flying) {
      final t = _flySteps / _flyTotal;
      final p = Offset.lerp(_flyFrom, _flyTo, t)!;
      _boule3d(
        s,
        V3.ground(p, bouleR + math.sin(math.pi * t) * (_shoot ? 110 : 70)),
        _flyingIsMine,
      );
    }
    final aiming = _myTurn && (_phase == _Phase.aim || _phase == _Phase.power);
    if (aiming) {
      final dir = Offset(math.sin(_angle), -math.cos(_angle));
      for (var d = 30.0; d < 150; d += 12) {
        s.shadow(circle + dir * d, 2, height: 0.6, opacity: 0.8);
      }
      _boule3d(s, V3.ground(circle, bouleR), true);
    }
    s.render(canvas);
    if (aiming) {
      drawText(
        canvas,
        _shoot ? '🎯 TIRER' : '🎳 POINTER',
        const Offset(180, 530),
        size: 14,
        display: true,
        align: TextAlign.center,
        color: _shoot ? const Color(0xFFE8322F) : Colors.white,
      );
      if (_phase == _Phase.power) {
        final g = _gauge;
        const r = Rect.fromLTWH(60, 610, 240, 14);
        canvas
          ..drawRRect(
            RRect.fromRectAndRadius(r, const Radius.circular(7)),
            Paint()..color = const Color(0x55000000),
          )
          ..drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(r.left, r.top, r.width * g, r.height),
              const Radius.circular(7),
            ),
            Paint()
              ..color = Color.lerp(
                const Color(0xFFFFD23F),
                const Color(0xFFE8322F),
                g,
              )!,
          );
      }
    }
    drawText(
      canvas,
      '🔴 $myPoints – $aiPoints 🟤',
      const Offset(180, 104),
      size: 18,
      display: true,
      align: TextAlign.center,
    );
    drawText(
      canvas,
      '${'●' * myLeft} | ${'●' * aiLeft}',
      const Offset(180, 126),
      size: 12,
      align: TextAlign.center,
    );
    if (terrain.wind != Offset.zero) {
      drawWind(canvas, const Offset(320, 560), terrain.wind, max: 30);
    }
    if (_phase == _Phase.endOfEnd && endResults.isNotEmpty) {
      final (m, a) = endResults.last;
      drawText(
        canvas,
        m > 0 ? '+$m' : (a > 0 ? '−$a' : '='),
        const Offset(180, 330),
        size: 48,
        display: true,
        align: TextAlign.center,
        color: const Color(0xFFFFD23F),
      );
    }
  }
}
