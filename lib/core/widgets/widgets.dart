import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/commit_colors.dart';
import '../utils/day_key.dart';

class CCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  const CCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.onTap});

  @override
  Widget build(BuildContext context) => Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(onTap: onTap, child: Padding(padding: padding, child: child)),
      );
}

/// Indigo→violet gradient; one per screen.
class HeroCard extends StatelessWidget {
  final Widget child;
  const HeroCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [context.scheme.primary, context.cc.gradientEnd],
          ),
        ),
        child: DefaultTextStyle.merge(style: TextStyle(color: context.cc.onAccent), child: child),
      );
}

class SectionTitle extends StatelessWidget {
  final String title;
  final Widget? trailing;
  const SectionTitle(this.title, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
        child: Row(children: [
          Expanded(child: Text(title, style: context.text.titleMedium?.copyWith(fontWeight: FontWeight.w700))),
          ?trailing,
        ]),
      );
}

class Pill extends StatelessWidget {
  final String label;
  final Color? color;
  final IconData? icon;
  const Pill(this.label, {super.key, this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    final c = color ?? context.cc.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(999)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        ?(icon == null ? null : Icon(icon, size: 13, color: c)),
        if (icon != null) const SizedBox(width: 4),
        Text(label, style: context.text.labelSmall?.copyWith(color: c, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

class LevelRing extends StatelessWidget {
  final double progress;
  final int level;
  final double size;
  final Color? color;
  const LevelRing({super.key, required this.progress, required this.level, this.size = 52, this.color});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: Stack(alignment: Alignment.center, children: [
          SizedBox.expand(
            child: CircularProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              strokeWidth: 5,
              strokeCap: StrokeCap.round,
              backgroundColor: context.cc.surfaceRaised,
              color: color ?? context.scheme.primary,
            ),
          ),
          Text('$level', style: AppTheme.mono(context, size: size * 0.32, weight: FontWeight.w800)),
        ]),
      );
}

/// Contribution-graph heatmap. [weeks] columns × 7 rows ending today.
class Heatmap extends StatelessWidget {
  final Map<String, int> activity;
  final String today;
  final int weeks;
  final double cell;
  const Heatmap({super.key, required this.activity, required this.today, this.weeks = 16, this.cell = 14});

  @override
  Widget build(BuildContext context) {
    final cc = context.cc;
    final end = parseDayKey(today);
    // Align so that the last column ends with today's weekday row.
    final lastRow = end.weekday % 7; // Sun=0
    final start = DateTime(end.year, end.month, end.day - (weeks - 1) * 7 - lastRow);
    return Semantics(
      label: 'Activity heatmap, last $weeks weeks',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var w = 0; w < weeks; w++)
            Padding(
              padding: const EdgeInsets.only(right: 3),
              child: Column(children: [
                for (var d = 0; d < 7; d++)
                  Builder(builder: (_) {
                    final date = DateTime(start.year, start.month, start.day + w * 7 + d);
                    final k = dayKey(date);
                    final future = k.compareTo(today) > 0;
                    return Container(
                      width: cell,
                      height: cell,
                      margin: const EdgeInsets.only(bottom: 3),
                      decoration: BoxDecoration(
                        color: future ? Colors.transparent : cc.heatFor(activity[k] ?? 0),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    );
                  }),
              ]),
            ),
        ],
      ),
    );
  }
}

/// Rounded tinted tile holding a Phosphor icon; the app's replacement for emoji.
class IconTile extends StatelessWidget {
  final IconData icon;
  final Color? color;
  final double size;
  const IconTile(this.icon, {super.key, this.color, this.size = 44});

  @override
  Widget build(BuildContext context) {
    final c = color ?? context.scheme.primary;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: c.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(size * 0.3)),
      child: Center(child: Icon(icon, size: size * 0.55, color: c)),
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final String? cta;
  final VoidCallback? onCta;
  const EmptyState({super.key, required this.icon, required this.title, required this.subtitle, this.cta, this.onCta});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          IconTile(icon, size: 72),
          const SizedBox(height: 12),
          Text(title, style: context.text.titleMedium?.copyWith(fontWeight: FontWeight.w700), textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text(subtitle, style: context.text.bodyMedium?.copyWith(color: context.cc.textSecondary), textAlign: TextAlign.center),
          if (cta != null) ...[
            const SizedBox(height: 16),
            FilledButton(onPressed: onCta, child: Text(cta!)),
          ],
        ]),
      );
}
