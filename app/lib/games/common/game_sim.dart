import 'dart:math' as math;
import 'dart:ui';

import '../../core/rng/seeded_random.dart';
import 'game_types.dart';

/// Logical world size shared by all mini-games (portrait 9:16).
abstract final class Arena {
  static const double width = 360;
  static const double height = 640;
  static const Rect rect = Rect.fromLTWH(0, 0, width, height);
  static const Offset center = Offset(width / 2, height / 2);
}

/// Fixed simulation rate (section 6).
const int stepsPerSecond = 120;
const double stepDt = 1 / stepsPerSecond;

enum Sfx {
  tap,
  hit,
  bounce,
  score,
  miss,
  whoosh,
  highlight,
  tick,
  countdown,
  go,
  fin,
  alarm,
}

enum Haptic { light, medium, heavy, selection }

/// A sound and/or vibration requested by a simulation.
class GameCue {
  const GameCue({this.sfx, this.haptic});

  final Sfx? sfx;
  final Haptic? haptic;
}

/// Pure-Dart game simulation: deterministic, headless and testable.
///
/// The Flame layer ([MiniGame]) feeds it inputs at fixed step boundaries,
/// calls [tick] 120 times per second and asks it to [render] in world units.
abstract class GameSim {
  GameSim(this.ctx);

  final GameContext ctx;

  /// Fixed steps elapsed (set by the runner).
  int step = 0;

  /// Current score, shown in the HUD.
  int score = 0;

  /// True when the game ended by itself (goal reached or failure).
  bool over = false;

  final List<GameCue> cues = [];
  final List<String> highlights = [];
  final Particles particles = Particles();

  double get elapsed => step / stepsPerSecond;

  /// Background outside the world (letterbox) and behind it.
  Color get backgroundColor;

  void onPointer(PointerPhase phase, int pointer, Offset pos);

  /// Advance the simulation by exactly one fixed step.
  void tick();

  void render(Canvas canvas);

  /// Called once when the global timer reaches the game's max duration.
  void onTimeUp() {}

  /// Final score (after end-of-game bonuses). Defaults to [score].
  int get finalScore => score;

  Map<String, num> get stats;

  /// Active physics bodies, displayed in the Game Lab.
  int get debugBodyCount => 0;

  /// Position (world units) the camera of the `night` modifier follows.
  Offset? get focus => null;

  void cue({Sfx? sfx, Haptic? haptic}) =>
      cues.add(GameCue(sfx: sfx, haptic: haptic));

  /// Records a "coup d'éclat" (animation + sound + share mention).
  void celebrate(String id) {
    highlights.add(id);
    cue(sfx: Sfx.highlight, haptic: Haptic.heavy);
  }

  /// Advances particles; call from [tick].
  void tickParticles() => particles.tick();
}

/// Lightweight visual particles. Uses its own generator: purely visual
/// randomness never influences the score (section 6).
class Particles {
  final List<_Particle> _items = [];
  final SeededRandom _rng = SeededRandom(0xC0FFEE);

  int get count => _items.length;

  void burst(
    Offset at,
    Color color, {
    int count = 16,
    double speed = 220,
    double life = 0.6,
    double size = 4,
    double gravity = 300,
  }) {
    for (var i = 0; i < count; i++) {
      final a = _rng.nextDouble() * math.pi * 2;
      final v = speed * (0.4 + _rng.nextDouble() * 0.6);
      _items.add(
        _Particle(
          at,
          Offset(math.cos(a) * v, math.sin(a) * v),
          color,
          life * (0.6 + _rng.nextDouble() * 0.4),
          size * (0.6 + _rng.nextDouble() * 0.8),
          gravity,
        ),
      );
    }
    if (_items.length > 400) _items.removeRange(0, _items.length - 400);
  }

  /// Fireworks: several colored bursts.
  void fireworks(Offset at) {
    const colors = [
      Color(0xFFFFD23F),
      Color(0xFFE8322F),
      Color(0xFF3FA7FF),
      Color(0xFF5BE37D),
    ];
    for (var i = 0; i < 4; i++) {
      burst(
        at + Offset((i - 1.5) * 30, (i.isEven ? -20 : 20)),
        colors[i],
        count: 24,
        speed: 320,
        life: 1.1,
      );
    }
  }

  void tick() {
    for (final p in _items) {
      p.age += stepDt;
      p.vel = p.vel.translate(0, p.gravity * stepDt);
      p.pos += p.vel * stepDt;
    }
    _items.removeWhere((p) => p.age >= p.life);
  }

  void render(Canvas canvas) {
    final paint = Paint();
    for (final p in _items) {
      final t = 1 - p.age / p.life;
      paint.color = p.color.withValues(alpha: t.clamp(0, 1));
      canvas.drawCircle(p.pos, p.size * (0.5 + t * 0.5), paint);
    }
  }
}

class _Particle {
  _Particle(this.pos, this.vel, this.color, this.life, this.size, this.gravity);

  Offset pos;
  Offset vel;
  final Color color;
  final double life;
  final double size;
  final double gravity;
  double age = 0;
}
