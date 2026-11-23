import 'dart:ui';

import 'package:flame_forge2d/flame_forge2d.dart';

import 'game_sim.dart';

/// Box2D helpers. Box2D works best with objects of 0.1–10 m, so the 360 × 640
/// world is mapped at [ppm] pixels per meter.
abstract final class Phys {
  static const double ppm = 40;

  static Vector2 v(Offset o) => Vector2(o.dx / ppm, o.dy / ppm);
  static Offset o(Vector2 v) => Offset(v.x * ppm, v.y * ppm);
  static double m(double px) => px / ppm;

  /// Creates a zero-gravity (top-down) or gravity world.
  static World world({Offset gravity = Offset.zero}) =>
      World(gravity: Vector2(gravity.dx / ppm, gravity.dy / ppm));

  /// One fixed step.
  static void step(World w) => w.step(stepDt, subStepCount: 4);

  static Body staticBox(
    World w,
    Rect r, {
    double restitution = 0.7,
    double friction = 0.2,
    double angle = 0,
  }) {
    final b = w.createBody(
      BodyDef(position: v(r.center), rotation: Rot.fromAngle(angle)),
    );
    b.createShape(
      Polygon.box(m(r.width / 2), m(r.height / 2)),
      ShapeDef(
        material: SurfaceMaterial(restitution: restitution, friction: friction),
      ),
    );
    return b;
  }

  static Body staticSegment(
    World w,
    Offset a,
    Offset b, {
    double restitution = 0.7,
  }) {
    final body = w.createBody(BodyDef());
    body.createShape(
      Segment(point1: v(a), point2: v(b)),
      ShapeDef(material: SurfaceMaterial(restitution: restitution)),
    );
    return body;
  }

  static Body staticCircle(
    World w,
    Offset c,
    double r, {
    double restitution = 0.7,
  }) {
    final b = w.createBody(BodyDef(position: v(c)));
    b.createShape(
      Circle(radius: m(r)),
      ShapeDef(material: SurfaceMaterial(restitution: restitution)),
    );
    return b;
  }

  static Body ball(
    World w,
    Offset c,
    double r, {
    double density = 1,
    double restitution = 0.5,
    double friction = 0.2,
    double linearDamping = 0,
    bool bullet = true,
  }) {
    final b = w.createBody(
      BodyDef(
        type: BodyType.dynamic,
        position: v(c),
        linearDamping: linearDamping,
        angularDamping: 2,
        isBullet: bullet,
      ),
    );
    b.createShape(
      Circle(radius: m(r)),
      ShapeDef(
        density: density,
        material: SurfaceMaterial(restitution: restitution, friction: friction),
        enableContactEvents: true,
        enableHitEvents: true,
      ),
    );
    return b;
  }
}

extension BodyPx on Body {
  Offset get px => Phys.o(position);
  Offset get velPx => Phys.o(linearVelocity);
  set velPx(Offset v) => linearVelocity = Phys.v(v);
  void moveTo(Offset p, [double angle = 0]) =>
      setTransform(Phys.v(p), Rot.fromAngle(angle));
}
