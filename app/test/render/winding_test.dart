import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:onegame/games/common/render3d.dart';

/// Red channel at the screen center, lit head-on: a primitive whose faces
/// are wound inside-out shows its unlit interior (≈ 0) instead.
Future<int> _centerRed(
  void Function(Scene3D) build, {
  bool fromAbove = false,
}) async {
  final cam = Camera3D(
    eye: fromAbove ? const V3(0, 400, 1) : const V3(0, 0, 400),
    target: const V3(0, 0, 0),
  );
  final s = Scene3D(
    cam,
    light: fromAbove ? const V3(0, 1, 0) : const V3(0, 0, 1),
    ambient: 0,
    diffuse: 1,
  );
  build(s);
  final rec = ui.PictureRecorder();
  s.render(ui.Canvas(rec));
  final img = await rec.endRecording().toImage(360, 640);
  final bytes = (await img.toByteData())!;
  return bytes.getUint8((320 * 360 + 180) * 4);
}

void main() {
  const red = ui.Color(0xFFFF0000);
  final cases = <String, (void Function(Scene3D), bool)>{
    'cylinder side': (
      (s) => s.cylinder(const V3(0, -50, 0), 40, 100, red, capped: false),
      false,
    ),
    'cylinder cap': (
      (s) => s.cylinder(const V3(0, -300, 0), 40, 300, red),
      true,
    ),
    'tube vertical': (
      (s) => s.tube(const V3(0, -50, 0), const V3(0, 50, 0), 40, 40, red),
      false,
    ),
    'tube horizontal': (
      (s) => s.tube(const V3(-50, 0, 0), const V3(50, 0, 0), 40, 40, red),
      false,
    ),
    'tube cap towards camera': (
      (s) => s.tube(
        const V3(0, 0, -5),
        const V3(0, 0, 5),
        40,
        40,
        red,
        capped: true,
      ),
      false,
    ),
    'tube cap away': (
      (s) => s.tube(
        const V3(0, 0, 5),
        const V3(0, 0, -5),
        40,
        40,
        red,
        capped: true,
      ),
      false,
    ),
    'sphere': ((s) => s.sphere(const V3(0, 0, 0), 40, red), false),
    'box': ((s) => s.box(const V3(0, -40, 0), 80, 80, 80, red), false),
  };
  for (final MapEntry(key: name, value: (build, above)) in cases.entries) {
    test('$name faces outwards', () async {
      expect(await _centerRed(build, fromAbove: above), greaterThan(200));
    });
  }
}
