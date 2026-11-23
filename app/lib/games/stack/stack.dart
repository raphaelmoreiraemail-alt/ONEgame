import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../core/l10n/l10n.dart';
import '../../core/rng/seeded_random.dart';
import '../common/draw.dart';
import '../common/fingerprint.dart';
import '../common/game_sim.dart';
import '../common/game_types.dart';
import '../common/mini_game_definition.dart';

/// 7.14 Tour infinie — tap to drop the sliding block; overhang is cut.
class StackGame extends MiniGameDefinition {
  const StackGame();

  @override
  String get id => 'stack';
  @override
  String get emoji => '🧱';
  @override
  GameCategory get category => GameCategory.adresse;
  @override
  int get rulesVersion => 1;
  @override
  Set<String> get supportedModifiers => {Modifiers.turbo, Modifiers.night};
  @override
  ScoreBounds get scoreBounds => const ScoreBounds(0, 40000);

  @override
  Map<String, num> get defaultTuning => const {
    'baseSpeed': 150,
    'speedPerBlock': 4,
    'maxSpeed': 420,
    'trapChance': 0.12,
    'perfectTolerance': 3,
    'regrow': 8,
  };

  @override
  String name(AppLocalizations l10n) => l10n.gameStackName;
  @override
  String rule(AppLocalizations l10n) => l10n.gameStackRule;

  @override
  String shareLine(AppLocalizations l10n, Map<String, num> s) => l10n
      .gameStackShare(s['height']?.toInt() ?? 0, s['perfects']?.toInt() ?? 0);

  @override
  List<(String, String)> statRows(AppLocalizations l10n, Map<String, num> s) =>
      [
        (l10n.statHeight, '${s['height'] ?? 0}'),
        (l10n.statPerfects, '${s['perfects'] ?? 0}'),
        (l10n.statMaxCombo, '${s['maxCombo'] ?? 0}'),
      ];

  @override
  Map<String, String> highlightLabels(AppLocalizations l10n) => {
    'perfectStreak': l10n.highlightPerfectStreak,
  };

  @override
  GameSim createSim(GameContext ctx) => StackSim(ctx, this);

  @override
  String levelFingerprint(int seed, String? modifierId) {
    final ctx = GameContext(seed: seed, modifierId: modifierId);
    final r = StackPlan(ctx, defaultTuning);
    return fingerprint([
      for (var i = 0; i < 60; i++) ...[r.speedOf(i), r.hueOf(i), r.fromLeft(i)],
    ]);
  }
}

/// Per-block parameters, derived from the seed with one generator per block
/// so they never depend on how the game was played.
class StackPlan {
  StackPlan(this.ctx, this.defaults);

  final GameContext ctx;
  final Map<String, num> defaults;

  double _t(String k) => ctx.tune(k, defaults[k]!);

  double speedOf(int i) {
    final r = SeededRandom.derive(ctx.seed, 'stack:block$i');
    var s = math.min(_t('baseSpeed') + i * _t('speedPerBlock'), _t('maxSpeed'));
    s *= r.doubleInRange(0.9, 1.1);
    if (i > 3 && r.chance(_t('trapChance'))) s *= 1.6; // trap block
    if (ctx.has(Modifiers.turbo)) s *= 1.25;
    return s;
  }

  bool isTrap(int i) =>
      speedOf(i) >
      math.min(_t('baseSpeed') + i * _t('speedPerBlock'), _t('maxSpeed')) *
          1.4 *
          (ctx.has(Modifiers.turbo) ? 1.25 : 1);

  double hueOf(int i) {
    final base =
        SeededRandom.derive(ctx.seed, 'stack:palette').nextDouble() * 360;
    return (base + i * 9) % 360;
  }

  bool fromLeft(int i) =>
      SeededRandom.derive(ctx.seed, 'stack:side$i').chance(0.5);
}

class _Block {
  _Block(this.x, this.w, this.level, this.color);

  double x;
  double w;
  final int level;
  final Color color;
}

class _Chunk {
  _Chunk(this.rect, this.color);

  Rect rect;
  final Color color;
  double vy = 0;
}

class StackSim extends GameSim {
  StackSim(super.ctx, StackGame def)
    : plan = StackPlan(ctx, def.defaultTuning),
      _tolerance = ctx.tune(
        'perfectTolerance',
        def.defaultTuning['perfectTolerance']!,
      ),
      _regrow = ctx.tune('regrow', def.defaultTuning['regrow']!) {
    _tower.add(_Block(80, baseWidth, 0, _color(0)));
    _spawn();
  }

  static const double baseWidth = 200;
  static const double blockH = 24;
  static const double baseY = 600;

  final StackPlan plan;
  final double _tolerance;
  final double _regrow;
  final List<_Block> _tower = [];
  final List<_Chunk> _chunks = [];
  late _Block _moving;
  double _dir = 1;
  double _speed = 0;
  double _camera = 0;

  int perfects = 0;
  int combo = 0;
  int maxCombo = 0;
  bool _tapped = false;

  int get height => _tower.length - 1;

  Color _color(int level) =>
      HSVColor.fromAHSV(1, plan.hueOf(level), 0.55, 0.95).toColor();

  @override
  Color get backgroundColor => const Color(0xFF0F1B2D);

  @override
  Offset get focus =>
      Offset(_moving.x + _moving.w / 2, _yOf(_moving.level) + blockH / 2);

  double _yOf(int level) => baseY - level * blockH + _camera;

  void _spawn() {
    final level = _tower.length;
    final top = _tower.last;
    final left = plan.fromLeft(level);
    _moving = _Block(left ? -top.w : Arena.width, top.w, level, _color(level));
    _dir = left ? 1 : -1;
    _speed = plan.speedOf(level);
  }

  @override
  void onPointer(PointerPhase phase, int pointer, Offset pos) {
    if (phase == PointerPhase.down) _tapped = true;
  }

  @override
  void tick() {
    tickParticles();
    // Camera keeps the top of the tower around y = 300.
    final target = math.max(0.0, (_tower.length - 12) * blockH);
    _camera += (target - _camera) * 0.08;
    for (final c in _chunks) {
      c.vy += 1400 * stepDt;
      c.rect = c.rect.translate(0, c.vy * stepDt);
    }
    _chunks.removeWhere((c) => c.rect.top > Arena.height + 200);

    if (_tapped) {
      _tapped = false;
      _drop();
      if (over) return;
    }
    _moving.x += _dir * _speed * stepDt;
    // Ping-pong between the screen edges.
    if (_moving.x + _moving.w > Arena.width + 40 && _dir > 0) _dir = -1;
    if (_moving.x < -40 && _dir < 0) _dir = 1;
  }

  void _drop() {
    final top = _tower.last;
    final l = math.max(_moving.x, top.x);
    final r = math.min(_moving.x + _moving.w, top.x + top.w);
    final y = _yOf(_moving.level);
    if (r - l <= 0) {
      // Missed completely: the block falls, game over.
      _chunks.add(
        _Chunk(Rect.fromLTWH(_moving.x, y, _moving.w, blockH), _moving.color),
      );
      cue(sfx: Sfx.miss, haptic: Haptic.heavy);
      over = true;
      return;
    }
    if ((_moving.x - top.x).abs() <= _tolerance) {
      perfects++;
      combo++;
      maxCombo = math.max(maxCombo, combo);
      final w = math.min(top.w + _regrow, baseWidth);
      final x = top.x - (w - top.w) / 2;
      _tower.add(_Block(x, w, _moving.level, _moving.color));
      particles.burst(
        Offset(x + w / 2, y),
        Colors.white,
        count: 14,
        gravity: 0,
      );
      cue(sfx: Sfx.score, haptic: Haptic.medium);
      if (combo == 5) celebrate('perfectStreak');
    } else {
      combo = 0;
      // Cut the overhang.
      if (_moving.x < l) {
        _chunks.add(
          _Chunk(Rect.fromLTRB(_moving.x, y, l, y + blockH), _moving.color),
        );
      }
      if (_moving.x + _moving.w > r) {
        _chunks.add(
          _Chunk(
            Rect.fromLTRB(r, y, _moving.x + _moving.w, y + blockH),
            _moving.color,
          ),
        );
      }
      _tower.add(_Block(l, r - l, _moving.level, _moving.color));
      cue(sfx: Sfx.tap, haptic: Haptic.light);
    }
    score = height * 50 + perfects * 100;
    _spawn();
  }

  @override
  Map<String, num> get stats => {
    'height': height,
    'perfects': perfects,
    'maxCombo': maxCombo,
  };

  @override
  void render(Canvas canvas) {
    final t = (height / 80).clamp(0.0, 1.0);
    canvas.drawRect(
      Arena.rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(const Color(0xFF6EC6FF), const Color(0xFF0B1026), t)!,
            Color.lerp(const Color(0xFFFFE0B2), const Color(0xFF283593), t)!,
          ],
        ).createShader(Arena.rect),
    );
    // Ground.
    canvas.drawRect(
      Rect.fromLTWH(0, baseY + blockH + _camera, 360, 400),
      Paint()..color = const Color(0xFF3E2723),
    );
    for (final b in _tower) {
      final y = _yOf(b.level);
      if (y > Arena.height || y < -blockH) continue;
      drawBox(canvas, Rect.fromLTWH(b.x, y, b.w, blockH), b.color, radius: 3);
    }
    for (final c in _chunks) {
      drawBox(canvas, c.rect.translate(0, 0), c.color, radius: 3);
    }
    if (!over) {
      final m = _moving;
      drawBox(
        canvas,
        Rect.fromLTWH(m.x, _yOf(m.level), m.w, blockH),
        m.color,
        radius: 3,
      );
      if (plan.isTrap(m.level)) {
        drawText(
          canvas,
          '⚡',
          Offset(m.x + m.w / 2, _yOf(m.level) + 12),
          size: 14,
          align: TextAlign.center,
        );
      }
    }
    if (combo >= 2) {
      drawText(
        canvas,
        '✨ ×$combo',
        const Offset(16, 100),
        size: 18,
        display: true,
        color: const Color(0xFFFFD23F),
      );
    }
    drawText(
      canvas,
      '$height',
      const Offset(344, 100),
      size: 22,
      display: true,
      align: TextAlign.right,
    );
  }
}
