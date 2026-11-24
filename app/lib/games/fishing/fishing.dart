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

  // ── 3D rendering ──────────────────────────────────────────────────────
  // Casting distance x (sim) runs away from the camera across the lake:
  // depth z = 560 − (x − 60)·4. The angler stands at the end of a dock.
  static final Camera3D _camera = Camera3D(
    eye: const V3(230, 150, 860),
    target: const V3(180, 0, 60),
    fovDegrees: 54,
    center: const Offset(180, 330),
  );
  static double _z(double x) => 560 - (x - 60) * 4;
  static const V3 _tip = V3(190, 92, 470);

  double _wave(double x, double z) =>
      math.sin(x * 0.03 + elapsed * 1.7) * 0.6 +
      math.sin(z * 0.025 - elapsed * 1.3) * 0.6;

  @override
  void render(Canvas canvas) {
    final horizon = _camera.project(const V3(230, 150, -100000))?.dy ?? 150;
    drawSky(
      canvas,
      Rect.fromLTWH(0, 0, 360, horizon + 1),
      const Color(0xFF5CA9E6),
      const Color(0xFFFCE3C4),
    );
    final hills = Path()..moveTo(0, horizon + 1);
    for (var x = 0.0; x <= 360; x += 8) {
      hills.lineTo(
        x,
        horizon - 18 - 22 * math.sin(x / 53 + 0.6).abs() - 7 * math.sin(x / 17),
      );
    }
    hills
      ..lineTo(360, horizon + 1)
      ..close();
    canvas
      ..drawPath(hills, Paint()..color = const Color(0xFF6C8F84))
      ..drawRect(
        Rect.fromLTWH(0, horizon, 360, 640 - horizon),
        Paint()..color = const Color(0xFF3D7FA8),
      );
    final s = Scene3D(
      _camera,
      light: const V3(-0.4, 1, 0.3),
      ambient: 0.5,
      fogColor: const Color(0xFFB9CCD2),
      fogStart: 1300,
      fogEnd: 3400,
    );
    // Lake with gentle animated ripples; brighter towards the horizon.
    const cell = 90.0;
    for (var i = -10; i < 14; i++) {
      for (var j = -32; j < 10; j++) {
        final x0 = i * cell, z0 = j * cell;
        final w = _wave(x0, z0);
        final far = ((-z0) / 2900).clamp(0.0, 1.0);
        final col = tint(
          Color.lerp(const Color(0xFF1F6E99), const Color(0xFF7FB6CF), far)!,
          w * 0.05 + (cellNoise(i, j, 3) - 0.5) * 0.03,
        );
        s.quad(
          V3(x0, 0, z0),
          V3(x0, 0, z0 + cell),
          V3(x0 + cell, 0, z0 + cell),
          V3(x0 + cell, 0, z0),
          col,
          layer: Layer.ground,
        );
      }
    }
    // Far shore with a pine forest.
    s.ground(
      const Rect.fromLTRB(-1400, -3300, 1800, -2900),
      (i, j) => tint(const Color(0xFF557A45), (cellNoise(i, j, 7) - 0.5) * 0.1),
      cell: 200,
      height: 2,
      layer: Layer.surface,
    );
    for (var k = 0; k < 34; k++) {
      final x = -1300 + k * 92.0 + cellNoise(k, 1, 4) * 60;
      final z = -2960 - cellNoise(k, 2, 4) * 260;
      final h = 90 + cellNoise(k, 3, 4) * 90;
      s
        ..tube(
          V3(x, 0, z),
          V3(x, h * 0.3, z),
          6,
          6,
          const Color(0xFF4E342E),
          segments: 4,
        )
        ..tube(
          V3(x, h * 0.2, z),
          V3(x, h, z),
          h * 0.28,
          0,
          const Color(0xFF2F5D3A),
          segments: 6,
        );
    }
    // Near bank (reeds) and the wooden dock.
    s.ground(
      const Rect.fromLTRB(-400, 640, 800, 900),
      (i, j) => tint(const Color(0xFF7A9A4A), (cellNoise(i, j, 8) - 0.5) * 0.1),
      cell: 100,
      height: 4,
      layer: Layer.surface,
    );
    for (var k = 0; k < 18; k++) {
      final x = -60 + k * 28.0 + cellNoise(k, 5, 4) * 14;
      if (x > 120 && x < 260) continue;
      final b = V3(x, 2, 640 + cellNoise(k, 6, 4) * 20);
      s.tube(
        b,
        b + V3(cellNoise(k, 7, 4) * 6 - 3, 30 + cellNoise(k, 8, 4) * 20, 0),
        1.4,
        0.5,
        const Color(0xFF8AA04A),
        segments: 3,
      );
    }
    for (var k = 0; k < 9; k++) {
      final z = 700 - k * 24.0;
      s.box(
        V3(190, 12, z),
        70,
        4,
        22,
        tint(const Color(0xFF8D6E63), (cellNoise(k, 0, 2) - 0.5) * 0.2),
        top: tint(const Color(0xFFA1887F), (cellNoise(k, 1, 2) - 0.5) * 0.2),
      );
    }
    for (final x in [158.0, 222.0]) {
      for (final z in [500.0, 600.0, 690.0]) {
        s.tube(
          V3(x, -20, z),
          V3(x, 16, z),
          3.5,
          3.5,
          const Color(0xFF5D4037),
          segments: 6,
        );
      }
    }
    // Zone buoys and their species labels.
    for (final x in [180.0, 260.0]) {
      for (final lat in [-140.0, 140.0]) {
        final b = V3(180 + lat, _wave(lat, _z(x)) * 2, _z(x));
        s
          ..sphere(b, 7, const Color(0xFFFF7043), lat: 4, lon: 8)
          ..tube(
            b,
            b + const V3(0, 14, 0),
            1,
            1,
            const Color(0xFFF5F5F5),
            segments: 4,
          );
      }
    }
    // Angler from behind, rod raised; the rod bends in a fight.
    final fighting = _phase == _Phase.fight;
    s
      ..shadow(const Offset(190, 520), 16, height: 16.3, opacity: 0.3)
      ..figure(
        const V3(190, 16, 520),
        const Color(0xFF2E7D32),
        scale: 1.5,
        arms: 0.12,
        shorts: const Color(0xFF3E4A59),
      )
      ..sphere(
        const V3(190, 77, 520),
        9.6,
        const Color(0xFFF2C14E),
        lat: 4,
        lon: 8,
      );
    const hand = V3(204, 52, 512);
    final bend = fighting ? (0.4 + tension * 0.6) : 0.0;
    final mid = hand + (_tip - hand) * 0.55 + V3(0, -bend * 8, -bend * 6);
    final tip = _tip + V3(0, -bend * 26, bend * 10);
    s
      ..tube(hand, mid, 1.6, 1.1, const Color(0xFF3E2723), segments: 4)
      ..tube(mid, tip, 1.1, 0.5, const Color(0xFF3E2723), segments: 4);
    void line(V3 to, Color c) =>
        s.tube(tip, to, 0.35, 0.35, c, segments: 3, layer: Layer.overlay);

    if (_phase == _Phase.sinking || _phase == _Phase.bite) {
      final dunk = _phase == _Phase.bite ? -6.0 : math.sin(elapsed * 3) * 1.5;
      final bob = V3(180, dunk + _wave(180, _z(_lureX)) * 2, _z(_lureX));
      line(bob + const V3(0, 9, 0), const Color(0xFFEEEEEE));
      s
        ..sphere(
          bob + const V3(0, 3, 0),
          6,
          const Color(0xFFE53935),
          lat: 4,
          lon: 8,
        )
        ..sphere(
          bob + const V3(0, 8, 0),
          4,
          const Color(0xFFF5F5F5),
          lat: 3,
          lon: 6,
        )
        ..tube(
          bob + const V3(0, 11, 0),
          bob + const V3(0, 18, 0),
          0.8,
          0.8,
          const Color(0xFFF5F5F5),
          segments: 3,
        );
      _ripples(s, bob, _phase == _Phase.bite ? 2.2 : 1);
      if (_phase == _Phase.bite) {
        final p = _camera.project(bob + const V3(0, 40, 0));
        if (p != null) {
          drawText(
            canvas,
            '!',
            p,
            size: 34,
            display: true,
            align: TextAlign.center,
            color: const Color(0xFFFFD23F),
          );
        }
      }
    } else if (fighting) {
      final x = rodTip.dx + distance;
      final thrash = math.sin(elapsed * 5);
      final head = V3(
        180 + thrash * 24,
        2 + math.sin(elapsed * 9).abs() * 6 * tension,
        _z(x),
      );
      line(
        head,
        tension > 0.8 ? const Color(0xFFE53935) : const Color(0xFFFFFFFF),
      );
      _fish3d(s, head, thrash);
      _ripples(s, head, 2.5);
    }
    s.render(canvas);
    for (var i = 0; i < 3; i++) {
      final p = _camera.project(V3(180, 26, _z(145 + i * 80.0)));
      if (p == null) continue;
      drawText(
        canvas,
        lake.zones[i].map((sp) => sp.emoji).toSet().join(),
        p,
        size: 12,
        align: TextAlign.center,
      );
    }
    if (fighting) {
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
    } else if (_phase == _Phase.idle) {
      drawText(
        canvas,
        '👆',
        const Offset(180, 600),
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

  /// Expanding rings on the water around [at].
  void _ripples(Scene3D s, V3 at, double strength) {
    for (var k = 0; k < 2; k++) {
      final t = (elapsed * 0.9 + k * 0.5) % 1;
      final r = 8 + t * 30 * strength;
      final col = Color.fromRGBO(255, 255, 255, (1 - t) * 0.6);
      const n = 18;
      for (var i = 0; i < n; i++) {
        final a0 = i / n * 2 * math.pi, a1 = (i + 1) / n * 2 * math.pi;
        V3 p(double a, double rr) =>
            V3(at.x + math.cos(a) * rr, 0.4, at.z + math.sin(a) * rr);
        s.quad(
          p(a0, r),
          p(a1, r),
          p(a1, r + 1.6),
          p(a0, r + 1.6),
          col,
          lit: false,
          doubleSided: true,
          layer: Layer.decal,
        );
      }
    }
  }

  /// Fish thrashing at the surface: body, tail and dorsal fin.
  void _fish3d(Scene3D s, V3 head, double thrash) {
    final body = _species!.color;
    final dir = V3(math.sin(thrash) * 0.6, 0, 1).normalized; // head → tail
    final side = V3(dir.z, 0, -dir.x);
    final mid = head + dir * 16;
    final tail = head + dir * 34;
    s
      ..tube(head, mid, 2, 8, body, segments: 8, capped: true)
      ..tube(mid, tail, 8, 2, tint(body, -0.1), segments: 8)
      ..tri(
        tail,
        tail + dir * 10 + side * 9 + const V3(0, 4, 0),
        tail + dir * 10 - side * 9 + const V3(0, 4, 0),
        tint(body, -0.2),
        doubleSided: true,
      )
      ..tri(
        mid - dir * 6 + const V3(0, 7, 0),
        mid + dir * 8 + const V3(0, 7, 0),
        mid + const V3(0, 14, 0),
        tint(body, -0.25),
        doubleSided: true,
      );
  }
}
