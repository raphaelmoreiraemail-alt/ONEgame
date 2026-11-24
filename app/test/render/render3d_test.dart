import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:onegame/games/common/render3d.dart';

void main() {
  final cam = Camera3D(
    eye: const V3(180, 400, 900),
    target: const V3(180, 0, 300),
  );

  test('project / unproject round trip on the ground', () {
    for (final p in [
      const Offset(180, 300),
      const Offset(60, 120),
      const Offset(320, 600),
    ]) {
      final s = cam.project(V3.ground(p))!;
      final back = cam.unprojectToGround(s)!;
      expect((back - p).distance, lessThan(1e-6));
    }
  });

  test(
    'the target is at the screen center; far things are higher and smaller',
    () {
      final c = cam.project(const V3(180, 0, 300))!;
      expect((c - const Offset(180, 320)).distance, lessThan(1e-6));
      final near = cam.project(const V3(180, 0, 600))!,
          far = cam.project(const V3(180, 0, 100))!;
      expect(far.dy, lessThan(near.dy));
      expect(
        cam.scaleAt(const V3(180, 0, 100), 10),
        lessThan(cam.scaleAt(const V3(180, 0, 600), 10)),
      );
      expect(
        cam.project(const V3(180, 400, 1000)),
        isNull,
      ); // behind the camera
    },
  );

  test('scene sorts and culls triangles', () {
    final s = Scene3D(cam)
      ..box(const V3(180, 0, 300), 40, 20, 40, const Color(0xFF8D6E63))
      ..sphere(const V3(180, 10, 400), 10, Colors.white)
      ..shadow(const Offset(180, 400), 10);
    // Only faces turned toward the camera are kept.
    expect(s.triangleCount, greaterThan(0));
    expect(s.triangleCount, lessThan(10 + 8 * 14 * 2 + 14));
  });

  test('tint and cell noise', () {
    expect(tint(const Color(0xFF808080), 1).r, closeTo(1, 1e-9));
    expect(tint(const Color(0xFF808080), -1).r, closeTo(0, 1e-9));
    expect(cellNoise(3, 4), cellNoise(3, 4));
    expect(cellNoise(3, 4), isNot(cellNoise(4, 3)));
  });
}
