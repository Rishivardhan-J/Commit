import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/commit_colors.dart';
import '../../core/widgets/widgets.dart';
import '../../data/app_store.dart';
import '../../engine/badge_engine.dart';
import '../../engine/streak_engine.dart';

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

    final merged = <String, int>{};
    void add(Map<String, int> m) => m.forEach((k, v) => merged[k] = (merged[k] ?? 0) + v);
    add({for (final c in s.commits.where((c) => !c.frozen)) c.day: c.tasks.clamp(1, 99)});
    if (gh != null) add(gh.activity);
    if (lc != null) add(lc.activity);

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
                      Text(b.emoji, style: const TextStyle(fontSize: 26)),
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
          const CCard(child: EmptyState(emoji: '📜', title: 'No commits yet', subtitle: 'Finish a task, then commit your day.'))
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
