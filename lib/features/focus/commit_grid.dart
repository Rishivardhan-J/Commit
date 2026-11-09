import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/widgets/polish.dart';

/// Columns/rows for a session of [minutes]: roughly square, 5..10 columns wide.
({int cols, int rows}) gridDims(int minutes) {
  final n = minutes.clamp(1, 240);
  final cols = math.sqrt(n).ceil().clamp(5, 10);
  return (cols: cols, rows: (n / cols).ceil());
}

/// The hero of the focus screen: one square per minute, filling like a contribution graph.
/// Finished minutes take heat colours, the current minute fills like liquid with the seconds.
class CommitGrid extends StatelessWidget {
  final int minutes;
  final double elapsedMin; // fractional minutes completed in this phase
  final List<Color> heat; // light → intense, used for finished minutes
  final Color track, current, glow;
  final bool dim;
  final ValueChanged<int>? onLengthChanged; // only while idle
  final String semanticsLabel;
  final double maxHeight;

  const CommitGrid({
    super.key,
    required this.minutes,
    required this.elapsedMin,
    required this.heat,
    required this.track,
    required this.current,
    required this.glow,
    required this.semanticsLabel,
    this.dim = false,
    this.maxHeight = 250,
    this.onLengthChanged,
  });

  @override
  Widget build(BuildContext context) {
    final d = gridDims(minutes);
    final still = reducedMotion(context);
    return LayoutBuilder(builder: (context, c) {
      // Fit both the width and a max height so tall sessions never push the controls off screen.
      final byWidth = (c.maxWidth - (d.cols - 1) * 5) / d.cols;
      final byHeight = (maxHeight - (d.rows - 1) * 5) / d.rows;
      final cell = math.min(byWidth, byHeight);
      final w = d.cols * cell + (d.cols - 1) * 5;
      final h = d.rows * cell + (d.rows - 1) * 5;
      Widget grid = Semantics(
        label: semanticsLabel,
        child: SizedBox(
          width: w,
          height: h,
          child: CustomPaint(
            painter: _GridPainter(
              minutes: minutes,
              cols: d.cols,
              elapsedMin: elapsedMin,
              heat: heat,
              track: track,
              current: current,
              glow: glow,
              dim: dim,
              pulse: !still,
            ),
          ),
        ),
      );
      grid = Center(child: grid);
      if (onLengthChanged == null) return grid;
      double acc = 0;
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanUpdate: (u) {
          acc += u.delta.dx - u.delta.dy; // right/up = longer
          while (acc.abs() >= 22) {
            final step = acc > 0 ? 5 : -5;
            acc -= acc > 0 ? 22 : -22;
            onLengthChanged!((minutes + step).clamp(5, 120));
          }
        },
        child: grid,
      );
    });
  }
}

class _GridPainter extends CustomPainter {
  final int minutes, cols;
  final double elapsedMin;
  final List<Color> heat;
  final Color track, current, glow;
  final bool dim, pulse;
  const _GridPainter({
    required this.minutes,
    required this.cols,
    required this.elapsedMin,
    required this.heat,
    required this.track,
    required this.current,
    required this.glow,
    required this.dim,
    required this.pulse,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const gap = 5.0;
    final cell = (size.width - (cols - 1) * gap) / cols;
    final radius = Radius.circular(cell * 0.24);
    final done = elapsedMin.floor();
    final frac = elapsedMin - done;
    final alpha = dim ? 0.6 : 1.0;

    for (var i = 0; i < minutes; i++) {
      final col = i % cols, row = i ~/ cols;
      var rect = Rect.fromLTWH(col * (cell + gap), row * (cell + gap), cell, cell);
      final rr = RRect.fromRectAndRadius(rect, radius);

      if (i < done) {
        // finished minute: heat ramps up through the session
        final t = minutes <= 1 ? 1.0 : i / (minutes - 1);
        final color = heat[(t * (heat.length - 1)).round().clamp(0, heat.length - 1)];
        var r = rr;
        if (pulse && i == done - 1 && frac < 0.35) {
          final k = 1 + 0.14 * math.sin(math.pi * frac / 0.35);
          r = RRect.fromRectAndRadius(Rect.fromCenter(center: rect.center, width: cell * k, height: cell * k), radius);
        }
        canvas.drawRRect(r, Paint()..color = color.withValues(alpha: alpha));
      } else if (i == done) {
        canvas.drawRRect(rr, Paint()..color = track);
        canvas.drawRRect(
            rr.inflate(2),
            Paint()
              ..color = glow.withValues(alpha: 0.28 * alpha)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7));
        canvas.save();
        canvas.clipRRect(rr);
        final fh = cell * frac.clamp(0.0, 1.0);
        final fill = Rect.fromLTWH(rect.left, rect.bottom - fh, cell, fh);
        canvas.drawRect(fill, Paint()..color = current.withValues(alpha: alpha));
        if (fh > 1.5) {
          canvas.drawLine(fill.topLeft, fill.topRight, Paint()
            ..color = Colors.white.withValues(alpha: 0.55)
            ..strokeWidth = 1.2);
        }
        canvas.restore();
        canvas.drawRRect(rr, Paint()
          ..color = current.withValues(alpha: 0.8 * alpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2);
      } else {
        canvas.drawRRect(rr, Paint()..color = track.withValues(alpha: 0.85));
      }
    }
  }

  @override
  bool shouldRepaint(_GridPainter o) =>
      o.minutes != minutes || o.elapsedMin != elapsedMin || o.dim != dim || o.heat != heat || o.track != track || o.current != current;
}

/// Box-breathing guide for breaks: in 4s, hold 4s, out 4s, hold 4s.
class BreathingSquare extends StatefulWidget {
  final Color color;
  final TextStyle? style;
  const BreathingSquare({super.key, required this.color, this.style});
  @override
  State<BreathingSquare> createState() => _BreathingSquareState();
}

class _BreathingSquareState extends State<BreathingSquare> with SingleTickerProviderStateMixin {
  late final AnimationController c = AnimationController(vsync: this, duration: const Duration(seconds: 16))..repeat();

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final still = reducedMotion(context);
    return AnimatedBuilder(
      animation: c,
      builder: (_, _) {
        final t = c.value * 16;
        final (label, k) = switch (t) {
          < 4 => ('Breathe in', Curves.easeInOut.transform(t / 4)),
          < 8 => ('Hold', 1.0),
          < 12 => ('Breathe out', 1 - Curves.easeInOut.transform((t - 8) / 4)),
          _ => ('Hold', 0.0),
        };
        final scale = still ? 0.8 : 0.55 + 0.45 * k;
        return Column(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(
            width: 150,
            height: 150,
            child: Center(
              child: Container(
                width: 150 * scale,
                height: 150 * scale,
                decoration: BoxDecoration(
                  color: widget.color.withValues(alpha: 0.18 + 0.2 * k),
                  borderRadius: BorderRadius.circular(28 * scale),
                  border: Border.all(color: widget.color, width: 2),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(still ? 'Breathe slowly' : label, style: widget.style),
        ]);
      },
    );
  }
}

/// Time readout where each digit rolls like an odometer when it changes.
class OdometerText extends StatelessWidget {
  final String text; // e.g. "12:41"
  final TextStyle style;
  const OdometerText(this.text, {super.key, required this.style});

  @override
  Widget build(BuildContext context) {
    final still = reducedMotion(context);
    return Semantics(
      excludeSemantics: true,
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        for (var i = 0; i < text.length; i++)
          still || text[i] == ':'
              ? Text(text[i], style: style)
              : AnimatedSwitcher(
                  duration: const Duration(milliseconds: 260),
                  switchInCurve: Curves.easeOutCubic,
                  transitionBuilder: (child, anim) => ClipRect(
                    child: SlideTransition(
                      position: Tween(begin: const Offset(0, 0.9), end: Offset.zero).animate(anim),
                      child: FadeTransition(opacity: anim, child: child),
                    ),
                  ),
                  layoutBuilder: (cur, prev) => Stack(alignment: Alignment.center, children: [...prev, ?cur]),
                  child: Text(text[i], key: ValueKey('$i${text[i]}'), style: style),
                ),
      ]),
    );
  }
}
