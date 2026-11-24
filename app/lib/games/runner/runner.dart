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

/// 7.19 Course — endless runner on 3 lanes: jump, slide, change lanes.
class RunnerGame extends MiniGameDefinition {
  const RunnerGame();

  @override
  String get id => 'runner';
  @override
  String get emoji => '🏃';
  @override
  GameCategory get category => GameCategory.arcade;
  @override
  int get rulesVersion => 1;
  @override
  Set<String> get supportedModifiers => {Modifiers.night, Modifiers.turbo};
  @override
  ScoreBounds get scoreBounds => const ScoreBounds(0, 12000);

  @override
  Map<String, num> get defaultTuning => const {
    'startSpeed': 320,
    'endSpeed': 560,
  };

  @override
  String name(AppLocalizations l10n) => l10n.gameRunnerName;
  @override
  String rule(AppLocalizations l10n) => l10n.gameRunnerRule;

  @override
  String shareLine(AppLocalizations l10n, Map<String, num> s) =>
      l10n.gameRunnerShare(s['meters']?.toInt() ?? 0, s['coins']?.toInt() ?? 0);

  @override
  List<(String, String)> statRows(AppLocalizations l10n, Map<String, num> s) =>
      [
        (l10n.statDistance, '${s['meters'] ?? 0} m'),
        (l10n.statCoins, '${s['coins'] ?? 0}'),
      ];

  @override
  Map<String, String> highlightLabels(AppLocalizations l10n) => {
    'marathon': l10n.highlightMarathon,
  };

  @override
  GameSim createSim(GameContext ctx) => RunnerSim(ctx, this);

  @override
  String levelFingerprint(int seed, String? modifierId) => fingerprint([
    for (final o in RunnerSim.track(
      GameContext(seed: seed, modifierId: modifierId),
    ).take(80)) ...[o.at, o.lane, o.kind.index],
  ]);
}

enum ObstacleType { low, high, block, coin }

class TrackItem {
  const TrackItem(this.at, this.lane, this.kind);

  /// Distance (px) along the track.
  final double at;
  final int lane;
  final ObstacleType kind;
}

class RunnerSim extends GameSim {
  RunnerSim(super.ctx, RunnerGame def)
    : _items = track(ctx),
      _v0 = ctx.tune('startSpeed', def.defaultTuning['startSpeed']!),
      _v1 = ctx.tune('endSpeed', def.defaultTuning['endSpeed']!),
      _turbo = ctx.has(Modifiers.turbo) ? 1.25 : 1.0;

  static const double playerY = 520;
  static const lanes = [100.0, 180.0, 260.0];

  /// Obstacles and coins from the seed: always at least one free lane.
  static List<TrackItem> track(GameContext ctx) {
    final r = SeededRandom.derive(ctx.seed, 'runner:track');
    final out = <TrackItem>[];
    var at = 700.0;
    while (at < 80000) {
      final kind = r.nextInt(10);
      if (kind < 3) {
        // A row of blocks with one free lane.
        final free = r.nextInt(3);
        for (var l = 0; l < 3; l++) {
          if (l != free) out.add(TrackItem(at, l, ObstacleType.block));
        }
        out.add(TrackItem(at, free, ObstacleType.coin));
      } else if (kind < 6) {
        out.add(TrackItem(at, r.nextInt(3), ObstacleType.low));
        out.add(TrackItem(at, r.nextInt(3), ObstacleType.low));
      } else if (kind < 8) {
        out.add(TrackItem(at, r.nextInt(3), ObstacleType.high));
      } else {
        final lane = r.nextInt(3);
        for (var k = 0; k < 5; k++) {
          out.add(TrackItem(at + k * 40, lane, ObstacleType.coin));
        }
      }
      at += r.doubleInRange(260, 420);
    }
    return out;
  }

  final List<TrackItem> _items;
  final double _v0, _v1, _turbo;
  final Set<int> _taken = {};

  double distance = 0;
  int coins = 0;
  int _lane = 1;
  double _x = lanes[1];
  int _jump = 0, _slide = 0;
  int _first = 0;
  bool survived = false;
  int? _pointer;
  Offset _down = Offset.zero;

  double get _speed =>
      (_v0 + (_v1 - _v0) * math.min(1, elapsed / 120)) * _turbo;
  int get meters => distance ~/ 20;
  bool get _airborne => _jump > 0;
  double get _height =>
      _airborne ? math.sin(math.pi * (1 - _jump / 72)) * 50 : 0;

  @override
  Color get backgroundColor => const Color(0xFF263238);

  @override
  Offset get focus => Offset(_x, playerY);

  @override
  void onPointer(PointerPhase phase, int pointer, Offset pos) {
    switch (phase) {
      case PointerPhase.down:
        _pointer = pointer;
        _down = pos;
      case PointerPhase.move:
        break;
      case PointerPhase.up:
        if (pointer != _pointer) return;
        _pointer = null;
        final d = pos - _down;
        if (d.distance < 24) {
          if (!_airborne) {
            _jump = 72; // 0.6 s
            _slide = 0;
            cue(sfx: Sfx.whoosh, haptic: Haptic.selection);
          }
        } else if (d.dy.abs() > d.dx.abs()) {
          if (d.dy > 0) {
            _slide = 72;
            _jump = 0;
            cue(sfx: Sfx.whoosh, haptic: Haptic.selection);
          } else if (!_airborne) {
            _jump = 72;
          }
        } else {
          _lane = (_lane + (d.dx > 0 ? 1 : -1)).clamp(0, 2);
          cue(haptic: Haptic.selection);
        }
    }
  }

  @override
  void tick() {
    tickParticles();
    distance += _speed * stepDt;
    if (_jump > 0) _jump--;
    if (_slide > 0) _slide--;
    _x += (lanes[_lane] - _x).clamp(-900 * stepDt, 900 * stepDt);
    while (_first < _items.length && _items[_first].at < distance - 200) {
      _first++;
    }
    for (
      var i = _first;
      i < _items.length && _items[i].at < distance + 40;
      i++
    ) {
      final o = _items[i];
      if ((o.at - distance).abs() > 18) continue;
      if ((lanes[o.lane] - _x).abs() > 34) continue;
      switch (o.kind) {
        case ObstacleType.coin:
          if (_taken.add(i)) {
            coins++;
            particles.burst(
              Offset(lanes[o.lane], playerY - 10),
              const Color(0xFFFFD23F),
              count: 6,
              gravity: 0,
              speed: 90,
            );
            cue(sfx: Sfx.score);
          }
        case ObstacleType.low:
          if (_height < 22) return _crash();
        case ObstacleType.high:
          if (_slide == 0) return _crash();
        case ObstacleType.block:
          return _crash();
      }
    }
    score = meters + coins * 20;
  }

  void _crash() {
    over = true;
    particles.burst(Offset(_x, playerY), const Color(0xFFE8322F), count: 30);
    cue(sfx: Sfx.hit, haptic: Haptic.heavy);
  }

  @override
  void onTimeUp() {
    survived = true;
    celebrate('marathon');
  }

  @override
  Map<String, num> get stats => {
    'meters': meters,
    'coins': coins,
    'survived': survived ? 1 : 0,
  };

  // ── 3D rendering ──────────────────────────────────────────────────────
  // Track point (lane x, at) → V3(x, h, distance − at): ahead is −z.
  static const double _ahead = 2100, _behind = 160;

  V3 _w(double x, double at, [double h = 0]) => V3(x, h, distance - at);

  @override
  void render(Canvas canvas) {
    final cam = Camera3D(
      eye: V3(180 + (_x - 180) * 0.35, 120, 220),
      target: V3(180 + (_x - 180) * 0.2, 10, -320),
      fovDegrees: 58,
      center: const Offset(180, 300),
    );
    final horizon = cam.project(const V3(180, 120, -100000))?.dy ?? 200;
    drawSky(
      canvas,
      Rect.fromLTWH(0, 0, 360, horizon + 2),
      const Color(0xFF1C2541),
      const Color(0xFFF6A55B),
    );
    // Far skyline silhouettes.
    final sky = Path()..moveTo(0, horizon + 1);
    for (var k = 0; k < 24; k++) {
      final x0 = k * 15.0, top = horizon - 8 - cellNoise(k, 1, 12) * 34;
      sky
        ..lineTo(x0, top)
        ..lineTo(x0 + 15, top);
    }
    sky
      ..lineTo(360, horizon + 1)
      ..close();
    canvas
      ..drawPath(sky, Paint()..color = const Color(0xFF3A3F5C))
      ..drawRect(
        Rect.fromLTWH(0, horizon, 360, 640 - horizon),
        Paint()..color = const Color(0xFF4A4E5E),
      );
    final s = Scene3D(
      cam,
      light: const V3(-0.5, 0.9, 0.4),
      ambient: 0.5,
      fogColor: const Color(0xFF9C7A75),
      fogStart: 800,
      fogEnd: _ahead,
    );
    // Street: asphalt rows, lane dashes, raised sidewalks.
    const cell = 80.0;
    final j0 = ((distance - _behind) / cell).floor();
    final j1 = ((distance + _ahead) / cell).ceil();
    for (var j = j0; j < j1; j++) {
      final a0 = j * cell, a1 = a0 + cell;
      s.quad(
        _w(40, a0),
        _w(40, a1),
        _w(320, a1),
        _w(320, a0),
        tint(const Color(0xFF3D4047), (cellNoise(j, 0, 21) - 0.5) * 0.05),
        layer: Layer.ground,
      );
      for (final x in [140.0, 220.0]) {
        s.quad(
          _w(x - 2, a0 + 10),
          _w(x - 2, a0 + 50),
          _w(x + 2, a0 + 50),
          _w(x + 2, a0 + 10),
          const Color(0xFFE0E0E0),
          layer: Layer.decal,
        );
      }
      for (final (x0, x1) in [(-40.0, 40.0), (320.0, 400.0)]) {
        s.box(
          _w((x0 + x1) / 2, (a0 + a1) / 2),
          x1 - x0,
          6,
          cell,
          tint(const Color(0xFF9E9E9E), (j.isEven ? 0.04 : 0) - 0.02),
          layer: Layer.surface,
        );
      }
    }
    // Buildings with lit windows, street lamps.
    for (
      var k = (distance - _behind) ~/ 150;
      k < (distance + _ahead) ~/ 150;
      k++
    ) {
      for (final side in [-1, 1]) {
        final h = 140 + cellNoise(k, side, 13) * 280;
        final x = side < 0 ? -110.0 : 470.0;
        final at = k * 150.0 + 75;
        final col = [
          const Color(0xFF8D6E63),
          const Color(0xFF607D8B),
          const Color(0xFFB0846A),
          const Color(0xFF78909C),
        ][(cellNoise(k, side, 14) * 4).floor() % 4];
        s.box(_w(x, at), 140, h, 144, col);
        // Facade facing the street.
        final fx = side < 0 ? -40.0 + 0.6 : 400.0 - 0.6;
        for (var row = 0; row < (h - 30) ~/ 46; row++) {
          for (var c = 0; c < 3; c++) {
            final lit = cellNoise(k * 7 + c, row, side + 40) > 0.55;
            final z0 = at - 54 + c * 40, z1 = z0 + 24;
            final y0 = 30 + row * 46.0, y1 = y0 + 26;
            final win = lit ? const Color(0xFFFFE08A) : const Color(0xFF2B3440);
            final p0 = _w(fx, z0, y0), p1 = _w(fx, z1, y0);
            final p2 = _w(fx, z1, y1), p3 = _w(fx, z0, y1);
            s.quad(
              p0,
              p1,
              p2,
              p3,
              win,
              doubleSided: true,
              lit: !lit,
              depthBias: -2,
            );
          }
        }
      }
      if (k.isEven) {
        for (final x in [30.0, 330.0]) {
          final base = _w(x, k * 150.0, 6);
          final arm = x < 180 ? 22.0 : -22.0;
          s
            ..tube(
              base,
              base + const V3(0, 110, 0),
              1.8,
              1.4,
              const Color(0xFF37474F),
              segments: 5,
            )
            ..tube(
              base + const V3(0, 108, 0),
              base + V3(arm, 112, 0),
              1.2,
              1.2,
              const Color(0xFF37474F),
              segments: 4,
            )
            ..sphere(
              base + V3(arm, 108, 0),
              3.5,
              const Color(0xFFFFF3C4),
              lat: 3,
              lon: 6,
            );
        }
      }
    }
    // Obstacles and coins.
    for (var i = _first; i < _items.length; i++) {
      final o = _items[i];
      if (o.at > distance + _ahead) break;
      if (o.at < distance - _behind) continue;
      final x = lanes[o.lane];
      switch (o.kind) {
        case ObstacleType.coin:
          if (_taken.contains(i)) continue;
          final a = elapsed * 4 + o.at * 0.01;
          final axis = V3(math.cos(a), 0, math.sin(a));
          final c = _w(x, o.at, 20 + math.sin(elapsed * 5 + o.at * 0.05) * 4);
          s.tube(
            c - axis * 1.5,
            c + axis * 1.5,
            7.5,
            7.5,
            const Color(0xFFFFC928),
            segments: 10,
            capped: true,
          );
        case ObstacleType.low:
          // Striped road barrier: jump over it.
          for (var k = 0; k < 4; k++) {
            s.box(
              _w(x - 24 + k * 16, o.at, 6),
              16,
              10,
              6,
              k.isEven ? const Color(0xFFFF6D00) : const Color(0xFFF5F5F5),
            );
          }
          for (final dx in [-26.0, 26.0]) {
            s.box(_w(x + dx, o.at), 4, 8, 14, const Color(0xFF424242));
          }
          s.shadow(
            _w(x, o.at - 6).flat,
            30,
            height: 0.4,
            opacity: 0.25,
            stretch: 1.4,
          );
        case ObstacleType.high:
          // Overhead bar on two posts: slide under it.
          for (final dx in [-32.0, 32.0]) {
            s.tube(
              _w(x + dx, o.at),
              _w(x + dx, o.at, 46),
              2,
              2,
              const Color(0xFFECEFF1),
              segments: 5,
            );
          }
          s.box(_w(x, o.at, 36), 70, 10, 8, const Color(0xFF29B6F6));
        case ObstacleType.block:
          // Delivery van parked across the lane.
          s
            ..shadow(
              _w(x, o.at - 10).flat,
              40,
              height: 0.4,
              opacity: 0.35,
              stretch: 0.9,
            )
            ..box(
              _w(x, o.at - 4, 4),
              60,
              56,
              90,
              const Color(0xFFF5F5F5),
              top: const Color(0xFFE0E0E0),
            )
            ..box(_w(x, o.at + 40, 4), 60, 36, 26, const Color(0xFFE53935))
            ..quad(
              _w(x - 24, o.at + 53.5, 22),
              _w(x + 24, o.at + 53.5, 22),
              _w(x + 24, o.at + 53.5, 36),
              _w(x - 24, o.at + 53.5, 36),
              const Color(0xFF263238),
              doubleSided: true,
              depthBias: -1,
            );
          for (final dx in [-28.0, 28.0]) {
            for (final dz in [-30.0, 30.0]) {
              final c = _w(x + dx, o.at + dz, 9);
              s.tube(
                c - const V3(3, 0, 0),
                c + const V3(3, 0, 0),
                9,
                9,
                const Color(0xFF1A1A1A),
                capped: true,
              );
            }
          }
      }
    }
    _runner3d(s);
    s.render(canvas);

    drawText(
      canvas,
      '$meters m',
      const Offset(16, 100),
      size: 16,
      display: true,
    );
    drawText(
      canvas,
      '🪙 $coins',
      const Offset(344, 100),
      size: 16,
      align: TextAlign.right,
    );
  }

  /// Animated runner: swinging arms and legs, jump and slide poses.
  void _runner3d(Scene3D s) {
    final h = _height;
    final base = _w(_x, distance, h);
    s.shadow(base.flat, 16 * (1 - h / 120), height: 0.5, opacity: 0.4);
    const shirt = Color(0xFFE8322F), skin = Color(0xFFFFCC80);
    const pants = Color(0xFF283593), shoe = Color(0xFFF5F5F5);
    final phase = distance / 26;
    const ax = V3(1, 0, 0);
    // Limb from [top] swinging by [a] (radians, + = forward / −z).
    void limb(V3 top, double a, double len, double w, Color c) {
      final ay = V3(0, -math.cos(a), -math.sin(a));
      final az = V3(0, math.sin(a), -math.cos(a));
      s.boxAxes(top + ay * len, ax, ay * -1, az * -1, w, len, w, c);
    }

    if (_slide > 0) {
      // Baseball slide: lying back, feet first.
      final hip = base + const V3(0, 8, 0);
      s
        ..boxAxes(
          hip,
          ax,
          const V3(0, 0.45, 0.89),
          const V3(0, 0.89, -0.45),
          16,
          22,
          9,
          shirt,
        )
        ..sphere(hip + const V3(0, 14, 25), 7, skin, lat: 5, lon: 8);
      for (final dx in [-5.0, 5.0]) {
        limb(hip + V3(dx, 0, 0), 1.35, 24, 6, pants);
      }
      return;
    }
    final swing = _airborne ? 0.5 : math.sin(phase) * 0.8;
    final hip = base + const V3(0, 26, 0);
    limb(hip + const V3(-5, 0, 0), swing, 25, 6.5, pants);
    limb(hip + const V3(5, 0, 0), _airborne ? -0.3 : -swing, 25, 6.5, pants);
    for (final (dx, a) in [(-5.0, swing), (5.0, _airborne ? -0.3 : -swing)]) {
      final foot = hip + V3(dx, -25 * math.cos(a), -25 * math.sin(a));
      s.box(foot + const V3(0, -1, -3), 7, 4, 11, shoe);
    }
    s
      ..box(hip, 17, 22, 10, shirt)
      ..sphere(hip + const V3(0, 30, 0), 7.5, skin, lat: 5, lon: 8)
      ..sphere(
        hip + const V3(0, 32.5, 1.5),
        7.6,
        const Color(0xFF3E2723),
        lat: 4,
        lon: 8,
      );
    limb(hip + const V3(-11, 20, 0), _airborne ? 2.6 : -swing, 17, 4.5, shirt);
    limb(hip + const V3(11, 20, 0), _airborne ? 2.6 : swing, 17, 4.5, shirt);
  }
}
