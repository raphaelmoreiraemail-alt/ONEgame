/// A small software 3D renderer on top of `Canvas.drawVertices`.
///
/// Game simulations stay 2D (top-down world of 360 × 640, x right, y toward
/// the player) and deterministic; scenes are only *drawn* in 3D:
/// world (x, y) → 3D (x, height, y). Triangles are projected with a
/// perspective camera, lit by a directional light, fogged with depth, sorted
/// back-to-front (painter's algorithm) and sent to the GPU in one call.
library;

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

/// Immutable 3D vector.
class V3 {
  const V3(this.x, this.y, this.z);

  /// From a top-down world point at height [h].
  V3.ground(Offset p, [double h = 0]) : this(p.dx, h, p.dy);

  final double x, y, z;

  V3 operator +(V3 o) => V3(x + o.x, y + o.y, z + o.z);
  V3 operator -(V3 o) => V3(x - o.x, y - o.y, z - o.z);
  V3 operator *(double s) => V3(x * s, y * s, z * s);
  double dot(V3 o) => x * o.x + y * o.y + z * o.z;
  V3 cross(V3 o) => V3(y * o.z - z * o.y, z * o.x - x * o.z, x * o.y - y * o.x);
  double get length => math.sqrt(x * x + y * y + z * z);
  V3 get normalized {
    final l = length;
    return l == 0 ? this : V3(x / l, y / l, z / l);
  }

  /// Top-down world position (drops the height).
  Offset get flat => Offset(x, z);

  @override
  String toString() => 'V3($x, $y, $z)';
}

/// Perspective camera looking at [target] from [eye].
class Camera3D {
  Camera3D({
    required this.eye,
    required this.target,
    this.fovDegrees = 50,
    this.viewport = const Size(360, 640),
    this.center,
  }) {
    _f = (target - eye).normalized;
    _r = _f.cross(const V3(0, 1, 0)).normalized;
    _u = _r.cross(_f);
    _focal = (viewport.height / 2) / math.tan(fovDegrees * math.pi / 360);
    _c = center ?? Offset(viewport.width / 2, viewport.height / 2);
  }

  final V3 eye;
  final V3 target;
  final double fovDegrees;
  final Size viewport;

  /// Screen point the camera axis goes through (default: middle).
  final Offset? center;

  late final V3 _f, _r, _u;
  late final double _focal;
  late final Offset _c;

  static const double near = 4;

  /// View-space depth of [p] (distance along the camera axis).
  double depth(V3 p) => (p - eye).dot(_f);

  /// Screen position of [p], or null when behind the near plane.
  Offset? project(V3 p) {
    final d = p - eye;
    final z = d.dot(_f);
    if (z < near) return null;
    return Offset(
      _c.dx + d.dot(_r) * _focal / z,
      _c.dy - d.dot(_u) * _focal / z,
    );
  }

  /// Screen size of a length [size] placed at [p].
  double scaleAt(V3 p, double size) => size * _focal / math.max(near, depth(p));

  /// Where a screen point hits the vertical plane z = [z] (3D point).
  V3? unprojectToPlaneZ(Offset screen, [double z = 0]) {
    final dir =
        _f * _focal + _r * (screen.dx - _c.dx) - _u * (screen.dy - _c.dy);
    if (dir.z.abs() < 1e-9) return null;
    final t = (z - eye.z) / dir.z;
    if (t <= 0) return null;
    return eye + dir * t;
  }

  /// Where a screen point hits the horizontal plane at [height], as a
  /// top-down world point (used to map touches onto the 3D scene).
  Offset? unprojectToGround(Offset screen, [double height = 0]) {
    final dir =
        _f * _focal + _r * (screen.dx - _c.dx) - _u * (screen.dy - _c.dy);
    if (dir.y.abs() < 1e-9) return null;
    final t = (height - eye.y) / dir.y;
    if (t <= 0) return null;
    return (eye + dir * t).flat;
  }
}

class _Tri {
  _Tri(
    this.a,
    this.b,
    this.c,
    this.ca,
    this.cb,
    this.cc,
    this.depth,
    this.layer,
  );

  final Offset a, b, c;
  final Color ca, cb, cc;
  final double depth;
  final int layer;
}

/// Draw order buckets: flat things lying on the ground must never be sorted
/// against each other by depth (their big triangles fool the painter's
/// algorithm), so they are drawn in fixed layers below the solid objects.
abstract final class Layer {
  static const int ground = 0;
  static const int surface = 1; // sand, water, markings on the ground
  static const int decal = 2; // shadows, guides
  static const int solid = 3; // everything with a volume
  static const int overlay = 4; // always on top (effects)
}

/// Collects lit triangles for one frame, then draws them sorted.
class Scene3D {
  Scene3D(
    this.camera, {
    V3 light = const V3(-0.45, 1, 0.55),
    this.ambient = 0.42,
    this.diffuse = 0.68,
    this.fogColor,
    this.fogStart = 900,
    this.fogEnd = 2400,
  }) : light = light.normalized;

  final Camera3D camera;
  final V3 light;
  final double ambient;
  final double diffuse;
  final Color? fogColor;
  final double fogStart;
  final double fogEnd;
  final List<_Tri> _tris = [];

  int get triangleCount => _tris.length;

  Color _shade(Color base, V3 normal, V3 at) {
    final lambert = math.max(0.0, normal.dot(light));
    final k = (ambient + diffuse * lambert).clamp(0.0, 1.35);
    var r = base.r * k, g = base.g * k, b = base.b * k;
    final fog = fogColor;
    if (fog != null) {
      final t = ((camera.depth(at) - fogStart) / (fogEnd - fogStart)).clamp(
        0.0,
        0.85,
      );
      r += (fog.r - r) * t;
      g += (fog.g - g) * t;
      b += (fog.b - b) * t;
    }
    return Color.from(
      alpha: base.a,
      red: r.clamp(0, 1),
      green: g.clamp(0, 1),
      blue: b.clamp(0, 1),
    );
  }

  /// One triangle; [normal] defaults to the face normal (counter-clockwise
  /// seen from outside). Back faces are culled unless [doubleSided].
  void tri(
    V3 a,
    V3 b,
    V3 c,
    Color color, {
    V3? normal,
    List<V3>? vertexNormals,
    List<Color>? vertexColors,
    bool doubleSided = false,
    bool lit = true,
    double depthBias = 0,
    int layer = Layer.solid,
  }) {
    final pa = camera.project(a),
        pb = camera.project(b),
        pc = camera.project(c);
    if (pa == null || pb == null || pc == null) return;
    final area =
        (pb.dx - pa.dx) * (pc.dy - pa.dy) - (pb.dy - pa.dy) * (pc.dx - pa.dx);
    var n = normal ?? (b - a).cross(c - a).normalized;
    if (area > 0) {
      // Facing away from the camera.
      if (!doubleSided) return;
      n = n * -1;
    }
    final cols = vertexColors ?? [color, color, color];
    Color at(int i, V3 p) {
      if (!lit) return cols[i];
      final vn = vertexNormals == null ? n : vertexNormals[i];
      return _shade(cols[i], vn, p);
    }

    final depth =
        (camera.depth(a) + camera.depth(b) + camera.depth(c)) / 3 + depthBias;
    _tris.add(_Tri(pa, pb, pc, at(0, a), at(1, b), at(2, c), depth, layer));
  }

  void quad(
    V3 a,
    V3 b,
    V3 c,
    V3 d,
    Color color, {
    bool doubleSided = false,
    bool lit = true,
    double depthBias = 0,
    int layer = Layer.solid,
  }) {
    tri(
      a,
      b,
      c,
      color,
      doubleSided: doubleSided,
      lit: lit,
      depthBias: depthBias,
      layer: layer,
    );
    tri(
      a,
      c,
      d,
      color,
      doubleSided: doubleSided,
      lit: lit,
      depthBias: depthBias,
      layer: layer,
    );
  }

  /// Horizontal rectangle at [height], split in cells so that perspective
  /// and near-plane clipping stay correct. [color] can vary per cell.
  void ground(
    Rect r,
    Color Function(int i, int j) color, {
    double height = 0,
    double cell = 40,
    double depthBias = 0,
    int layer = Layer.ground,
  }) {
    final nx = math.max(1, (r.width / cell).ceil());
    final nz = math.max(1, (r.height / cell).ceil());
    final dx = r.width / nx, dz = r.height / nz;
    for (var i = 0; i < nx; i++) {
      for (var j = 0; j < nz; j++) {
        final x0 = r.left + i * dx, z0 = r.top + j * dz;
        quad(
          V3(x0, height, z0),
          V3(x0, height, z0 + dz),
          V3(x0 + dx, height, z0 + dz),
          V3(x0 + dx, height, z0),
          color(i, j),
          depthBias: depthBias,
          layer: layer,
        );
      }
    }
  }

  /// Axis-aligned box (optionally turned by [yaw] around the vertical),
  /// [base] = center of its bottom face.
  void box(
    V3 base,
    double width,
    double height,
    double depth,
    Color color, {
    double yaw = 0,
    Color? top,
    int layer = Layer.solid,
    double depthBias = 0,
  }) {
    final c = math.cos(yaw), s = math.sin(yaw);
    V3 p(double x, double y, double z) =>
        V3(base.x + x * c - z * s, base.y + y, base.z + x * s + z * c);
    final w = width / 2, d = depth / 2;
    final b0 = p(-w, 0, -d),
        b1 = p(w, 0, -d),
        b2 = p(w, 0, d),
        b3 = p(-w, 0, d);
    final t0 = p(-w, height, -d),
        t1 = p(w, height, -d),
        t2 = p(w, height, d),
        t3 = p(-w, height, d);
    quad(
      t0,
      t3,
      t2,
      t1,
      top ?? color,
      layer: layer,
      depthBias: depthBias,
    ); // top
    quad(
      b3,
      b2,
      t2,
      t3,
      color,
      layer: layer,
      depthBias: depthBias,
    ); // front (+z)
    quad(
      b1,
      b0,
      t0,
      t1,
      color,
      layer: layer,
      depthBias: depthBias,
    ); // back (−z)
    quad(b0, b3, t3, t0, color, layer: layer, depthBias: depthBias); // left
    quad(b2, b1, t1, t2, color, layer: layer, depthBias: depthBias); // right
  }

  /// Box with an arbitrary orientation: [ax], [ay], [az] are its unit axes
  /// (width, height, depth); [base] is the center of its bottom face.
  void boxAxes(
    V3 base,
    V3 ax,
    V3 ay,
    V3 az,
    double width,
    double height,
    double depth,
    Color color,
  ) {
    final w = width / 2, d = depth / 2;
    V3 p(double x, double y, double z) => base + ax * x + ay * y + az * z;
    final b0 = p(-w, 0, -d),
        b1 = p(w, 0, -d),
        b2 = p(w, 0, d),
        b3 = p(-w, 0, d);
    final t0 = p(-w, height, -d),
        t1 = p(w, height, -d),
        t2 = p(w, height, d),
        t3 = p(-w, height, d);
    quad(t0, t3, t2, t1, color);
    quad(b0, b1, b2, b3, color);
    quad(b3, b2, t2, t3, color);
    quad(b1, b0, t0, t1, color);
    quad(b0, b3, t3, t0, color);
    quad(b2, b1, t1, t2, color);
  }

  /// A simple athlete facing the camera (−z), leaning by [roll] radians
  /// (sideways dive) with arms raised by [arms] (0 = down, 1 = up).
  void figure(
    V3 feet,
    Color shirt, {
    double roll = 0,
    double arms = 0,
    double scale = 1,
    Color skin = const Color(0xFFFFCC80),
    Color shorts = const Color(0xFF212121),
  }) {
    final c = math.cos(roll), s = math.sin(roll);
    final up = V3(-s, c, 0), side = V3(c, s, 0);
    const fwd = V3(0, 0, 1);
    V3 at(double x, double y) => feet + side * (x * scale) + up * (y * scale);
    boxAxes(at(-4, 0), side, up, fwd, 5 * scale, 16 * scale, 5 * scale, shorts);
    boxAxes(at(4, 0), side, up, fwd, 5 * scale, 16 * scale, 5 * scale, shorts);
    boxAxes(at(0, 15), side, up, fwd, 16 * scale, 19 * scale, 9 * scale, shirt);
    for (final dir in [-1.0, 1.0]) {
      final a = dir * (0.25 + arms * 2.4);
      final ac = math.cos(a), as = math.sin(a);
      final armUp = up * ac + side * (-as);
      final armSide = side * ac + up * as;
      boxAxes(
        at(dir * 10, 31),
        armSide,
        armUp * -1,
        fwd,
        4.5 * scale,
        15 * scale,
        4.5 * scale,
        shirt,
      );
    }
    sphere(at(0, 40), 6 * scale, skin, lat: 5, lon: 8);
  }

  /// Vertical cylinder; [base] = center of its bottom.
  void cylinder(
    V3 base,
    double radius,
    double height,
    Color color, {
    int segments = 14,
    Color? top,
    bool capped = true,
  }) {
    final ring = [
      for (var i = 0; i <= segments; i++)
        (
          math.cos(i / segments * 2 * math.pi),
          math.sin(i / segments * 2 * math.pi),
        ),
    ];
    final topC = base + V3(0, height, 0);
    for (var i = 0; i < segments; i++) {
      final (c0, s0) = ring[i];
      final (c1, s1) = ring[i + 1];
      final a = base + V3(c0 * radius, 0, s0 * radius);
      final b = base + V3(c1 * radius, 0, s1 * radius);
      final n0 = V3(c0, 0, s0), n1 = V3(c1, 0, s1);
      tri(
        a,
        b + V3(0, height, 0),
        b,
        color,
        vertexNormals: [n0, n1, n1],
        normal: (n0 + n1).normalized,
      );
      tri(
        a,
        a + V3(0, height, 0),
        b + V3(0, height, 0),
        color,
        vertexNormals: [n0, n0, n1],
        normal: (n0 + n1).normalized,
      );
      if (capped) {
        tri(
          topC,
          b + V3(0, height, 0),
          a + V3(0, height, 0),
          top ?? color,
          normal: const V3(0, 1, 0),
        );
      }
    }
  }

  /// Tube from [a] to [b] (radius [ra] at a, [rb] at b; 0 makes a cone),
  /// for shafts, barrels, rods and limbs in any direction.
  void tube(
    V3 a,
    V3 b,
    double ra,
    double rb,
    Color color, {
    int segments = 8,
    bool capped = false,
    int layer = Layer.solid,
  }) {
    final axis = (b - a).normalized;
    final helper = axis.y.abs() < 0.9 ? const V3(0, 1, 0) : const V3(1, 0, 0);
    final u = axis.cross(helper).normalized;
    final v = axis.cross(u);
    for (var i = 0; i < segments; i++) {
      final a0 = i / segments * 2 * math.pi;
      final a1 = (i + 1) / segments * 2 * math.pi;
      final n0 = u * math.cos(a0) + v * math.sin(a0);
      final n1 = u * math.cos(a1) + v * math.sin(a1);
      final p0 = a + n0 * ra, p1 = a + n1 * ra;
      final q0 = b + n0 * rb, q1 = b + n1 * rb;
      tri(
        p0,
        p1,
        q1,
        color,
        vertexNormals: [n0, n1, n1],
        normal: (n0 + n1).normalized,
        layer: layer,
      );
      tri(
        p0,
        q1,
        q0,
        color,
        vertexNormals: [n0, n1, n0],
        normal: (n0 + n1).normalized,
        layer: layer,
      );
      if (capped) {
        tri(b, q0, q1, color, normal: axis, layer: layer);
        tri(a, p1, p0, color, normal: axis * -1, layer: layer);
      }
    }
  }

  /// Smooth-shaded sphere.
  void sphere(
    V3 center,
    double radius,
    Color color, {
    int lat = 8,
    int lon = 14,
    Color? stripe,
  }) {
    V3 n(int i, int j) {
      final th = i / lat * math.pi, ph = j / lon * 2 * math.pi;
      return V3(
        math.sin(th) * math.cos(ph),
        math.cos(th),
        math.sin(th) * math.sin(ph),
      );
    }

    for (var i = 0; i < lat; i++) {
      final band = stripe != null && (i == lat ~/ 2 - 1 || i == lat ~/ 2);
      final col = band ? stripe : color;
      for (var j = 0; j < lon; j++) {
        final a = n(i, j),
            b = n(i + 1, j),
            c = n(i + 1, j + 1),
            d = n(i, j + 1);
        tri(
          center + a * radius,
          center + d * radius,
          center + c * radius,
          col,
          vertexNormals: [a, d, c],
        );
        tri(
          center + a * radius,
          center + c * radius,
          center + b * radius,
          col,
          vertexNormals: [a, c, b],
        );
      }
    }
  }

  /// Soft ground shadow (unlit dark disc) under an object.
  void shadow(
    Offset at,
    double radius, {
    double height = 0.2,
    double opacity = 0.35,
    double stretch = 1,
    int layer = Layer.decal,
  }) {
    const segs = 14;
    final c = V3.ground(at, height);
    final col = Color.fromRGBO(0, 0, 0, opacity);
    const edge = Color.fromRGBO(0, 0, 0, 0);
    for (var i = 0; i < segs; i++) {
      final a0 = i / segs * 2 * math.pi, a1 = (i + 1) / segs * 2 * math.pi;
      tri(
        c,
        V3(
          c.x + math.cos(a1) * radius * stretch,
          height,
          c.z + math.sin(a1) * radius,
        ),
        V3(
          c.x + math.cos(a0) * radius * stretch,
          height,
          c.z + math.sin(a0) * radius,
        ),
        col,
        vertexColors: [col, edge, edge],
        lit: false,
        doubleSided: true,
        layer: layer,
      );
    }
  }

  /// Draws everything collected, far to near, in one GPU call.
  void render(Canvas canvas) {
    if (_tris.isEmpty) return;
    _tris.sort(
      (a, b) =>
          a.layer != b.layer ? a.layer - b.layer : b.depth.compareTo(a.depth),
    );
    final pos = Float32List(_tris.length * 6);
    final cols = Int32List(_tris.length * 3);
    var p = 0, k = 0;
    for (final t in _tris) {
      pos[p++] = t.a.dx;
      pos[p++] = t.a.dy;
      pos[p++] = t.b.dx;
      pos[p++] = t.b.dy;
      pos[p++] = t.c.dx;
      pos[p++] = t.c.dy;
      cols[k++] = t.ca.toARGB32();
      cols[k++] = t.cb.toARGB32();
      cols[k++] = t.cc.toARGB32();
    }
    canvas.drawVertices(
      Vertices.raw(VertexMode.triangles, pos, colors: cols),
      BlendMode.dst,
      Paint(),
    );
    _tris.clear();
  }
}

/// Sky gradient behind a 3D scene.
void drawSky(Canvas canvas, Rect area, Color top, Color horizon) {
  canvas.drawRect(
    area,
    Paint()
      ..shader = Gradient.linear(area.topCenter, area.bottomCenter, [
        top,
        horizon,
      ]),
  );
}

/// Deterministic per-cell variation (grass, wood...) without any RNG state.
double cellNoise(int i, int j, [int salt = 0]) {
  var h = (i * 374761393 + j * 668265263 + salt * 1442695041) & 0x7fffffff;
  h = ((h ^ (h >> 13)) * 1274126177) & 0x7fffffff;
  return (h & 0xffff) / 0xffff;
}

/// Lighter / darker variant of [c] (amount in −1..1).
Color tint(Color c, double amount) {
  final t = amount.clamp(-1.0, 1.0);
  double ch(double v) => t >= 0 ? v + (1 - v) * t : v * (1 + t);
  return Color.from(alpha: c.a, red: ch(c.r), green: ch(c.g), blue: ch(c.b));
}
