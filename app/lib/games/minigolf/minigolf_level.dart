import 'dart:math' as math;
import 'dart:ui';

import '../../core/rng/seeded_random.dart';
import '../common/game_sim.dart';

/// Course geometry (world units).
abstract final class Course {
  static const Rect bounds = Rect.fromLTRB(16, 92, 344, 626);
  static const double cupY = 132;
  static const double teeY = 592;
  static const double cupRadius = 11;
  static const double ballRadius = 7;
}

enum ObstacleKind { wall, bumper, sand, water, slope, windmill, mover, portal }

/// One obstacle of a hole. Meaning of fields depends on [kind]:
/// - wall: [rect] rotated by [angle];
/// - bumper / windmill / portal: [rect].center + [rect].width / 2 as radius;
/// - sand / water: [rect];
/// - slope: [rect] + force [vector] (px/s²);
/// - mover: [rect] at rest, oscillating along [vector] (amplitude, px) with
///   period [period] s;
/// - windmill: angular speed [period] rad/s;
/// - portal: entrance [rect], exit at [vector].
class Obstacle {
  const Obstacle(
    this.kind,
    this.rect, {
    this.angle = 0,
    this.vector = Offset.zero,
    this.period = 0,
  });

  final ObstacleKind kind;
  final Rect rect;
  final double angle;
  final Offset vector;
  final double period;

  Obstacle mirrored() {
    double mx(double x) => Arena.width - x;
    return Obstacle(
      kind,
      Rect.fromLTRB(mx(rect.right), rect.top, mx(rect.left), rect.bottom),
      angle: -angle,
      vector: kind == ObstacleKind.portal
          ? Offset(mx(vector.dx), vector.dy)
          : Offset(-vector.dx, vector.dy),
      period: kind == ObstacleKind.windmill ? -period : period,
    );
  }

  List<Object> get fingerprintParts => [
    kind.index,
    rect.left,
    rect.top,
    rect.right,
    rect.bottom,
    angle,
    vector.dx,
    vector.dy,
    period,
  ];
}

class GolfHole {
  const GolfHole({
    required this.tee,
    required this.cup,
    required this.par,
    required this.obstacles,
    required this.modules,
  });

  final Offset tee;
  final Offset cup;
  final int par;
  final List<Obstacle> obstacles;
  final List<String> modules;
}

typedef _ModuleBuilder = List<Obstacle> Function(Rect band, SeededRandom r);

class _Module {
  const _Module(this.id, this.difficulty, this.build);

  final String id;
  final int difficulty;
  final _ModuleBuilder build;
}

Obstacle _wall(double l, double t, double r, double b, {double angle = 0}) =>
    Obstacle(ObstacleKind.wall, Rect.fromLTRB(l, t, r, b), angle: angle);

Obstacle _circle(
  ObstacleKind k,
  Offset c,
  double radius, {
  double period = 0,
}) => Obstacle(
  k,
  Rect.fromCircle(center: c, radius: radius),
  period: period,
);

const double _l = 16;
const double _r = 344;
const double _w = _r - _l;

/// ~24 hand-made course modules; each can be mirrored by the seed.
final List<_Module> _modules = [
  _Module('open', 0, (b, r) => []),
  _Module('center_block', 1, (b, r) {
    final w = r.doubleInRange(90, 140);
    return [
      _wall(180 - w / 2, b.center.dy - 12, 180 + w / 2, b.center.dy + 12),
    ];
  }),
  _Module(
    'side_block',
    1,
    (b, r) => [
      _wall(
        _l,
        b.center.dy - 12,
        _l + _w * r.doubleInRange(0.5, 0.62),
        b.center.dy + 12,
      ),
    ],
  ),
  _Module(
    'chicane',
    2,
    (b, r) => [
      _wall(
        _l,
        b.top + b.height * 0.28 - 10,
        _l + _w * 0.58,
        b.top + b.height * 0.28 + 10,
      ),
      _wall(
        _r - _w * 0.58,
        b.top + b.height * 0.72 - 10,
        _r,
        b.top + b.height * 0.72 + 10,
      ),
    ],
  ),
  _Module('gate', 1, (b, r) {
    final gap = r.doubleInRange(54, 70);
    final gx = r.doubleInRange(_l + 40, _r - 40 - gap);
    return [
      _wall(_l, b.center.dy - 10, gx, b.center.dy + 10),
      _wall(gx + gap, b.center.dy - 10, _r, b.center.dy + 10),
    ];
  }),
  _Module(
    'windmill',
    2,
    (b, r) => [
      _circle(
        ObstacleKind.windmill,
        b.center,
        r.doubleInRange(46, 56),
        period: r.doubleInRange(1.4, 2.4),
      ),
    ],
  ),
  _Module(
    'mover',
    1,
    (b, r) => [
      Obstacle(
        ObstacleKind.mover,
        Rect.fromCenter(
          center: b.center,
          width: r.doubleInRange(90, 120),
          height: 18,
        ),
        vector: Offset(r.doubleInRange(70, 100), 0),
        period: r.doubleInRange(2.2, 3.4),
      ),
    ],
  ),
  _Module(
    'bumpers',
    1,
    (b, r) => [
      for (final dx in [-80.0, 0.0, 80.0])
        _circle(
          ObstacleKind.bumper,
          b.center.translate(dx, dx == 0 ? -b.height * 0.18 : b.height * 0.12),
          14,
        ),
    ],
  ),
  _Module(
    'sand_center',
    0,
    (b, r) => [
      Obstacle(
        ObstacleKind.sand,
        Rect.fromCenter(
          center: b.center,
          width: r.doubleInRange(120, 200),
          height: b.height * 0.6,
        ),
      ),
    ],
  ),
  _Module(
    'sand_sides',
    0,
    (b, r) => [
      Obstacle(
        ObstacleKind.sand,
        Rect.fromLTWH(_l, b.top + 10, 90, b.height - 20),
      ),
      Obstacle(
        ObstacleKind.sand,
        Rect.fromLTWH(_r - 90, b.top + 10, 90, b.height - 20),
      ),
    ],
  ),
  _Module(
    'water_center',
    2,
    (b, r) => [
      Obstacle(
        ObstacleKind.water,
        Rect.fromCenter(
          center: b.center,
          width: r.doubleInRange(150, 200),
          height: b.height * 0.55,
        ),
      ),
    ],
  ),
  _Module(
    'water_side',
    1,
    (b, r) => [
      Obstacle(
        ObstacleKind.water,
        Rect.fromLTWH(_l, b.top + 8, _w * 0.5, b.height - 16),
      ),
    ],
  ),
  _Module(
    'slope_side',
    1,
    (b, r) => [
      Obstacle(
        ObstacleKind.slope,
        Rect.fromLTRB(_l, b.top, _r, b.bottom),
        vector: Offset(r.doubleInRange(110, 170), 0),
      ),
    ],
  ),
  _Module(
    'slope_back',
    2,
    (b, r) => [
      Obstacle(
        ObstacleKind.slope,
        Rect.fromLTRB(_l, b.top, _r, b.bottom),
        vector: Offset(0, r.doubleInRange(120, 170)),
      ),
    ],
  ),
  _Module(
    'slope_forward',
    0,
    (b, r) => [
      Obstacle(
        ObstacleKind.slope,
        Rect.fromLTRB(_l, b.top, _r, b.bottom),
        vector: Offset(0, -r.doubleInRange(90, 130)),
      ),
    ],
  ),
  _Module(
    'diagonal',
    1,
    (b, r) => [
      _wall(
        100,
        b.center.dy - 9,
        260,
        b.center.dy + 9,
        angle: r.doubleInRange(0.3, 0.6),
      ),
    ],
  ),
  _Module('tunnel', 1, (b, r) {
    final inX = r.doubleInRange(70, 120);
    return [
      _wall(_l, b.center.dy - 10, _r, b.center.dy + 10),
      Obstacle(
        ObstacleKind.portal,
        Rect.fromCircle(center: Offset(inX, b.center.dy + 32), radius: 14),
        vector: Offset(Arena.width - inX, b.center.dy - 34),
      ),
    ];
  }),
  _Module(
    'bumper_wall',
    1,
    (b, r) => [
      _wall(_l, b.center.dy - 10, 120, b.center.dy + 10),
      _wall(240, b.center.dy - 10, _r, b.center.dy + 10),
      _circle(ObstacleKind.bumper, b.center, 16),
    ],
  ),
  _Module(
    'double_mover',
    2,
    (b, r) => [
      for (final f in [0.3, 0.7])
        Obstacle(
          ObstacleKind.mover,
          Rect.fromCenter(
            center: Offset(180, b.top + b.height * f),
            width: 100,
            height: 16,
          ),
          vector: Offset(f < 0.5 ? 90 : -90, 0),
          period: 2.8,
        ),
    ],
  ),
  _Module(
    'funnel',
    1,
    (b, r) => [
      _wall(_l, b.center.dy - 8, 160, b.center.dy + 8, angle: -0.35),
      _wall(200, b.center.dy - 8, _r, b.center.dy + 8, angle: 0.35),
    ],
  ),
  _Module(
    'islands',
    1,
    (b, r) => [
      _wall(70, b.center.dy - 14, 120, b.center.dy + 14),
      _wall(240, b.center.dy - 14, 290, b.center.dy + 14),
      Obstacle(
        ObstacleKind.sand,
        Rect.fromCenter(center: b.center, width: 80, height: 50),
      ),
    ],
  ),
  _Module(
    'pillars',
    1,
    (b, r) => [
      for (final x in [110.0, 250.0])
        for (final y in [0.3, 0.7])
          _wall(
            x - 12,
            b.top + b.height * y - 12,
            x + 12,
            b.top + b.height * y + 12,
          ),
    ],
  ),
  _Module(
    'windmill_gate',
    2,
    (b, r) => [
      _wall(_l, b.center.dy - 10, 140, b.center.dy + 10),
      _wall(220, b.center.dy - 10, _r, b.center.dy + 10),
      _circle(ObstacleKind.windmill, b.center, 40, period: 2),
    ],
  ),
  _Module(
    'sand_water',
    2,
    (b, r) => [
      Obstacle(
        ObstacleKind.water,
        Rect.fromLTWH(_l, b.top + 10, 110, b.height - 20),
      ),
      Obstacle(
        ObstacleKind.sand,
        Rect.fromLTWH(_r - 110, b.top + 10, 110, b.height - 20),
      ),
    ],
  ),
];

abstract final class GolfLevel {
  static const int holes = 3;
  static List<String> get moduleIds => [for (final m in _modules) m.id];

  static List<GolfHole> generate(int seed) => [
    for (var i = 0; i < holes; i++) _hole(seed, i),
  ];

  static GolfHole _hole(int seed, int index) {
    final r = SeededRandom.derive(seed, 'minigolf:hole$index');
    final bandCount = index == 0 ? 2 : 3;
    const top = Course.cupY + 40;
    const bottom = Course.teeY - 34;
    final bandH = (bottom - top) / bandCount;
    final obstacles = <Obstacle>[];
    final ids = <String>[];
    var difficulty = 0;
    final used = <int>{};
    for (var b = 0; b < bandCount; b++) {
      var m = r.nextInt(_modules.length);
      while (used.contains(m)) {
        m = (m + 1) % _modules.length;
      }
      used.add(m);
      final module = _modules[m];
      final band = Rect.fromLTRB(
        _l,
        top + b * bandH,
        _r,
        top + (b + 1) * bandH,
      );
      final mirror = r.chance(0.5);
      final built = module.build(band, r);
      obstacles.addAll(mirror ? built.map((o) => o.mirrored()) : built);
      ids.add('${module.id}${mirror ? '~' : ''}');
      difficulty += module.difficulty;
    }
    final cup = Offset(r.doubleInRange(60, 300), Course.cupY);
    final tee = Offset(r.doubleInRange(120, 240), Course.teeY);
    final par = math.min(4, math.max(2, 2 + (difficulty + 1) ~/ 2));
    return GolfHole(
      tee: tee,
      cup: cup,
      par: par,
      obstacles: obstacles,
      modules: ids,
    );
  }
}
