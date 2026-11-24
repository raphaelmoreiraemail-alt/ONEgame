import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../core/l10n/l10n.dart';
import '../../core/rng/seeded_random.dart';
import '../common/fingerprint.dart';
import '../common/game_sim.dart';
import '../common/game_types.dart';
import '../common/mini_game_definition.dart';
import '../common/render3d.dart';

/// 7.20 Serpent — classic snake on a 20 × 30 grid with seeded walls.
class SnakeGame extends MiniGameDefinition {
  const SnakeGame();

  @override
  String get id => 'snake';
  @override
  String get emoji => '🐍';
  @override
  GameCategory get category => GameCategory.arcade;
  @override
  int get rulesVersion => 1;
  @override
  Set<String> get supportedModifiers => {Modifiers.turbo};
  @override
  ScoreBounds get scoreBounds => const ScoreBounds(0, 40000);

  @override
  Map<String, num> get defaultTuning => const {
    'startSpeed': 7,
    'speedStep': 1,
    'goldenChance': 0.25,
  };

  @override
  String name(AppLocalizations l10n) => l10n.gameSnakeName;
  @override
  String rule(AppLocalizations l10n) => l10n.gameSnakeRule;

  @override
  String shareLine(AppLocalizations l10n, Map<String, num> s) =>
      l10n.gameSnakeShare(
        s['fruits']?.toInt() ?? 0,
        s['golden']?.toInt() ?? 0,
        s['length']?.toInt() ?? 0,
      );

  @override
  List<(String, String)> statRows(AppLocalizations l10n, Map<String, num> s) =>
      [
        (l10n.statFruits, '${s['fruits'] ?? 0}'),
        (l10n.statGolden, '${s['golden'] ?? 0}'),
        (l10n.statLength, '${s['length'] ?? 0}'),
      ];

  @override
  Map<String, String> highlightLabels(AppLocalizations l10n) => {
    'bigSnake': l10n.highlightBigSnake,
  };

  @override
  GameSim createSim(GameContext ctx) => SnakeSim(ctx, this);

  @override
  String levelFingerprint(int seed, String? modifierId) => fingerprint([
    for (final w in SnakeSim.walls(seed)) ...[w.$1, w.$2],
  ]);
}

typedef Cell = (int, int);

class SnakeSim extends GameSim {
  SnakeSim(super.ctx, SnakeGame def)
    : _walls = walls(ctx.seed).toSet(),
      _fruitRng = SeededRandom.derive(ctx.seed, 'snake:fruits'),
      _speed0 = ctx.tune('startSpeed', def.defaultTuning['startSpeed']!),
      _speedStep = ctx.tune('speedStep', def.defaultTuning['speedStep']!),
      _golden = ctx.tune('goldenChance', def.defaultTuning['goldenChance']!),
      _turbo = ctx.has(Modifiers.turbo) ? 1.25 : 1.0 {
    _body.addAll([(10, 22), (10, 23), (10, 24), (10, 25)]);
    _fruit = _place();
  }

  static const int cols = 20;
  static const int rows = 30;
  static const double cell = 16;
  static const Offset origin = Offset(20, 120);

  /// Interior walls from the seed (never on the starting column).
  static List<Cell> walls(int seed) {
    final r = SeededRandom.derive(seed, 'snake:walls');
    final out = <Cell>[];
    final n = r.intInRange(3, 6);
    for (var i = 0; i < n; i++) {
      final horizontal = r.chance(0.5);
      final len = r.intInRange(3, 7);
      final x = r.intInRange(1, cols - 2 - (horizontal ? len : 0));
      final y = r.intInRange(2, rows - 10 - (horizontal ? 0 : len));
      for (var k = 0; k < len; k++) {
        final c = horizontal ? (x + k, y) : (x, y + k);
        if (c.$1 != 10) out.add(c);
      }
    }
    return out;
  }

  final Set<Cell> _walls;
  final SeededRandom _fruitRng;
  final double _speed0, _speedStep, _golden, _turbo;
  final List<Cell> _body = [];
  Cell _dir = (0, -1);
  final List<Cell> _queued = [];
  late Cell _fruit;
  Cell? _gold;
  int _goldUntil = 0;
  int fruits = 0, golden = 0;
  double _acc = 0;
  int _grow = 0;
  int? _pointer;
  Offset _down = Offset.zero;

  double get _speed => (_speed0 + (fruits ~/ 5) * _speedStep) * _turbo;

  Cell _place() {
    // Deterministic: the n-th fruit always draws from the same sequence,
    // skipping occupied cells.
    while (true) {
      final c = (_fruitRng.nextInt(cols), _fruitRng.nextInt(rows));
      if (!_walls.contains(c) && !_body.contains(c) && c != _gold) return c;
    }
  }

  Offset _center(Cell c) =>
      origin + Offset((c.$1 + 0.5) * cell, (c.$2 + 0.5) * cell);

  @override
  Color get backgroundColor => const Color(0xFF1B2E1F);

  @override
  Offset get focus => _center(_body.first);

  @override
  void onPointer(PointerPhase phase, int pointer, Offset pos) {
    switch (phase) {
      case PointerPhase.down:
        _pointer = pointer;
        _down = pos;
      case PointerPhase.move:
        if (pointer != _pointer) return;
        final d = pos - _down;
        if (d.distance < 24) return;
        final dir = d.dx.abs() > d.dy.abs()
            ? (d.dx > 0 ? 1 : -1, 0)
            : (0, d.dy > 0 ? 1 : -1);
        final last = _queued.isEmpty ? _dir : _queued.last;
        if (dir != last &&
            (dir.$1 != -last.$1 || dir.$2 != -last.$2) &&
            _queued.length < 2) {
          _queued.add(dir);
        }
        _down = pos;
      case PointerPhase.up:
        if (pointer == _pointer) _pointer = null;
    }
  }

  @override
  void tick() {
    tickParticles();
    if (_gold != null && step > _goldUntil) _gold = null;
    _acc += _speed * stepDt;
    while (_acc >= 1 && !over) {
      _acc -= 1;
      _move();
    }
  }

  void _move() {
    if (_queued.isNotEmpty) _dir = _queued.removeAt(0);
    final h = _body.first;
    final next = (h.$1 + _dir.$1, h.$2 + _dir.$2);
    final tail = _grow > 0 ? null : _body.last;
    if (next.$1 < 0 ||
        next.$1 >= cols ||
        next.$2 < 0 ||
        next.$2 >= rows ||
        _walls.contains(next) ||
        (_body.contains(next) && next != tail)) {
      over = true;
      particles.burst(_center(h), const Color(0xFF66BB6A), count: 30);
      cue(sfx: Sfx.hit, haptic: Haptic.heavy);
      return;
    }
    _body.insert(0, next);
    if (_grow > 0) {
      _grow--;
    } else {
      _body.removeLast();
    }
    if (next == _fruit) {
      fruits++;
      score += 100;
      _grow += 2;
      particles.burst(
        _center(next),
        const Color(0xFFE53935),
        count: 10,
        gravity: 0,
      );
      cue(sfx: Sfx.score, haptic: Haptic.light);
      _fruit = _place();
      if (_gold == null && _fruitRng.chance(_golden)) {
        _gold = _place();
        _goldUntil = step + 5 * stepsPerSecond;
      }
    } else if (next == _gold) {
      golden++;
      score += 300;
      _grow += 3;
      _gold = null;
      particles.burst(
        _center(next),
        const Color(0xFFFFD23F),
        count: 16,
        gravity: 0,
      );
      cue(sfx: Sfx.highlight, haptic: Haptic.medium);
    }
    if (_body.length >= 25 && !highlights.contains('bigSnake')) {
      celebrate('bigSnake');
    }
  }

  @override
  Map<String, num> get stats => {
    'fruits': fruits,
    'golden': golden,
    'length': _body.length,
  };

  // ── 3D rendering ──────────────────────────────────────────────────────
  // Board (x, y) → V3(x, h, y), seen from the south. Swipes stay in screen
  // space: up is still "away", so the controls are unchanged.
  static final Camera3D _camera = Camera3D(
    eye: const V3(180, 640, 960),
    target: const V3(180, 0, 372),
    fovDegrees: 46,
    center: const Offset(180, 352),
  );

  V3 _c3((int, int) c, [double h = 0]) => V3.ground(_center(c), h);

  @override
  void render(Canvas canvas) {
    drawSky(
      canvas,
      Arena.rect,
      const Color(0xFF1E3B26),
      const Color(0xFF0F2015),
    );
    final s = Scene3D(_camera, light: const V3(-0.45, 1, 0.4), ambient: 0.5);
    final board = Rect.fromLTWH(origin.dx, origin.dy, cols * cell, rows * cell);
    // Soil around, a wooden frame, a chequered lawn.
    s.ground(
      board.inflate(260),
      (i, j) =>
          tint(const Color(0xFF3E2C1E), (cellNoise(i, j, 4) - 0.5) * 0.08),
      cell: 80,
      height: -10,
    );
    final frame = board.inflate(10);
    for (final r in [
      Rect.fromLTRB(frame.left, frame.top, frame.right, board.top),
      Rect.fromLTRB(frame.left, board.bottom, frame.right, frame.bottom),
      Rect.fromLTRB(frame.left, board.top, board.left, board.bottom),
      Rect.fromLTRB(board.right, board.top, frame.right, board.bottom),
    ]) {
      s.box(
        V3(r.center.dx, -10, r.center.dy),
        r.width,
        16,
        r.height,
        const Color(0xFF8D6E63),
        top: const Color(0xFFA1887F),
        layer: Layer.surface,
      );
    }
    s.ground(
      board,
      (i, j) => tint(
        (i + j).isEven ? const Color(0xFF6DB34F) : const Color(0xFF5EA343),
        (cellNoise(i, j, 9) - 0.5) * 0.05,
      ),
      cell: cell,
      layer: Layer.surface,
    );
    for (final w in _walls) {
      final c = _c3(w);
      s
        ..shadow(_center(w).translate(4, 3), cell * 0.75, opacity: 0.3)
        ..box(
          c,
          cell,
          14,
          cell,
          tint(
            const Color(0xFF8A8580),
            (cellNoise(w.$1, w.$2, 7) - 0.5) * 0.15,
          ),
          top: const Color(0xFFA9A49E),
        );
    }
    _apple(s, _c3(_fruit), const Color(0xFFD32F2F), 6.5);
    if (_gold != null) {
      final blink = (_goldUntil - step) < stepsPerSecond && step % 20 < 10;
      if (!blink) {
        _apple(
          s,
          _c3(_gold!, math.sin(elapsed * 4) * 2 + 2),
          const Color(0xFFFFC107),
          7.5,
        );
      }
    }
    // Snake: chain of glossy spheres, the head bigger with eyes.
    for (var i = _body.length - 1; i >= 1; i--) {
      final t = i / math.max(1, _body.length - 1);
      final col = Color.lerp(
        const Color(0xFF8BC34A),
        const Color(0xFF2E6B1A),
        t,
      )!;
      final r = 7.6 - t * 1.6;
      s
        ..shadow(_center(_body[i]).translate(3, 2), r * 1.1, opacity: 0.3)
        ..sphere(
          _c3(_body[i], r),
          r,
          (i ~/ 2).isEven ? col : tint(col, -0.12),
          lat: 5,
          lon: 8,
        );
      // Fill the gap with the next segment.
      final mid = (_c3(_body[i], r) + _c3(_body[i - 1], r)) * 0.5;
      s.sphere(mid, r * 0.92, col, lat: 4, lon: 8);
    }
    final head = _c3(_body.first, 8.5);
    final f = V3(_dir.$1.toDouble(), 0, _dir.$2.toDouble());
    final side = V3(-f.z, 0, f.x);
    s
      ..shadow(_center(_body.first).translate(3, 2), 10, opacity: 0.35)
      ..sphere(head, 9, const Color(0xFF9CCC65), lat: 6, lon: 10);
    for (final k in [-1.0, 1.0]) {
      final e = head + f * 5 + side * (k * 4.5) + const V3(0, 5, 0);
      s
        ..sphere(e, 3, const Color(0xFFFFFFFF), lat: 3, lon: 6)
        ..sphere(
          e + f * 1.8 + const V3(0, 0.8, 0),
          1.6,
          const Color(0xFF111111),
          lat: 3,
          lon: 5,
        );
    }
    s.tube(
      head + f * 8,
      head + f * 14 + const V3(0, -2, 0),
      0.9,
      0.4,
      const Color(0xFFE53935),
      segments: 4,
    );
    s.render(canvas);
  }

  static void _apple(Scene3D s, V3 at, Color c, double r) {
    s
      ..shadow(Offset(at.x + 3, at.z + 2), r * 1.1, opacity: 0.3)
      ..sphere(at + V3(0, r, 0), r, c, lat: 6, lon: 10)
      ..tube(
        at + V3(0, r * 1.8, 0),
        at + V3(0.8, r * 2.4, 0),
        0.7,
        0.5,
        const Color(0xFF5D4037),
        segments: 4,
      )
      ..tri(
        at + V3(0.8, r * 2.2, 0),
        at + V3(4.5, r * 2.5, -1.5),
        at + V3(2, r * 2.0, 2),
        const Color(0xFF43A047),
        doubleSided: true,
      );
  }
}
