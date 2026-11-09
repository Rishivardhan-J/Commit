import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/commit_colors.dart';
import '../../core/utils/day_key.dart';
import '../../core/widgets/widgets.dart';
import '../../data/app_store.dart';
import '../../data/models.dart';
import '../../engine/coding_score.dart';
import '../../engine/streak_engine.dart';
import '../../engine/suggestion_engine.dart';
import '../../engine/xp_engine.dart';
import '../capture/capture_sheet.dart';
import '../tasks/task_tile.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final n = ref.read(appProvider.notifier);
      n.sync();
      n.replanReminder();
    });
  }

  String _greeting(int h) => h < 5 ? 'Late night' : h < 12 ? 'Good morning' : h < 18 ? 'Good afternoon' : 'Good evening';

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appProvider);
    final today = ref.watch(todayProvider);
    final now = ref.read(clockProvider)();
    final cc = context.cc;
    final streak = computeStreak(s, today);
    final score = codingScore(s, streak.current);
    final staged = s.tasks.where((t) => t.stagedFor == today || (t.done && t.doneDay == today)).toList();
    final doneCount = staged.where((t) => t.done).length;
    final uncommitted = staged.where((t) => t.done).length;
    final level = levelFor(s.totalXp);
    final suggestions = buildSuggestions(s, today);
    final lc = s.snapshots['leetcode'];
    final gh = s.snapshots['github'];

    // Merged weekly activity: real commits/tasks plus platform activity.
    final merged = <String, int>{};
    void add(Map<String, int> m) => m.forEach((k, v) => merged[k] = (merged[k] ?? 0) + v);
    add({for (final c in s.commits.where((c) => !c.frozen)) c.day: c.tasks.clamp(1, 99)});
    if (gh != null) add(gh.activity);
    if (lc != null) add(lc.activity);

    final cta = _cta(context, ref, s, today, staged, doneCount, streak);
    final week = [for (var i = 6; i >= 0; i--) addDays(today, -i)];
    final activeDays = week.where((d) => (merged[d] ?? 0) > 0 || s.restDays.contains(d)).length;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.read(appProvider.notifier).sync(force: true),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                      Text('${_greeting(now.hour)}${s.name.isEmpty ? '' : ', ${s.name}'}',
                          style: context.text.bodyMedium?.copyWith(color: cc.textSecondary)),
                      Pill('you ${versionString(s.totalXp, s.skillXp.values)}', color: cc.info),
                    ]),
                    const SizedBox(height: 2),
                    Text("Today's focus", style: context.text.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                  ]),
                ),
                const SizedBox(width: 4),
                for (final a in [
                  ('Focus timer', Icons.timer_outlined, '/focus'),
                  ('Stats and log', Icons.insights_rounded, '/stats'),
                  ('Settings', Icons.settings_outlined, '/settings'),
                ])
                  IconButton(
                    tooltip: a.$1,
                    icon: Icon(a.$2),
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints(minWidth: 40, minHeight: 44),
                    padding: EdgeInsets.zero,
                    onPressed: () => context.push(a.$3),
                  ),
              ]),
              const SizedBox(height: 12),
              HeroCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('CODING SCORE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
                        Text('$score', style: AppTheme.mono(context, size: 44, weight: FontWeight.w800, color: cc.onAccent)),
                      ]),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(color: cc.onAccent.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(14)),
                      child: Column(children: [
                        Text('🔥 ${streak.current}', style: AppTheme.mono(context, size: 20, weight: FontWeight.w800, color: cc.onAccent)),
                        Text('day streak', style: TextStyle(fontSize: 11, color: cc.onAccent)),
                      ]),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  Wrap(spacing: 8, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                    Text('Lv ${level.level} · ${level.remaining} xp to Lv ${level.level + 1}',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    Text('🧊 ${s.stash} stash', style: const TextStyle(fontSize: 13)),
                  ]),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: level.progress,
                      minHeight: 8,
                      backgroundColor: cc.onAccent.withValues(alpha: 0.18),
                      color: cc.onAccent,
                    ),
                  ),
                ]),
              ),
              if (hotfixAvailable(s, today))
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: CCard(
                    child: Row(children: [
                      const Text('🩹', style: TextStyle(fontSize: 22)),
                      const SizedBox(width: 12),
                      Expanded(child: Text('Missed yesterday? Finish 2 or more tasks today and commit — a double-day hotfix saves your streak.', style: context.text.bodyMedium)),
                    ]),
                  ),
                ),
              const SizedBox(height: 12),
              cta,
              const SectionTitle('This week'),
              CCard(
                child: Column(children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    for (final d in week)
                      Column(children: [
                        Text(['M', 'T', 'W', 'T', 'F', 'S', 'S'][parseDayKey(d).weekday - 1],
                            style: context.text.labelSmall?.copyWith(color: cc.textSecondary)),
                        const SizedBox(height: 6),
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: s.restDays.contains(d) ? cc.info.withValues(alpha: 0.3) : cc.heatFor(merged[d] ?? 0),
                            borderRadius: BorderRadius.circular(10),
                            border: d == today ? Border.all(color: context.scheme.primary, width: 2) : null,
                          ),
                        ),
                      ]),
                  ]),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('$activeDays of 7 days active',
                        style: context.text.bodySmall?.copyWith(color: cc.textSecondary)),
                  ),
                ]),
              ),
              SectionTitle('Staged for today',
                  trailing: uncommitted > 0 && !streak.committedToday
                      ? Pill('$uncommitted uncommitted change${uncommitted == 1 ? '' : 's'}', color: cc.warning, icon: Icons.edit_note_rounded)
                      : staged.isNotEmpty
                          ? Pill('$doneCount of ${staged.length} done', color: cc.success)
                          : null),
              CCard(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: staged.isEmpty
                    ? EmptyState(
                        emoji: '🗂️',
                        title: 'Nothing staged yet',
                        subtitle: 'Pick 1–3 things for today. Small, specific, doable.',
                        cta: 'Stage a task',
                        onCta: () => showCaptureSheet(context),
                      )
                    : Column(children: [for (final t in staged) TaskTile(task: t)]),
              ),
              if (suggestions.isNotEmpty) ...[
                const SectionTitle('Incoming PR from future you'),
                _SuggestionCard(suggestion: suggestions.first),
              ],
              if (gh != null || lc != null) ...[
                const SectionTitle('Platforms'),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (gh != null)
                    Expanded(
                      child: _PlatformCard(
                        title: 'GitHub',
                        value: '${gh.stats['weekCommits'] ?? 0}',
                        caption: 'commits this week',
                        color: context.scheme.primary,
                        error: s.syncErrors['github'],
                      ),
                    ),
                  if (gh != null && lc != null) const SizedBox(width: 12),
                  if (lc != null)
                    Expanded(
                      child: _PlatformCard(
                        title: 'LeetCode',
                        value: '${lc.stats['solved'] ?? 0}',
                        caption: 'solved · ${lc.stats['weekSolved'] ?? 0} this week',
                        color: const Color(0xFFFFA116),
                        error: s.syncErrors['leetcode'],
                        progress: ((lc.stats['solved'] ?? 0) / 500).clamp(0, 1).toDouble(),
                      ),
                    ),
                ]),
              ] else ...[
                const SectionTitle('Platforms'),
                CCard(
                  onTap: () => context.push('/settings'),
                  child: Row(children: [
                    const Icon(Icons.link_rounded),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text('Link GitHub or LeetCode so real work can complete your tasks.',
                          style: context.text.bodyMedium),
                    ),
                    const Icon(Icons.chevron_right),
                  ]),
                ),
              ],
              if (now.weekday == DateTime.monday) _WeeklyRecap(today: today),
            ],
          ),
        ),
      ),
    );
  }

  /// Single primary action; changes with where the user is in the daily loop.
  Widget _cta(BuildContext context, WidgetRef ref, AppState s, String today, List<Task> staged, int done, StreakInfo streak) {
    final cc = context.cc;
    if (streak.committedToday) {
      return CCard(
        child: Row(children: [
          Icon(Icons.verified_rounded, color: cc.success),
          const SizedBox(width: 12),
          Expanded(
            child: Text('Day committed. Come back tomorrow — or add more for the log.',
                style: context.text.bodyMedium),
          ),
        ]),
      );
    }
    if (done > 0) {
      return FilledButton.icon(
        onPressed: () => context.push('/commit'),
        icon: const Icon(Icons.commit_rounded),
        label: Text('Commit the day · $done change${done == 1 ? '' : 's'}'),
      );
    }
    if (staged.isEmpty) {
      return FilledButton.icon(
        onPressed: () => showCaptureSheet(context),
        icon: const Icon(Icons.add_task_rounded),
        label: const Text('Stage today (git add)'),
      );
    }
    return CCard(
      child: Row(children: [
        Icon(Icons.bolt_rounded, color: cc.warning),
        const SizedBox(width: 12),
        Expanded(
          child: Text('Finish one staged task to unlock tonight\'s commit. Bad day? Hold a task for its 2-minute version.',
              style: context.text.bodyMedium),
        ),
      ]),
    );
  }
}

class _SuggestionCard extends ConsumerWidget {
  final Suggestion suggestion;
  const _SuggestionCard({required this.suggestion});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final n = ref.read(appProvider.notifier);
    final cc = context.cc;
    return CCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.call_merge_rounded, color: cc.idea, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(suggestion.title, style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w700))),
        ]),
        const SizedBox(height: 6),
        Text(suggestion.reason, style: context.text.bodySmall?.copyWith(color: cc.textSecondary)),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => n.dismissSuggestion(suggestion.title),
              child: const Text('Close'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton(
              onPressed: () => n.acceptSuggestion(
                title: suggestion.title,
                skill: suggestion.skill,
                type: suggestion.type,
                difficulty: suggestion.difficulty,
                fallback: suggestion.fallback,
                rule: suggestion.rule,
              ),
              child: const Text('Merge'),
            ),
          ),
        ]),
      ]),
    );
  }
}

class _PlatformCard extends StatelessWidget {
  final String title, value, caption;
  final Color color;
  final String? error;
  final double? progress;
  const _PlatformCard({required this.title, required this.value, required this.caption, required this.color, this.error, this.progress});

  @override
  Widget build(BuildContext context) => CCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Text(title, style: context.text.labelLarge),
          ]),
          const SizedBox(height: 8),
          Text(value, style: AppTheme.mono(context, size: 28, weight: FontWeight.w800)),
          Text(caption, style: context.text.bodySmall?.copyWith(color: context.cc.textSecondary)),
          if (progress != null) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(value: progress, minHeight: 6, color: context.scheme.primary, backgroundColor: context.cc.surfaceRaised),
            ),
          ],
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('Showing cached data · $error', style: context.text.labelSmall?.copyWith(color: context.cc.warning)),
            ),
        ]),
      );
}

/// Monday "release notes": last week's shipped work, framed as a fresh start.
class _WeeklyRecap extends ConsumerWidget {
  final String today;
  const _WeeklyRecap({required this.today});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appProvider);
    final from = addDays(today, -7);
    final week = s.commits.where((c) => !c.frozen && c.day.compareTo(from) >= 0 && c.day.compareTo(today) < 0).toList();
    if (week.isEmpty) return const SizedBox.shrink();
    final xp = week.fold<int>(0, (a, c) => a + c.xp);
    final tasks = week.fold<int>(0, (a, c) => a + c.tasks);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SectionTitle('Release notes · last week'),
      CCard(
        child: Text('You committed ${week.length} day${week.length == 1 ? '' : 's'}, shipped $tasks changes and earned $xp xp. '
            'New week, new branch — what do you want to ship?',
            style: context.text.bodyMedium),
      ),
    ]);
  }
}
