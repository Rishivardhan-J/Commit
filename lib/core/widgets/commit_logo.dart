import 'dart:math' as math;
import 'package:flutter/material.dart';

/// The Commit mark: a "C" arc whose open end finishes in an amber commit node.
/// Geometry mirrors assets/brand/icon_full.svg (1024 grid) so in-app and launcher icons match.
class CommitLogo extends StatelessWidget {
  final double size;

  /// Draw the rounded gradient tile behind the mark (the app-icon look).
  final bool tile;
  const CommitLogo({super.key, this.size = 96, this.tile = true});

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Commit logo',
        image: true,
        child: SizedBox(
          width: size,
          height: size,
          child: CustomPaint(painter: _LogoPainter(tile: tile)),
        ),
      );
}

class _LogoPainter extends CustomPainter {
  final bool tile;
  const _LogoPainter({required this.tile});

  static const _indigo = Color(0xFF6366F1);
  static const _violet = Color(0xFF7C3AED);
  static const _amber = Color(0xFFFBBF24);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 1024;
    canvas.save();
    canvas.scale(s);
    const full = Rect.fromLTWH(0, 0, 1024, 1024);

    if (tile) {
      final rrect = RRect.fromRectAndRadius(full, const Radius.circular(230));
      canvas.drawRRect(
        rrect,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_indigo, _violet],
          ).createShader(full),
      );
      canvas.drawRRect(
        rrect,
        Paint()
          ..shader = const RadialGradient(
            center: Alignment(-0.4, -0.7),
            radius: 0.75,
            colors: [Color(0x38FFFFFF), Color(0x00FFFFFF)],
          ).createShader(full),
      );
    }

    const center = Offset(548, 512);
    const r = 235.0;
    final end = Offset(center.dx + r * math.cos(48 * math.pi / 180), center.dy + r * math.sin(48 * math.pi / 180));
    final arcColor = tile ? Colors.white : _indigo;

    canvas.saveLayer(full, Paint());
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: r),
      -48 * math.pi / 180,
      -264 * math.pi / 180,
      false,
      Paint()
        ..color = arcColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 112
        ..strokeCap = StrokeCap.round,
    );
    // Clear ring around the node so it reads as a git commit dot.
    canvas.drawCircle(end, 94, Paint()..blendMode = BlendMode.clear);
    canvas.restore();

    canvas.drawCircle(end, 66, Paint()..color = _amber);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_LogoPainter old) => old.tile != tile;
}
