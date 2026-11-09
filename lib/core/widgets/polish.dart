import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

bool reducedMotion(BuildContext context) => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

/// Counts up to [value] whenever it changes (score, XP, streak). Instant under reduced motion.
class AnimatedCount extends StatelessWidget {
  final int value;
  final TextStyle? style;
  final String prefix, suffix;
  final Duration duration;
  const AnimatedCount({
    super.key,
    required this.value,
    this.style,
    this.prefix = '',
    this.suffix = '',
    this.duration = const Duration(milliseconds: 800),
  });

  @override
  Widget build(BuildContext context) {
    if (reducedMotion(context)) return Text('$prefix$value$suffix', style: style);
    return TweenAnimationBuilder<double>(
      tween: Tween(end: value.toDouble()),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (_, v, _) => Text('$prefix${v.round()}$suffix', style: style),
    );
  }
}

extension StaggerIn on Widget {
  /// Fade + gentle rise, delayed by [index] so a column of cards cascades in.
  Widget staggerIn(BuildContext context, int index) {
    if (reducedMotion(context)) return this;
    return animate()
        .fadeIn(duration: 380.ms, delay: (60 * index).ms, curve: Curves.easeOutCubic)
        .slideY(begin: 0.06, end: 0, duration: 380.ms, delay: (60 * index).ms, curve: Curves.easeOutCubic);
  }
}

/// One-shot confetti (pure CustomPainter, no package). Plays once on mount.
class ConfettiBurst extends StatefulWidget {
  final List<Color> colors;
  final int count;
  const ConfettiBurst({super.key, required this.colors, this.count = 70});
  @override
  State<ConfettiBurst> createState() => _ConfettiBurstState();
}

class _ConfettiBurstState extends State<ConfettiBurst> with SingleTickerProviderStateMixin {
  late final AnimationController c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200))..forward();
  late final List<_Piece> pieces = _make();

  List<_Piece> _make() {
    final r = math.Random(7);
    return [
      for (var i = 0; i < widget.count; i++)
        _Piece(
          angle: -math.pi / 2 + (r.nextDouble() - 0.5) * math.pi * 0.9,
          speed: 380 + r.nextDouble() * 520,
          spin: (r.nextDouble() - 0.5) * 12,
          size: 6 + r.nextDouble() * 7,
          color: widget.colors[i % widget.colors.length],
        ),
    ];
  }

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (reducedMotion(context)) return const SizedBox.shrink();
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: c,
        builder: (_, _) => CustomPaint(size: Size.infinite, painter: _ConfettiPainter(pieces, c.value)),
      ),
    );
  }
}

class _Piece {
  final double angle, speed, spin, size;
  final Color color;
  const _Piece({required this.angle, required this.speed, required this.spin, required this.size, required this.color});
}

class _ConfettiPainter extends CustomPainter {
  final List<_Piece> pieces;
  final double t;
  _ConfettiPainter(this.pieces, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final origin = Offset(size.width / 2, size.height * 0.38);
    const gravity = 900.0;
    final secs = t * 2.2;
    for (final p in pieces) {
      final dx = math.cos(p.angle) * p.speed * secs;
      final dy = math.sin(p.angle) * p.speed * secs + 0.5 * gravity * secs * secs;
      final pos = origin + Offset(dx, dy);
      final fade = (1 - ((t - 0.6) / 0.4)).clamp(0.0, 1.0);
      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(p.spin * secs);
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.55), const Radius.circular(2)),
        Paint()..color = p.color.withValues(alpha: fade),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}
