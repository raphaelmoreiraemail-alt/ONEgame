import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';

import '../../core/l10n/l10n.dart';
import '../../core/rng/seeded_random.dart';
import '../common/draw.dart';
import '../common/fingerprint.dart';
import '../common/game_sim.dart';
import '../common/game_types.dart';
import '../common/mini_game_definition.dart';
import '../common/render3d.dart';

/// 7.13 Fléchettes — 9 darts, hold to aim (drifting sight), release to throw.
class DartsGame extends MiniGameDefinition {
  const DartsGame();

  @override
  String get id => 'darts';
  @override
  String get emoji => '🎯';
  @override
  GameCategory get category => GameCategory.adresse;
  @override
  int get rulesVersion => 1;
  @override
  Set<String> get supportedModifiers => {Modifiers.wind, Modifiers.night};
  @override
  ScoreBounds get scoreBounds => const ScoreBounds(0, 9 * 60 * 10 + 3 * 500);

  @override
  Map<String, num> get defaultTuning => const {
    'drift': 9,
    'driftHz': 1.3,
    'aimOffset': 90,
  };

  @override
  String name(AppLocalizations l10n) => l10n.gameDartsName;
  @override
  String rule(AppLocalizations l10n) => l10n.gameDartsRule;

  @override
  String shareLine(AppLocalizations l10n, Map<String, num> s) =>
      l10n.gameDartsShare(
        s['points']?.toInt() ?? 0,
        s['triples']?.toInt() ?? 0,
        s['bulls']?.toInt() ?? 0,
      );

  @override
  List<(String, String)> statRows(AppLocalizations l10n, Map<String, num> s) =>
      [
        (l10n.statPoints, '${s['points'] ?? 0}'),
        (l10n.statTriples, '${s['triples'] ?? 0}'),
        (l10n.statBulls, '${s['bulls'] ?? 0}'),
        (l10n.statBestTurn, '${s['bestTurn'] ?? 0}'),
      ];

  @override
  Map<String, String> highlightLabels(AppLocalizations l10n) => {
    'oneEighty': l10n.highlightOneEighty,
  };

  @override
  GameSim createSim(GameContext ctx) => DartsSim(ctx, this);

  @override
  String levelFingerprint(int seed, String? modifierId) {
    final ctx = GameContext(seed: seed, modifierId: modifierId);
    final d = Drift(ctx, 9, 1.3);
    return fingerprint([
      for (var dart = 0; dart < 9; dart++)
        for (final t in [0.0, 0.7, 1.9]) ...[
          d.at(dart, t).dx,
          d.at(dart, t).dy,
        ],
      DartsSim.windFor(ctx).dx,
    ]);
  }
}

/// Smoothed 1D value noise per axis and per dart, from the seed.
class Drift {
  Drift(this.ctx, this.amplitude, this.hz);

  final GameContext ctx;
  final double amplitude;
  final double hz;
  final Map<int, List<double>> _knots = {};

  List<double> _for(int dart) => _knots.putIfAbsent(dart, () {
    final r = SeededRandom.derive(ctx.seed, 'darts:drift$dart');
    return [for (var i = 0; i < 400; i++) r.doubleInRange(-1, 1)];
  });

  double _noise(List<double> k, double x) {
    final i = x.floor();
    final f = x - i;
    final s = f * f * (3 - 2 * f);
    final a = k[i % k.length];
    final b = k[(i + 1) % k.length];
    return a + (b - a) * s;
  }

  /// Sight offset after holding for [t] seconds.
  Offset at(int dart, double t) {
    final k = _for(dart);
    final x = t * hz;
    // Hold longer than 3 s: the hand gets shakier.
    final shake = 1 + math.max(0, t - 3) * 0.6;
    return Offset(_noise(k, x), _noise(k, x + 137.5)) * amplitude * shake;
  }
}

/// Standard dartboard geometry (radii in board units, 170 = double outer).
abstract final class Board {
  static const Offset center = Offset(180, 290);
  static const double radius = 150;
  static const List<int> sectors = [
    20,
    1,
    18,
    4,
    13,
    6,
    10,
    15,
    2,
    17,
    3,
    19,
    7,
    16,
    8,
    11,
    14,
    9,
    12,
    5,
  ];
  static double _r(double mm) => mm / 170 * radius;
  static final double bullIn = _r(6.35);
  static final double bullOut = _r(15.9);
  static final double tripleIn = _r(99);
  static final double tripleOut = _r(107);
  static final double doubleIn = _r(162);
  static final double doubleOut = _r(170);

  /// (points, multiplier, sector) where sector is 25 for the bull.
  static (int, int, int) score(Offset p) {
    final d = p - center;
    final r = d.distance;
    if (r <= bullIn) return (50, 2, 25);
    if (r <= bullOut) return (25, 1, 25);
    if (r > doubleOut) return (0, 0, 0);
    // Angle clockwise from the top, sector 20 centered on 0.
    var a = math.atan2(d.dx, -d.dy) * 180 / math.pi;
    a = (a + 9 + 360) % 360;
    final sector = sectors[(a ~/ 18) % 20];
    final mult = r >= doubleIn ? 2 : (r >= tripleIn && r <= tripleOut ? 3 : 1);
    return (sector * mult, mult, sector);
  }
}

class _Dart {
  _Dart(this.at, this.points);

  final Offset at;
  final int points;
}

class DartsSim extends GameSim {
  DartsSim(super.ctx, DartsGame def)
    : _drift = Drift(
        ctx,
        ctx.tune('drift', def.defaultTuning['drift']!),
        ctx.tune('driftHz', def.defaultTuning['driftHz']!),
      ),
      _aimOffset = ctx.tune('aimOffset', def.defaultTuning['aimOffset']!),
      wind = windFor(ctx);

  static const int totalDarts = 9;

  static Offset windFor(GameContext ctx) {
    if (!ctx.has(Modifiers.wind)) return Offset.zero;
    final r = SeededRandom.derive(ctx.seed, 'darts:wind');
    return Offset(r.doubleInRange(-14, 14), r.doubleInRange(-6, 6));
  }

  final Drift _drift;
  final double _aimOffset;
  final Offset wind;

  int thrown = 0;
  int points = 0;
  int triples = 0;
  int bulls = 0;
  int bestTurn = 0;
  int _turn = 0;
  final List<_Dart> _onBoard = [];

  int? _pointer;
  Offset _finger = Offset.zero;
  int _holdStart = 0;
  int _flight = 0;
  Offset? _flyingTo;
  int _pullIn = 0;

  Offset get _sight =>
      _finger.translate(0, -_aimOffset) +
      _drift.at(thrown, (step - _holdStart) / stepsPerSecond);

  @override
  Color get backgroundColor => const Color(0xFF263238);

  @override
  Offset get focus => _pointer != null ? _sight : Board.center;

  @override
  void onPointer(PointerPhase phase, int pointer, Offset pos) {
    if (thrown >= totalDarts || _flight > 0 || _pullIn > 0) return;
    switch (phase) {
      case PointerPhase.down:
        if (_pointer != null) return;
        _pointer = pointer;
        _finger = pos;
        _holdStart = step;
      case PointerPhase.move:
        if (pointer == _pointer) _finger = pos;
      case PointerPhase.up:
        if (pointer != _pointer) return;
        _pointer = null;
        _finger = pos;
        _flyingTo = _sight + wind;
        _flight = (0.22 * stepsPerSecond).round();
        cue(sfx: Sfx.whoosh, haptic: Haptic.light);
    }
  }

  @override
  void tick() {
    tickParticles();
    if (_flight > 0 && --_flight == 0) _land(_flyingTo!);
    if (_pullIn > 0 && --_pullIn == 0) {
      _onBoard.clear();
      if (thrown >= totalDarts) over = true;
    }
  }

  void _land(Offset at) {
    final (pts, mult, sector) = Board.score(at);
    _onBoard.add(_Dart(at, pts));
    thrown++;
    points += pts;
    _turn += pts;
    if (mult == 3) triples++;
    if (sector == 25) bulls++;
    score += pts * 10;
    if (pts > 0) {
      cue(sfx: mult >= 2 ? Sfx.score : Sfx.hit, haptic: Haptic.light);
      particles.burst(
        at,
        const Color(0xFFFFD23F),
        count: mult * 5,
        gravity: 0,
        speed: 120,
      );
    } else {
      cue(sfx: Sfx.miss);
    }
    if (_onBoard.length == 3) {
      bestTurn = math.max(bestTurn, _turn);
      if (_turn == 180) {
        score += 500;
        celebrate('oneEighty');
        particles.fireworks(Board.center);
      }
      _turn = 0;
      _pullIn = stepsPerSecond; // show the turn for 1 s
    } else if (thrown >= totalDarts) {
      _pullIn = stepsPerSecond;
    }
  }

  @override
  Map<String, num> get stats => {
    'points': points,
    'darts': thrown,
    'triples': triples,
    'bulls': bulls,
    'bestTurn': bestTurn,
  };

  // ── 3D rendering ──────────────────────────────────────────────────────
  // The board plane (z = 0) maps 1:1 to arena coordinates; darts stick out
  // towards the player (+z) and get real perspective.
  static final double _focal = 320 / math.tan(25 * math.pi / 180);
  static final Camera3D _camera = Camera3D(
    eye: V3(180, 0, _focal),
    target: const V3(180, 0, 0),
  );
  static V3 _p(Offset o, [double z = 0]) => V3(o.dx, 320 - o.dy, z);
  static const V3 _stuckDir = V3(0.2, 0.45, 1);
  static ui.Picture? _boardPicture;

  @override
  void render(Canvas canvas) {
    _drawRoom(canvas);
    canvas.drawPicture(_boardPicture ??= _recordBoard());
    // Soft shadows of the darts on the board (light from the top left).
    final shade = Paint()
      ..color = const Color(0x66000000)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    for (final d in _onBoard) {
      canvas.drawLine(d.at, d.at.translate(22, 60), shade);
    }
    final s = Scene3D(_camera, light: const V3(-0.4, 0.8, 0.9), ambient: 0.45);
    for (final d in _onBoard) {
      _dart3d(s, _p(d.at), _stuckDir);
    }
    if (_flight > 0 && _flyingTo != null) {
      final t = 1 - _flight / (0.22 * stepsPerSecond);
      final to = _p(_flyingTo!);
      final from = V3(to.x * 0.7 + 54, to.y - 160, 430);
      final arc = math.sin(t * math.pi) * 40;
      final tip = from + (to - from) * t + V3(0, arc, 0);
      _dart3d(s, tip, V3(0, 0.15 - 0.3 * t, 1));
    }
    // Darts left, standing in a rack at the bottom.
    for (var i = 0; i < totalDarts - thrown; i++) {
      _dart3d(
        s,
        _p(Offset(26 + i * 15.0, 632), 30),
        const V3(0.05, 1, 0.25),
        scale: 0.5,
      );
    }
    s.render(canvas);
    if (_pointer != null) {
      final sight = _sight;
      final p = Paint()
        ..color = const Color(0xFF00E676)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;
      canvas
        ..drawCircle(sight, 10, p)
        ..drawLine(sight.translate(-16, 0), sight.translate(16, 0), p)
        ..drawLine(sight.translate(0, -16), sight.translate(0, 16), p);
    } else if (thrown < totalDarts && _pullIn == 0) {
      drawText(
        canvas,
        '☝️',
        const Offset(180, 540),
        size: 32,
        align: TextAlign.center,
      );
    }
    if (_onBoard.isNotEmpty) {
      drawText(
        canvas,
        _onBoard.map((d) => '${d.points}').join(' + '),
        const Offset(180, 480),
        size: 18,
        display: true,
        align: TextAlign.center,
      );
    }
    if (wind != Offset.zero) {
      drawWind(canvas, const Offset(320, 470), wind, max: 15);
    }
  }

  /// Pub wall: wood panelling, a spotlight on the board, the oche shelf.
  void _drawRoom(Canvas c) {
    c.drawRect(Arena.rect, Paint()..color = const Color(0xFF2A1B14));
    for (var i = 0; i < 9; i++) {
      final x = i * 42.0 - 8;
      c
        ..drawRect(
          Rect.fromLTWH(x, 0, 40, 600),
          Paint()
            ..color = tint(
              const Color(0xFF4A2F22),
              (cellNoise(i, 3) - 0.5) * 0.2,
            ),
        )
        ..drawRect(
          Rect.fromLTWH(x + 40, 0, 2, 600),
          Paint()..color = const Color(0xFF1A100B),
        );
    }
    c
      ..drawRect(
        const Rect.fromLTWH(0, 600, 360, 40),
        Paint()..color = const Color(0xFF1C120D),
      )
      ..drawRect(
        const Rect.fromLTWH(0, 598, 360, 4),
        Paint()..color = const Color(0xFF6D4C41),
      )
      // Warm spotlight from above, dark corners.
      ..drawRect(
        Arena.rect,
        Paint()
          ..shader = const RadialGradient(
            center: Alignment(0, -0.2),
            radius: 0.95,
            colors: [Color(0x40FFE0B2), Color(0x00000000), Color(0xB0000000)],
            stops: [0, 0.45, 1],
          ).createShader(Arena.rect),
      );
  }

  /// The board never changes: record it once (sisal, wires, numbers).
  static ui.Picture _recordBoard() {
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    const ctr = Board.center;
    // Cast shadow on the wall, then the black catch ring.
    c
      ..drawCircle(
        ctr.translate(10, 18),
        Board.radius + 26,
        Paint()
          ..color = const Color(0xA0000000)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
      )
      ..drawCircle(
        ctr,
        Board.radius + 24,
        Paint()
          ..shader =
              const RadialGradient(
                colors: [
                  Color(0xFF2B2B2B),
                  Color(0xFF151515),
                  Color(0xFF050505),
                ],
                stops: [0.8, 0.95, 1],
              ).createShader(
                Rect.fromCircle(center: ctr, radius: Board.radius + 24),
              ),
      );
    for (var i = 0; i < 20; i++) {
      final start = (-90 - 9 + i * 18) * math.pi / 180;
      const sweep = 18 * math.pi / 180;
      final dark = i.isEven;
      void ring(double r1, double r2, Color col) {
        final path = Path()
          ..arcTo(Rect.fromCircle(center: ctr, radius: r2), start, sweep, true)
          ..arcTo(
            Rect.fromCircle(center: ctr, radius: r1),
            start + sweep,
            -sweep,
            false,
          )
          ..close();
        c.drawPath(path, Paint()..color = col);
      }

      final base = dark ? const Color(0xFF1C1A18) : const Color(0xFFE9D9B4);
      final special = dark ? const Color(0xFFC62828) : const Color(0xFF1B7F3B);
      ring(Board.bullOut, Board.tripleIn, base);
      ring(Board.tripleIn, Board.tripleOut, special);
      ring(Board.tripleOut, Board.doubleIn, base);
      ring(Board.doubleIn, Board.doubleOut, special);
      final a = (-90 + i * 18) * math.pi / 180;
      drawText(
        c,
        '${Board.sectors[i]}',
        ctr + Offset(math.cos(a), math.sin(a)) * (Board.radius + 12),
        size: 12,
        display: true,
        color: const Color(0xFFE0E0E0),
        align: TextAlign.center,
      );
    }
    c
      ..drawCircle(ctr, Board.bullOut, Paint()..color = const Color(0xFF1B7F3B))
      ..drawCircle(ctr, Board.bullIn, Paint()..color = const Color(0xFFC62828));
    // Sisal fibres: tiny deterministic flecks.
    final light = Paint()..color = const Color(0x22FFFFFF);
    final dark = Paint()..color = const Color(0x26000000);
    for (var k = 0; k < 1400; k++) {
      final r = math.sqrt(cellNoise(k, 1, 77)) * Board.doubleOut;
      final a = cellNoise(k, 2, 77) * 2 * math.pi;
      final p = ctr + Offset(math.cos(a), math.sin(a)) * r;
      c.drawCircle(p, 0.6 + cellNoise(k, 3, 77), k.isEven ? light : dark);
    }
    // Wire spider: rings and radial wires, with a highlight.
    final wire = Paint()
      ..color = const Color(0xFFCFD8DC)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;
    for (final r in [
      Board.bullIn,
      Board.bullOut,
      Board.tripleIn,
      Board.tripleOut,
      Board.doubleIn,
      Board.doubleOut,
    ]) {
      c.drawCircle(ctr, r, wire);
    }
    for (var i = 0; i < 20; i++) {
      final a = (-90 - 9 + i * 18) * math.pi / 180;
      final d = Offset(math.cos(a), math.sin(a));
      c.drawLine(ctr + d * Board.bullOut, ctr + d * Board.doubleOut, wire);
    }
    // Spotlight sheen on the board face.
    c.drawCircle(
      ctr,
      Board.radius + 24,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.35, -0.45),
          radius: 1.1,
          colors: [Color(0x30FFFFFF), Color(0x00FFFFFF), Color(0x40000000)],
          stops: [0, 0.55, 1],
        ).createShader(Rect.fromCircle(center: ctr, radius: Board.radius + 24)),
    );
    return rec.endRecording();
  }

  /// A steel-tip dart: point, tungsten barrel, shaft and four flights.
  /// [tip] is the point, [dir] goes from the point towards the flights.
  static void _dart3d(Scene3D s, V3 tip, V3 dir, {double scale = 1}) {
    final d = dir.normalized;
    V3 at(double l) => tip + d * (l * scale);
    const steel = Color(0xFFB0BEC5);
    const tungsten = Color(0xFF78909C);
    const grip = Color(0xFF455A64);
    const shaft = Color(0xFF212121);
    const flight = Color(0xFFE8322F);
    s
      ..tube(at(0), at(16), 0.2 * scale, 1.1 * scale, steel, segments: 6)
      ..tube(at(16), at(22), 2.2 * scale, 2.7 * scale, tungsten)
      ..tube(at(22), at(32), 2.7 * scale, 2.7 * scale, grip)
      ..tube(at(32), at(44), 2.7 * scale, 2.0 * scale, tungsten)
      ..tube(at(44), at(72), 1.3 * scale, 1.3 * scale, shaft, segments: 6);
    // Flights: two crossed kite shapes.
    final helper = d.y.abs() < 0.9 ? const V3(0, 1, 0) : const V3(1, 0, 0);
    final u = d.cross(helper).normalized;
    final v = d.cross(u);
    for (final side in [u, v, u * -1, v * -1]) {
      s.quad(
        at(60),
        at(66) + side * (9 * scale),
        at(82) + side * (11 * scale),
        at(84),
        flight,
        doubleSided: true,
      );
    }
  }
}
