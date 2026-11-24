import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import 'render3d.dart';

/// Shared 3D football stadium (penalty, free kick): goal mouth on the z = 0
/// plane centered on x = 180, pitch toward +z.
class Football3D {
  Football3D({
    required this.halfWidth,
    required this.spotDistance,
    Camera3D? camera,
  }) : height = halfWidth * 2 * 2.44 / 7.32,
       camera =
           camera ??
           Camera3D(
             eye: V3(180, 95, spotDistance + 260),
             target: const V3(180, 30, 0),
             fovDegrees: 52,
             center: const Offset(180, 250),
           );

  final double halfWidth;
  final double height;
  final double spotDistance;
  final Camera3D camera;

  /// Goal-space (u, v) → 3D point on the goal line (u = ±1 posts, v = 1 bar).
  V3 goal(double u, double v, [double z = 0]) =>
      V3(180 + u * halfWidth, v * height, z);

  Scene3D scene() => Scene3D(
    camera,
    fogColor: const Color(0xFF9BD0F0),
    fogStart: 700,
    fogEnd: 1800,
    ambient: 0.5,
  );

  void sky(Canvas c) => drawSky(
    c,
    const Rect.fromLTWH(0, 0, 360, 640),
    const Color(0xFF4A90D9),
    const Color(0xFFBFE3FA),
  );

  /// Pitch, lines, stands, goal frame and net.
  void stadium(Scene3D s, {double spotZ = -1}) {
    s.ground(
      const Rect.fromLTRB(-500, -300, 860, 1100),
      (i, j) => tint(
        j.isEven ? const Color(0xFF2E8B47) : const Color(0xFF2A7F41),
        (cellNoise(i, j, 5) - 0.5) * 0.03,
      ),
      cell: 40,
    );
    const line = Color(0xFFF2F2F2);
    void stripe(Rect r) => s.ground(
      r,
      (i, j) => line,
      cell: 400,
      height: 0.3,
      layer: Layer.surface,
    );
    stripe(const Rect.fromLTRB(-400, -2, 760, 2)); // goal line
    stripe(
      Rect.fromLTRB(180 - 2.2 * halfWidth, 0, 180 - 2.2 * halfWidth + 4, 170),
    ); // box sides
    stripe(
      Rect.fromLTRB(180 + 2.2 * halfWidth - 4, 0, 180 + 2.2 * halfWidth, 170),
    );
    stripe(
      Rect.fromLTRB(180 - 2.2 * halfWidth, 168, 180 + 2.2 * halfWidth, 172),
    );
    stripe(
      Rect.fromLTRB(180 - 1.1 * halfWidth, 0, 180 - 1.1 * halfWidth + 4, 60),
    );
    stripe(
      Rect.fromLTRB(180 + 1.1 * halfWidth - 4, 0, 180 + 1.1 * halfWidth, 60),
    );
    stripe(Rect.fromLTRB(180 - 1.1 * halfWidth, 58, 180 + 1.1 * halfWidth, 62));
    if (spotZ >= 0) s.shadow(Offset(180, spotZ), 4, opacity: 0.9, height: 0.4);
    // Stands behind the goal.
    for (var row = 0; row < 6; row++) {
      final z = -160.0 - row * 30;
      s.box(
        V3(180, row * 18.0, z),
        1300,
        18,
        30,
        row.isEven ? const Color(0xFF37474F) : const Color(0xFF455A64),
      );
      for (var k = 0; k < 40; k++) {
        if (cellNoise(k, row, 9) < 0.55) continue;
        final colors = [
          const Color(0xFFE8322F),
          const Color(0xFFFFD23F),
          const Color(0xFF1E88E5),
          Colors.white,
        ];
        s.box(
          V3(-460 + k * 32.0 + cellNoise(k, row) * 10, row * 18.0 + 18, z),
          9,
          12,
          8,
          colors[(cellNoise(k, row, 2) * 4).floor() % 4],
        );
      }
    }
    // Net: back, top and sides (thin translucent mesh).
    const net = Color(0x40FFFFFF);
    const depth = 46.0;
    for (var x = -1.0; x <= 1.0001; x += 0.1) {
      s.quad(
        goal(x, 0, -depth),
        goal(x + 0.004, 0, -depth),
        goal(x + 0.004, 1, -depth),
        goal(x, 1, -depth),
        net,
        doubleSided: true,
        lit: false,
      );
      s.quad(
        goal(x, 1, 0),
        goal(x + 0.004, 1, 0),
        goal(x + 0.004, 1, -depth),
        goal(x, 1, -depth),
        net,
        doubleSided: true,
        lit: false,
      );
    }
    for (var v = 0.0; v <= 1.0001; v += 0.12) {
      s.quad(
        goal(-1, v, -depth),
        goal(1, v, -depth),
        goal(1, v + 0.006, -depth),
        goal(-1, v + 0.006, -depth),
        net,
        doubleSided: true,
        lit: false,
      );
      for (final side in [-1.0, 1.0]) {
        s.quad(
          goal(side, v, 0),
          goal(side, v, -depth),
          goal(side, v + 0.006, -depth),
          goal(side, v + 0.006, 0),
          net,
          doubleSided: true,
          lit: false,
        );
      }
    }
    // Frame: posts and crossbar.
    const white = Color(0xFFFAFAFA);
    s
      ..cylinder(goal(-1, 0), 3, height + 3, white, segments: 8)
      ..cylinder(goal(1, 0), 3, height + 3, white, segments: 8)
      ..box(goal(0, 1), halfWidth * 2 + 6, 5, 6, white);
  }

  void ball(Scene3D s, V3 p, {double r = 6}) {
    final c = V3(p.x, math.max(r, p.y), p.z);
    s
      ..shadow(p.flat, r * (1 + p.y / 80), opacity: 0.4 / (1 + p.y / 60))
      ..sphere(c, r, Colors.white, lat: 8, lon: 12)
      ..sphere(
        c + V3(0, r * 0.62, r * 0.55),
        r * 0.3,
        const Color(0xFF222222),
        lat: 3,
        lon: 5,
      )
      ..sphere(
        c + V3(-r * 0.62, -r * 0.05, r * 0.6),
        r * 0.28,
        const Color(0xFF222222),
        lat: 3,
        lon: 5,
      )
      ..sphere(
        c + V3(r * 0.6, -r * 0.2, r * 0.62),
        r * 0.28,
        const Color(0xFF222222),
        lat: 3,
        lon: 5,
      );
  }
}
