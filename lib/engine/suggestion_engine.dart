import '../data/models.dart';

class Suggestion {
  final String title;
  final String skill;
  final TaskType type;
  final int difficulty;
  final String reason;
  final String fallback;
  final AutoRule? rule;
  const Suggestion({
    required this.title,
    required this.skill,
    required this.type,
    required this.difficulty,
    required this.reason,
    required this.fallback,
    this.rule,
  });
}

const coreTopics = {
  'Array': 'Arrays',
  'Dynamic Programming': 'Dynamic Programming',
  'Graph': 'Graphs',
  'Tree': 'Trees',
  'Binary Search': 'Binary Search',
  'Hash Table': 'Hashing',
  'Linked List': 'Linked Lists',
  'Backtracking': 'Backtracking',
};

/// "PRs from future you": weak LeetCode topics first, then neglected focus skills.
List<Suggestion> buildSuggestions(AppState s, String today) {
  final out = <Suggestion>[];
  final lc = s.snapshots['leetcode'];
  if (lc != null && lc.breakdown.isNotEmpty) {
    final counts = {
      for (final e in coreTopics.entries) e.value: lc.breakdown[e.key] ?? 0,
    };
    final strongest = counts.values.fold<int>(0, (a, b) => a > b ? a : b);
    final weak = counts.entries.toList()..sort((a, b) => a.value.compareTo(b.value));
    for (final w in weak.take(2)) {
      if (strongest - w.value < 5) continue;
      out.add(Suggestion(
        title: 'Solve 3 ${w.key} problems',
        skill: w.key,
        type: TaskType.dsa,
        difficulty: 2,
        reason: 'You have solved $strongest in your strongest topic but only ${w.value} in ${w.key}.',
        fallback: 'Read one ${w.key} problem and sketch an approach',
        rule: const AutoRule('lc.solved', 3),
      ));
    }
  }
  final skills = s.focusSkills.isEmpty ? <String>[] : s.focusSkills;
  final byXp = [...skills]..sort((a, b) => (s.skillXp[a] ?? 0).compareTo(s.skillXp[b] ?? 0));
  for (final k in byXp.take(2)) {
    final recent = s.tasks.any((t) => t.skill == k && t.done);
    out.add(Suggestion(
      title: recent ? 'Level up $k with one focused session' : 'Start your first $k task',
      skill: k,
      type: TaskType.learning,
      difficulty: 1,
      reason: '$k is your lowest focus skill — a little here moves it fastest.',
      fallback: 'Spend 2 minutes reading about $k',
    ));
  }
  return [
    for (final x in out)
      if (!s.dismissedSuggestions.contains('$today|${x.title}') &&
          !s.tasks.any((t) => !t.done && t.title == x.title))
        x,
  ];
}
