import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../core/l10n/l10n.dart';
import '../../core/rng/seeded_random.dart';
import '../common/draw.dart';
import '../common/fingerprint.dart';
import '../common/game_sim.dart';
import '../common/game_types.dart';
import '../common/mini_game_definition.dart';

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

  @override
  void render(Canvas canvas) {
    canvas.drawRect(Arena.rect, Paint()..color = const Color(0xFF1B2E1F));
    final board = Rect.fromLTWH(origin.dx, origin.dy, cols * cell, rows * cell);
    canvas.drawRect(board, Paint()..color = const Color(0xFF2E4A33));
    for (var x = 0; x < cols; x++) {
      for (var y = 0; y < rows; y++) {
        if ((x + y).isEven) {
          canvas.drawRect(
            Rect.fromLTWH(
              origin.dx + x * cell,
              origin.dy + y * cell,
              cell,
              cell,
            ),
            Paint()..color = const Color(0xFF2B4430),
          );
        }
      }
    }
    for (final w in _walls) {
      drawBox(
        canvas,
        Rect.fromLTWH(
          origin.dx + w.$1 * cell,
          origin.dy + w.$2 * cell,
          cell,
          cell,
        ),
        const Color(0xFF795548),
        radius: 3,
      );
    }
    drawBall(canvas, _center(_fruit), 6, const Color(0xFFE53935));
    if (_gold != null) {
      final blink = (_goldUntil - step) < stepsPerSecond && step % 20 < 10;
      if (!blink) drawBall(canvas, _center(_gold!), 7, const Color(0xFFFFD23F));
    }
    for (var i = _body.length - 1; i >= 0; i--) {
      final t = i / math.max(1, _body.length - 1);
      final c = Color.lerp(
        const Color(0xFF9CCC65),
        const Color(0xFF33691E),
        t,
      )!;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: _center(_body[i]),
            width: cell - 1,
            height: cell - 1,
          ),
          const Radius.circular(5),
        ),
        Paint()..color = c,
      );
    }
    final h = _center(_body.first);
    canvas
      ..drawCircle(
        h +
            Offset(
              _dir.$2 == 0 ? 3.0 * _dir.$1 : -3,
              _dir.$1 == 0 ? 3.0 * _dir.$2 : -3,
            ),
        2,
        Paint()..color = Colors.black,
      )
      ..drawCircle(
        h +
            Offset(
              _dir.$2 == 0 ? 3.0 * _dir.$1 : 3,
              _dir.$1 == 0 ? 3.0 * _dir.$2 : 3,
            ),
        2,
        Paint()..color = Colors.black,
      );
  }
}
