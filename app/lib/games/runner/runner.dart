import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../core/l10n/l10n.dart';
import '../../core/rng/seeded_random.dart';
import '../common/draw.dart';
import '../common/fingerprint.dart';
import '../common/game_sim.dart';
import '../common/game_types.dart';
import '../common/mini_game_definition.dart';

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

  double _screenY(double at) => playerY - (at - distance);

  @override
  void render(Canvas canvas) {
    canvas.drawRect(Arena.rect, Paint()..color = const Color(0xFF263238));
    canvas.drawPath(
      Path()
        ..moveTo(150, 90)
        ..lineTo(210, 90)
        ..lineTo(330, 640)
        ..lineTo(30, 640)
        ..close(),
      Paint()..color = const Color(0xFF455A64),
    );
    final dash = Paint()
      ..color = Colors.white24
      ..strokeWidth = 3;
    for (var y = -(distance % 60); y < 640; y += 60) {
      for (final x in [140.0, 220.0]) {
        canvas.drawLine(Offset(x, y), Offset(x, y + 30), dash);
      }
    }
    for (var i = _first; i < _items.length; i++) {
      final o = _items[i];
      final y = _screenY(o.at);
      if (y < 60) break;
      if (y > 680) continue;
      final x = lanes[o.lane];
      switch (o.kind) {
        case ObstacleType.coin:
          if (!_taken.contains(i)) {
            drawBall(canvas, Offset(x, y), 8, const Color(0xFFFFD23F));
          }
        case ObstacleType.low:
          drawBox(
            canvas,
            Rect.fromCenter(center: Offset(x, y), width: 60, height: 14),
            const Color(0xFFFF7043),
          );
        case ObstacleType.high:
          canvas
            ..drawLine(
              Offset(x - 30, y),
              Offset(x - 30, y - 40),
              Paint()
                ..color = Colors.white70
                ..strokeWidth = 3,
            )
            ..drawLine(
              Offset(x + 30, y),
              Offset(x + 30, y - 40),
              Paint()
                ..color = Colors.white70
                ..strokeWidth = 3,
            );
          drawBox(
            canvas,
            Rect.fromCenter(center: Offset(x, y - 40), width: 64, height: 10),
            const Color(0xFF29B6F6),
          );
        case ObstacleType.block:
          drawBox(
            canvas,
            Rect.fromCenter(center: Offset(x, y - 10), width: 58, height: 40),
            const Color(0xFF8D6E63),
          );
      }
    }
    // Runner.
    final h = _height;
    final body = _slide > 0
        ? Rect.fromCenter(
            center: Offset(_x, playerY - 6),
            width: 30,
            height: 16,
          )
        : Rect.fromCenter(
            center: Offset(_x, playerY - 18 - h),
            width: 22,
            height: 30,
          );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(_x, playerY + 4), width: 30, height: 8),
      Paint()..color = Colors.black38,
    );
    drawBox(canvas, body, const Color(0xFFE8322F), radius: 8);
    canvas.drawCircle(
      Offset(_x, body.top - 6),
      8,
      Paint()..color = const Color(0xFFFFD23F),
    );
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
}
