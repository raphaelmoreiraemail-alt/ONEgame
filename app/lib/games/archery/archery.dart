import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../core/l10n/l10n.dart';
import '../../core/rng/seeded_random.dart';
import '../common/draw.dart';
import '../common/fingerprint.dart';
import '../common/game_sim.dart';
import '../common/game_types.dart';
import '../common/mini_game_definition.dart';
import '../darts/darts.dart' show Drift;

/// 7.10 Tir à l'arc — 10 arrows, wind, targets further away, moving at the end.
class ArcheryGame extends MiniGameDefinition {
  const ArcheryGame();

  @override
  String get id => 'archery';
  @override
  String get emoji => '🏹';
  @override
  GameCategory get category => GameCategory.sport;
  @override
  int get rulesVersion => 1;
  @override
  Set<String> get supportedModifiers => {Modifiers.wind};
  @override
  ScoreBounds get scoreBounds => const ScoreBounds(0, ArcherySim.arrows * 150);

  @override
  Map<String, num> get defaultTuning => const {
    'drift': 7,
    'driftHz': 1.1,
    'minDraw': 70,
  };

  @override
  String name(AppLocalizations l10n) => l10n.gameArcheryName;
  @override
  String rule(AppLocalizations l10n) => l10n.gameArcheryRule;

  @override
  String shareLine(AppLocalizations l10n, Map<String, num> s) =>
      l10n.gameArcheryShare(
        s['points']?.toInt() ?? 0,
        s['bullseyes']?.toInt() ?? 0,
      );

  @override
  List<(String, String)> statRows(AppLocalizations l10n, Map<String, num> s) =>
      [
        (l10n.statPoints, '${s['points'] ?? 0} / 100'),
        (l10n.statBullseyes, '${s['bullseyes'] ?? 0}'),
        (l10n.statArrows, '${s['arrows'] ?? 0} / ${ArcherySim.arrows}'),
      ];

  @override
  Map<String, String> highlightLabels(AppLocalizations l10n) => {
    'mouche': l10n.highlightMouche,
  };

  @override
  GameSim createSim(GameContext ctx) => ArcherySim(ctx, this);

  @override
  String levelFingerprint(int seed, String? modifierId) => fingerprint([
    for (final e in ArcheryRange.generate(
      GameContext(seed: seed, modifierId: modifierId),
    )) ...[e.radius, e.wind.dx, e.wind.dy, e.swing, e.period],
  ]);
}

/// One end: target size (distance), wind, movement.
class ArcheryRange {
  const ArcheryRange(this.radius, this.wind, this.swing, this.period);

  final double radius;

  /// Deflection (px) at full flight.
  final Offset wind;

  /// Horizontal movement amplitude (0 = still).
  final double swing;
  final double period;

  static List<ArcheryRange> generate(GameContext ctx) {
    final r = SeededRandom.derive(ctx.seed, 'archery:range');
    final strong = ctx.has(Modifiers.wind) ? 2.0 : 1.0;
    return [
      for (var i = 0; i < ArcherySim.arrows; i++)
        ArcheryRange(
          72 - i * 4.0,
          Offset(r.doubleInRange(-12, 12), r.doubleInRange(-5, 5)) * strong,
          i >= ArcherySim.arrows - 3 ? r.doubleInRange(40, 80) : 0,
          r.doubleInRange(1.6, 2.6),
        ),
    ];
  }
}

class ArcherySim extends GameSim {
  ArcherySim(super.ctx, ArcheryGame def)
    : range = ArcheryRange.generate(ctx),
      _drift = Drift(
        ctx,
        ctx.tune('drift', def.defaultTuning['drift']!),
        ctx.tune('driftHz', def.defaultTuning['driftHz']!),
      ),
      _minDraw = ctx.tune('minDraw', def.defaultTuning['minDraw']!);

  static const int arrows = 10;
  static const Offset targetHome = Offset(180, 250);

  final List<ArcheryRange> range;
  final Drift _drift;
  final double _minDraw;

  int shot = 0;
  int points = 0;
  int bullseyes = 0;
  final List<(Offset, int)> _hits = [];

  int? _pointer;
  Offset _start = Offset.zero;
  Offset _finger = Offset.zero;
  int _drawStart = 0;
  int _flight = 0;
  Offset _landing = Offset.zero;
  bool _short = false;
  int _show = 0;

  ArcheryRange get _r => range[math.min(shot, arrows - 1)];

  Offset get targetCenter => targetHome.translate(
    _r.swing * math.sin(2 * math.pi * elapsed / _r.period),
    0,
  );

  double get _draw => (_finger - _start).distance;

  /// Nominal draw: pulling exactly this far down aims at the center height;
  /// less aims low, more aims high. Left / right are mirrored like a bow.
  static const double nominalDraw = 110;

  Offset get _sight {
    final pull = _finger - _start;
    return targetHome +
        Offset(-pull.dx * 0.9, -(pull.dy - nominalDraw) * 0.9) +
        _drift.at(shot, (step - _drawStart) / stepsPerSecond);
  }

  @override
  Color get backgroundColor => const Color(0xFF81C784);

  @override
  void onPointer(PointerPhase phase, int pointer, Offset pos) {
    if (shot >= arrows || _flight > 0 || _show > 0) return;
    switch (phase) {
      case PointerPhase.down:
        if (_pointer != null) return;
        _pointer = pointer;
        _start = pos;
        _finger = pos;
        _drawStart = step;
      case PointerPhase.move:
        if (pointer == _pointer) _finger = pos;
      case PointerPhase.up:
        if (pointer != _pointer) return;
        _pointer = null;
        _finger = pos;
        _short = _draw < _minDraw;
        // Pulling down moves the sight up (like a bow); a weak draw drops.
        final aim = _sight;
        _landing = Offset(aim.dx, aim.dy + (_short ? 140 : 0)) + _r.wind;
        _flight = (0.45 * stepsPerSecond).round();
        cue(sfx: Sfx.whoosh, haptic: Haptic.light);
    }
  }

  @override
  void tick() {
    tickParticles();
    if (_show > 0 && --_show == 0) {
      shot++;
      if (shot >= arrows) over = true;
    }
    if (_flight > 0 && --_flight == 0) _land();
  }

  void _land() {
    // Ring from the distance to the (possibly moving) target center.
    final d = (_landing - targetCenter).distance / _r.radius;
    int pts;
    if (d <= 0.06) {
      pts = 150;
      bullseyes++;
      celebrate('mouche');
      particles.fireworks(_landing);
    } else if (d <= 1) {
      final ring = 10 - (d * 10).floor();
      pts = ring.clamp(1, 10) * 10;
      cue(sfx: ring >= 8 ? Sfx.score : Sfx.hit, haptic: Haptic.light);
    } else {
      pts = 0;
      cue(sfx: Sfx.miss);
    }
    points += pts == 150 ? 10 : pts ~/ 10;
    score += pts;
    _hits.add((_landing - targetCenter, pts));
    _show = (0.8 * stepsPerSecond).round();
  }

  @override
  Map<String, num> get stats => {
    'points': points,
    'bullseyes': bullseyes,
    'arrows': math.min(shot, arrows),
  };

  @override
  void render(Canvas canvas) {
    canvas.drawRect(
      Arena.rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF90CAF9),
            Color(0xFFB3E5FC),
            Color(0xFF81C784),
            Color(0xFF66BB6A),
          ],
          stops: [0, 0.3, 0.32, 1],
        ).createShader(Arena.rect),
    );
    final c = targetCenter;
    final rad = _r.radius;
    canvas.drawRect(
      Rect.fromCenter(center: c.translate(0, rad + 30), width: 8, height: 60),
      Paint()..color = const Color(0xFF6D4C41),
    );
    const colors = [
      Colors.white,
      Colors.white,
      Color(0xFF212121),
      Color(0xFF212121),
      Color(0xFF1E88E5),
      Color(0xFF1E88E5),
      Color(0xFFE53935),
      Color(0xFFE53935),
      Color(0xFFFFD23F),
      Color(0xFFFFD23F),
    ];
    drawShadowCircle(canvas, c, rad);
    for (var i = 0; i < 10; i++) {
      canvas.drawCircle(c, rad * (1 - i / 10), Paint()..color = colors[i]);
    }
    canvas.drawCircle(c, rad * 0.06, Paint()..color = const Color(0xFFE8322F));
    for (final (off, _)
        in _hits.length > 3 ? _hits.sublist(_hits.length - 3) : _hits) {
      _arrowHead(canvas, c + off);
    }
    if (_flight > 0) {
      final t = 1 - _flight / (0.45 * stepsPerSecond);
      _arrowHead(
        canvas,
        Offset.lerp(const Offset(180, 600), _landing, t)!,
        scale: 2 - t,
      );
    }
    if (_pointer != null) {
      final s = _sight;
      final p = Paint()
        ..color = _draw < _minDraw ? Colors.white54 : const Color(0xFFE8322F)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;
      canvas
        ..drawCircle(s, 9, p)
        ..drawLine(s.translate(-14, 0), s.translate(14, 0), p)
        ..drawLine(s.translate(0, -14), s.translate(0, 14), p);
      // Bow string.
      final pull = (_finger - _start).dy.clamp(0.0, 120.0);
      final bow = Paint()
        ..color = const Color(0xFF5D4037)
        ..strokeWidth = 6
        ..style = PaintingStyle.stroke;
      canvas
        ..drawArc(
          Rect.fromCenter(
            center: const Offset(180, 560),
            width: 160,
            height: 80,
          ),
          math.pi,
          math.pi,
          false,
          bow,
        )
        ..drawLine(
          const Offset(100, 560),
          Offset(180, 560 + pull * 0.4),
          Paint()
            ..color = Colors.white
            ..strokeWidth = 2,
        )
        ..drawLine(
          const Offset(260, 560),
          Offset(180, 560 + pull * 0.4),
          Paint()
            ..color = Colors.white
            ..strokeWidth = 2,
        );
    } else if (shot < arrows && _flight == 0 && _show == 0) {
      drawText(
        canvas,
        '👇',
        const Offset(180, 560),
        size: 32,
        align: TextAlign.center,
      );
    }
    if (_r.wind.distance > 4) {
      drawWind(canvas, const Offset(320, 110), _r.wind, max: 24);
    }
    drawText(
      canvas,
      '🏹 ${math.max(0, arrows - shot)}',
      const Offset(16, 100),
      size: 16,
    );
    if (_show > 0 && _hits.isNotEmpty) {
      drawText(
        canvas,
        _hits.last.$2 == 150 ? '★' : '${_hits.last.$2 ~/ 10}',
        const Offset(180, 420),
        size: 40,
        display: true,
        align: TextAlign.center,
        color: const Color(0xFFFFD23F),
      );
    }
  }

  void _arrowHead(Canvas c, Offset p, {double scale = 1}) {
    c
      ..drawCircle(p, 3 * scale, Paint()..color = const Color(0xFF3E2723))
      ..drawLine(
        p,
        p.translate(0, 10 * scale),
        Paint()
          ..color = const Color(0xFFE8322F)
          ..strokeWidth = 2 * scale,
      );
  }
}
