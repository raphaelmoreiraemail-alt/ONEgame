import 'dart:math' as math;

import 'package:flame/game.dart';
import 'package:material_ui/material_ui.dart';

import 'draw.dart';
import 'game_sim.dart';
import 'game_types.dart';

/// Flame wrapper around a [GameSim]: fixed-step accumulator, letterboxed
/// world, input stamping and logging, HUD notifiers.
class MiniGame extends FlameGame {
  MiniGame({
    required this.sim,
    required this.maxDuration,
    this.onCue,
    this.onFinished,
    this.showDebug = false,
  }) : maxSteps = maxDuration.inMilliseconds * stepsPerSecond ~/ 1000 {
    remainingSeconds.value = (maxSteps / stepsPerSecond).ceil();
  }

  final GameSim sim;
  final Duration maxDuration;
  final int maxSteps;
  final void Function(GameCue cue)? onCue;
  final VoidCallback? onFinished;
  final bool showDebug;

  final ValueNotifier<int> scoreListenable = ValueNotifier(0);
  final ValueNotifier<int> remainingSeconds = ValueNotifier(0);
  final ValueNotifier<String?> highlightListenable = ValueNotifier(null);

  final List<InputEvent> inputLog = [];
  final List<(PointerPhase, int, Offset)> _pending = [];

  double _acc = 0;
  bool _finished = false;
  bool timedOut = false;
  bool get finished => _finished;

  double _scale = 1;
  Offset _offset = Offset.zero;

  double _fps = 0;
  double fpsValue() => _fps;

  @override
  Color backgroundColor() => sim.backgroundColor;

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    _scale = math.min(size.x / Arena.width, size.y / Arena.height);
    _offset = Offset(
      (size.x - Arena.width * _scale) / 2,
      (size.y - Arena.height * _scale) / 2,
    );
  }

  /// Screen pointer (local to the GameWidget) → queued world input.
  void pointer(PointerPhase phase, int id, Offset local) {
    if (_finished) return;
    final screen = (local - _offset) / _scale;
    // 3D scenes: the touch is where the finger points in the scene.
    final pos = sim.touchToWorld(screen) ?? _lastGround[id] ?? screen;
    _lastGround[id] = pos;
    _pending.add((phase, id, pos));
  }

  final Map<int, Offset> _lastGround = {};

  @override
  void update(double dt) {
    super.update(dt);
    if (dt > 0) _fps = _fps == 0 ? 1 / dt : _fps * 0.9 + (1 / dt) * 0.1;
    if (_finished) return;
    _acc += math.min(dt, 0.25);
    while (_acc >= stepDt && !_finished) {
      _acc -= stepDt;
      stepOnce();
    }
  }

  /// Runs exactly one fixed step (public for tests and fast-forward).
  void stepOnce() {
    if (_finished) return;
    for (final (phase, id, pos) in _pending) {
      final ev = InputEvent(
        step: sim.step,
        phase: phase,
        pointer: id,
        x: (pos.dx * 10).roundToDouble() / 10,
        y: (pos.dy * 10).roundToDouble() / 10,
      );
      inputLog.add(ev);
      sim.onPointer(phase, id, ev.position);
    }
    _pending.clear();
    sim.tick();
    sim.step++;

    for (final c in sim.cues) {
      onCue?.call(c);
    }
    sim.cues.clear();
    if (sim.highlights.isNotEmpty &&
        highlightListenable.value != sim.highlights.last) {
      highlightListenable.value = sim.highlights.last;
    }
    scoreListenable.value = sim.score;
    remainingSeconds.value = ((maxSteps - sim.step) / stepsPerSecond)
        .ceil()
        .clamp(0, 999);

    if (!sim.over && sim.step >= maxSteps) {
      timedOut = true;
      sim.onTimeUp();
      sim.over = true;
    }
    if (sim.over) {
      _finished = true;
      scoreListenable.value = sim.finalScore;
      onFinished?.call();
    }
  }

  /// The app was in background for [elapsed]: official games never pause,
  /// so the simulation catches up (without input) up to the time limit.
  void fastForward(Duration elapsed) {
    final steps = elapsed.inMicroseconds * stepsPerSecond ~/ 1000000;
    for (var i = 0; i < steps && !_finished; i++) {
      stepOnce();
    }
  }

  @override
  void onRemove() {
    sim.dispose();
    super.onRemove();
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    canvas
      ..save()
      ..translate(_offset.dx, _offset.dy)
      ..scale(_scale)
      ..clipRect(Arena.rect);
    sim.render(canvas);
    sim.particles.render(canvas);
    if (sim.ctx.has(Modifiers.night)) {
      drawNight(canvas, sim.focus ?? Arena.center, 130);
    }
    canvas.restore();
    if (showDebug) {
      drawText(
        canvas,
        'FPS ${_fps.toStringAsFixed(0)} · bodies ${sim.debugBodyCount}'
        ' · particles ${sim.particles.count}',
        Offset(8, size.y - 24),
        size: 12,
        color: const Color(0xFF00FF66),
      );
    }
  }
}
