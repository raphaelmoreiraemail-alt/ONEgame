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
import 'bowling_score.dart';

/// 7.5 Bowling — 5 frames, official scoring, curved swipe = hook.
class BowlingGame extends MiniGameDefinition {
  const BowlingGame();

  @override
  String get id => 'bowling';
  @override
  String get emoji => '🎳';
  @override
  GameCategory get category => GameCategory.sport;
  @override
  int get rulesVersion => 1;
  @override
  Set<String> get supportedModifiers => const {};
  @override
  ScoreBounds get scoreBounds => const ScoreBounds(0, 1500);

  @override
  Map<String, num> get defaultTuning => const {
    'minSpeed': 420,
    'maxSpeed': 1150,
    'hookAccel': 420,
    'pinDamping': 2.2,
  };

  @override
  String name(AppLocalizations l10n) => l10n.gameBowlingName;
  @override
  String rule(AppLocalizations l10n) => l10n.gameBowlingRule;

  @override
  String shareLine(AppLocalizations l10n, Map<String, num> s) =>
      l10n.gameBowlingShare(
        s['pins']?.toInt() ?? 0,
        s['strikes']?.toInt() ?? 0,
        s['spares']?.toInt() ?? 0,
      );

  @override
  List<(String, String)> statRows(AppLocalizations l10n, Map<String, num> s) =>
      [
        (l10n.statBowlingScore, '${s['pins'] ?? 0} / 150'),
        (l10n.statStrikes, '${s['strikes'] ?? 0}'),
        (l10n.statSpares, '${s['spares'] ?? 0}'),
      ];

  @override
  Map<String, String> highlightLabels(AppLocalizations l10n) => {
    'strike': l10n.highlightStrike,
    'turkey': l10n.highlightTurkey,
  };

  @override
  GameSim createSim(GameContext ctx) => BowlingSim(ctx, this);

  @override
  String levelFingerprint(int seed, String? modifierId) {
    final l = BowlingLane.generate(seed);
    return fingerprint([
      l.oilEndY,
      l.oilBias,
      l.offsetPin,
      l.pinOffset.dx,
      l.pinOffset.dy,
    ]);
  }
}

/// Lane conditions from the seed.
class BowlingLane {
  const BowlingLane(this.oilEndY, this.oilBias, this.offsetPin, this.pinOffset);

  /// Hook only "bites" on the dry back end (y < [oilEndY]).
  final double oilEndY;

  /// Lateral drift on the oily front part (px/s²).
  final double oilBias;

  /// Index of a slightly misplaced pin (-1: none).
  final int offsetPin;
  final Offset pinOffset;

  static BowlingLane generate(int seed) {
    final r = SeededRandom.derive(seed, 'bowling:lane');
    final misplaced = r.chance(0.6);
    return BowlingLane(
      r.doubleInRange(300, 420),
      r.doubleInRange(-45, 45),
      misplaced ? r.nextInt(10) : -1,
      misplaced
          ? Offset(r.doubleInRange(-3, 3), r.doubleInRange(-3, 3))
          : Offset.zero,
    );
  }
}

enum _Phase { position, rolling, settling, done }

class BowlingSim extends GameSim {
  BowlingSim(super.ctx, BowlingGame def)
    : lane = BowlingLane.generate(ctx.seed),
      _minSpeed = ctx.tune('minSpeed', def.defaultTuning['minSpeed']!),
      _maxSpeed = ctx.tune('maxSpeed', def.defaultTuning['maxSpeed']!),
      _hook = ctx.tune('hookAccel', def.defaultTuning['hookAccel']!),
      _pinDamping = ctx.tune('pinDamping', def.defaultTuning['pinDamping']!) {
    _world = Phys.world();
    _rackPins();
    _resetBall();
  }

  static const double laneLeft = 105;
  static const double laneRight = 255;
  static const double foulY = 560;
  static const double ballR = 13;
  static const double pinR = 7;
  static const int frames = 5;

  final BowlingLane lane;
  final double _minSpeed;
  final double _maxSpeed;
  final double _hook;
  final double _pinDamping;
  late final World _world;

  final List<Offset> _pinHome = [];
  final List<Body?> _pins = List.filled(10, null);
  final List<bool> _standing = List.filled(10, true);
  Body? _ball;
  bool _gutter = false;

  final List<int> rolls = [];
  int strikes = 0;
  int spares = 0;
  int _consecutiveStrikes = 0;
  int frame = 0;
  int _rollInFrame = 0;
  int _pinsBeforeRoll = 10;

  _Phase _phase = _Phase.position;
  int _phaseSteps = 0;
  double _spin = 0;
  double _ballX = 180;

  int? _pointer;
  bool _throwing = false;
  final List<(int, Offset)> _path = [];
  double _dragFromX = 0;
  double _ballFromX = 0;

  @override
  Color get backgroundColor => const Color(0xFF1A1A2E);

  @override
  int get debugBodyCount => 1 + _pins.where((p) => p != null).length;

  static Offset pinSpot(int i) {
    // Rows 1-2-3-4 from the front, pin spacing 30 px.
    const rows = [
      [0],
      [1, 2],
      [3, 4, 5],
      [6, 7, 8, 9],
    ];
    for (var r = 0; r < rows.length; r++) {
      final idx = rows[r].indexOf(i);
      if (idx >= 0) {
        final n = rows[r].length;
        return Offset(180 + (idx - (n - 1) / 2) * 30, 230 - r * 26);
      }
    }
    return Offset.zero;
  }

  void _rackPins() {
    for (final p in _pins) {
      p?.destroy();
    }
    _pinHome.clear();
    for (var i = 0; i < 10; i++) {
      final home =
          pinSpot(i) + (i == lane.offsetPin ? lane.pinOffset : Offset.zero);
      _pinHome.add(home);
      _pins[i] = Phys.ball(
        _world,
        home,
        pinR,
        density: 0.55,
        restitution: 0.45,
        friction: 0.2,
        linearDamping: _pinDamping,
        bullet: false,
      )..angularDamping = 3;
      _standing[i] = true;
    }
  }

  void _resetBall() {
    _ball?.destroy();
    _ball = null;
    _gutter = false;
    _phase = _Phase.position;
    _phaseSteps = 0;
  }

  @override
  void onPointer(PointerPhase phase, int pointer, Offset pos) {
    if (_phase != _Phase.position) return;
    switch (phase) {
      case PointerPhase.down:
        if (_pointer != null || pos.dy < 330) return;
        _pointer = pointer;
        _throwing = false;
        _path
          ..clear()
          ..add((step, pos));
        _dragFromX = pos.dx;
        _ballFromX = _ballX;
      case PointerPhase.move:
        if (pointer != _pointer) return;
        _path.add((step, pos));
        final total = pos - _path.first.$2;
        if (!_throwing &&
            total.dy < -40 &&
            (Offset(_ballX, foulY) - _path.first.$2).distance < 70) {
          _throwing = true;
        }
        if (!_throwing) {
          _ballX = (_ballFromX + pos.dx - _dragFromX).clamp(
            laneLeft + ballR,
            laneRight - ballR,
          );
        }
      case PointerPhase.up:
        if (pointer != _pointer) return;
        _pointer = null;
        _path.add((step, pos));
        if (_throwing) _throw();
        _throwing = false;
    }
  }

  void _throw() {
    final start = _path.first.$2;
    final end = _path.last.$2;
    final d = end - start;
    if (d.dy > -40) return;
    final len = d.distance;
    final dur = math.max(1, _path.last.$1 - _path.first.$1) / stepsPerSecond;
    final speed = (len / dur * 0.55).clamp(_minSpeed, _maxSpeed);
    // Direction: limited aiming angle.
    final angle = math.atan2(d.dx, -d.dy).clamp(-0.14, 0.14);
    // Curvature of the swipe → spin (hook).
    var dev = 0.0;
    final n = Offset(-d.dy, d.dx) / len;
    for (final (_, p) in _path) {
      final off = (p - start).dx * n.dx + (p - start).dy * n.dy;
      if (off.abs() > dev.abs()) dev = off;
    }
    _spin = (dev / len * 3).clamp(-1.0, 1.0);
    _ball = Phys.ball(
      _world,
      Offset(_ballX, foulY),
      ballR,
      density: 3,
      restitution: 0.2,
    )..velPx = Offset(math.sin(angle), -math.cos(angle)) * speed;
    _pinsBeforeRoll = _standing.where((s) => s).length;
    _phase = _Phase.rolling;
    _phaseSteps = 0;
    cue(sfx: Sfx.whoosh, haptic: Haptic.medium);
  }

  @override
  void tick() {
    tickParticles();
    _phaseSteps++;
    final ball = _ball;
    if (_phase == _Phase.rolling && ball != null) {
      final p = ball.px;
      if (!_gutter &&
          (p.dx < laneLeft - 2 || p.dx > laneRight + 2) &&
          p.dy > 240) {
        // Gutter ball: it slides to the end without touching pins.
        _gutter = true;
        ball.isEnabled = false;
        cue(sfx: Sfx.miss);
      }
      if (_gutter) {
        final x = p.dx < 180 ? laneLeft - 10 : laneRight + 10;
        ball.moveTo(Offset(x, p.dy - 700 * stepDt));
      } else {
        // Hook bites on the dry back end; oil gives a slight drift.
        var ax = lane.oilBias;
        if (p.dy < lane.oilEndY) ax += -_spin * _hook;
        ball.applyForce(Phys.v(Offset(ax, 0)) * ball.mass);
      }
      if (p.dy < 90 ||
          _phaseSteps > 5 * stepsPerSecond ||
          (!_gutter && ball.velPx.distance < 20 && _phaseSteps > 60)) {
        _phase = _Phase.settling;
        _phaseSteps = 0;
      }
    }
    Phys.step(_world);
    for (final _ in _world.contactEvents.hit) {
      cue(sfx: Sfx.hit, haptic: Haptic.light);
    }
    if (_phase == _Phase.settling &&
        _phaseSteps > (1.2 * stepsPerSecond).round()) {
      _endRoll();
    }
  }

  void _endRoll() {
    var down = 0;
    for (var i = 0; i < 10; i++) {
      final p = _pins[i];
      if (p == null) continue;
      final moved = (p.px - _pinHome[i]).distance > 6;
      final out = p.px.dx < laneLeft || p.px.dx > laneRight || p.px.dy < 80;
      if (moved || out) {
        p.destroy();
        _pins[i] = null;
        _standing[i] = false;
      }
    }
    final standing = _standing.where((s) => s).length;
    down = _pinsBeforeRoll - standing;
    rolls.add(down);
    final last = frame == frames - 1;
    var rerack = false;
    var nextFrame = false;

    if (_rollInFrame == 0) {
      if (down == 10) {
        strikes++;
        _consecutiveStrikes++;
        celebrate(_consecutiveStrikes == 3 ? 'turkey' : 'strike');
        particles.fireworks(const Offset(180, 200));
        if (last) {
          rerack = true;
          _rollInFrame = 1;
        } else {
          nextFrame = true;
        }
      } else {
        _consecutiveStrikes = 0;
        _rollInFrame = 1;
        cue(sfx: down > 0 ? Sfx.score : Sfx.miss);
      }
    } else if (_rollInFrame == 1) {
      final first = rolls[rolls.length - 2];
      if (!last) {
        if (first + down == 10) {
          spares++;
          cue(sfx: Sfx.score, haptic: Haptic.medium);
          particles.burst(
            const Offset(180, 200),
            const Color(0xFFFFD23F),
            count: 24,
          );
        }
        nextFrame = true;
      } else {
        if (first == 10 && down == 10) {
          strikes++;
          _consecutiveStrikes++;
          celebrate(
            _consecutiveStrikes >= 3 && _consecutiveStrikes % 3 == 0
                ? 'turkey'
                : 'strike',
          );
          rerack = true;
          _rollInFrame = 2;
        } else if (first == 10) {
          _rollInFrame = 2;
          _consecutiveStrikes = 0;
        } else if (first + down == 10) {
          spares++;
          cue(sfx: Sfx.score, haptic: Haptic.medium);
          rerack = true;
          _rollInFrame = 2;
        } else {
          nextFrame = true;
        }
      }
    } else {
      if (down == 10 && _pinsBeforeRoll == 10) {
        strikes++;
        celebrate('strike');
      }
      nextFrame = true;
    }
    if (nextFrame) {
      frame++;
      _rollInFrame = 0;
      rerack = true;
    }
    score = bowlingResolved(rolls, frames: frames) * 10;
    if (frame >= frames) {
      _phase = _Phase.done;
      over = true;
      return;
    }
    if (rerack) _rackPins();
    _resetBall();
  }

  @override
  int get finalScore => bowlingResolved(rolls, frames: frames) * 10;

  @override
  void dispose() => _world.destroy();

  @override
  Map<String, num> get stats => {
    'pins': bowlingResolved(rolls, frames: frames),
    'strikes': strikes,
    'spares': spares,
    'frames': math.min(frame, frames),
  };

  @override
  void render(Canvas canvas) {
    // Approach + lane wood.
    canvas.drawRect(Arena.rect, Paint()..color = const Color(0xFF1A1A2E));
    canvas.drawRect(
      const Rect.fromLTRB(laneLeft - 18, 70, laneRight + 18, 640),
      Paint()..color = const Color(0xFF424242),
    );
    for (var i = 0; i < 10; i++) {
      canvas.drawRect(
        Rect.fromLTWH(laneLeft + i * 15.0, 70, 15, 570),
        Paint()
          ..color = i.isEven
              ? const Color(0xFFE3B778)
              : const Color(0xFFD9A863),
      );
    }
    // Oil sheen.
    canvas.drawRect(
      Rect.fromLTRB(laneLeft, lane.oilEndY, laneRight, foulY),
      Paint()..color = const Color(0x22FFFFFF),
    );
    // Arrows + foul line.
    final mark = Paint()..color = const Color(0xFF8D5524);
    for (var i = 1; i < 6; i++) {
      final x = laneLeft + i * 25.0;
      canvas.drawPath(
        Path()
          ..moveTo(x, 440)
          ..lineTo(x - 4, 452)
          ..lineTo(x + 4, 452)
          ..close(),
        mark,
      );
    }
    canvas.drawLine(
      const Offset(laneLeft, foulY + 16),
      const Offset(laneRight, foulY + 16),
      Paint()
        ..color = const Color(0xFFB71C1C)
        ..strokeWidth = 3,
    );
    // Pins.
    for (var i = 0; i < 10; i++) {
      final p = _pins[i];
      if (p == null) continue;
      drawBall(canvas, p.px, pinR, Colors.white);
      canvas.drawCircle(
        p.px,
        pinR * 0.45,
        Paint()..color = const Color(0xFFE8322F),
      );
    }
    // Ball.
    final ball = _ball;
    final bp = ball?.px ?? Offset(_ballX, foulY);
    drawBall(canvas, bp, ballR, const Color(0xFF283593));
    for (final o in [
      const Offset(-3, -4),
      const Offset(3, -4),
      const Offset(0, 2),
    ]) {
      canvas.drawCircle(bp + o, 2, Paint()..color = const Color(0xFF0D1440));
    }
    if (_phase == _Phase.position && _path.length > 1 && _throwing) {
      final path = Path()..moveTo(_path.first.$2.dx, _path.first.$2.dy);
      for (final (_, p) in _path.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0x88FFD23F)
          ..strokeWidth = 6
          ..style = PaintingStyle.stroke,
      );
    }
    // Scorecard.
    final totals = bowlingTotals(rolls, frames: frames);
    for (var f = 0; f < frames; f++) {
      final r = Rect.fromLTWH(20 + f * 64.0, 6 + 84, 60, 0);
      drawText(
        canvas,
        '${f + 1}:${totals[f] ?? (f == frame ? '…' : '')}',
        Offset(r.left, 0 + 96),
        size: 12,
        color: f == frame ? const Color(0xFFFFD23F) : Colors.white70,
      );
    }
  }
}
