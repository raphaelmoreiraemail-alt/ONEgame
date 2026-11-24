import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../core/l10n/l10n.dart';
import '../../core/rng/seeded_random.dart';
import '../common/fingerprint.dart';
import '../common/game_sim.dart';
import '../common/game_types.dart';
import '../common/mini_game_definition.dart';
import '../common/render3d.dart';

/// 7.17 Survie 2:00 — dodge falling blocks for two minutes.
class SurvivalGame extends MiniGameDefinition {
  const SurvivalGame();

  @override
  String get id => 'survival';
  @override
  String get emoji => '☄️';
  @override
  GameCategory get category => GameCategory.arcade;
  @override
  int get rulesVersion => 1;
  @override
  Set<String> get supportedModifiers => {
    Modifiers.night,
    Modifiers.turbo,
    Modifiers.mirror,
  };
  @override
  ScoreBounds get scoreBounds => const ScoreBounds(0, 1200 + 40 * 50 + 500);

  @override
  Map<String, num> get defaultTuning => const {
    'startSpeed': 220,
    'endSpeed': 520,
    'startInterval': 0.85,
    'endInterval': 0.32,
    'wallGapStart': 130,
    'wallGapEnd': 95,
  };

  @override
  String name(AppLocalizations l10n) => l10n.gameSurvivalName;
  @override
  String rule(AppLocalizations l10n) => l10n.gameSurvivalRule;

  @override
  String shareLine(AppLocalizations l10n, Map<String, num> stats) =>
      l10n.gameSurvivalShare(
        stats['seconds']?.toInt() ?? 0,
        stats['orbs']?.toInt() ?? 0,
      );

  @override
  List<(String, String)> statRows(
    AppLocalizations l10n,
    Map<String, num> stats,
  ) => [
    (l10n.statSeconds, '${stats['seconds'] ?? 0}'),
    (l10n.statOrbs, '${stats['orbs'] ?? 0}'),
  ];

  @override
  Map<String, String> highlightLabels(AppLocalizations l10n) => {
    'survivor': l10n.highlightSurvivor,
  };

  @override
  GameSim createSim(GameContext ctx) => SurvivalSim(ctx, this);

  @override
  String levelFingerprint(int seed, String? modifierId) => fingerprint([
    for (final s in SurvivalLevel.generate(
      GameContext(seed: seed, modifierId: modifierId),
      defaultTuning,
    )) ...[s.step, s.kind.index, s.x, s.w, s.h, s.speed],
  ]);
}

enum SpawnKind { block, wall, orb }

class SurvivalSpawn {
  const SurvivalSpawn(this.step, this.kind, this.x, this.w, this.h, this.speed);

  final int step;
  final SpawnKind kind;

  /// For walls: [x] is the gap start and [w] the gap width.
  final double x;
  final double w;
  final double h;
  final double speed;
}

abstract final class SurvivalLevel {
  static List<SurvivalSpawn> generate(
    GameContext ctx,
    Map<String, num> defaults,
  ) {
    double tune(String k) => ctx.tune(k, defaults[k]!);
    final rng = SeededRandom.derive(ctx.seed, 'survival:spawns');
    final turbo = ctx.has(Modifiers.turbo) ? 1.25 : 1.0;
    final out = <SurvivalSpawn>[];
    double lerp(double a, double b, double t) => a + (b - a) * t;

    var t = 1.0;
    var nextWall = 18.0;
    var nextOrb = 4.0;
    while (t < 120) {
      final p = t / 120;
      final speed = lerp(tune('startSpeed'), tune('endSpeed'), p) * turbo;
      final step = (t * stepsPerSecond).round();
      if (t >= nextWall) {
        final gap = lerp(tune('wallGapStart'), tune('wallGapEnd'), p);
        final gx = rng.doubleInRange(16, Arena.width - 16 - gap);
        out.add(SurvivalSpawn(step, SpawnKind.wall, gx, gap, 26, speed * 0.8));
        nextWall += rng.doubleInRange(9, 13);
        t += 1.1 / turbo;
        continue;
      }
      if (t >= nextOrb) {
        final ox = rng.doubleInRange(24, Arena.width - 24);
        out.add(SurvivalSpawn(step, SpawnKind.orb, ox, 24, 24, speed * 0.7));
        nextOrb += rng.doubleInRange(3, 5);
      }
      final w = rng.doubleInRange(30, 70 + 40 * p);
      final x = rng.doubleInRange(0, Arena.width - w);
      final h = rng.doubleInRange(24, 40);
      out.add(SurvivalSpawn(step, SpawnKind.block, x, w, h, speed));
      t +=
          lerp(tune('startInterval'), tune('endInterval'), p) /
          turbo *
          rng.doubleInRange(0.7, 1.3);
    }
    return out;
  }
}

class _Falling {
  _Falling(this.rect, this.kind, this.speed, this.color);

  Rect rect;
  final SpawnKind kind;
  final double speed;
  final Color color;
  bool taken = false;
}

class SurvivalSim extends GameSim {
  SurvivalSim(super.ctx, SurvivalGame def)
    : _spawns = SurvivalLevel.generate(ctx, def.defaultTuning),
      _mirror = ctx.has(Modifiers.mirror);

  static const _playerSize = 34.0;
  static const _playerY = 560.0;
  static const _maxPlayerSpeed = 1500.0;
  static const _palette = [
    Color(0xFF3FA7FF),
    Color(0xFF9B5DE5),
    Color(0xFF00BBF9),
    Color(0xFFF15BB5),
  ];

  final List<SurvivalSpawn> _spawns;
  final bool _mirror;
  int _next = 0;
  final List<_Falling> _items = [];

  double _x = Arena.width / 2;
  double _targetX = Arena.width / 2;
  double? _dragStartFinger;
  double _dragStartTarget = 0;
  int? _pointer;

  int orbs = 0;
  bool survived = false;

  static final List<Offset> _stars = () {
    final r = SeededRandom(7);
    return List.generate(
      60,
      (_) =>
          Offset(r.nextDouble() * Arena.width, r.nextDouble() * Arena.height),
    );
  }();

  Rect get _player => Rect.fromCenter(
    center: Offset(_x, _playerY),
    width: _playerSize,
    height: _playerSize,
  );

  @override
  Color get backgroundColor => const Color(0xFF140F24);

  @override
  Offset get focus =>
      _camera.project(V3(_x, 20, _playerY)) ?? Offset(_x, _playerY);

  @override
  void onPointer(PointerPhase phase, int pointer, Offset pos) {
    switch (phase) {
      case PointerPhase.down:
        if (_pointer != null) return;
        _pointer = pointer;
        _dragStartFinger = pos.dx;
        _dragStartTarget = _targetX;
      case PointerPhase.move:
        if (pointer != _pointer || _dragStartFinger == null) return;
        final dx = pos.dx - _dragStartFinger!;
        _targetX = (_dragStartTarget + (_mirror ? -dx : dx)).clamp(
          _playerSize / 2,
          Arena.width - _playerSize / 2,
        );
      case PointerPhase.up:
        if (pointer != _pointer) return;
        _pointer = null;
        _dragStartFinger = null;
    }
  }

  @override
  void tick() {
    tickParticles();
    // Player follows the drag target with a speed cap.
    const maxStep = _maxPlayerSpeed * stepDt;
    _x += (_targetX - _x).clamp(-maxStep, maxStep);

    while (_next < _spawns.length && _spawns[_next].step <= step) {
      final s = _spawns[_next++];
      switch (s.kind) {
        case SpawnKind.block:
          _items.add(
            _Falling(
              Rect.fromLTWH(s.x, -s.h, s.w, s.h),
              s.kind,
              s.speed,
              _palette[_next % _palette.length],
            ),
          );
        case SpawnKind.wall:
          const c = Color(0xFFE8322F);
          _items
            ..add(
              _Falling(Rect.fromLTWH(0, -s.h, s.x, s.h), s.kind, s.speed, c),
            )
            ..add(
              _Falling(
                Rect.fromLTRB(s.x + s.w, -s.h, Arena.width, 0),
                s.kind,
                s.speed,
                c,
              ),
            );
        case SpawnKind.orb:
          _items.add(
            _Falling(
              Rect.fromCenter(center: Offset(s.x, -12), width: 24, height: 24),
              s.kind,
              s.speed,
              const Color(0xFFFFD23F),
            ),
          );
      }
    }

    final hitbox = _player.deflate(4);
    for (final it in _items) {
      it.rect = it.rect.translate(0, it.speed * stepDt);
      if (it.taken) continue;
      if (it.kind == SpawnKind.orb) {
        if ((it.rect.center - _player.center).distance < 28) {
          it.taken = true;
          orbs++;
          particles.burst(it.rect.center, it.color, count: 12);
          cue(sfx: Sfx.score, haptic: Haptic.light);
        }
      } else if (it.rect.overlaps(hitbox)) {
        over = true;
        particles.burst(_player.center, const Color(0xFFE8322F), count: 30);
        cue(sfx: Sfx.hit, haptic: Haptic.heavy);
      }
    }
    _items.removeWhere((it) => it.rect.top > Arena.height || it.taken);
    score = (elapsed.floor()) * 10 + orbs * 50;
  }

  @override
  void onTimeUp() {
    survived = true;
    score = 120 * 10 + orbs * 50 + 500;
    celebrate('survivor');
    particles.fireworks(_player.center.translate(0, -120));
  }

  @override
  Map<String, num> get stats => {
    'seconds': math.min(120, elapsed.floor()),
    'orbs': orbs,
    'survived': survived ? 1 : 0,
  };

  // ── 3D rendering ──────────────────────────────────────────────────────
  // Arena (x, y) → V3(x, h, y): obstacles come from the far end of a neon
  // track towards the camera.
  static final Camera3D _camera = Camera3D(
    eye: const V3(180, 210, 880),
    target: const V3(180, 0, 180),
    fovDegrees: 50,
    center: const Offset(180, 330),
  );

  @override
  void render(Canvas canvas) {
    final horizon = _camera.project(const V3(180, 210, -100000))?.dy ?? 120;
    drawSky(
      canvas,
      Rect.fromLTWH(0, 0, 360, horizon + 1),
      const Color(0xFF0B0620),
      const Color(0xFF3A1250),
    );
    final star = Paint()..color = const Color(0x88FFFFFF);
    for (final st in _stars) {
      if (st.dy * 0.4 < horizon - 4) {
        canvas.drawCircle(Offset(st.dx, st.dy * 0.4), 1, star);
      }
    }
    // Striped retro sun sitting on the horizon.
    final sun = Rect.fromCircle(center: Offset(180, horizon - 4), radius: 62);
    canvas
      ..save()
      ..clipRect(Rect.fromLTRB(0, 0, 360, horizon))
      ..drawCircle(
        sun.center,
        62,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFE259), Color(0xFFFF4E8A)],
          ).createShader(sun),
      );
    for (var k = 0; k < 5; k++) {
      final y = horizon - 8 - k * 9.0;
      canvas.drawRect(
        Rect.fromLTRB(0, y, 360, y + 2.5 + (4 - k) * 0.6),
        Paint()..color = const Color(0xFF3A1250),
      );
    }
    canvas
      ..restore()
      ..drawRect(
        Rect.fromLTWH(0, horizon, 360, 640 - horizon),
        Paint()..color = const Color(0xFF120A24),
      );
    final s = Scene3D(
      _camera,
      light: const V3(-0.3, 1, 0.5),
      ambient: 0.45,
      fogColor: const Color(0xFF241040),
      fogStart: 900,
      fogEnd: 3200,
    );
    // Neon grid scrolling towards the player.
    const grid = Color(0xFFFF3FD0);
    final scroll = (elapsed * 260) % 80;
    for (var k = -40; k < 9; k++) {
      final z = k * 80.0 + scroll;
      s.quad(
        V3(-900, 0, z - 1.5),
        V3(-900, 0, z + 1.5),
        V3(1260, 0, z + 1.5),
        V3(1260, 0, z - 1.5),
        grid,
        lit: false,
        layer: Layer.decal,
      );
    }
    for (var k = -12; k <= 16; k++) {
      final x = k * 60.0;
      s.quad(
        V3(x - 1.2, 0, -3200),
        V3(x - 1.2, 0, 700),
        V3(x + 1.2, 0, 700),
        V3(x + 1.2, 0, -3200),
        k == 0 || k == 6 ? const Color(0xFF39E8FF) : grid,
        lit: false,
        layer: Layer.decal,
      );
    }
    for (final it in _items) {
      final r = it.rect;
      if (it.kind == SpawnKind.orb) {
        final c = V3(
          r.center.dx,
          22 + math.sin(elapsed * 5 + r.center.dx) * 4,
          r.center.dy,
        );
        s
          ..shadow(r.center, 12, height: 0.5, opacity: 0.4)
          ..sphere(c, 10, it.color, lat: 6, lon: 10);
      } else {
        final h = it.kind == SpawnKind.wall ? 60.0 : 36.0;
        s
          ..shadow(
            r.center.translate(6, 6),
            math.max(r.width, r.height) * 0.6,
            height: 0.5,
            opacity: 0.35,
          )
          ..box(
            V3(r.center.dx, 0, r.center.dy),
            r.width,
            h,
            r.height,
            it.color,
            top: tint(it.color, 0.35),
          );
        // Neon edge on top.
        s.box(
          V3(r.center.dx, h, r.bottom - 1.5),
          r.width,
          2,
          3,
          tint(it.color, 0.6),
        );
      }
    }
    if (!over || survived) {
      // Hover robot: body, visor with eyes, glowing thruster.
      final hover = 14 + math.sin(elapsed * 6) * 3;
      final b = V3(_x, hover, _playerY);
      final tiltX = ((_targetX - _x) / 120).clamp(-0.4, 0.4);
      s
        ..shadow(Offset(_x, _playerY), 20, height: 0.5, opacity: 0.5)
        ..sphere(
          V3(_x, hover - 4, _playerY),
          9,
          const Color(0xFF39E8FF),
          lat: 4,
          lon: 8,
        )
        ..box(
          b,
          _playerSize,
          _playerSize * 0.8,
          _playerSize,
          const Color(0xFFE8322F),
          yaw: tiltX,
          top: const Color(0xFFFF6E5A),
        )
        ..box(
          b + const V3(0, _playerSize * 0.36, _playerSize / 2 + 1.5),
          _playerSize * 0.8,
          11,
          4,
          const Color(0xFF1A1030),
        );
      for (final dx in [-7.0, 7.0]) {
        s.sphere(
          b + V3(dx, _playerSize * 0.36 + 5.5, _playerSize / 2 + 4),
          3.2,
          const Color(0xFF39E8FF),
          lat: 3,
          lon: 6,
        );
      }
    }
    s.render(canvas);
  }
}
