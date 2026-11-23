import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../theme/app_colors.dart';

/// The OneGame red twin-bell alarm clock (section 11), drawn in code.
/// When [ringing], it shakes (unless [reduceMotion]).
class AlarmClock extends StatefulWidget {
  const AlarmClock({
    super.key,
    this.size = 220,
    required this.semanticLabel,
    this.ringing = false,
    this.reduceMotion = false,
  });

  final double size;
  final String semanticLabel;
  final bool ringing;
  final bool reduceMotion;

  @override
  State<AlarmClock> createState() => _AlarmClockState();
}

class _AlarmClockState extends State<AlarmClock>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 110),
  );

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(AlarmClock old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    final animate = widget.ringing && !widget.reduceMotion;
    if (animate && !_shake.isAnimating) {
      _shake.repeat(reverse: true);
    } else if (!animate && _shake.isAnimating) {
      _shake
        ..stop()
        ..value = 0.5;
    }
  }

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: widget.semanticLabel,
      image: true,
      child: AnimatedBuilder(
        animation: _shake,
        builder: (context, child) => Transform.rotate(
          angle: _shake.isAnimating ? (_shake.value - 0.5) * 0.18 : 0,
          child: child,
        ),
        child: SizedBox.square(
          dimension: widget.size,
          child: CustomPaint(painter: _AlarmClockPainter()),
        ),
      ),
    );
  }
}

class _AlarmClockPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final center = Offset(s / 2, s * 0.56);
    final radius = s * 0.36;
    final red = Paint()..color = AppColors.alarmRed;
    final dark = Paint()..color = AppColors.night;

    // Legs.
    final legs = Paint()
      ..color = AppColors.night
      ..strokeWidth = s * 0.04
      ..strokeCap = StrokeCap.round;
    for (final dir in [-1, 1]) {
      final a = math.pi / 2 + dir * 0.7;
      canvas.drawLine(
        center + Offset(math.cos(a), math.sin(a)) * radius * 0.9,
        center + Offset(math.cos(a), math.sin(a)) * radius * 1.22,
        legs,
      );
    }
    // Bells.
    for (final dir in [-1, 1]) {
      final a = -math.pi / 2 + dir * 0.75;
      final c = center + Offset(math.cos(a), math.sin(a)) * radius * 1.02;
      canvas.drawCircle(c, s * 0.13, red);
      canvas.drawCircle(
        c,
        s * 0.13,
        Paint()
          ..color = AppColors.night
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * 0.02,
      );
    }
    // Hammer.
    canvas.drawCircle(center - Offset(0, radius * 1.18), s * 0.035, dark);
    // Body, face, ticks, hands.
    canvas.drawShadow(
      Path()..addOval(Rect.fromCircle(center: center, radius: radius)),
      Colors.black,
      6,
      false,
    );
    canvas.drawCircle(center, radius, red);
    canvas.drawCircle(center, radius * 0.8, Paint()..color = AppColors.bone);
    final tick = Paint()
      ..color = AppColors.night
      ..strokeWidth = s * 0.015
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 12; i++) {
      final a = i * math.pi / 6;
      final dirV = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(
        center + dirV * radius * 0.66,
        center + dirV * radius * (i % 3 == 0 ? 0.52 : 0.6),
        tick,
      );
    }
    final hand = Paint()
      ..color = AppColors.night
      ..strokeWidth = s * 0.025
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(center, center + const Offset(0, -1) * radius * 0.5, hand);
    canvas.drawLine(
      center,
      center + const Offset(1, 0.3) * radius * 0.38,
      hand,
    );
    canvas.drawCircle(center, s * 0.025, Paint()..color = AppColors.yellow);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
