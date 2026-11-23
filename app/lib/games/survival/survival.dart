import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../core/l10n/l10n.dart';
import '../../core/rng/seeded_random.dart';
import '../common/draw.dart';
import '../common/fingerprint.dart';
import '../common/game_sim.dart';
import '../common/game_types.dart';
import '../common/mini_game_definition.dart';

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
  Offset get focus => Offset(_x, _playerY);

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

  @override
  void render(Canvas canvas) {
    canvas.drawRect(
      Arena.rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1B1430), Color(0xFF2B1A3A)],
        ).createShader(Arena.rect),
    );
    final star = Paint()..color = const Color(0x55FFFFFF);
    for (final s in _stars) {
      final y = (s.dy + elapsed * 20) % Arena.height;
      canvas.drawCircle(Offset(s.dx, y), 1.2, star);
    }
    for (final it in _items) {
      if (it.kind == SpawnKind.orb) {
        canvas.drawCircle(
          it.rect.center,
          18,
          Paint()..color = const Color(0x44FFD23F),
        );
        drawBall(canvas, it.rect.center, 10, it.color, shadow: false);
      } else {
        drawBox(canvas, it.rect, it.color);
      }
    }
    if (!over || survived) {
      drawBox(canvas, _player, const Color(0xFFE8322F), radius: 8);
      final eye = Paint()..color = Colors.white;
      final pupil = Paint()..color = const Color(0xFF120D0E);
      for (final dx in [-7.0, 7.0]) {
        canvas
          ..drawCircle(_player.center.translate(dx, -4), 5, eye)
          ..drawCircle(_player.center.translate(dx, -5), 2.4, pupil);
      }
    }
  }
}
