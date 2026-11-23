import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../core/rng/seeded_random.dart';

/// Simple generated avatar (section 9.8): shapes + colors from an integer,
/// no photo upload in v1.
class Avatar extends StatelessWidget {
  const Avatar({
    super.key,
    required this.seed,
    this.size = 72,
    this.semanticLabel,
  });

  final int seed;
  final double size;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) => Semantics(
    label: semanticLabel,
    image: true,
    child: SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _AvatarPainter(seed)),
    ),
  );
}

class _AvatarPainter extends CustomPainter {
  _AvatarPainter(this.seed);

  final int seed;

  static const _palette = [
    Color(0xFFE8322F),
    Color(0xFFFFD23F),
    Color(0xFF3FA7FF),
    Color(0xFF5BE37D),
    Color(0xFF9B5DE5),
    Color(0xFFFF8A3D),
    Color(0xFF00BBF9),
    Color(0xFFF15BB5),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final r = SeededRandom.derive(seed, 'avatar');
    final s = size.width;
    final bg = _palette[r.nextInt(_palette.length)];
    var fg = _palette[r.nextInt(_palette.length)];
    if (fg == bg) fg = const Color(0xFF120D0E);
    final c = Offset(s / 2, s / 2);
    canvas
      ..clipPath(Path()..addOval(Offset.zero & size))
      ..drawRect(Offset.zero & size, Paint()..color = bg);
    final shape = r.nextInt(4);
    final p = Paint()..color = fg;
    switch (shape) {
      case 0:
        canvas.drawCircle(c, s * 0.3, p);
      case 1:
        canvas
          ..save()
          ..translate(c.dx, c.dy)
          ..rotate(r.doubleInRange(0, math.pi / 2))
          ..drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(
                center: Offset.zero,
                width: s * 0.5,
                height: s * 0.5,
              ),
              Radius.circular(s * 0.08),
            ),
            p,
          )
          ..restore();
      case 2:
        canvas.drawPath(
          Path()
            ..moveTo(c.dx, s * 0.2)
            ..lineTo(s * 0.8, s * 0.75)
            ..lineTo(s * 0.2, s * 0.75)
            ..close(),
          p,
        );
      default:
        final path = Path();
        for (var i = 0; i < 10; i++) {
          final a = -math.pi / 2 + i * math.pi / 5;
          final rad = i.isEven ? s * 0.34 : s * 0.15;
          final pt = c + Offset(math.cos(a), math.sin(a)) * rad;
          i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
        }
        canvas.drawPath(path..close(), p);
    }
    // Eyes: every avatar is a little character.
    final eye = Paint()..color = Colors.white;
    final pupil = Paint()..color = const Color(0xFF120D0E);
    final dy = s * r.doubleInRange(0.42, 0.52);
    for (final dx in [-0.1, 0.1]) {
      canvas
        ..drawCircle(Offset(s * (0.5 + dx), dy), s * 0.06, eye)
        ..drawCircle(Offset(s * (0.5 + dx), dy), s * 0.03, pupil);
    }
  }

  @override
  bool shouldRepaint(_AvatarPainter old) => old.seed != seed;
}
