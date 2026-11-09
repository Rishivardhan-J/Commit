import '../core/utils/day_key.dart';
import '../data/models.dart';

/// How much of a rule's metric happened today according to cached snapshots.
int metricToday(AppState s, String metric, String today) {
  switch (metric) {
    case 'lc.solved':
      return s.snapshots['leetcode']?.activity[today] ?? 0;
    case 'gh.commits':
      return s.snapshots['github']?.activity[today] ?? 0;
  }
  return 0;
}

/// Tasks that real activity has now satisfied ("CI passed").
List<Task> satisfiedTasks(AppState s, String today) => [
      for (final t in s.tasks)
        if (!t.done &&
            t.rule != null &&
            t.stagedFor == today &&
            metricToday(s, t.rule!.metric, today) >= t.rule!.target)
          t,
    ];

({int have, int need})? ruleProgress(AppState s, Task t, String today) {
  final r = t.rule;
  if (r == null) return null;
  return (have: metricToday(s, r.metric, today).clamp(0, r.target), need: r.target);
}

int unusedDaysSince(String? d, String today) => d == null ? 999 : daysBetween(d, today);
