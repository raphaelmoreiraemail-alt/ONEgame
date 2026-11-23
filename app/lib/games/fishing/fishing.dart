import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../core/l10n/l10n.dart';
import '../../core/rng/seeded_random.dart';
import '../common/draw.dart';
import '../common/fingerprint.dart';
import '../common/game_sim.dart';
import '../common/game_types.dart';
import '../common/mini_game_definition.dart';

/// 7.15 Pêche — cast, strike at the bite, reel without breaking the line.
class FishingGame extends MiniGameDefinition {
  const FishingGame();

  @override
  String get id => 'fishing';
  @override
  String get emoji => '🎣';
  @override
  GameCategory get category => GameCategory.adresse;
  @override
  int get rulesVersion => 1;
  @override
  Set<String> get supportedModifiers => const {};
  @override
  ScoreBounds get scoreBounds => const ScoreBounds(0, 12000);

  @override
  Map<String, num> get defaultTuning => const {
    'reelSpeed': 120,
    'biteWindow': 0.7,
    'legendaryChance': 0.01,
  };

  @override
  String name(AppLocalizations l10n) => l10n.gameFishingName;
  @override
  String rule(AppLocalizations l10n) => l10n.gameFishingRule;

  @override
  String shareLine(AppLocalizations l10n, Map<String, num> s) =>
      l10n.gameFishingShare(
        s['fish']?.toInt() ?? 0,
        ((s['grams'] ?? 0) / 1000).toStringAsFixed(1),
      );

  @override
  List<(String, String)> statRows(
    AppLocalizations l10n,
    Map<String, num> s,
  ) => [
    (l10n.statFish, '${s['fish'] ?? 0}'),
    (l10n.statWeight, '${((s['grams'] ?? 0) / 1000).toStringAsFixed(2)} kg'),
    (l10n.statBiggest, '${s['biggest'] ?? 0} g'),
    (l10n.statLineBreaks, '${s['breaks'] ?? 0}'),
  ];

  @override
  Map<String, String> highlightLabels(AppLocalizations l10n) => {
    'legendary': l10n.highlightLegendary,
  };

  @override
  GameSim createSim(GameContext ctx) => FishingSim(ctx, this);

  @override
  String levelFingerprint(int seed, String? modifierId) {
    final lake = Lake.generate(seed);
    return fingerprint([
      for (final z in lake.zones)
        for (final s in z) ...[s.emoji, s.minG, s.maxG, s.strength],
      for (var i = 0; i < 10; i++) lake.biteDelay(i),
    ]);
  }
}

class Species {
  const Species(this.emoji, this.minG, this.maxG, this.strength, this.color);

  final String emoji;
  final int minG, maxG;

  /// How hard it pulls (0..1).
  final double strength;
  final Color color;
}

class Lake {
  Lake(this.seed, this.zones);

  final int seed;

  /// Species present in the near / middle / far zones.
  final List<List<Species>> zones;

  static const _pool = [
    Species('🐟', 80, 400, 0.25, Color(0xFF90A4AE)),
    Species('🐠', 150, 600, 0.35, Color(0xFFFFB74D)),
    Species('🐡', 300, 900, 0.45, Color(0xFFFFF176)),
    Species('🐟', 500, 1800, 0.55, Color(0xFF81C784)),
    Species('🦈', 1500, 4000, 0.8, Color(0xFF78909C)),
    Species('🐋', 2500, 6000, 0.9, Color(0xFF4FC3F7)),
  ];
  static const legendary = Species('🐉', 8000, 12000, 1, Color(0xFFE8322F));

  static Lake generate(int seed) {
    final r = SeededRandom.derive(seed, 'fishing:lake');
    return Lake(seed, [
      [_pool[0], _pool[1], _pool[r.intInRange(1, 2)]],
      [_pool[r.intInRange(1, 2)], _pool[2], _pool[3]],
      [_pool[3], _pool[r.intInRange(3, 4)], _pool[r.intInRange(4, 5)]],
    ]);
  }

  double biteDelay(int cast) =>
      SeededRandom.derive(seed, 'fishing:bite$cast').doubleInRange(1.0, 3.6);

  (Species, int, double) fishFor(int cast, int zone, double legendaryChance) {
    final r = SeededRandom.derive(seed, 'fishing:fish$cast');
    if (r.chance(legendaryChance)) {
      return (
        legendary,
        r.intInRange(legendary.minG, legendary.maxG),
        r.nextDouble() * 6,
      );
    }
    final s = r.pick(zones[zone]);
    return (s, r.intInRange(s.minG, s.maxG), r.nextDouble() * 6);
  }
}

enum _Phase { idle, sinking, bite, fight, landed }

class FishingSim extends GameSim {
  FishingSim(super.ctx, FishingGame def)
    : lake = Lake.generate(ctx.seed),
      _reel = ctx.tune('reelSpeed', def.defaultTuning['reelSpeed']!),
      _window = ctx.tune('biteWindow', def.defaultTuning['biteWindow']!),
      _legendary = ctx.tune(
        'legendaryChance',
        def.defaultTuning['legendaryChance']!,
      );

  static const Offset rodTip = Offset(70, 200);
  static const double waterY = 260;

  final Lake lake;
  final double _reel, _window, _legendary;

  _Phase _phase = _Phase.idle;
  int _cast = 0;
  int _phaseSteps = 0;
  double _lureX = 0;
  int _zone = 0;
  Species? _species;
  int _grams = 0;
  double _phaseSeed = 0;
  double distance = 0;
  double tension = 0;
  bool _holding = false;
  int? _pointer;
  Offset _down = Offset.zero;
  int _downStep = 0;

  int fish = 0, grams = 0, biggest = 0, breaks = 0, escapes = 0;
  final List<(String, int)> catches = [];

  @visibleForTesting
  bool get debugBiting => _phase == _Phase.bite;

  @override
  Color get backgroundColor => const Color(0xFF0277BD);

  @override
  Offset get focus => Offset(_lureX, waterY + 40);

  @override
  void onPointer(PointerPhase phase, int pointer, Offset pos) {
    switch (phase) {
      case PointerPhase.down:
        if (_pointer != null) return;
        _pointer = pointer;
        _down = pos;
        _downStep = step;
        if (_phase == _Phase.bite) {
          _hook();
        } else if (_phase == _Phase.fight) {
          _holding = true;
        } else if (_phase == _Phase.sinking) {
          // Striking too early scares the fish away.
          _phase = _Phase.idle;
          cue(sfx: Sfx.miss);
        }
      case PointerPhase.move:
        break;
      case PointerPhase.up:
        if (pointer != _pointer) return;
        _pointer = null;
        _holding = false;
        if (_phase == _Phase.idle) {
          final d = pos - _down;
          final dur = (step - _downStep) / stepsPerSecond;
          if (d.dy < -40 && dur < 1) _castLine(d.distance);
        }
    }
  }

  void _castLine(double swipe) {
    _lureX = (110 + swipe * 0.9).clamp(110.0, 330.0);
    _zone = _lureX < 180 ? 0 : (_lureX < 260 ? 1 : 2);
    _phase = _Phase.sinking;
    _phaseSteps = 0;
    cue(sfx: Sfx.whoosh, haptic: Haptic.light);
  }

  void _hook() {
    final (s, g, ph) = lake.fishFor(_cast, _zone, _legendary);
    _species = s;
    _grams = g;
    _phaseSeed = ph;
    distance = _lureX - rodTip.dx;
    tension = 0.2;
    _phase = _Phase.fight;
    _phaseSteps = 0;
    _holding = true;
    cue(sfx: Sfx.hit, haptic: Haptic.heavy);
  }

  @override
  void tick() {
    tickParticles();
    _phaseSteps++;
    final t = _phaseSteps / stepsPerSecond;
    switch (_phase) {
      case _Phase.idle:
      case _Phase.landed:
        if (_phase == _Phase.landed && t > 1.2) _phase = _Phase.idle;
      case _Phase.sinking:
        if (t >= lake.biteDelay(_cast)) {
          _phase = _Phase.bite;
          _phaseSteps = 0;
          particles.burst(
            Offset(_lureX, waterY),
            Colors.white,
            count: 10,
            gravity: 200,
            speed: 120,
          );
          cue(sfx: Sfx.tap, haptic: Haptic.heavy);
        }
      case _Phase.bite:
        if (t > _window) {
          escapes++;
          _cast++;
          _phase = _Phase.idle;
          cue(sfx: Sfx.miss);
        }
      case _Phase.fight:
        final s = _species!;
        // Pull pattern: bursts and rests, stronger for big fish.
        final pull =
            (0.5 +
                    0.5 *
                        math.sin(t * 2.3 + _phaseSeed) *
                        math.sin(t * 0.9 + _phaseSeed * 2))
                .clamp(0.0, 1.0) *
            s.strength *
            math.max(0.3, 1 - t / 25);
        if (_holding) {
          distance -= _reel * (1 - pull * 0.7) * stepDt;
          tension += (0.25 + pull * 1.1) * stepDt;
        } else {
          distance += pull * 40 * stepDt;
          tension -= 0.9 * stepDt;
        }
        tension = tension.clamp(0.0, 1.2);
        if (tension >= 1) {
          breaks++;
          _cast++;
          _phase = _Phase.idle;
          particles.burst(
            Offset(rodTip.dx + distance, waterY + 30),
            Colors.white,
            count: 14,
          );
          cue(sfx: Sfx.miss, haptic: Haptic.heavy);
        } else if (distance <= 0) {
          _land();
        } else if (distance > 320) {
          escapes++;
          _cast++;
          _phase = _Phase.idle;
        }
    }
  }

  void _land() {
    fish++;
    grams += _grams;
    biggest = math.max(biggest, _grams);
    catches.add((_species!.emoji, _grams));
    score += _grams ~/ 10;
    if (identical(_species, Lake.legendary)) {
      score += 1000;
      celebrate('legendary');
      particles.fireworks(rodTip.translate(60, 60));
    } else {
      cue(sfx: Sfx.score, haptic: Haptic.medium);
      particles.burst(
        rodTip.translate(20, 60),
        const Color(0xFFFFD23F),
        count: 16,
      );
    }
    _cast++;
    _phase = _Phase.landed;
    _phaseSteps = 0;
  }

  @override
  Map<String, num> get stats => {
    'fish': fish,
    'grams': grams,
    'biggest': biggest,
    'breaks': breaks,
  };

  @override
  void render(Canvas canvas) {
    canvas
      ..drawRect(
        const Rect.fromLTRB(0, 0, 360, waterY),
        Paint()..color = const Color(0xFFFFCC80),
      )
      ..drawRect(
        const Rect.fromLTRB(0, waterY, 360, 640),
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF29B6F6), Color(0xFF01579B)],
          ).createShader(const Rect.fromLTRB(0, waterY, 360, 640)),
      );
    // Zone markers.
    for (final x in [180.0, 260.0]) {
      canvas.drawLine(
        Offset(x, waterY + 4),
        Offset(x, waterY + 14),
        Paint()
          ..color = Colors.white38
          ..strokeWidth = 2,
      );
    }
    for (var i = 0; i < 3; i++) {
      drawText(
        canvas,
        lake.zones[i].map((s) => s.emoji).toSet().join(),
        Offset(145 + i * 80.0, waterY + 24),
        size: 12,
        align: TextAlign.center,
      );
    }
    // Dock + angler.
    canvas.drawRect(
      const Rect.fromLTWH(0, 230, 70, 30),
      Paint()..color = const Color(0xFF6D4C41),
    );
    drawBox(
      canvas,
      const Rect.fromLTWH(28, 190, 18, 40),
      const Color(0xFFE8322F),
      radius: 6,
    );
    canvas.drawCircle(
      const Offset(37, 182),
      9,
      Paint()..color = const Color(0xFFFFCC80),
    );
    canvas.drawLine(
      const Offset(44, 210),
      rodTip,
      Paint()
        ..color = const Color(0xFF3E2723)
        ..strokeWidth = 3,
    );
    // Line + bobber / fish.
    if (_phase == _Phase.sinking || _phase == _Phase.bite) {
      final dunk = _phase == _Phase.bite ? 8.0 : 2 * math.sin(elapsed * 3);
      final bob = Offset(_lureX, waterY + dunk);
      canvas
        ..drawLine(
          rodTip,
          bob,
          Paint()
            ..color = Colors.white70
            ..strokeWidth = 1,
        )
        ..drawCircle(bob, 6, Paint()..color = const Color(0xFFE8322F))
        ..drawRect(
          Rect.fromCenter(center: bob.translate(0, -5), width: 3, height: 6),
          Paint()..color = Colors.white,
        );
      if (_phase == _Phase.bite) {
        drawText(
          canvas,
          '!',
          bob.translate(0, -30),
          size: 34,
          display: true,
          align: TextAlign.center,
          color: const Color(0xFFFFD23F),
        );
      }
    } else if (_phase == _Phase.fight) {
      final fishPos = Offset(
        rodTip.dx + distance,
        waterY + 50 + 14 * math.sin(elapsed * 5),
      );
      canvas.drawLine(
        rodTip,
        fishPos,
        Paint()
          ..color = tension > 0.8 ? const Color(0xFFE53935) : Colors.white
          ..strokeWidth = 1.5,
      );
      drawText(
        canvas,
        _species!.emoji,
        fishPos,
        size: 26,
        align: TextAlign.center,
      );
      // Tension gauge (red zone at the top).
      const g = Rect.fromLTWH(320, 300, 18, 220);
      canvas
        ..drawRRect(
          RRect.fromRectAndRadius(g, const Radius.circular(9)),
          Paint()..color = Colors.black38,
        )
        ..drawRect(
          Rect.fromLTWH(g.left, g.top, g.width, g.height * 0.2),
          Paint()..color = const Color(0x88E53935),
        )
        ..drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(
              g.left,
              g.bottom - g.height * tension.clamp(0.0, 1.0),
              g.width,
              g.height * tension.clamp(0.0, 1.0),
            ),
            const Radius.circular(9),
          ),
          Paint()
            ..color = Color.lerp(
              const Color(0xFF66BB6A),
              const Color(0xFFE53935),
              tension.clamp(0.0, 1.0),
            )!,
        );
      drawText(
        canvas,
        _holding ? '⟲' : '✋',
        const Offset(329, 540),
        size: 20,
        align: TextAlign.center,
      );
    } else if (_phase == _Phase.landed && catches.isNotEmpty) {
      drawText(
        canvas,
        '${catches.last.$1} ${catches.last.$2} g',
        const Offset(180, 160),
        size: 26,
        display: true,
        align: TextAlign.center,
        color: const Color(0xFF01579B),
      );
    } else {
      drawText(
        canvas,
        '👆',
        const Offset(180, 560),
        size: 30,
        align: TextAlign.center,
      );
    }
    drawText(
      canvas,
      '🎣 $fish · ${(grams / 1000).toStringAsFixed(1)} kg',
      const Offset(16, 100),
      size: 15,
      color: const Color(0xFF3E2723),
    );
  }
}
