import 'dart:math' as math;
import 'package:flutter/material.dart';

class ProfilingDonutPainter extends CustomPainter {
  final double progress;
  final double rotation;

  ProfilingDonutPainter({
    required this.progress,
    this.rotation = 0.0,
  });

  // The 5 iconic Spendee segmented loader colors
  static const List<Color> segmentColors = [
    Color(0xFFFF6584), // Pink
    Color(0xFF10B981), // Emerald Green
    Color(0xFFFF5757), // Coral Red
    Color(0xFF00C0FF), // Sky Blue
    Color(0xFFFFD166), // Warm Amber / Beige
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = size.width / 2;
    final innerRadius = outerRadius * 0.58;
    final strokeWidth = outerRadius - innerRadius;
    final radius = innerRadius + strokeWidth / 2;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    final baseRect = Rect.fromCircle(center: center, radius: radius);

    // Subtle background track
    paint.color = Colors.black.withValues(alpha: 0.04);
    canvas.drawCircle(center, radius, paint);

    // Draw the 5 colored arc segments proportionally
    final totalSegments = segmentColors.length;
    final sweepPerSegment = (2 * math.pi) / totalSegments;
    final currentTotalSweep = 2 * math.pi * progress.clamp(0.0, 1.0);

    for (int i = 0; i < totalSegments; i++) {
      final segStartAngle = -math.pi / 2 + rotation + (i * sweepPerSegment);
      final segSweepAvailable = (currentTotalSweep - (i * sweepPerSegment))
          .clamp(0.0, sweepPerSegment);

      if (segSweepAvailable > 0) {
        paint.color = segmentColors[i];
        canvas.drawArc(
          baseRect,
          segStartAngle,
          segSweepAvailable,
          false,
          paint,
        );
      }
    }

    // Soft inner glow ring
    final innerPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.03)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawCircle(center, innerRadius, innerPaint);
  }

  @override
  bool shouldRepaint(covariant ProfilingDonutPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.rotation != rotation;
  }
}
