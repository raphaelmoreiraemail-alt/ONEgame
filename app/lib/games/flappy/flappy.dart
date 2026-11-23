import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../core/l10n/l10n.dart';
import '../../core/rng/seeded_random.dart';
import '../common/draw.dart';
import '../common/fingerprint.dart';
import '../common/game_sim.dart';
import '../common/game_types.dart';
import '../common/mini_game_definition.dart';

/// 7.18 Vol — tap to flap through the pipes.
class FlappyGame extends MiniGameDefinition {
  const FlappyGame();

  @override
  String get id => 'flappy';
  @override
  String get emoji => '🐦';
  @override
  GameCategory get category => GameCategory.arcade;
  @override
  int get rulesVersion => 1;
  @override
  Set<String> get supportedModifiers => {Modifiers.turbo};
  @override
  ScoreBounds get scoreBounds => const ScoreBounds(0, 20000);

  @override
  Map<String, num> get defaultTuning => const {
    'gravity': 1500,
    'flap': 440,
    'speed': 150,
    'gapStart': 160,
    'gapEnd': 118,
  };

  @override
  String name(AppLocalizations l10n) => l10n.gameFlappyName;
  @override
  String rule(AppLocalizations l10n) => l10n.gameFlappyRule;

  @override
  String shareLine(AppLocalizations l10n, Map<String, num> s) => l10n
      .gameFlappyShare(s['pipes']?.toInt() ?? 0, s['perfect']?.toInt() ?? 0);

  @override
  List<(String, String)> statRows(AppLocalizations l10n, Map<String, num> s) =>
      [
        (l10n.statPipes, '${s['pipes'] ?? 0}'),
        (l10n.statCenterPasses, '${s['perfect'] ?? 0}'),
      ];

  @override
  Map<String, String> highlightLabels(AppLocalizations l10n) => {
    'perfectFlight': l10n.highlightPerfectFlight,
  };

  @override
  GameSim createSim(GameContext ctx) => FlappySim(ctx, this);

  @override
  String levelFingerprint(int seed, String? modifierId) {
    final p = FlappySim.pipes(
      GameContext(seed: seed, modifierId: modifierId),
      defaultTuning,
    );
    return fingerprint([
      for (final x in p.take(40)) ...[x.gapY, x.gap, x.swing, x.period],
    ]);
  }
}

class Pipe {
  const Pipe(this.gapY, this.gap, this.swing, this.period);

  final double gapY;
  final double gap;

  /// Vertical movement (after 60 s).
  final double swing;
  final double period;
}

class FlappySim extends GameSim {
  FlappySim(super.ctx, FlappyGame def)
    : _pipes = pipes(ctx, def.defaultTuning),
      _gravity = ctx.tune('gravity', def.defaultTuning['gravity']!),
      _flap = ctx.tune('flap', def.defaultTuning['flap']!),
      _speed =
          ctx.tune('speed', def.defaultTuning['speed']!) *
          (ctx.has(Modifiers.turbo) ? 1.25 : 1);

  static const double birdX = 100;
  static const double spacing = 200;
  static const double pipeW = 56;
  static const double top = 92;
  static const double ground = 600;

  static List<Pipe> pipes(GameContext ctx, Map<String, num> d) {
    final r = SeededRandom.derive(ctx.seed, 'flappy:pipes');
    final g0 = ctx.tune('gapStart', d['gapStart']!),
        g1 = ctx.tune('gapEnd', d['gapEnd']!);
    return [
      for (var i = 0; i < 160; i++)
        Pipe(
          r.doubleInRange(top + 110, ground - 110),
          g0 + (g1 - g0) * math.min(1, i / 60),
          r.doubleInRange(20, 50),
          r.doubleInRange(1.6, 2.8),
        ),
    ];
  }

  final List<Pipe> _pipes;
  final double _gravity;
  final double _flap;
  final double _speed;

  double _y = 320, _vy = 0;
  double _scroll = 0;
  int _next = 0;
  int passed = 0, perfect = 0, _perfectRow = 0;
  bool _started = false;

  double _pipeX(int i) => 420 + i * spacing - _scroll;

  double _gapY(int i, double atScroll) {
    final p = _pipes[i % _pipes.length];
    // Pipes start moving after 60 s.
    if (elapsed < 60) return p.gapY;
    return p.gapY +
        p.swing * math.sin(2 * math.pi * (elapsed - 60) / p.period + i);
  }

  @override
  Color get backgroundColor => const Color(0xFF4FC3F7);

  @override
  Offset get focus => Offset(birdX, _y);

  @override
  void onPointer(PointerPhase phase, int pointer, Offset pos) {
    if (phase != PointerPhase.down) return;
    _started = true;
    _vy = -_flap;
    cue(sfx: Sfx.whoosh, haptic: Haptic.selection);
  }

  @override
  void tick() {
    tickParticles();
    if (!_started) {
      _y = 320 + 8 * math.sin(elapsed * 4);
      return;
    }
    _vy += _gravity * stepDt;
    _y += _vy * stepDt;
    _scroll += _speed * stepDt;
    if (_y > ground - 12 || _y < top + 12) return _crash();
    for (var i = math.max(0, _next - 1); i <= _next + 1; i++) {
      final x = _pipeX(i);
      if (birdX + 12 > x && birdX - 12 < x + pipeW) {
        final gy = _gapY(i, _scroll);
        final half = _pipes[i % _pipes.length].gap / 2;
        if (_y - 11 < gy - half || _y + 11 > gy + half) return _crash();
      }
    }
    if (birdX - 12 > _pipeX(_next) + pipeW) {
      final gy = _gapY(_next, _scroll);
      passed++;
      if ((_y - gy).abs() < 14) {
        perfect++;
        _perfectRow++;
        score += 150;
        particles.burst(
          Offset(birdX, _y),
          const Color(0xFFFFD23F),
          count: 10,
          gravity: 0,
        );
        cue(sfx: Sfx.score, haptic: Haptic.light);
        if (_perfectRow == 5) celebrate('perfectFlight');
      } else {
        _perfectRow = 0;
        score += 100;
        cue(sfx: Sfx.tap);
      }
      _next++;
    }
  }

  void _crash() {
    over = true;
    particles.burst(Offset(birdX, _y), const Color(0xFFFFD23F), count: 30);
    cue(sfx: Sfx.hit, haptic: Haptic.heavy);
  }

  @override
  Map<String, num> get stats => {'pipes': passed, 'perfect': perfect};

  @override
  void render(Canvas canvas) {
    canvas.drawRect(
      Arena.rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF4FC3F7), Color(0xFFB3E5FC)],
        ).createShader(Arena.rect),
    );
    // Parallax clouds.
    for (var i = 0; i < 6; i++) {
      final x = (i * 140 - _scroll * 0.3) % 500 - 70;
      canvas.drawOval(
        Rect.fromLTWH(x, 130 + (i % 3) * 70.0, 80, 26),
        Paint()..color = Colors.white70,
      );
    }
    for (var i = math.max(0, _next - 1); i < _next + 3; i++) {
      final x = _pipeX(i);
      final gy = _gapY(i, _scroll);
      final half = _pipes[i % _pipes.length].gap / 2;
      const c = Color(0xFF43A047);
      drawBox(
        canvas,
        Rect.fromLTRB(x, top, x + pipeW, gy - half),
        c,
        radius: 4,
      );
      drawBox(
        canvas,
        Rect.fromLTRB(x, gy + half, x + pipeW, ground),
        c,
        radius: 4,
      );
      for (final y in [gy - half - 16, gy + half]) {
        drawBox(
          canvas,
          Rect.fromLTWH(x - 4, y, pipeW + 8, 16),
          const Color(0xFF66BB6A),
          radius: 4,
        );
      }
    }
    canvas.drawRect(
      const Rect.fromLTRB(0, ground, 360, 640),
      Paint()..color = const Color(0xFFD7B98E),
    );
    // Bird.
    final angle = (_vy / 900).clamp(-0.5, 1.0);
    canvas
      ..save()
      ..translate(birdX, _y)
      ..rotate(angle);
    drawBall(canvas, Offset.zero, 13, const Color(0xFFFFD23F));
    canvas
      ..drawCircle(const Offset(5, -4), 4, Paint()..color = Colors.white)
      ..drawCircle(const Offset(6, -4), 2, Paint()..color = Colors.black)
      ..drawPath(
        Path()
          ..moveTo(11, 0)
          ..lineTo(20, 3)
          ..lineTo(11, 6)
          ..close(),
        Paint()..color = const Color(0xFFE8322F),
      )
      ..drawOval(
        Rect.fromCenter(
          center: Offset(-4, 3 + (step % 20 < 10 ? -3 : 3)),
          width: 12,
          height: 7,
        ),
        Paint()..color = const Color(0xFFFFB300),
      )
      ..restore();
    if (!_started) {
      drawText(
        canvas,
        '👆',
        const Offset(180, 420),
        size: 34,
        align: TextAlign.center,
      );
    }
    drawText(
      canvas,
      '$passed',
      const Offset(180, 110),
      size: 30,
      display: true,
      align: TextAlign.center,
    );
  }
}
