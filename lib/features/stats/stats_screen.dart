import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/commit_colors.dart';
import '../../core/utils/day_key.dart';
import '../../core/widgets/widgets.dart';
import '../../data/app_store.dart';
import '../../engine/badge_engine.dart';
import '../../engine/streak_engine.dart';
import '../../core/icons.dart';

class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appProvider);
    final today = ref.watch(todayProvider);
    final cc = context.cc;
    final streak = computeStreak(s, today);
    final gh = s.snapshots['github'];
    final lc = s.snapshots['leetcode'];
    final cfs = s.snapshots['codeforces'];

    final merged = <String, int>{};
    void add(Map<String, int> m) => m.forEach((k, v) => merged[k] = (merged[k] ?? 0) + v);
    add({for (final c in s.commits.where((c) => !c.frozen)) c.day: c.tasks.clamp(1, 99)});
    if (gh != null) add(gh.activity);
    if (lc != null) add(lc.activity);
    if (cfs != null) add(cfs.activity);

    Widget stat(String label, String value) => Expanded(
          child: Column(children: [
            Text(value, style: AppTheme.mono(context, size: 22, weight: FontWeight.w800)),
            Text(label, style: context.text.labelSmall?.copyWith(color: cc.textSecondary)),
          ]),
        );

    final log = [...s.commits]..sort((a, b) => b.day.compareTo(a.day));

    return Scaffold(
      appBar: AppBar(title: const Text('Stats & log')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 40), children: [
        CCard(
          child: Row(children: [
            stat('current streak', '${streak.current}'),
            stat('best streak', '${streak.best}'),
            stat('days committed', '${s.commits.where((c) => !c.frozen).length}'),
          ]),
        ),
        const SectionTitle('Trends'),
        _Trends(merged: merged, today: today, focusByDay: s.focusByDay, focusMinutes: s.focusMinutes),
        const SectionTitle('Commit graph · all platforms'),
        CCard(child: SingleChildScrollView(scrollDirection: Axis.horizontal, reverse: true, child: Heatmap(activity: merged, today: today))),
        if (lc != null) ...[
          const SectionTitle('LeetCode'),
          CCard(
            child: Column(children: [
              Row(children: [
                stat('easy', '${lc.stats['easy'] ?? 0}'),
                stat('medium', '${lc.stats['medium'] ?? 0}'),
                stat('hard', '${lc.stats['hard'] ?? 0}'),
                if ((lc.stats['rating'] ?? 0) > 0) stat('rating', '${lc.stats['rating']}'),
              ]),
              const SizedBox(height: 12),
              _TopicBars(data: lc.breakdown),
            ]),
          ),
        ],
        if (cfs != null) ...[
          const SectionTitle('Codeforces'),
          CCard(
            child: Column(children: [
              Row(children: [
                stat('solved', '${cfs.stats['solved'] ?? 0}'),
                stat('rating', '${cfs.stats['rating'] ?? 0}'),
                stat('max rating', '${cfs.stats['maxRating'] ?? 0}'),
              ]),
              const SizedBox(height: 12),
              _TopicBars(data: cfs.breakdown),
            ]),
          ),
        ],
        if (gh != null) ...[
          const SectionTitle('GitHub'),
          CCard(
            child: Column(children: [
              Row(children: [
                stat('repos', '${gh.stats['repos'] ?? 0}'),
                stat('stars', '${gh.stats['stars'] ?? 0}'),
                stat('PRs opened', '${gh.stats['openedPrs'] ?? 0}'),
              ]),
              const SizedBox(height: 12),
              _TopicBars(data: gh.breakdown, label: 'Top languages'),
            ]),
          ),
        ],
        for (final e in s.syncErrors.entries)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('${e.key}: ${e.value}', style: TextStyle(color: cc.warning)),
          ),
        const SectionTitle('Badges'),
        CCard(
          child: Wrap(spacing: 10, runSpacing: 10, children: [
            for (final b in badgeDefs)
              Tooltip(
                message: b.hint,
                child: Opacity(
                  opacity: s.badges.contains(b.id) ? 1 : 0.35,
                  child: Container(
                    width: 96,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: cc.surfaceRaised, borderRadius: BorderRadius.circular(12)),
                    child: Column(children: [
                      IconTile(b.icon, size: 44),
                      const SizedBox(height: 4),
                      Text(b.name, textAlign: TextAlign.center, style: context.text.labelSmall),
                    ]),
                  ),
                ),
              ),
          ]),
        ),
        const SectionTitle('git log'),
        if (log.isEmpty)
          const CCard(child: EmptyState(icon: AppIcons.gitCommit, title: 'No commits yet', subtitle: 'Finish a task, then commit your day.'))
        else
          CCard(
            child: Column(children: [
              for (final c in log.take(30))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(children: [
                    Icon(c.frozen ? Icons.ac_unit : Icons.circle, size: 12, color: c.frozen ? cc.info : c.critical ? cc.warning : cc.success),
                    const SizedBox(width: 10),
                    Text(c.day.substring(5), style: AppTheme.mono(context, size: 12, color: cc.textSecondary)),
                    const SizedBox(width: 10),
                    Expanded(child: Text(c.message, maxLines: 1, overflow: TextOverflow.ellipsis)),
                    if (!c.frozen) Text('+${c.xp}', style: AppTheme.mono(context, size: 12, color: cc.warning)),
                  ]),
                ),
            ]),
          ),
      ]),
    );
  }
}

class _TopicBars extends StatelessWidget {
  final Map<String, int> data;
  final String label;
  const _TopicBars({required this.data, this.label = 'Topic strength'});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox.shrink();
    final top = data.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final shown = top.take(6).toList();
    final max = shown.first.value == 0 ? 1 : shown.first.value;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: context.text.labelLarge?.copyWith(color: context.cc.textSecondary)),
      const SizedBox(height: 8),
      for (final e in shown)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(children: [
            SizedBox(width: 110, child: Text(e.key, overflow: TextOverflow.ellipsis, style: context.text.bodySmall)),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(value: e.value / max, minHeight: 8, color: context.scheme.primary, backgroundColor: context.cc.surfaceRaised),
              ),
            ),
            SizedBox(width: 36, child: Text('${e.value}', textAlign: TextAlign.right, style: AppTheme.mono(context, size: 12))),
          ]),
        ),
    ]);
  }
}

class _Trends extends StatelessWidget {
  final Map<String, int> merged, focusByDay, focusMinutes;
  final String today;
  const _Trends({required this.merged, required this.today, required this.focusByDay, required this.focusMinutes});

  int _sum(Map<String, int> m, String from, String to) =>
      m.entries.where((e) => e.key.compareTo(from) >= 0 && e.key.compareTo(to) <= 0).fold(0, (a, e) => a + e.value);

  @override
  Widget build(BuildContext context) {
    final cc = context.cc;
    final thisWeek = _sum(merged, addDays(today, -6), today);
    final lastWeek = _sum(merged, addDays(today, -13), addDays(today, -7));
    final String headline;
    final Color color;
    if (lastWeek == 0 && thisWeek == 0) {
      headline = 'No activity yet — your first commit starts the trend';
      color = cc.textSecondary;
    } else if (lastWeek == 0) {
      headline = '$thisWeek activities this week — a fresh start';
      color = cc.success;
    } else {
      final pct = ((thisWeek - lastWeek) / lastWeek * 100).round();
      headline = pct >= 0 ? 'You did $pct% more than last week' : 'Activity is ${-pct}% below last week';
      color = pct >= 0 ? cc.success : cc.warning;
    }
    final days = [for (var i = 6; i >= 0; i--) addDays(today, -i)];
    final maxY = days.map((d) => merged[d] ?? 0).fold<int>(1, (a, b) => a > b ? a : b).toDouble();
    final focusTop = (focusMinutes.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).take(5).toList();
    final focusToday = focusByDay[today] ?? 0;

    return CCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(headline, style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w700, color: color)),
        Text('This week $thisWeek · last week $lastWeek', style: context.text.bodySmall?.copyWith(color: cc.textSecondary)),
        const SizedBox(height: 14),
        SizedBox(
          height: 130,
          child: BarChart(BarChartData(
            maxY: maxY * 1.25,
            gridData: const FlGridData(show: false),
            borderData: FlBorderData(show: false),
            barTouchData: BarTouchData(enabled: false),
            titlesData: FlTitlesData(
              leftTitles: const AxisTitles(),
              topTitles: const AxisTitles(),
              rightTitles: const AxisTitles(),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (v, _) => Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(['M', 'T', 'W', 'T', 'F', 'S', 'S'][parseDayKey(days[v.toInt()]).weekday - 1],
                        style: TextStyle(fontSize: 11, color: cc.textSecondary)),
                  ),
                ),
              ),
            ),
            barGroups: [
              for (var i = 0; i < 7; i++)
                BarChartGroupData(x: i, barRods: [
                  BarChartRodData(
                    toY: (merged[days[i]] ?? 0).toDouble(),
                    width: 18,
                    borderRadius: BorderRadius.circular(6),
                    color: i == 6 ? context.scheme.primary : context.scheme.primary.withValues(alpha: 0.45),
                    backDrawRodData: BackgroundBarChartRodData(show: true, toY: maxY * 1.25, color: cc.surfaceRaised),
                  ),
                ]),
            ],
          )),
        ),
        if (focusTop.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Focus time by skill · $focusToday min today', style: context.text.labelLarge?.copyWith(color: cc.textSecondary)),
          const SizedBox(height: 8),
          for (final e in focusTop)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(children: [
                SizedBox(width: 110, child: Text(e.key, overflow: TextOverflow.ellipsis, style: context.text.bodySmall)),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(value: e.value / focusTop.first.value, minHeight: 8, color: cc.warning, backgroundColor: cc.surfaceRaised),
                  ),
                ),
                SizedBox(width: 56, child: Text('${e.value}m', textAlign: TextAlign.right, style: AppTheme.mono(context, size: 12))),
              ]),
            ),
        ],
      ]),
    );
  }
}
