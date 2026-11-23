import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_theme.dart';
import 'game_sim.dart';

/// Small drawing helpers shared by mini-games (vector shapes, no assets).

final Paint _shadowPaint = Paint()
  ..color = const Color(0x55000000)
  ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

void drawShadowCircle(Canvas c, Offset center, double r, {double dy = 4}) =>
    c.drawCircle(center.translate(2, dy), r, _shadowPaint);

void drawShadowRRect(Canvas c, RRect rr, {double dy = 4}) =>
    c.drawRRect(rr.shift(Offset(2, dy)), _shadowPaint);

void drawBox(Canvas c, Rect r, Color color, {double radius = 6}) {
  final rr = RRect.fromRectAndRadius(r, Radius.circular(radius));
  drawShadowRRect(c, rr);
  c.drawRRect(rr, Paint()..color = color);
  c.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(
        r.left + 3,
        r.top + 3,
        r.width - 6,
        math.min(6, r.height / 3),
      ),
      Radius.circular(radius / 2),
    ),
    Paint()..color = Colors.white.withValues(alpha: 0.18),
  );
}

void drawBall(Canvas c, Offset p, double r, Color color, {bool shadow = true}) {
  if (shadow) drawShadowCircle(c, p, r, dy: r * 0.35);
  c.drawCircle(p, r, Paint()..color = color);
  c.drawCircle(
    p.translate(-r * 0.3, -r * 0.3),
    r * 0.35,
    Paint()..color = Colors.white.withValues(alpha: 0.45),
  );
}

void drawText(
  Canvas c,
  String text,
  Offset at, {
  double size = 16,
  Color color = Colors.white,
  bool display = false,
  TextAlign align = TextAlign.left,
  double? maxWidth,
}) {
  final tp = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        fontSize: size,
        color: color,
        fontFamily: display ? AppFonts.display : AppFonts.body,
        fontWeight: display ? FontWeight.normal : FontWeight.w600,
        fontFeatures: AppFonts.tabular,
      ),
    ),
    textAlign: align,
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: maxWidth ?? 1000);
  var o = at;
  if (align == TextAlign.center) {
    o = at.translate(-tp.width / 2, -tp.height / 2);
  }
  if (align == TextAlign.right) o = at.translate(-tp.width, 0);
  tp.paint(c, o);
}

/// Darkness with a soft visibility hole (`night` modifier).
void drawNight(Canvas c, Offset focus, double radius) {
  final shader = const RadialGradient(
    colors: [Color(0x00000000), Color(0x00000000), Color(0xF2000000)],
    stops: [0, 0.55, 1],
  ).createShader(Rect.fromCircle(center: focus, radius: radius));
  c
    ..saveLayer(Arena.rect, Paint())
    ..drawRect(Arena.rect, Paint()..color = const Color(0xF2000000))
    ..drawCircle(
      focus,
      radius,
      Paint()
        ..blendMode = BlendMode.dstOut
        ..color = Colors.white,
    )
    ..drawCircle(focus, radius, Paint()..shader = shader)
    ..restore();
}

/// Wind sock + arrow (`wind` modifier). [wind] in world units/s².
void drawWind(Canvas c, Offset at, Offset wind, {double max = 60}) {
  final strength = (wind.distance / max).clamp(0.0, 1.0);
  final dir = wind.distance == 0 ? const Offset(1, 0) : wind / wind.distance;
  c.drawCircle(at, 22, Paint()..color = const Color(0x66000000));
  final tip = at + dir * (8 + 12 * strength);
  final tail = at - dir * 12;
  final p = Paint()
    ..color = const Color(0xFFFFD23F)
    ..strokeWidth = 3
    ..strokeCap = StrokeCap.round;
  c.drawLine(tail, tip, p);
  final n = Offset(-dir.dy, dir.dx);
  c
    ..drawLine(tip, tip - dir * 7 + n * 5, p)
    ..drawLine(tip, tip - dir * 7 - n * 5, p);
  drawText(
    c,
    '${(strength * 30).round()} km/h',
    at.translate(0, 32),
    size: 10,
    align: TextAlign.center,
  );
}

/// Draws a dashed segment of at most [maxLen] (aim guides).
void drawDashed(Canvas c, Offset from, Offset dir, double maxLen, Paint p) {
  final d = dir.distance == 0 ? Offset.zero : dir / dir.distance;
  for (double t = 0; t < maxLen; t += 8) {
    c.drawLine(from + d * t, from + d * math.min(t + 4, maxLen), p);
  }
}
