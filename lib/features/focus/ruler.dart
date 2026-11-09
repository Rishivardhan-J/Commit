import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/commit_colors.dart';

/// Horizontal ruler to pick a focus length (5–120 min, 5-min steps) with a haptic tick per step.
class LengthRuler extends StatelessWidget {
  final int minutes;
  final ValueChanged<int> onChanged;
  const LengthRuler({super.key, required this.minutes, required this.onChanged});

  static const min = 5, max = 120;

  void _pick(double dx, double width) {
    final raw = min + (dx / width).clamp(0.0, 1.0) * (max - min);
    final m = ((raw / 5).round() * 5).clamp(min, max);
    if (m != minutes) {
      HapticFeedback.selectionClick();
      onChanged(m);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cc = context.cc;
    return Semantics(
      slider: true,
      label: 'Focus length',
      value: '$minutes minutes',
      increasedValue: '${(minutes + 5).clamp(min, max)} minutes',
      decreasedValue: '${(minutes - 5).clamp(min, max)} minutes',
      onIncrease: () => onChanged((minutes + 5).clamp(min, max)),
      onDecrease: () => onChanged((minutes - 5).clamp(min, max)),
      child: LayoutBuilder(builder: (context, c) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: (d) => _pick(d.localPosition.dx, c.maxWidth),
          onHorizontalDragUpdate: (d) => _pick(d.localPosition.dx, c.maxWidth),
          onTapDown: (d) => _pick(d.localPosition.dx, c.maxWidth),
          child: SizedBox(
            height: 58,
            width: c.maxWidth,
            child: CustomPaint(
              painter: _RulerPainter(minutes, context.scheme.primary, cc.border, cc.textSecondary, AppTheme.mono(context, size: 12, weight: FontWeight.w800).fontFamily),
            ),
          ),
        );
      }),
    );
  }
}

class _RulerPainter extends CustomPainter {
  final int minutes;
  final Color active, tick, label;
  final String? font;
  _RulerPainter(this.minutes, this.active, this.tick, this.label, this.font);

  @override
  void paint(Canvas canvas, Size size) {
    const steps = (LengthRuler.max - LengthRuler.min) ~/ 5;
    for (var i = 0; i <= steps; i++) {
      final m = LengthRuler.min + i * 5;
      final x = size.width * i / steps;
      final major = m % 30 == 0 || m == 5;
      final on = m <= minutes;
      canvas.drawLine(
        Offset(x, 30),
        Offset(x, 30 - (major ? 18 : 10)),
        Paint()
          ..color = on ? active : tick
          ..strokeWidth = major ? 2.4 : 1.6
          ..strokeCap = StrokeCap.round,
      );
      if (major && m % 30 == 0) {
        final tp = TextPainter(
          text: TextSpan(text: '$m', style: TextStyle(color: label, fontSize: 10, fontFamily: font)),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(x - tp.width / 2, 36));
      }
    }
    // thumb
    final tx = size.width * (minutes - LengthRuler.min) / (LengthRuler.max - LengthRuler.min);
    canvas.drawCircle(Offset(tx, 30), 9, Paint()..color = active.withValues(alpha: 0.25)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
    canvas.drawCircle(Offset(tx, 30), 7, Paint()..color = active);
    canvas.drawCircle(Offset(tx, 30), 3, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_RulerPainter o) => o.minutes != minutes || o.active != active || o.tick != tick;
}
