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

  @override
  void render(Canvas canvas) {
    canvas
      ..drawRect(Arena.rect, Paint()..color = const Color(0xFF90A4AE))
      ..drawRect(sheet, Paint()..color = const Color(0xFFF5FBFF));
    const ringColors = [
      Colors.white,
      Color(0xFFE53935),
      Colors.white,
      Color(0xFF1E88E5),
    ];
    for (var i = rings.length - 1; i >= 0; i--) {
      canvas.drawCircle(house, rings[i], Paint()..color = ringColors[i]);
    }
    canvas
      ..drawLine(
        Offset(sheet.left, house.dy),
        Offset(sheet.right, house.dy),
        Paint()..color = Colors.black26,
      )
      ..drawLine(
        Offset(180, sheet.top),
        const Offset(180, 640),
        Paint()..color = Colors.black12,
      )
      ..drawLine(
        Offset(sheet.left, 420),
        Offset(sheet.right, 420),
        Paint()
          ..color = const Color(0x66E53935)
          ..strokeWidth = 3,
      );
    void stone(Body? b, Color handle) {
      if (b == null) return;
      drawBall(canvas, b.px, stoneR, const Color(0xFF78909C));
      canvas
        ..save()
        ..translate(b.px.dx, b.px.dy)
        ..rotate(b.angle)
        ..drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(-7, -3, 14, 6),
            const Radius.circular(3),
          ),
          Paint()..color = handle,
        )
        ..restore();
    }

    for (final b in _them) {
      stone(b, const Color(0xFFFFD23F));
    }
    for (final b in _mine) {
      stone(b, const Color(0xFFE8322F));
    }
    if (_moving != null && _sweeping) {
      final p = _moving!.px.translate(0, -22);
      final brush = Paint()
        ..color = const Color(0xFF263238)
        ..strokeWidth = 4;
      final wiggle = (step % 12 < 6 ? -6.0 : 6.0);
      canvas.drawLine(
        p.translate(-10 + wiggle, 0),
        p.translate(10 + wiggle, 0),
        brush,
      );
    }
    if (_moving == null && thrown < stones) {
      drawBall(canvas, hack, stoneR, const Color(0xFF78909C));
      drawText(
        canvas,
        '👆',
        const Offset(180, 620),
        size: 22,
        align: TextAlign.center,
      );
    }
    if (_moving != null) {
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
