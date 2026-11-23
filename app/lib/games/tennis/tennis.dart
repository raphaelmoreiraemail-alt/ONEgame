import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../core/l10n/l10n.dart';
import '../../core/rng/seeded_random.dart';
import '../common/draw.dart';
import '../common/fingerprint.dart';
import '../common/game_sim.dart';
import '../common/game_types.dart';
import '../common/mini_game_definition.dart';

/// 7.7 Tennis de table — first to 7 points against an AI, 2 minutes max.
class TennisGame extends MiniGameDefinition {
  const TennisGame();

  @override
  String get id => 'tennis';
  @override
  String get emoji => '🏓';
  @override
  GameCategory get category => GameCategory.sport;
  @override
  int get rulesVersion => 1;
  @override
  Set<String> get supportedModifiers => const {};
  @override
  ScoreBounds get scoreBounds =>
      const ScoreBounds(0, 7 * 100 + 7 * 100 + 13 * 50 + 500);

  @override
  Map<String, num> get defaultTuning => const {
    'baseSpeed': 380,
    'smashSpeed': 760,
    'smashThreshold': 850,
  };

  @override
  String name(AppLocalizations l10n) => l10n.gameTennisName;
  @override
  String rule(AppLocalizations l10n) => l10n.gameTennisRule;

  @override
  String shareLine(AppLocalizations l10n, Map<String, num> s) {
    final me = s['me']?.toInt() ?? 0, ai = s['ai']?.toInt() ?? 0;
    final head = me > ai
        ? l10n.gameTennisWin(me, ai)
        : l10n.gameTennisLoss(me, ai);
    return '$head · ${l10n.gameTennisRally(s['bestRally']?.toInt() ?? 0)}';
  }

  @override
  List<(String, String)> statRows(AppLocalizations l10n, Map<String, num> s) =>
      [
        (l10n.statMatch, '${s['me'] ?? 0} – ${s['ai'] ?? 0}'),
        (l10n.statBestRally, '${s['bestRally'] ?? 0}'),
        (l10n.statSmashes, '${s['smashes'] ?? 0}'),
      ];

  @override
  Map<String, String> highlightLabels(AppLocalizations l10n) => {
    'smash': l10n.highlightSmash,
  };

  @override
  GameSim createSim(GameContext ctx) => TennisSim(ctx, this);

  @override
  String levelFingerprint(int seed, String? modifierId) {
    final ai = TennisAi.generate(seed);
    return fingerprint([
      ai.style.index,
      ai.speed,
      ai.accuracy,
      ai.spin,
      for (final t in ai.targets.take(20)) t,
    ]);
  }
}

enum AiStyle { defensive, attacker, chopper }

/// AI personality and shot sequence, from the seed.
class TennisAi {
  const TennisAi(
    this.style,
    this.speed,
    this.accuracy,
    this.spin,
    this.targets,
    this.misses,
  );

  final AiStyle style;

  /// Paddle speed (px/s).
  final double speed;

  /// Base probability to return a ball it reaches.
  final double accuracy;
  final double spin;

  /// Target x of each AI shot.
  final List<double> targets;

  /// Uniform draws deciding errors, one per AI shot.
  final List<double> misses;

  static TennisAi generate(int seed) {
    final r = SeededRandom.derive(seed, 'tennis:ai');
    final style = AiStyle.values[r.nextInt(3)];
    final s = SeededRandom.derive(seed, 'tennis:shots');
    return TennisAi(
      style,
      switch (style) {
        AiStyle.defensive => 330,
        AiStyle.attacker => 290,
        AiStyle.chopper => 300,
      },
      switch (style) {
        AiStyle.defensive => 0.93,
        AiStyle.attacker => 0.84,
        AiStyle.chopper => 0.89,
      },
      switch (style) {
        AiStyle.chopper => 220,
        _ => 60,
      },
      [for (var i = 0; i < 400; i++) s.doubleInRange(70, 290)],
      [for (var i = 0; i < 400; i++) s.nextDouble()],
    );
  }
}

class TennisSim extends GameSim {
  TennisSim(super.ctx, TennisGame def)
    : ai = TennisAi.generate(ctx.seed),
      _base = ctx.tune('baseSpeed', def.defaultTuning['baseSpeed']!),
      _smash = ctx.tune('smashSpeed', def.defaultTuning['smashSpeed']!),
      _smashThreshold = ctx.tune(
        'smashThreshold',
        def.defaultTuning['smashThreshold']!,
      ) {
    _serve();
  }

  static const Rect table = Rect.fromLTRB(40, 120, 320, 600);
  static const double playerY = 586;
  static const double aiY = 134;
  static const double paddleHalf = 30;
  static const int winPoints = 7;

  final TennisAi ai;
  final double _base;
  final double _smash;
  final double _smashThreshold;

  int me = 0, opp = 0;
  int rally = 0, bestRally = 0, smashes = 0;
  int _aiShot = 0;
  int _pointsPlayed = 0;

  Offset _ball = Offset.zero;
  Offset _vel = Offset.zero;
  double _curl = 0;
  bool _lastHitByMe = false;
  bool _lastWasSmash = false;
  bool _live = false;
  bool _waitingServe = false;
  int _pause = 0;

  double _px = 180, _pxPrev = 180, _pxVel = 0;
  double _ax = 180;
  int? _pointer;
  double _dragFrom = 0, _paddleFrom = 0;

  @override
  Color get backgroundColor => const Color(0xFF1B263B);

  @override
  Offset get focus => _ball;

  void _serve() {
    rally = 0;
    _curl = 0;
    _lastWasSmash = false;
    // Serve changes every 2 points.
    final playerServes = (_pointsPlayed ~/ 2).isEven;
    if (playerServes) {
      _ball = Offset(_px, playerY - 14);
      _vel = Offset.zero;
      _waitingServe = true;
      _live = false;
    } else {
      _ball = Offset(_ax, aiY + 14);
      _aiHit(serve: true);
    }
  }

  @override
  void onPointer(PointerPhase phase, int pointer, Offset pos) {
    switch (phase) {
      case PointerPhase.down:
        if (_pointer != null) return;
        _pointer = pointer;
        _dragFrom = pos.dx;
        _paddleFrom = _px;
        if (_waitingServe && _pause == 0) {
          _waitingServe = false;
          _vel = Offset((_px - 180) * -0.4, -_base);
          _live = true;
          _lastHitByMe = true;
          cue(sfx: Sfx.tap, haptic: Haptic.light);
        }
      case PointerPhase.move:
        if (pointer == _pointer) {
          _px = (_paddleFrom + pos.dx - _dragFrom).clamp(
            table.left,
            table.right,
          );
        }
      case PointerPhase.up:
        if (pointer == _pointer) _pointer = null;
    }
  }

  void _aiHit({bool serve = false}) {
    final i = _aiShot++ % ai.targets.length;
    final target = Offset(ai.targets[i], playerY);
    final speed = switch (ai.style) {
      AiStyle.attacker => _base * 1.25,
      AiStyle.defensive => _base * 0.9,
      AiStyle.chopper => _base,
    };
    final d = target - _ball;
    _vel = d / d.distance * speed;
    _curl = ai.style == AiStyle.chopper ? (ai.misses[i] - 0.5) * ai.spin : 0;
    _lastHitByMe = false;
    _lastWasSmash = false;
    _live = true;
    if (!serve) rally++;
    cue(sfx: Sfx.tap);
  }

  @override
  void tick() {
    tickParticles();
    _pxVel = (_px - _pxPrev) / stepDt;
    _pxPrev = _px;
    if (_pause > 0) {
      if (--_pause == 0) {
        if (me >= winPoints || opp >= winPoints) {
          if (me > opp) {
            score += 500;
            particles.fireworks(const Offset(180, 320));
          }
          over = true;
          return;
        }
        _serve();
      }
      return;
    }
    if (_waitingServe) {
      _ball = Offset(_px, playerY - 14);
      return;
    }
    if (!_live) return;
    // AI paddle follows the ball when it comes its way.
    final aiTarget = _vel.dy < 0 ? _ball.dx : 180.0;
    _ax += (aiTarget - _ax).clamp(-ai.speed * stepDt, ai.speed * stepDt);

    _vel = _vel.translate(_curl * stepDt, 0);
    final prev = _ball;
    _ball += _vel * stepDt;
    if (_ball.dx < table.left - 30 || _ball.dx > table.right + 30) {
      _point(playerWins: !_lastHitByMe);
      return;
    }
    // Player contact.
    if (prev.dy < playerY && _ball.dy >= playerY && _vel.dy > 0) {
      final off = _ball.dx - _px;
      if (off.abs() <= paddleHalf + 6) {
        final smash = _pxVel.abs() > _smashThreshold;
        final speed = smash
            ? _smash
            : _base + math.min(_pxVel.abs() * 0.1, 120);
        _vel = Offset(off / paddleHalf * 240, -speed);
        _curl = (_pxVel * 0.18).clamp(-260.0, 260.0);
        _lastHitByMe = true;
        _lastWasSmash = smash;
        rally++;
        if (smash) smashes++;
        particles.burst(
          _ball,
          Colors.white,
          count: smash ? 18 : 6,
          gravity: 0,
          speed: 120,
        );
        cue(
          sfx: smash ? Sfx.hit : Sfx.tap,
          haptic: smash ? Haptic.heavy : Haptic.light,
        );
      } else {
        _point(playerWins: false);
      }
      return;
    }
    // AI contact.
    if (prev.dy > aiY && _ball.dy <= aiY && _vel.dy < 0) {
      final reaches = (_ball.dx - _ax).abs() <= paddleHalf + 8;
      final i = _aiShot % ai.misses.length;
      var p = ai.accuracy - math.max(0, rally - 6) * 0.01;
      if (_lastWasSmash) p -= 0.55;
      if (_curl.abs() > 120) p -= 0.15;
      if (reaches && ai.misses[i] < p) {
        _aiHit();
      } else {
        _aiShot++;
        _point(playerWins: true);
      }
    }
  }

  void _point({required bool playerWins}) {
    _live = false;
    _pointsPlayed++;
    bestRally = math.max(bestRally, rally);
    if (rally > 10) score += 50;
    if (playerWins) {
      me++;
      score += 100;
      if (_lastWasSmash) {
        score += 100;
        celebrate('smash');
      }
      cue(sfx: Sfx.score, haptic: Haptic.medium);
    } else {
      opp++;
      cue(sfx: Sfx.miss, haptic: Haptic.light);
    }
    _pause = (0.9 * stepsPerSecond).round();
  }

  @override
  void onTimeUp() {
    if (me > opp) score += 500;
  }

  @override
  Map<String, num> get stats => {
    'me': me,
    'ai': opp,
    'bestRally': bestRally,
    'smashes': smashes,
  };

  @override
  void render(Canvas canvas) {
    canvas.drawRect(Arena.rect, Paint()..color = const Color(0xFF1B263B));
    drawShadowRRect(
      canvas,
      RRect.fromRectAndRadius(table, const Radius.circular(4)),
      dy: 8,
    );
    canvas
      ..drawRect(table, Paint()..color = const Color(0xFF1565C0))
      ..drawRect(
        table,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      )
      ..drawLine(
        Offset(180, table.top),
        Offset(180, table.bottom),
        Paint()
          ..color = Colors.white54
          ..strokeWidth = 1.5,
      )
      ..drawRect(
        Rect.fromLTRB(table.left - 10, 357, table.right + 10, 363),
        Paint()..color = const Color(0xFFECEFF1),
      );
    void paddle(double x, double y, Color c) {
      drawBox(
        canvas,
        Rect.fromCenter(
          center: Offset(x, y),
          width: paddleHalf * 2,
          height: 12,
        ),
        c,
        radius: 6,
      );
    }

    paddle(_ax, aiY, const Color(0xFF212121));
    paddle(_px, playerY, const Color(0xFFE8322F));
    drawBall(canvas, _ball, 6, Colors.white);
    drawText(
      canvas,
      '$me',
      const Offset(20, 560),
      size: 34,
      display: true,
      color: const Color(0xFFE8322F),
    );
    drawText(canvas, '$opp', const Offset(20, 140), size: 34, display: true);
    if (rally > 2) {
      drawText(
        canvas,
        '×$rally',
        const Offset(340, 350),
        size: 16,
        align: TextAlign.right,
      );
    }
    if (_waitingServe) {
      drawText(
        canvas,
        '👆',
        const Offset(180, 520),
        size: 30,
        align: TextAlign.center,
      );
    }
  }
}
