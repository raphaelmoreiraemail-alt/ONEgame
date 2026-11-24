import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../core/l10n/l10n.dart';
import '../../core/rng/seeded_random.dart';
import '../common/draw.dart';
import '../common/fingerprint.dart';
import '../common/game_sim.dart';
import '../common/game_types.dart';
import '../common/mini_game_definition.dart';
import '../common/render3d.dart';

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

  // ── 3D rendering ──────────────────────────────────────────────────────
  // The play plane (z = 0) maps 1:1 to arena coordinates; scenery further
  // back scrolls at the same world speed and gets parallax from perspective.
  static final double _focal = 320 / math.tan(25 * math.pi / 180);
  static final Camera3D _camera = Camera3D(
    eye: V3(180, 0, _focal),
    target: const V3(180, 0, 0),
  );
  static V3 _p(double x, double y, [double z = 0]) => V3(x, 320 - y, z);
  static const double _groundH = 320 - ground;

  @override
  void render(Canvas canvas) {
    drawSky(
      canvas,
      Arena.rect,
      const Color(0xFF3FA9F5),
      const Color(0xFFD7F0FB),
    );
    final s = Scene3D(
      _camera,
      light: const V3(-0.35, 0.8, 0.7),
      ambient: 0.5,
      fogColor: const Color(0xFFCDEBF8),
      fogStart: 1200,
      fogEnd: 6000,
    );
    // Ground: scrolling grass strip in front of a meadow.
    const cell = 40.0;
    final shift = _scroll % cell;
    final base = (_scroll / cell).floor();
    s.ground(
      Rect.fromLTRB(-1400 - shift, -2800, 1800 - shift, 300),
      (i, j) {
        final k = i + base;
        final c = j > 66 ? const Color(0xFF7CB342) : const Color(0xFF8BC34A);
        return tint(
          c,
          ((k + j).isEven ? 0.03 : -0.02) + (cellNoise(k, j, 3) - 0.5) * 0.04,
        );
      },
      cell: cell,
      height: _groundH,
    );
    s.box(
      V3(180 - shift, _groundH - 30, 30),
      3200,
      30,
      60,
      const Color(0xFF9C7A4F),
      top: const Color(0xFF7CB342),
      layer: Layer.surface,
    );
    // Rolling hills, trees and clouds far behind (scrolling with the world).
    for (var k = -4; k < 10; k++) {
      final wx = (k * 380.0 - _scroll) % 4560 - 1400;
      final h = 140 + cellNoise(k, 1, 8) * 160;
      s.sphere(
        V3(wx, _groundH - h * 1.3, -2200),
        h * 1.5,
        const Color(0xFF5E9A4A),
        lat: 8,
        lon: 16,
      );
    }
    for (var k = 0; k < 14; k++) {
      final wx = (k * 170.0 + cellNoise(k, 2, 8) * 80 - _scroll) % 2380 - 700;
      final z = -380 - cellNoise(k, 3, 8) * 500;
      final sz = 0.9 + cellNoise(k, 4, 8) * 0.8;
      final b = V3(wx, _groundH, z);
      s
        ..tube(
          b,
          b + V3(0, 46 * sz, 0),
          5 * sz,
          4 * sz,
          const Color(0xFF6D4C41),
          segments: 5,
        )
        ..sphere(
          b + V3(0, 70 * sz, 0),
          30 * sz,
          const Color(0xFF4C8C3F),
          lat: 5,
          lon: 8,
        );
    }
    for (var k = 0; k < 6; k++) {
      final wx = (k * 420.0 - _scroll * 0.6) % 2520 - 800;
      final c = V3(wx, 160 + cellNoise(k, 5, 8) * 160, -1600);
      for (var b = 0; b < 3; b++) {
        s.sphere(
          c + V3(b * 38.0 - 38, (b == 1 ? 14 : 0), 0),
          b == 1 ? 46 : 34,
          const Color(0xFFFFFFFF),
          lat: 4,
          lon: 8,
        );
      }
    }
    // Pipes: real cylinders with lips.
    const pipe = Color(0xFF43A047), lip = Color(0xFF5CBF5F);
    for (var i = math.max(0, _next - 1); i < _next + 3; i++) {
      final cx = _pipeX(i) + pipeW / 2;
      final gy = _gapY(i, _scroll);
      final half = _pipes[i % _pipes.length].gap / 2;
      s
        ..cylinder(
          _p(cx, gy - half - 12),
          pipeW / 2,
          gy - half - 12 + 40,
          pipe,
          segments: 16,
        )
        ..cylinder(_p(cx, gy - half), pipeW / 2 + 5, 18, lip, segments: 16)
        ..cylinder(
          _p(cx, ground + 10),
          pipeW / 2,
          ground + 10 - (gy + half + 12),
          pipe,
          segments: 16,
        )
        ..cylinder(_p(cx, gy + half + 18), pipeW / 2 + 5, 18, lip, segments: 16)
        ..shadow(
          Offset(cx + 6, 10),
          pipeW * 0.7,
          height: _groundH + 0.5,
          opacity: 0.3,
        );
    }
    _bird3d(s);
    s.render(canvas);
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

  /// Round bird: body, belly, flapping wings, beak, eyes; pitches with
  /// its vertical speed.
  void _bird3d(Scene3D s) {
    final angle = (_vy / 900).clamp(-0.5, 1.0);
    final c = _p(birdX, _y);
    final fx = V3(math.cos(angle), -math.sin(angle), 0); // beak direction
    final up = V3(math.sin(angle), math.cos(angle), 0);
    const side = V3(0, 0, 1);
    final flap = math.sin(elapsed * (_started ? 22 : 10)) * 0.9;
    s
      ..shadow(
        Offset(c.x, 10),
        12,
        height: _groundH + 0.6,
        opacity: 0.25 * (1 - ((ground - _y) / 600).clamp(0.0, 0.8)),
      )
      ..sphere(c, 13, const Color(0xFFFFD23F), lat: 7, lon: 12)
      ..sphere(
        c + fx * 4 - up * 5 + side * 4,
        8,
        const Color(0xFFFFF3C4),
        lat: 4,
        lon: 8,
      )
      ..tube(
        c + fx * 11 + up * 1,
        c + fx * 22 - up * 1,
        4.5,
        0,
        const Color(0xFFFF7043),
        segments: 6,
      )
      ..tube(
        c - fx * 10 + up * 2,
        c - fx * 19 + up * 6,
        4,
        1,
        const Color(0xFFFFB300),
        segments: 5,
      );
    for (final z in [8.0, -8.0]) {
      final e = c + fx * 6 + up * 5 + side * z;
      s
        ..sphere(e, 4, const Color(0xFFFFFFFF), lat: 4, lon: 6)
        ..sphere(
          e + fx * 1.8 + side * (z.sign * 2),
          2,
          const Color(0xFF111111),
          lat: 3,
          lon: 5,
        );
    }
    for (final z in [1.0, -1.0]) {
      final root = c - fx * 2 + side * (z * 10);
      final tip =
          root -
          fx * 8 +
          side * (z * 12 * math.cos(flap)) +
          up * (14 * math.sin(flap));
      s.tri(
        root + fx * 6,
        tip,
        root - fx * 8,
        const Color(0xFFFFB300),
        doubleSided: true,
      );
    }
  }
}
