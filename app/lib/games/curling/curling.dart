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
import '../common/render3d.dart';

/// 7.9 Curling — 6 stones as close as possible to the button.
class CurlingGame extends MiniGameDefinition {
  const CurlingGame();

  @override
  String get id => 'curling';
  @override
  String get emoji => '🥌';
  @override
  GameCategory get category => GameCategory.sport;
  @override
  int get rulesVersion => 1;
  @override
  Set<String> get supportedModifiers => {Modifiers.ice};
  @override
  ScoreBounds get scoreBounds => const ScoreBounds(0, 6 * 400 + 4 * 200);

  @override
  Map<String, num> get defaultTuning => const {
    'damping': 0.5,
    'sweepDamping': 0.32,
    'curl': 55,
    'swipeGain': 0.5,
  };

  @override
  String name(AppLocalizations l10n) => l10n.gameCurlingName;
  @override
  String rule(AppLocalizations l10n) => l10n.gameCurlingRule;

  @override
  String shareLine(AppLocalizations l10n, Map<String, num> s) => l10n
      .gameCurlingShare(s['inHouse']?.toInt() ?? 0, s['knocked']?.toInt() ?? 0);

  @override
  List<(String, String)> statRows(AppLocalizations l10n, Map<String, num> s) =>
      [
        (l10n.statInHouse, '${s['inHouse'] ?? 0} / 6'),
        (l10n.statKnockedOut, '${s['knocked'] ?? 0}'),
        (l10n.statButtons, '${s['buttons'] ?? 0}'),
      ];

  @override
  Map<String, String> highlightLabels(AppLocalizations l10n) => {
    'button': l10n.highlightButton,
  };

  @override
  GameSim createSim(GameContext ctx) => CurlingSim(ctx, this);

  @override
  String levelFingerprint(int seed, String? modifierId) => fingerprint([
    for (final o in CurlingSim.opponents(seed)) ...[o.dx, o.dy],
  ]);
}

class CurlingSim extends GameSim {
  CurlingSim(super.ctx, CurlingGame def)
    : _damping =
          ctx.tune('damping', def.defaultTuning['damping']!) *
          (ctx.has(Modifiers.ice) ? 0.5 : 1),
      _sweepDamping =
          ctx.tune('sweepDamping', def.defaultTuning['sweepDamping']!) *
          (ctx.has(Modifiers.ice) ? 0.5 : 1),
      _curl = ctx.tune('curl', def.defaultTuning['curl']!),
      _gain = ctx.tune('swipeGain', def.defaultTuning['swipeGain']!) {
    final w = _world = Phys.world();
    const s = sheet;
    for (final (a, b) in [
      (s.topLeft, s.topRight),
      (s.topLeft, s.bottomLeft),
      (s.topRight, s.bottomRight),
    ]) {
      Phys.staticSegment(w, a, b, restitution: 0.3);
    }
    for (final o in opponents(ctx.seed)) {
      _them.add(_stone(o));
    }
    _initiallyIn = _live(_them).where((b) => _ring(b.px) > 0).length;
  }

  static const Rect sheet = Rect.fromLTRB(60, 96, 300, 640);
  static const Offset house = Offset(180, 200);
  static const Offset hack = Offset(180, 590);
  static const double stoneR = 11;
  static const List<double> rings = [12, 30, 50, 72];
  static const List<int> ringPoints = [400, 250, 150, 50];
  static const int stones = 6;

  /// Opponent stones already in play, from the seed.
  static List<Offset> opponents(int seed) {
    final r = SeededRandom.derive(seed, 'curling:opponents');
    final n = r.intInRange(2, 4);
    final out = <Offset>[];
    while (out.length < n) {
      final a = r.nextDouble() * math.pi * 2;
      final d = r.doubleInRange(10, 95);
      final p = house + Offset(math.cos(a), math.sin(a) * 1.2) * d;
      if (out.every((q) => (q - p).distance > stoneR * 2.4)) out.add(p);
    }
    return out;
  }

  final double _damping;
  final double _sweepDamping;
  final double _curl;
  final double _gain;
  late final World _world;
  final List<Body?> _mine = [];
  final List<Body?> _them = [];
  late final int _initiallyIn;

  int thrown = 0;
  int buttons = 0;
  Body? _moving;
  double _spin = 0;
  int _lastSweep = -1000;
  int _sweeps = 0;
  int? _pointer;
  final List<(int, Offset)> _path = [];

  Iterable<Body> _live(List<Body?> l) => l.whereType<Body>();

  Body _stone(Offset at) => Phys.ball(
    _world,
    at,
    stoneR,
    density: 3,
    restitution: 0.5,
    friction: 0.1,
    linearDamping: _damping,
  )..angularDamping = 0.5;

  /// 1 (button) … 4 (outer ring), 0 outside the house.
  int _ring(Offset p) {
    final d = (p - house).distance - stoneR * 0.5;
    for (var i = 0; i < rings.length; i++) {
      if (d <= rings[i]) return i + 1;
    }
    return 0;
  }

  bool get _sweeping => step - _lastSweep < 36;

  @override
  Color get backgroundColor => const Color(0xFFB0BEC5);

  @override
  int get debugBodyCount => _live(_mine).length + _live(_them).length;

  @override
  Offset get focus => _moving?.px ?? house;

  @override
  void onPointer(PointerPhase phase, int pointer, Offset pos) {
    if (_moving != null) {
      // Frantic taps = sweeping.
      if (phase == PointerPhase.down) {
        _lastSweep = step;
        _sweeps++;
        cue(sfx: Sfx.tap, haptic: Haptic.selection);
      }
      return;
    }
    if (thrown >= stones) return;
    switch (phase) {
      case PointerPhase.down:
        if (_pointer != null || pos.dy < 380) return;
        _pointer = pointer;
        _path
          ..clear()
          ..add((step, pos));
      case PointerPhase.move:
        if (pointer == _pointer) _path.add((step, pos));
      case PointerPhase.up:
        if (pointer != _pointer) return;
        _pointer = null;
        _path.add((step, pos));
        _launch();
    }
  }

  void _launch() {
    final a = _path.first, b = _path.last;
    final d = b.$2 - a.$2;
    if (d.dy > -40) return;
    final dt = math.max(1, b.$1 - a.$1) / stepsPerSecond;
    var v = d / dt * _gain;
    if (v.distance > 760) v = v / v.distance * 760;
    // Curvature of the swipe = rotation of the stone (curl).
    var dev = 0.0;
    final n = Offset(-d.dy, d.dx) / d.distance;
    for (final (_, p) in _path) {
      final off = (p - a.$2).dx * n.dx + (p - a.$2).dy * n.dy;
      if (off.abs() > dev.abs()) dev = off;
    }
    _spin = (dev / d.distance * 4).clamp(-1.0, 1.0);
    final s = _stone(hack)..velPx = v;
    s.angularVelocity = _spin * 3;
    _mine.add(s);
    _moving = s;
    thrown++;
    cue(sfx: Sfx.whoosh, haptic: Haptic.medium);
  }

  @override
  void tick() {
    tickParticles();
    final m = _moving;
    if (m != null) {
      final v = m.velPx;
      m.linearDamping = _sweeping ? _sweepDamping : _damping;
      if (v.distance > 8) {
        // Curl grows as the stone slows down; sweeping straightens it.
        final dir = v / v.distance;
        final side = Offset(-dir.dy, dir.dx);
        final curl =
            _spin *
            _curl *
            (1 - (v.distance / 900).clamp(0.0, 0.8)) *
            (_sweeping ? 0.6 : 1);
        m.applyForce(Phys.v(side * curl) * m.mass);
      }
    }
    Phys.step(_world);
    for (final _ in _world.contactEvents.hit) {
      cue(sfx: Sfx.hit, haptic: Haptic.light);
    }
    // Stones leaving the sheet are removed from the world.
    for (final list in [_mine, _them]) {
      for (var i = 0; i < list.length; i++) {
        final b = list[i];
        if (b != null && !sheet.contains(b.px)) {
          if (identical(b, _moving)) _moving = null;
          b.destroy();
          list[i] = null;
          cue(sfx: Sfx.miss);
        }
      }
    }
    if (m == null) return;
    final stillThere = identical(_moving, m);
    final allStill = [
      ..._live(_mine),
      ..._live(_them),
    ].every((b) => b.velPx.distance < 3);
    if (!stillThere || allStill) {
      _moving = null;
      if (stillThere && (m.px - house).distance < rings[0]) {
        buttons++;
        celebrate('button');
        particles.fireworks(house);
      }
      _rescore();
      if (thrown >= stones) over = true;
    }
  }

  /// Cached at each rescore: bodies must not be read after [dispose].
  int inHouse = 0;
  int knockedOut = 0;

  void _rescore() {
    var s = 0;
    inHouse = 0;
    for (final b in _live(_mine)) {
      final r = _ring(b.px);
      if (r > 0) {
        s += ringPoints[r - 1];
        inHouse++;
      }
    }
    knockedOut = math.max(
      0,
      _initiallyIn - _live(_them).where((b) => _ring(b.px) > 0).length,
    );
    score = s + knockedOut * 200;
  }

  @override
  void onTimeUp() {
    if (!_disposed) _rescore();
  }

  bool _disposed = false;

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _world.destroy();
  }

  @override
  Map<String, num> get stats => {
    'inHouse': inHouse,
    'knocked': knockedOut,
    'buttons': buttons,
    'sweeps': _sweeps,
  };

  // ---------------------------------------------------------------- 3D

  static final Camera3D _camera = Camera3D(
    eye: const V3(180, 240, 860),
    target: const V3(180, 0, 250),
    fovDegrees: 46,
    center: const Offset(180, 300),
  );

  @override
  Camera3D get camera3d => _camera;

  void _stone3d(Scene3D s, Body? b, Color handle) {
    if (b == null) return;
    final p = b.px;
    s
      ..shadow(p.translate(3, 3), stoneR * 1.1)
      ..cylinder(
        V3.ground(p),
        stoneR,
        7,
        const Color(0xFF78909C),
        top: const Color(0xFF90A4AE),
        segments: 16,
      )
      ..box(V3.ground(p, 7), 13, 4, 5, handle, yaw: b.angle);
  }

  @override
  void render(Canvas canvas) {
    drawSky(
      canvas,
      Arena.rect,
      const Color(0xFF90A4AE),
      const Color(0xFFECEFF1),
    );
    final s = Scene3D(
      _camera,
      ambient: 0.6,
      fogColor: const Color(0xFFECEFF1),
      fogStart: 700,
      fogEnd: 1800,
    );
    s
      ..ground(
        const Rect.fromLTRB(-400, -400, 760, 1100),
        (i, j) => const Color(0xFFB0BEC5),
        cell: 100,
        height: -2,
      )
      ..ground(
        sheet,
        (i, j) =>
            tint(const Color(0xFFF5FBFF), (cellNoise(i, j, 6) - 0.5) * 0.02),
        cell: 30,
        layer: Layer.surface,
      );
    const ringColors = [
      Colors.white,
      Color(0xFFE53935),
      Colors.white,
      Color(0xFF1E88E5),
    ];
    for (var i = rings.length - 1; i >= 0; i--) {
      s.cylinder(
        V3.ground(house, -1 + (rings.length - i) * 0.01),
        rings[i],
        1.2,
        ringColors[i],
        segments: 32,
        top: ringColors[i],
      );
    }
    s
      ..ground(
        Rect.fromLTRB(sheet.left, house.dy - 1, sheet.right, house.dy + 1),
        (i, j) => const Color(0x55000000),
        cell: 400,
        height: 0.4,
        layer: Layer.decal,
      )
      ..ground(
        Rect.fromLTRB(sheet.left, 418, sheet.right, 422),
        (i, j) => const Color(0x88E53935),
        cell: 400,
        height: 0.4,
        layer: Layer.decal,
      )
      ..box(
        V3(sheet.left - 5, 0, 368),
        10,
        10,
        sheet.height,
        const Color(0xFF455A64),
      )
      ..box(
        V3(sheet.right + 5, 0, 368),
        10,
        10,
        sheet.height,
        const Color(0xFF455A64),
      );
    for (final b in _them) {
      _stone3d(s, b, const Color(0xFFFFD23F));
    }
    for (final b in _mine) {
      _stone3d(s, b, const Color(0xFFE8322F));
    }
    final m = _moving;
    if (m != null && _sweeping) {
      final p = m.px.translate(step % 12 < 6 ? -6 : 6, -24);
      s
        ..box(V3.ground(p, 0.5), 26, 3, 6, const Color(0xFF263238))
        ..figure(
          V3.ground(p.translate(18, 8)),
          const Color(0xFF1565C0),
          arms: 0.2,
          scale: 0.6,
        );
    }
    if (m == null && thrown < stones) {
      _stone3d(s, null, const Color(0xFFE8322F));
    }
    s.render(canvas);
    if (m == null && thrown < stones) {
      final p = _camera.project(V3.ground(hack));
      if (p != null) {
        drawText(
          canvas,
          '👆',
          p.translate(0, 24),
          size: 22,
          align: TextAlign.center,
        );
      }
    }
    if (m != null) {
      drawText(
        canvas,
        'TAP TAP TAP',
        const Offset(180, 470),
        size: 16,
        display: true,
        align: TextAlign.center,
        color: _sweeping ? const Color(0xFFE8322F) : Colors.black38,
      );
    }
    drawText(
      canvas,
      '🥌 ${stones - thrown}',
      const Offset(16, 100),
      size: 16,
      color: Colors.black87,
    );
  }
}
