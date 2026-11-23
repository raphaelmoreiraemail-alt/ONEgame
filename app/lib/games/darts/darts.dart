import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../core/l10n/l10n.dart';
import '../../core/rng/seeded_random.dart';
import '../common/draw.dart';
import '../common/fingerprint.dart';
import '../common/game_sim.dart';
import '../common/game_types.dart';
import '../common/mini_game_definition.dart';

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

  @override
  void render(Canvas canvas) {
    canvas.drawRect(
      Arena.rect,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xFF37474F), Color(0xFF1C262B)],
        ).createShader(Rect.fromCircle(center: Board.center, radius: 360)),
    );
    _drawBoard(canvas);
    for (final d in _onBoard) {
      _drawDart(canvas, d.at, 1);
    }
    if (_flight > 0 && _flyingTo != null) {
      final t = 1 - _flight / (0.22 * stepsPerSecond);
      final from = _flyingTo!.translate(0, 220);
      _drawDart(canvas, Offset.lerp(from, _flyingTo!, t)!, 1.6 - 0.6 * t);
    }
    if (_pointer != null) {
      final s = _sight;
      final p = Paint()
        ..color = const Color(0xFF00E676)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;
      canvas
        ..drawCircle(s, 10, p)
        ..drawLine(s.translate(-16, 0), s.translate(16, 0), p)
        ..drawLine(s.translate(0, -16), s.translate(0, 16), p);
    } else if (thrown < totalDarts && _pullIn == 0) {
      drawText(
        canvas,
        '☝️',
        const Offset(180, 560),
        size: 32,
        align: TextAlign.center,
      );
    }
    // Remaining darts.
    for (var i = 0; i < totalDarts - thrown; i++) {
      _drawDart(canvas, Offset(30 + i * 16.0, 610), 0.7);
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

  void _drawBoard(Canvas c) {
    const ctr = Board.center;
    c.drawCircle(
      ctr,
      Board.radius + 18,
      Paint()..color = const Color(0xFF111111),
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

      final base = dark ? const Color(0xFF1B1B1B) : const Color(0xFFF1E3C8);
      final special = dark ? const Color(0xFFD32F2F) : const Color(0xFF2E7D32);
      ring(Board.bullOut, Board.tripleIn, base);
      ring(Board.tripleIn, Board.tripleOut, special);
      ring(Board.tripleOut, Board.doubleIn, base);
      ring(Board.doubleIn, Board.doubleOut, special);
      final a = (-90 + i * 18) * math.pi / 180;
      drawText(
        c,
        '${Board.sectors[i]}',
        ctr + Offset(math.cos(a), math.sin(a)) * (Board.radius + 10),
        size: 11,
        align: TextAlign.center,
      );
    }
    c
      ..drawCircle(ctr, Board.bullOut, Paint()..color = const Color(0xFF2E7D32))
      ..drawCircle(ctr, Board.bullIn, Paint()..color = const Color(0xFFD32F2F));
  }

  void _drawDart(Canvas c, Offset at, double scale) {
    final p = Paint()
      ..color = const Color(0xFFFFD23F)
      ..strokeWidth = 3 * scale
      ..strokeCap = StrokeCap.round;
    c
      ..drawLine(at, at.translate(6 * scale, 22 * scale), p)
      ..drawPath(
        Path()
          ..moveTo(at.dx + 6 * scale, at.dy + 18 * scale)
          ..lineTo(at.dx + 13 * scale, at.dy + 28 * scale)
          ..lineTo(at.dx + 1 * scale, at.dy + 28 * scale)
          ..close(),
        Paint()..color = const Color(0xFFE8322F),
      )
      ..drawCircle(at, 2 * scale, Paint()..color = Colors.white);
  }
}
