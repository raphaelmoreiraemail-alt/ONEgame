import 'dart:math' as math;

import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/l10n/l10n.dart';
import '../../core/rng/seeded_random.dart';
import '../common/draw.dart';
import '../common/fingerprint.dart';
import '../common/game_sim.dart';
import '../common/game_types.dart';
import '../common/mini_game_definition.dart';
import '../common/physics.dart';

/// 7.12 Billard — pot as many balls as possible in 2 minutes.
class BillardGame extends MiniGameDefinition {
  const BillardGame();

  @override
  String get id => 'billard';
  @override
  String get emoji => '🎱';
  @override
  GameCategory get category => GameCategory.sport;
  @override
  int get rulesVersion => 1;
  @override
  Set<String> get supportedModifiers => {Modifiers.ice};
  @override
  ScoreBounds get scoreBounds => const ScoreBounds(0, 15000);

  @override
  Map<String, num> get defaultTuning => const {'maxShot': 1500, 'damping': 0.9};

  @override
  String name(AppLocalizations l10n) => l10n.gameBillardName;
  @override
  String rule(AppLocalizations l10n) => l10n.gameBillardRule;

  @override
  String shareLine(AppLocalizations l10n, Map<String, num> s) =>
      l10n.gameBillardShare(
        s['potted']?.toInt() ?? 0,
        s['bestSeries']?.toInt() ?? 0,
      );

  @override
  List<(String, String)> statRows(AppLocalizations l10n, Map<String, num> s) =>
      [
        (l10n.statPotted, '${s['potted'] ?? 0} / ${BillardSim.ballCount}'),
        (l10n.statBestSeries, '${s['bestSeries'] ?? 0}'),
        (l10n.statScratches, '${s['scratches'] ?? 0}'),
      ];

  @override
  Map<String, String> highlightLabels(AppLocalizations l10n) => {
    'doublePot': l10n.highlightDoublePot,
  };

  @override
  GameSim createSim(GameContext ctx) => BillardSim(ctx, this);

  @override
  String levelFingerprint(int seed, String? modifierId) => fingerprint([
    for (final b in BillardSim.rack(seed)) ...[b.dx, b.dy],
  ]);
}

class BillardSim extends GameSim {
  BillardSim(super.ctx, BillardGame def)
    : _maxShot = ctx.tune('maxShot', def.defaultTuning['maxShot']!),
      _damping =
          ctx.tune('damping', def.defaultTuning['damping']!) *
          (ctx.has(Modifiers.ice) ? 0.5 : 1) {
    final w = _world = Phys.world();
    const t = table;
    // Cushions with gaps for the 6 pockets.
    const g = pocketR + 2;
    for (final (a, b) in [
      (Offset(t.left + g, t.top), Offset(t.right - g, t.top)),
      (Offset(t.left + g, t.bottom), Offset(t.right - g, t.bottom)),
      (Offset(t.left, t.top + g), Offset(t.left, t.center.dy - g)),
      (Offset(t.left, t.center.dy + g), Offset(t.left, t.bottom - g)),
      (Offset(t.right, t.top + g), Offset(t.right, t.center.dy - g)),
      (Offset(t.right, t.center.dy + g), Offset(t.right, t.bottom - g)),
    ]) {
      Phys.staticSegment(w, a, b, restitution: 0.8);
    }
    final spots = rack(ctx.seed);
    for (var i = 0; i < spots.length; i++) {
      _balls.add(_ball(spots[i]));
      _colors.add(_palette[i % _palette.length]);
    }
    _cue = _ball(cueSpot);
  }

  static const Rect table = Rect.fromLTRB(36, 112, 324, 600);
  static const double ballR = 9;
  static const double pocketR = 15;
  static const int ballCount = 15;
  static const Offset cueSpot = Offset(180, 520);
  static const _palette = [
    Color(0xFFFFC107),
    Color(0xFF1E88E5),
    Color(0xFFE53935),
    Color(0xFF8E24AA),
    Color(0xFFFF7043),
    Color(0xFF43A047),
    Color(0xFF6D4C41),
    Color(0xFF212121),
  ];

  static List<Offset> get pockets => [
    table.topLeft,
    table.topRight,
    table.bottomLeft,
    table.bottomRight,
    Offset(table.left, table.center.dy),
    Offset(table.right, table.center.dy),
  ];

  /// Initial layout from the seed (non-overlapping, away from pockets).
  static List<Offset> rack(int seed) {
    final r = SeededRandom.derive(seed, 'billard:rack');
    final out = <Offset>[];
    var guard = 0;
    while (out.length < ballCount && guard++ < 5000) {
      final p = Offset(
        r.doubleInRange(table.left + 30, table.right - 30),
        r.doubleInRange(table.top + 30, 440),
      );
      if (out.every((q) => (q - p).distance > ballR * 2.6) &&
          pockets.every((k) => (k - p).distance > 50)) {
        out.add(p);
      }
    }
    return out;
  }

  final double _maxShot;
  final double _damping;
  late final World _world;
  final List<Body?> _balls = [];
  final List<Color> _colors = [];
  late Body _cue;

  int potted = 0, scratches = 0, series = 0, bestSeries = 0;
  int _pottedThisShot = 0;
  bool _rolling = false;
  int _rollSteps = 0;
  int? _pointer;
  Offset? _aim;

  Body _ball(Offset at) => Phys.ball(
    _world,
    at,
    ballR,
    density: 1,
    restitution: 0.92,
    friction: 0.05,
    linearDamping: _damping,
  )..angularDamping = 1;

  @override
  Color get backgroundColor => const Color(0xFF3E2723);

  @override
  int get debugBodyCount => 1 + _balls.where((b) => b != null).length;

  @override
  Offset get focus => _cue.px;

  @override
  void onPointer(PointerPhase phase, int pointer, Offset pos) {
    if (_rolling) return;
    switch (phase) {
      case PointerPhase.down:
        if (_pointer == null && (pos - _cue.px).distance < 90) {
          _pointer = pointer;
          _aim = pos;
        }
      case PointerPhase.move:
        if (pointer == _pointer) _aim = pos;
      case PointerPhase.up:
        if (pointer != _pointer) return;
        _pointer = null;
        final pull = _cue.px - pos;
        _aim = null;
        final power = math.min(pull.distance / 110, 1.0);
        if (power < 0.08) return;
        _cue.velPx = pull / pull.distance * power * _maxShot;
        _rolling = true;
        _rollSteps = 0;
        _pottedThisShot = 0;
        cue(sfx: Sfx.hit, haptic: Haptic.medium);
    }
  }

  bool _inPocket(Offset p) => pockets.any((k) => (k - p).distance < pocketR);

  @override
  void tick() {
    tickParticles();
    Phys.step(_world);
    for (final _ in _world.contactEvents.hit) {
      cue(sfx: Sfx.tap);
    }
    if (!_rolling) return;
    _rollSteps++;
    for (var i = 0; i < _balls.length; i++) {
      final b = _balls[i];
      if (b == null) continue;
      if (_inPocket(b.px) || !table.inflate(20).contains(b.px)) {
        particles.burst(b.px, _colors[i], count: 12, gravity: 0);
        b.destroy();
        _balls[i] = null;
        potted++;
        _pottedThisShot++;
        series++;
        bestSeries = math.max(bestSeries, series);
        // 100 per ball + 50 per ball already in the current series.
        score += 100 + 50 * (series - 1);
        cue(sfx: Sfx.score, haptic: Haptic.light);
      }
    }
    if (_inPocket(_cue.px) || !table.inflate(20).contains(_cue.px)) {
      scratches++;
      score = math.max(0, score - 150);
      series = 0;
      _cue
        ..moveTo(cueSpot)
        ..velPx = Offset.zero;
      cue(sfx: Sfx.miss, haptic: Haptic.heavy);
    }
    final moving =
        _cue.velPx.distance > 5 ||
        _balls.any((b) => b != null && b.velPx.distance > 5);
    if (!moving || _rollSteps > 8 * stepsPerSecond) {
      for (final b in [_cue, ..._balls.whereType<Body>()]) {
        b.velPx = Offset.zero;
      }
      _rolling = false;
      if (_pottedThisShot >= 2) {
        // Two balls or more in one shot: points doubled.
        score += 100 * _pottedThisShot;
        celebrate('doublePot');
      }
      if (_pottedThisShot == 0) series = 0;
      if (potted >= ballCount) over = true;
    }
  }

  @override
  void dispose() => _world.destroy();

  @override
  Map<String, num> get stats => {
    'potted': potted,
    'bestSeries': bestSeries,
    'scratches': scratches,
  };

  @override
  void render(Canvas canvas) {
    canvas.drawRect(Arena.rect, Paint()..color = const Color(0xFF3E2723));
    final rail = table.inflate(16);
    canvas
      ..drawRRect(
        RRect.fromRectAndRadius(rail, const Radius.circular(14)),
        Paint()..color = const Color(0xFF5D4037),
      )
      ..drawRect(table, Paint()..color = const Color(0xFF00695C))
      ..drawLine(
        Offset(table.left, 470),
        Offset(table.right, 470),
        Paint()..color = Colors.white24,
      );
    for (final k in pockets) {
      canvas.drawCircle(k, pocketR, Paint()..color = const Color(0xFF111111));
    }
    for (var i = 0; i < _balls.length; i++) {
      final b = _balls[i];
      if (b == null) continue;
      drawBall(canvas, b.px, ballR, _colors[i]);
      if (i >= 8) {
        canvas.drawCircle(b.px, ballR * 0.55, Paint()..color = Colors.white);
      }
    }
    drawBall(canvas, _cue.px, ballR, const Color(0xFFFAFAFA));
    final aim = _aim;
    if (aim != null) {
      final pull = _cue.px - aim;
      if (pull.distance > 4) {
        final power = math.min(pull.distance / 110, 1.0);
        drawDashed(
          canvas,
          _cue.px,
          pull,
          60,
          Paint()
            ..color = Colors.white
            ..strokeWidth = 2,
        );
        // Cue stick behind the ball.
        final dir = pull / pull.distance;
        canvas.drawLine(
          _cue.px - dir * (14 + power * 40),
          _cue.px - dir * (200 + power * 40),
          Paint()
            ..color = const Color(0xFFD7A86E)
            ..strokeWidth = 5
            ..strokeCap = StrokeCap.round,
        );
      }
    }
    if (series >= 2) {
      drawText(
        canvas,
        '🔥 $series',
        const Offset(16, 92),
        size: 16,
        display: true,
        color: const Color(0xFFFFD23F),
      );
    }
    drawText(
      canvas,
      '$potted/$ballCount',
      const Offset(344, 92),
      size: 16,
      align: TextAlign.right,
    );
  }
}
